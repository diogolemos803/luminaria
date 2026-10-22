import Foundation
import Combine
import CoreBluetooth

/// Situação da ligação com a lâmpada, do ponto de vista de quem usa o app.
enum LampLink: Equatable {
    /// Nenhuma lâmpada pareada neste iPhone.
    case noLamp
    case bluetoothOff
    case unauthorized
    /// Procurando uma lâmpada nova pra parear.
    case searching
    /// Lâmpada pareada, tentando conectar (inclui fora de alcance/desligada da tomada).
    case connecting
    /// Conectou numa lâmpada nova, esperando o iOS terminar o pareamento.
    case pairing
    case connected
    /// A lâmpada desfez o vínculo e desconectou: a janela de pareamento estava fechada.
    case pairingRejected
    /// O iPhone guarda uma chave antiga (a lâmpada apagou os pareamentos segurando o toque
    /// 10 s): só some esquecendo o aparelho em Ajustes → Bluetooth.
    case staleBond
    /// A lâmpada fala uma versão do protocolo que este app não conhece.
    case unsupportedVersion(UInt8)
}

protocol LampTransportDelegate: AnyObject {
    func transport(didChange link: LampLink)
    func transport(didPair identifier: UUID)
    func transport(didReceiveState bytes: [UInt8])
    func transport(didReadRoutine bytes: [UInt8])
    func transport(didFailWrite message: String)
}

/// O que o `LampManager` precisa de quem fala com a lâmpada. Duas implementações: a de
/// verdade (CoreBluetooth) e a simulada (pra ver as telas antes da placa chegar).
protocol LampTransport: AnyObject {
    var delegate: LampTransportDelegate? { get set }
    func connect(to identifier: UUID)
    func startPairing()
    func stopPairing()
    func disconnect()
    func send(_ bytes: [UInt8])
    func readRoutine()
}

/// Lâmpada SOVEE (Bluetooth) — singleton no mesmo estilo de `AlarmManager`/
/// `ScreenTimeManager`. Guarda o identificador da lâmpada pareada, reconecta sozinho
/// enquanto o app está aberto, acerta a hora da lâmpada a cada conexão (e sempre que ela
/// avisa que perdeu a hora) e expõe o estado que a própria lâmpada informa.
///
/// **Sem modo de segundo plano `bluetooth-central` de propósito**: a lâmpada roda a luz
/// da manhã sozinha pelo relógio dela (RTC com pilha), então o app só precisa estar
/// conectado com a tela aberta — na hora de encostar na luminária ou mexendo na tela da
/// lâmpada. Ver CLAUDE.md.
final class LampManager: ObservableObject {
    static let shared = LampManager()

    @Published private(set) var link: LampLink = .noLamp
    @Published private(set) var state: LampState?
    /// Rotina que está de fato gravada na lâmpada (lida da característica ROUTINE).
    @Published private(set) var savedRoutine: LampRoutine?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isSimulated: Bool
    @Published private(set) var lampID: UUID?
    /// "Cancelar a luz de hoje" já mandado desde a última gravação da luz da manhã.
    @Published private(set) var isTodayCancelled = false
    /// Última cor escolhida à mão (pra ligar de novo na mesma cor).
    @Published private(set) var manualMix: Double
    @Published private(set) var manualBrightness: Double
    /// Última vez que a pessoa mexeu na cor/brilho: enquanto mexe, a tela mostra o valor do
    /// controle na hora em vez de esperar a resposta da lâmpada (senão a cor anda aos saltos).
    @Published private(set) var lastManualEdit = Date.distantPast

    var hasLamp: Bool { lampID != nil }
    var isConnected: Bool { link == .connected }
    /// Acesa agora, segundo a própria lâmpada.
    var isLit: Bool { isConnected && !(state?.color.isOff ?? true) }

    private static let realIDKey = "com.luminaria.lamp.id"
    private static let simulatedIDKey = "com.luminaria.lamp.simulatedID"
    private static let simulatedKey = "com.luminaria.lamp.isSimulated"
    private static let mixKey = "com.luminaria.lamp.manualMix"
    private static let brightnessKey = "com.luminaria.lamp.manualBrightness"

    private var transport: LampTransport
    private var hasStarted = false
    /// Depois de cada escrita, o byte 11 do próximo STATE diz se a lâmpada aceitou.
    private var awaitingResult = false
    private var lastClockSent: Date?
    /// Noite pedida com a lâmpada ainda conectando (ver `beginNight`).
    private var pendingNight: (commands: [LampCommand], completion: (Bool) -> Void)?
    private var pendingNightTimeout: DispatchWorkItem?
    /// Desarme pedido com a lâmpada longe: manda na próxima conexão.
    private var pendingEndNight = false
    private var lastColorSend = Date.distantPast
    /// No máximo ~16 comandos de cor por segundo enquanto a pessoa arrasta o controle.
    private static let colorSendInterval: TimeInterval = 0.06
    private var trailingColorSend: DispatchWorkItem?

    private init() {
        let defaults = UserDefaults.standard
        let simulated = defaults.bool(forKey: Self.simulatedKey)
        isSimulated = simulated
        lampID = (defaults.string(forKey: simulated ? Self.simulatedIDKey : Self.realIDKey)).flatMap(UUID.init(uuidString:))
        manualMix = defaults.object(forKey: Self.mixKey) as? Double ?? LampPreset.all[2].color.mix
        manualBrightness = defaults.object(forKey: Self.brightnessKey) as? Double ?? 0.8
        transport = simulated ? SimulatedLampTransport() : BluetoothLampTransport()
        transport.delegate = self
    }

    // MARK: - Ciclo de vida

    /// Chamado quando o app abre/volta pra frente. Só cria o `CBCentralManager` (e pede a
    /// permissão de Bluetooth) se já existir uma lâmpada pareada — quem não tem a lâmpada
    /// nunca vê o pedido.
    func start() {
        guard let lampID else { return }
        if hasStarted, link == .connected || link == .connecting { return }
        hasStarted = true
        transport.connect(to: lampID)
    }

    func startPairing() {
        errorMessage = nil
        link = .searching
        transport.startPairing()
    }

    func cancelPairing() {
        transport.stopPairing()
        if lampID == nil { link = .noLamp }
    }

    /// Esquece a lâmpada NESTE app. O pareamento do iOS (a chave guardada pelo sistema)
    /// não tem API pra apagar — a tela orienta a fazer isso em Ajustes → Bluetooth.
    func forget() {
        transport.disconnect()
        UserDefaults.standard.removeObject(forKey: isSimulated ? Self.simulatedIDKey : Self.realIDKey)
        lampID = nil
        link = .noLamp
        state = nil
        savedRoutine = nil
        errorMessage = nil
        hasStarted = false
        failPendingNight()
    }

    /// Troca entre a lâmpada de verdade e a simulada (até a placa chegar).
    func setSimulated(_ simulated: Bool) {
        guard simulated != isSimulated else { return }
        transport.disconnect()
        failPendingNight()
        isSimulated = simulated
        UserDefaults.standard.set(simulated, forKey: Self.simulatedKey)
        state = nil
        savedRoutine = nil
        errorMessage = nil
        hasStarted = false
        transport = simulated ? SimulatedLampTransport() : BluetoothLampTransport()
        transport.delegate = self
        lampID = UserDefaults.standard.string(forKey: simulated ? Self.simulatedIDKey : Self.realIDKey).flatMap(UUID.init(uuidString:))
        link = .noLamp
        start()
    }

    // MARK: - Controle manual

    /// Cor escolhida na tela (mistura + brilho). Enquanto a pessoa arrasta o controle, manda
    /// no máximo ~16 comandos por segundo, sempre terminando no valor final.
    func setManual(mix: Double, brightness: Double) {
        manualMix = mix
        manualBrightness = brightness
        lastManualEdit = Date()
        UserDefaults.standard.set(mix, forKey: Self.mixKey)
        UserDefaults.standard.set(brightness, forKey: Self.brightnessKey)
        let elapsed = Date().timeIntervalSince(lastColorSend)
        if elapsed >= Self.colorSendInterval {
            trailingColorSend?.cancel()
            trailingColorSend = nil
            sendManualColor()
        } else if trailingColorSend == nil {
            let work = DispatchWorkItem { [weak self] in
                self?.trailingColorSend = nil
                self?.sendManualColor()
            }
            trailingColorSend = work
            DispatchQueue.main.asyncAfter(deadline: .now() + (Self.colorSendInterval - elapsed), execute: work)
        }
    }

    private func sendManualColor() {
        lastColorSend = Date()
        send(.color(LampColor(mix: manualMix, brightness: max(manualBrightness, 0.01))))
    }

    func turnOn() { sendManualColor() }
    func turnOff() { send(.off) }
    func identify() { send(.identify) }

    func cancelToday() {
        if send(.cancelToday) { isTodayCancelled = true }
    }

    // MARK: - Noite (integração com o modo noite)

    /// No instante em que a luminária (NFC) é reconhecida com o modo noite armado: a
    /// lâmpada começa a apagar devagar e a luz da manhã fica gravada nela — de uma vez só,
    /// só pra manhã seguinte. Se a lâmpada ainda estiver conectando, espera alguns segundos;
    /// `completion(false)` = não respondeu (a tela avisa que a luz da manhã não vai acender).
    /// Sem lâmpada pareada, não faz nada.
    func beginNight(routine: SleepRoutine, alarmDate: Date?, completion: @escaping (Bool) -> Void) {
        guard hasLamp else { completion(true); return }
        var commands: [LampCommand] = []
        if routine.lampSleep.enabled {
            let color = LampColor(mix: routine.lampSleep.mix, brightness: max(routine.lampSleep.brightness, 0.01))
            let minutes = min(max(routine.lampSleep.minutes, LampCommand.fadeRange.lowerBound), LampCommand.fadeRange.upperBound)
            commands.append(.fadeOut(from: color, minutes: minutes))
        }
        if routine.lampWake.enabled, let alarmDate {
            commands.append(.writeRoutine(routine.lampWake.lampRoutine(alarmDate: alarmDate)))
        } else {
            // Garante que nenhuma luz da manhã antiga fique gravada.
            commands.append(.writeRoutine(.disabled))
        }
        pendingEndNight = false
        isTodayCancelled = false
        if isConnected {
            commands.forEach { send($0) }
            refreshRoutineSoon()
            completion(true)
            return
        }
        failPendingNight()
        pendingNight = (commands, completion)
        start()
        let timeout = DispatchWorkItem { [weak self] in self?.failPendingNight() }
        pendingNightTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: timeout)
    }

    /// Desarme pelo botão redondo: cancela o apagar devagar e a luz da manhã daquela noite.
    func endNight() {
        guard hasLamp else { return }
        failPendingNight(callCompletion: false)
        guard isConnected else {
            pendingEndNight = true
            return
        }
        sendEndNight()
    }

    private func sendEndNight() {
        pendingEndNight = false
        if state?.mode == .fading { send(.off) }
        send(.cancelToday)
        send(.writeRoutine(.disabled))
        refreshRoutineSoon()
    }

    private func failPendingNight(callCompletion: Bool = true) {
        pendingNightTimeout?.cancel()
        pendingNightTimeout = nil
        guard let pending = pendingNight else { return }
        pendingNight = nil
        if callCompletion { pending.completion(false) }
    }

    // MARK: - Envio

    @discardableResult
    private func send(_ command: LampCommand) -> Bool {
        guard isConnected else {
            errorMessage = hasLamp ? "A lâmpada não está conectada. Chegue perto dela e confira se está na tomada." : nil
            return false
        }
        errorMessage = nil
        awaitingResult = true
        if case .setClock = command { lastClockSent = Date() }
        transport.send(command.bytes())
        return true
    }

    private func sendClockIfNeeded(force: Bool = false) {
        if !force, let lastClockSent, Date().timeIntervalSince(lastClockSent) < 10 { return }
        send(.setClock(Date()))
    }

    private func refreshRoutineSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, self.isConnected else { return }
            self.transport.readRoutine()
        }
    }

    private func didBecomeConnected() {
        sendClockIfNeeded(force: true)
        transport.readRoutine()
        if let pending = pendingNight {
            pendingNightTimeout?.cancel()
            pendingNightTimeout = nil
            pendingNight = nil
            pending.commands.forEach { send($0) }
            refreshRoutineSoon()
            pending.completion(true)
        } else if pendingEndNight {
            sendEndNight()
        }
    }
}

extension LampManager: LampTransportDelegate {
    func transport(didChange newLink: LampLink) {
        if case .unsupportedVersion = link, newLink == .connected { return }
        let wasConnected = isConnected
        link = newLink
        if newLink == .connected, !wasConnected {
            didBecomeConnected()
        }
        if newLink != .connected { awaitingResult = false }
    }

    func transport(didPair identifier: UUID) {
        lampID = identifier
        UserDefaults.standard.set(identifier.uuidString, forKey: isSimulated ? Self.simulatedIDKey : Self.realIDKey)
        hasStarted = true
    }

    func transport(didReceiveState bytes: [UInt8]) {
        guard let version = LampState.version(of: bytes) else { return }
        guard version == LampProtocol.version else {
            link = .unsupportedVersion(version)
            state = nil
            return
        }
        guard let newState = LampState(bytes: bytes) else { return }
        state = newState
        if awaitingResult {
            awaitingResult = false
            if let message = newState.lastResult.message { errorMessage = message }
        }
        if !newState.clockValid, isConnected { sendClockIfNeeded() }
    }

    func transport(didReadRoutine bytes: [UInt8]) {
        savedRoutine = LampRoutine(payload: bytes)
    }

    func transport(didFailWrite message: String) {
        errorMessage = "A lâmpada não recebeu o comando (\(message))."
    }
}

// MARK: - Bluetooth de verdade

/// CoreBluetooth. Tudo na fila principal (`queue: nil`), como o resto do app.
///
/// **Não testado com a placa** (ela ainda não foi fabricada): pareamento "Just Works", a
/// recusa fora da janela de pareamento e o alcance precisam de teste real — ver CLAUDE.md.
final class BluetoothLampTransport: NSObject, LampTransport {
    weak var delegate: LampTransportDelegate?

    private let serviceUUID = CBUUID(string: LampProtocol.serviceUUID)
    private let commandUUID = CBUUID(string: LampProtocol.commandUUID)
    private let stateUUID = CBUUID(string: LampProtocol.stateUUID)
    private let routineUUID = CBUUID(string: LampProtocol.routineUUID)

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var commandChar: CBCharacteristic?
    private var stateChar: CBCharacteristic?
    private var routineChar: CBCharacteristic?
    private var wantedID: UUID?
    private var isPairingNewLamp = false
    /// Primeira leitura/notificação protegida deu certo = conexão criptografada (pareada).
    private var isEncrypted = false

    func connect(to identifier: UUID) {
        wantedID = identifier
        isPairingNewLamp = false
        ensureCentralThenProceed()
    }

    func startPairing() {
        disconnectPeripheral()
        wantedID = nil
        isPairingNewLamp = true
        ensureCentralThenProceed()
    }

    func stopPairing() {
        guard isPairingNewLamp else { return }
        isPairingNewLamp = false
        central?.stopScan()
        if !isEncrypted { disconnectPeripheral() }
    }

    func disconnect() {
        wantedID = nil
        isPairingNewLamp = false
        central?.stopScan()
        disconnectPeripheral()
    }

    func send(_ bytes: [UInt8]) {
        guard let peripheral, let commandChar else { return }
        peripheral.writeValue(Data(bytes), for: commandChar, type: .withResponse)
    }

    func readRoutine() {
        guard let peripheral, let routineChar else { return }
        peripheral.readValue(for: routineChar)
    }

    private func ensureCentralThenProceed() {
        if central == nil {
            // A primeira criação dispara o pedido de permissão de Bluetooth (texto em
            // NSBluetoothAlwaysUsageDescription); o resto segue em `centralManagerDidUpdateState`.
            central = CBCentralManager(delegate: self, queue: nil)
        } else {
            proceed()
        }
    }

    private func proceed() {
        guard let central, central.state == .poweredOn else { return }
        if isPairingNewLamp {
            delegate?.transport(didChange: .searching)
            central.scanForPeripherals(withServices: [serviceUUID])
        } else if let wantedID {
            delegate?.transport(didChange: .connecting)
            if let known = central.retrievePeripherals(withIdentifiers: [wantedID]).first {
                attach(known)
                // Conexão "pendente": não expira — o iOS completa quando a lâmpada aparecer.
                central.connect(known)
            } else {
                central.scanForPeripherals(withServices: [serviceUUID])
            }
        }
    }

    private func attach(_ p: CBPeripheral) {
        peripheral = p
        p.delegate = self
    }

    private func disconnectPeripheral() {
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
        peripheral = nil
        commandChar = nil
        stateChar = nil
        routineChar = nil
        isEncrypted = false
    }
}

extension BluetoothLampTransport: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            proceed()
        case .poweredOff:
            delegate?.transport(didChange: .bluetoothOff)
        case .unauthorized:
            delegate?.transport(didChange: .unauthorized)
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if isPairingNewLamp {
            central.stopScan()
            attach(peripheral)
            delegate?.transport(didChange: .pairing)
            central.connect(peripheral)
        } else if peripheral.identifier == wantedID {
            central.stopScan()
            attach(peripheral)
            central.connect(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isEncrypted = false
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard wantedID != nil || isPairingNewLamp else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.peripheral === peripheral else { return }
            central.connect(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        commandChar = nil
        stateChar = nil
        routineChar = nil
        let wasEncrypted = isEncrypted
        isEncrypted = false
        if let cbError = error as? CBError, cbError.code == .peerRemovedPairingInformation {
            wantedID = nil
            isPairingNewLamp = false
            self.peripheral = nil
            delegate?.transport(didChange: .staleBond)
            return
        }
        if isPairingNewLamp && !wasEncrypted {
            // Firmware: celular novo fora da janela de pareamento → a lâmpada desfaz o
            // vínculo e desconecta. Não confirmado em aparelho (ver CLAUDE.md).
            isPairingNewLamp = false
            self.peripheral = nil
            delegate?.transport(didChange: .pairingRejected)
            return
        }
        guard wantedID != nil, self.peripheral === peripheral else { return }
        delegate?.transport(didChange: .connecting)
        central.connect(peripheral)
    }
}

extension BluetoothLampTransport: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else { return }
        peripheral.discoverCharacteristics([commandUUID, stateUUID, routineUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case commandUUID: commandChar = characteristic
            case stateUUID: stateChar = characteristic
            case routineUUID: routineChar = characteristic
            default: break
            }
        }
        guard let stateChar else { return }
        // Todas as características exigem conexão criptografada: o primeiro acesso dispara
        // o pareamento do iOS ("Just Works") se ainda não houver vínculo.
        peripheral.setNotifyValue(true, for: stateChar)
        peripheral.readValue(for: stateChar)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            if isPairingNewLamp && !isEncrypted {
                delegate?.transport(didFailWrite: error.localizedDescription)
            }
            return
        }
        guard let data = characteristic.value else { return }
        if !isEncrypted {
            isEncrypted = true
            if isPairingNewLamp {
                isPairingNewLamp = false
                wantedID = peripheral.identifier
                delegate?.transport(didPair: peripheral.identifier)
            }
            delegate?.transport(didChange: .connected)
        }
        if characteristic.uuid == stateUUID {
            delegate?.transport(didReceiveState: [UInt8](data))
        } else if characteristic.uuid == routineUUID {
            delegate?.transport(didReadRoutine: [UInt8](data))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error { delegate?.transport(didFailWrite: error.localizedDescription) }
    }
}

// MARK: - Lâmpada simulada

/// Imita a lâmpada (firmware v2) pra validar as telas antes da placa chegar: limitador,
/// recusa de valores fora da faixa, perda de hora (começa sem hora até o app acertar),
/// apagar devagar, piscar ao identificar e a rampa da luz da manhã de uma vez só. O
/// pareamento sempre dá certo. Responde com os mesmos bytes da lâmpada real, então o
/// `LampManager` passa pelo mesmo caminho de leitura.
final class SimulatedLampTransport: LampTransport {
    weak var delegate: LampTransportDelegate?

    static let simulatedID = UUID(uuidString: "5A1E0000-0000-4000-8000-5A1E5A1E5A1E")!

    private var timer: Timer?
    private var pendingWork: [DispatchWorkItem] = []
    private var connected = false

    private var color = LampColor.off
    private var mode = LampState.Mode.off
    private var limiter = false
    /// Diferença entre o relógio da lâmpada e o do iPhone; `nil` = perdeu a hora.
    private var clockOffset: TimeInterval?
    private var routine = LampRoutine.disabled
    private var lastResult = LampState.CommandResult.ok
    private var fade: (from: LampColor, start: Date, minutes: Int)?
    private var dismissedAlarm: Date?
    private var blinkUntil: Date?

    func connect(to identifier: UUID) {
        cancelWork()
        later(0.6) { [weak self] in self?.becomeConnected() }
    }

    func startPairing() {
        cancelWork()
        delegate?.transport(didChange: .searching)
        later(1.5) { [weak self] in self?.delegate?.transport(didChange: .pairing) }
        later(2.6) { [weak self] in
            guard let self else { return }
            self.delegate?.transport(didPair: Self.simulatedID)
            self.becomeConnected()
        }
    }

    func stopPairing() {
        cancelWork()
    }

    func disconnect() {
        cancelWork()
        connected = false
        timer?.invalidate()
        timer = nil
    }

    func send(_ bytes: [UInt8]) {
        guard connected else { return }
        apply(bytes)
        // A lâmpada aplica em ~10 ms e notifica.
        soon(0.05) { [weak self] in self?.tick() }
    }

    func readRoutine() {
        guard connected else { return }
        soon(0.05) { [weak self] in
            guard let self, self.connected else { return }
            self.delegate?.transport(didReadRoutine: self.routine.payload)
        }
    }

    private func becomeConnected() {
        connected = true
        delegate?.transport(didChange: .connected)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        tick()
    }

    private func later(_ seconds: TimeInterval, _ block: @escaping () -> Void) {
        let work = DispatchWorkItem(block: block)
        pendingWork.append(work)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    /// Respostas rápidas da "lâmpada" (não entram em `pendingWork`, que só guarda as etapas
    /// de conexão/pareamento canceláveis).
    private func soon(_ seconds: TimeInterval, _ block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: block)
    }

    private func cancelWork() {
        pendingWork.forEach { $0.cancel() }
        pendingWork.removeAll()
    }

    private var lampNow: Date? { clockOffset.map { Date().addingTimeInterval($0) } }

    private func limited(_ c: LampColor) -> LampColor {
        let sum = Int(c.amber) + Int(c.red)
        guard sum > LampProtocol.powerLimit else { limiter = false; return c }
        limiter = true
        let k = Double(LampProtocol.powerLimit) / Double(sum)
        return LampColor(amber: UInt8(Double(c.amber) * k), red: UInt8(Double(c.red) * k))
    }

    /// Quem manda por último vence: cor/desligar pelo celular dispensa a rotina do dia.
    private func dismissRunningRoutine() {
        if mode == .routine, let window = currentRoutineWindow() { dismissedAlarm = window.alarm }
    }

    private func apply(_ bytes: [UInt8]) {
        guard let opcode = bytes.first.flatMap(LampOpcode.init(rawValue:)) else {
            lastResult = .badOpcode
            return
        }
        let expected: [LampOpcode: Int] = [
            .color: 3, .off: 1, .setClock: 7, .writeRoutine: 1 + LampRoutine.byteCount,
            .cancelToday: 1, .identify: 1, .fadeOut: 4,
        ]
        guard bytes.count == expected[opcode] else {
            lastResult = .badLength
            return
        }
        lastResult = .ok
        switch opcode {
        case .color:
            dismissRunningRoutine()
            fade = nil
            color = limited(LampColor(amber: bytes[1], red: bytes[2]))
            mode = color.isOff ? .off : .manual
        case .off:
            dismissRunningRoutine()
            fade = nil
            color = .off
            mode = .off
        case .setClock:
            var comps = DateComponents()
            comps.year = 2000 + Int(bytes[1])
            comps.month = Int(bytes[2])
            comps.day = Int(bytes[3])
            comps.hour = Int(bytes[4])
            comps.minute = Int(bytes[5])
            comps.second = Int(bytes[6])
            guard (1...12).contains(Int(bytes[2])), (1...31).contains(Int(bytes[3])), Int(bytes[4]) < 24,
                  Int(bytes[5]) < 60, Int(bytes[6]) < 60, let date = Calendar.current.date(from: comps) else {
                lastResult = .outOfRange
                return
            }
            clockOffset = date.timeIntervalSinceNow
        case .writeRoutine:
            guard let newRoutine = LampRoutine(payload: Array(bytes.dropFirst())), newRoutine.isValid,
                  bytes[1] <= 1 else {
                lastResult = .outOfRange
                return
            }
            routine = newRoutine
            dismissedAlarm = nil
        case .cancelToday:
            if let window = currentRoutineWindow() ?? nextRoutineWindow() { dismissedAlarm = window.alarm }
            if mode == .routine { color = .off; mode = .off }
        case .identify:
            blinkUntil = Date().addingTimeInterval(1.6)
        case .fadeOut:
            guard LampCommand.fadeRange.contains(Int(bytes[3])) else {
                lastResult = .outOfRange
                return
            }
            dismissRunningRoutine()
            let from = limited(LampColor(amber: bytes[1], red: bytes[2]))
            fade = (from, Date(), Int(bytes[3]))
            color = from
            mode = .fading
        }
    }

    /// Janela [despertador − rampa, despertador + mantém] que contém agora (relógio da lâmpada).
    private func currentRoutineWindow() -> (start: Date, alarm: Date, end: Date)? {
        guard routine.enabled, let now = lampNow else { return nil }
        let calendar = Calendar.current
        for dayOffset in [0, 1, -1] {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let alarm = calendar.date(bySettingHour: routine.hour, minute: routine.minute, second: 0, of: day),
                  routine.days & LampRoutine.dayBit(for: alarm, calendar: calendar) != 0 else { continue }
            let start = alarm.addingTimeInterval(-Double(routine.rampMinutes) * 60)
            let end = alarm.addingTimeInterval(Double(routine.holdMinutes) * 60)
            if now >= start && now < end { return (start, alarm, end) }
        }
        return nil
    }

    private func nextRoutineWindow() -> (start: Date, alarm: Date, end: Date)? {
        guard routine.enabled, let now = lampNow else { return nil }
        let calendar = Calendar.current
        for dayOffset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let alarm = calendar.date(bySettingHour: routine.hour, minute: routine.minute, second: 0, of: day),
                  routine.days & LampRoutine.dayBit(for: alarm, calendar: calendar) != 0 else { continue }
            let start = alarm.addingTimeInterval(-Double(routine.rampMinutes) * 60)
            if start > now { return (start, alarm, alarm.addingTimeInterval(Double(routine.holdMinutes) * 60)) }
        }
        return nil
    }

    private func tick() {
        guard connected else { return }
        let now = Date()

        if let fade {
            let t = now.timeIntervalSince(fade.start) / (Double(fade.minutes) * 60)
            if t >= 1 {
                self.fade = nil
                color = .off
                mode = .off
            } else {
                color = LampColor(amber: UInt8(Double(fade.from.amber) * (1 - t)), red: UInt8(Double(fade.from.red) * (1 - t)))
                mode = .fading
            }
        } else if let window = currentRoutineWindow(), window.alarm != dismissedAlarm, let lampNow {
            let fromMix = routine.from.mix, toMix = routine.to.mix
            let fromB = Double(routine.fromBrightness) / 255, toB = Double(routine.toBrightness) / 255
            if lampNow < window.alarm {
                let k = lampNow.timeIntervalSince(window.start) / window.alarm.timeIntervalSince(window.start)
                color = limited(LampColor(mix: fromMix + (toMix - fromMix) * k, brightness: fromB + (toB - fromB) * k))
            } else {
                color = limited(LampColor(mix: toMix, brightness: toB))
            }
            mode = .routine
        } else if mode == .routine {
            // Fim da janela (ou dispensada): apaga; rotina de uma vez só se desliga sozinha.
            color = .off
            mode = .off
            if routine.onlyNext { routine.enabled = false }
        }

        var shown = color
        if let blinkUntil {
            if now < blinkUntil {
                let phase = Int(now.timeIntervalSince(blinkUntil.addingTimeInterval(-1.6)) / 0.27)
                shown = phase % 2 == 0 ? LampColor(amber: 255, red: 0) : .off
                soon(0.27) { [weak self] in self?.tick() }
            } else {
                self.blinkUntil = nil
            }
        }

        let clock = (lampNow ?? Date(timeIntervalSince1970: 946_684_800))
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: clock)
        let state = LampState(
            mode: mode, color: shown, clockValid: clockOffset != nil, limiterActive: limiter,
            pairingWindowOpen: false, routineEnabled: routine.enabled, clock: comps, lastResult: lastResult
        )
        delegate?.transport(didReceiveState: state.bytes)
    }
}
