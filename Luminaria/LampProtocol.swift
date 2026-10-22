import Foundation

/// Protocolo Bluetooth (BLE) da lâmpada SOVEE — placa própria com ESP32-C3, duas fitas de
/// LED (âmbar e vermelha, sem azul), 12 V. Só bytes aqui: nada de CoreBluetooth nem de
/// SwiftUI, pra a lâmpada simulada (`SimulatedLampTransport`) e a de verdade
/// (`BluetoothLampTransport`) falarem exatamente a mesma língua.
///
/// **Versão 2 do protocolo** — a v1 é a que o firmware tinha em 2026-10-18; a v2 são as
/// três mudanças pedidas pelo app pra caber nas telas aprovadas (ver CLAUDE.md, pendência
/// da lâmpada): rotina de uma vez só (bit7 de `dias`), apagar devagar (opcode 0x07, modo 3
/// no STATE) e brilho separado da cor no amanhecer (rotina com 12 bytes). Se o firmware
/// implementar diferente, só este arquivo muda.
enum LampProtocol {
    static let version: UInt8 = 2
    /// Nome da lâmpada nas telas do app.
    static let displayName = "Lâmpada SOVEE"
    /// Nomes que a lâmpada anuncia por Bluetooth (o que o iOS mostra no aviso de
    /// pareamento e em Ajustes → Bluetooth). O app NÃO procura por nome — a busca é pelo
    /// `serviceUUID` —, então trocar o nome no firmware não quebra nada; esta lista só
    /// serve pros textos que mandam a pessoa achar a lâmpada nos Ajustes. "Zleepy Lamp" é
    /// o nome do firmware atual; "SOVEE Lamp" é o nome depois do rebrand (pendente de
    /// firmware, ver CLAUDE.md).
    static let advertisedNames = ["SOVEE Lamp", "Zleepy Lamp"]
    /// Como os textos citam o nome que aparece nos Ajustes do iPhone.
    static let settingsName = "\(advertisedNames[0]) (ou \(advertisedNames[1]))"
    static let serviceUUID = "5a1e0000-4c41-4d50-8000-7a6c65657079"
    /// Escrever, sempre com resposta (`.withResponse`).
    static let commandUUID = "5a1e0001-4c41-4d50-8000-7a6c65657079"
    /// Ler + notificar (a cada mudança e ~1 s).
    static let stateUUID = "5a1e0002-4c41-4d50-8000-7a6c65657079"
    /// Ler: a rotina que está de fato gravada na lâmpada (ela é a fonte da verdade).
    static let routineUUID = "5a1e0003-4c41-4d50-8000-7a6c65657079"
    /// Limitador de corrente da lâmpada: a soma das duas fitas nunca passa de 160% de 255.
    static let powerLimit = 408
}

enum LampOpcode: UInt8 {
    case color = 0x01
    case off = 0x02
    case setClock = 0x03
    case writeRoutine = 0x04
    case cancelToday = 0x05
    case identify = 0x06
    /// v2: acende nesta cor e apaga linearmente em N minutos.
    case fadeOut = 0x07
}

/// Uma cor da lâmpada = quanto de cada fita (0–255). Só existe o espectro amarelo →
/// laranja → vermelho: não dá pra fazer branco, verde nem azul.
///
/// Na tela, a cor é escolhida como **mistura** (0 = amarelo, só âmbar; 1 = vermelho, só
/// vermelho) e **brilho** (0–1). A mistura preserva a proporção exata entre as fitas; a
/// "cor cheia" de uma mistura põe o canal maior em 255 e respeita o limitador (soma ≤
/// 408), então o seletor nunca pede algo que a lâmpada vá cortar.
struct LampColor: Equatable, Codable {
    var amber: UInt8
    var red: UInt8

    static let off = LampColor(amber: 0, red: 0)

    init(amber: UInt8, red: UInt8) {
        self.amber = amber
        self.red = red
    }

    init(mix: Double, brightness: Double) {
        let full = Self.full(mix: mix)
        let b = min(max(brightness, 0), 1)
        amber = UInt8(clamping: Int((full.amber * b).rounded()))
        red = UInt8(clamping: Int((full.red * b).rounded()))
    }

    var isOff: Bool { amber == 0 && red == 0 }

    /// 0 = amarelo (só âmbar) … 1 = vermelho (só vermelho).
    var mix: Double {
        let total = Int(amber) + Int(red)
        return total == 0 ? 0 : Double(red) / Double(total)
    }

    /// Brilho relativo à cor cheia da mesma mistura.
    var brightness: Double {
        let full = Self.full(mix: mix)
        let byAmber = full.amber > 0 ? Double(amber) / full.amber : 0
        let byRed = full.red > 0 ? Double(red) / full.red : 0
        return min(max(byAmber, byRed), 1)
    }

    /// A mesma mistura no brilho máximo (é o que a rotina v2 manda como cor; o brilho vai
    /// em byte separado).
    var atFullBrightness: LampColor { LampColor(mix: mix, brightness: 1) }

    /// Potência em % de uma fita (a lâmpada aguenta até 160%).
    var powerPercent: Int { Int((Double(Int(amber) + Int(red)) / 255 * 100).rounded()) }

    static func full(mix: Double) -> (amber: Double, red: Double) {
        let m = min(max(mix, 0), 1)
        let k = 255 / max(1 - m, m)
        var a = k * (1 - m)
        var r = k * m
        let sum = a + r
        let limit = Double(LampProtocol.powerLimit)
        if sum > limit {
            a *= limit / sum
            r *= limit / sum
        }
        return (a, r)
    }
}

/// As 5 mesclas prontas (âmbar, vermelho) — todas dentro do limitador.
struct LampPreset: Identifiable {
    let id: String
    let name: String
    let color: LampColor

    static let all: [LampPreset] = [
        LampPreset(id: "amarelo", name: "Amarelo", color: LampColor(amber: 255, red: 0)),
        LampPreset(id: "ambar", name: "Âmbar quente", color: LampColor(amber: 255, red: 50)),
        LampPreset(id: "laranja", name: "Laranja", color: LampColor(amber: 204, red: 102)),
        LampPreset(id: "laranjaVermelho", name: "Laranja-avermelhado", color: LampColor(amber: 100, red: 180)),
        LampPreset(id: "vermelho", name: "Vermelho", color: LampColor(amber: 0, red: 255)),
    ]

    /// Nome pra uma mistura qualquer: o da mescla pronta se estiver bem perto, senão a faixa.
    static func name(forMix mix: Double) -> String {
        if let nearest = all.min(by: { abs($0.color.mix - mix) < abs($1.color.mix - mix) }),
           abs(nearest.color.mix - mix) < 0.04 {
            return nearest.name
        }
        return mix < 0.5 ? "Entre amarelo e laranja" : "Entre laranja e vermelho"
    }
}

/// STATE (12 bytes, ler/notificar).
struct LampState: Equatable {
    enum Mode: UInt8 {
        case off = 0
        case manual = 1
        case routine = 2
        /// v2: apagando devagar (opcode 0x07).
        case fading = 3
    }

    enum CommandResult: UInt8 {
        case ok = 0
        case badOpcode = 1
        case badLength = 2
        case outOfRange = 3

        var message: String? {
            switch self {
            case .ok: return nil
            case .badOpcode: return "A lâmpada não reconheceu o comando. O firmware dela pode ser de outra versão."
            case .badLength: return "A lâmpada recusou o comando (tamanho errado). O firmware dela pode ser de outra versão."
            case .outOfRange: return "A lâmpada recusou um valor fora da faixa. Nada mudou nela."
            }
        }
    }

    static let byteCount = 12

    var version: UInt8
    var mode: Mode
    /// Cor atual, já depois do limitador e do fade.
    var color: LampColor
    var clockValid: Bool
    var limiterActive: Bool
    var pairingWindowOpen: Bool
    var routineEnabled: Bool
    /// Relógio da lâmpada (hora local); só confiável com `clockValid`.
    var clock: DateComponents
    var lastResult: CommandResult

    /// Versão do protocolo (byte 0) — lida antes de tudo, pra recusar versões desconhecidas
    /// com uma mensagem clara em vez de interpretar bytes de outro formato.
    static func version(of bytes: [UInt8]) -> UInt8? { bytes.first }

    init?(bytes: [UInt8]) {
        guard bytes.count >= Self.byteCount, bytes[0] == LampProtocol.version else { return nil }
        version = bytes[0]
        mode = Mode(rawValue: bytes[1]) ?? .manual
        color = LampColor(amber: bytes[2], red: bytes[3])
        let flags = bytes[4]
        clockValid = flags & 0b0001 != 0
        limiterActive = flags & 0b0010 != 0
        pairingWindowOpen = flags & 0b0100 != 0
        routineEnabled = flags & 0b1000 != 0
        var comps = DateComponents()
        comps.year = 2000 + Int(bytes[5])
        comps.month = Int(bytes[6])
        comps.day = Int(bytes[7])
        comps.hour = Int(bytes[8])
        comps.minute = Int(bytes[9])
        comps.second = Int(bytes[10])
        clock = comps
        lastResult = CommandResult(rawValue: bytes[11]) ?? .outOfRange
    }

    init(version: UInt8 = LampProtocol.version, mode: Mode, color: LampColor, clockValid: Bool, limiterActive: Bool,
         pairingWindowOpen: Bool, routineEnabled: Bool, clock: DateComponents, lastResult: CommandResult) {
        self.version = version
        self.mode = mode
        self.color = color
        self.clockValid = clockValid
        self.limiterActive = limiterActive
        self.pairingWindowOpen = pairingWindowOpen
        self.routineEnabled = routineEnabled
        self.clock = clock
        self.lastResult = lastResult
    }

    var bytes: [UInt8] {
        var flags: UInt8 = 0
        if clockValid { flags |= 0b0001 }
        if limiterActive { flags |= 0b0010 }
        if pairingWindowOpen { flags |= 0b0100 }
        if routineEnabled { flags |= 0b1000 }
        return [
            version, mode.rawValue, color.amber, color.red, flags,
            UInt8(clamping: (clock.year ?? 2000) - 2000), UInt8(clamping: clock.month ?? 1), UInt8(clamping: clock.day ?? 1),
            UInt8(clamping: clock.hour ?? 0), UInt8(clamping: clock.minute ?? 0), UInt8(clamping: clock.second ?? 0),
            lastResult.rawValue,
        ]
    }
}

/// Rotina de despertar gravada na lâmpada (comando 0x04; característica ROUTINE).
///
/// v2, 12 bytes: ligada, dias, hora, minuto, rampa_min, mantém_min, de_âmbar, de_vermelho,
/// de_brilho, para_âmbar, para_vermelho, para_brilho. As cores vão no brilho máximo e o
/// brilho em byte separado — senão "vermelho a 0%" viraria (0, 0) e perderia a cor.
/// `dias`: bit0 = segunda … bit6 = domingo; **bit7 = só a próxima ocorrência** (a lâmpada
/// roda uma vez e grava `ligada = 0` sozinha). O app sempre grava assim: a luz da manhã
/// vale só pra manhã seguinte a uma noite com o modo noite armado (decisão do usuário).
struct LampRoutine: Equatable {
    static let byteCount = 12

    var enabled: Bool
    var days: UInt8
    var onlyNext: Bool
    var hour: Int
    var minute: Int
    var rampMinutes: Int
    var holdMinutes: Int
    var from: LampColor
    var fromBrightness: UInt8
    var to: LampColor
    var toBrightness: UInt8

    static let rampRange = 1...120
    static let holdRange = 0...240

    /// Rotina desligada (usada pra apagar uma luz da manhã que não deve mais acontecer).
    static let disabled = LampRoutine(
        enabled: false, days: 0x7F, onlyNext: false, hour: 7, minute: 0, rampMinutes: 1, holdMinutes: 0,
        from: .off, fromBrightness: 0, to: .off, toBrightness: 0
    )

    var isValid: Bool {
        (0...23).contains(hour) && (0...59).contains(minute)
            && Self.rampRange.contains(rampMinutes) && Self.holdRange.contains(holdMinutes)
    }

    var payload: [UInt8] {
        [
            enabled ? 1 : 0,
            (days & 0x7F) | (onlyNext ? 0x80 : 0),
            UInt8(clamping: hour), UInt8(clamping: minute),
            UInt8(clamping: rampMinutes), UInt8(clamping: holdMinutes),
            from.amber, from.red, fromBrightness,
            to.amber, to.red, toBrightness,
        ]
    }

    init(enabled: Bool, days: UInt8, onlyNext: Bool, hour: Int, minute: Int, rampMinutes: Int, holdMinutes: Int,
         from: LampColor, fromBrightness: UInt8, to: LampColor, toBrightness: UInt8) {
        self.enabled = enabled
        self.days = days
        self.onlyNext = onlyNext
        self.hour = hour
        self.minute = minute
        self.rampMinutes = rampMinutes
        self.holdMinutes = holdMinutes
        self.from = from
        self.fromBrightness = fromBrightness
        self.to = to
        self.toBrightness = toBrightness
    }

    init?(payload bytes: [UInt8]) {
        guard bytes.count >= Self.byteCount else { return nil }
        enabled = bytes[0] == 1
        days = bytes[1] & 0x7F
        onlyNext = bytes[1] & 0x80 != 0
        hour = Int(bytes[2])
        minute = Int(bytes[3])
        rampMinutes = Int(bytes[4])
        holdMinutes = Int(bytes[5])
        from = LampColor(amber: bytes[6], red: bytes[7])
        fromBrightness = bytes[8]
        to = LampColor(amber: bytes[9], red: bytes[10])
        toBrightness = bytes[11]
    }

    /// Bit do dia da semana de `date` no formato da lâmpada (bit0 = segunda … bit6 = domingo).
    static func dayBit(for date: Date, calendar: Calendar = .current) -> UInt8 {
        // Calendar: 1 = domingo … 7 = sábado → segunda (2) vira 0, domingo (1) vira 6.
        let weekday = calendar.component(.weekday, from: date)
        return 1 << UInt8((weekday + 5) % 7)
    }

    /// Horário em que a luz começa a subir (despertador − rampa).
    var startTime: (hour: Int, minute: Int) {
        let total = ((hour * 60 + minute - rampMinutes) % 1440 + 1440) % 1440
        return (total / 60, total % 60)
    }

    /// Horário em que a luz apaga (despertador + tempo acesa depois).
    var endTime: (hour: Int, minute: Int) {
        let total = (hour * 60 + minute + holdMinutes) % 1440
        return (total / 60, total % 60)
    }
}

enum LampCommand: Equatable {
    case color(LampColor)
    case off
    case setClock(Date)
    case writeRoutine(LampRoutine)
    case cancelToday
    case identify
    case fadeOut(from: LampColor, minutes: Int)

    static let fadeRange = 1...120

    func bytes(calendar: Calendar = .current) -> [UInt8] {
        switch self {
        case .color(let c):
            return [LampOpcode.color.rawValue, c.amber, c.red]
        case .off:
            return [LampOpcode.off.rawValue]
        case .setClock(let date):
            // Hora LOCAL do celular — a lâmpada não sabe nada de fuso.
            let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            return [
                LampOpcode.setClock.rawValue,
                UInt8(clamping: (c.year ?? 2000) - 2000), UInt8(clamping: c.month ?? 1), UInt8(clamping: c.day ?? 1),
                UInt8(clamping: c.hour ?? 0), UInt8(clamping: c.minute ?? 0), UInt8(clamping: c.second ?? 0),
            ]
        case .writeRoutine(let routine):
            return [LampOpcode.writeRoutine.rawValue] + routine.payload
        case .cancelToday:
            return [LampOpcode.cancelToday.rawValue]
        case .identify:
            return [LampOpcode.identify.rawValue]
        case .fadeOut(let from, let minutes):
            return [LampOpcode.fadeOut.rawValue, from.amber, from.red, UInt8(clamping: minutes)]
        }
    }
}

// MARK: - Ajustes da lâmpada por rotina de sono

/// "Lâmpada ao dormir": quando a luminária (NFC) é reconhecida com o modo noite armado,
/// a lâmpada acende nesta cor e apaga devagar em `minutes`.
struct LampSleepSettings: Codable, Equatable {
    var enabled: Bool = true
    /// `mix`/`brightness` ficaram só pela compatibilidade do que já foi salvo — desde o
    /// item 3 do plano Hatch (2026-10-22) o apagar começa da luz que estiver acesa.
    var mix: Double = LampPreset.all[3].color.mix
    var brightness: Double = 0.6
    var minutes: Int = 15

    /// Único ajuste mostrado no editor: em quanto tempo a luz apaga.
    static let minuteChoices = [15, 30, 45, 60]

    /// `minutes` preso a 15–60 (rotinas antigas podiam ter 1–120).
    var fadeMinutes: Int { min(max(minutes, 15), 60) }

    /// Comando de apagar devagar a partir da luz atual da lâmpada (`current`, do STATE).
    /// Lâmpada apagada (ou estado desconhecido) → `nil`: não acende uma luz pra apagar.
    func fadeCommand(current: LampColor?) -> LampCommand? {
        guard enabled, let current, !current.isOff else { return nil }
        return .fadeOut(from: current, minutes: fadeMinutes)
    }
}

/// "Lâmpada ao acordar": amanhecer que termina na hora do despertador da rotina, gravado
/// na lâmpada como rotina de uma vez só (só a manhã seguinte).
struct LampWakeSettings: Codable, Equatable {
    var enabled: Bool = true
    var minutesBefore: Int = 15
    var fromMix: Double = 1
    var fromBrightness: Double = 0
    var toMix: Double = 0
    var toBrightness: Double = 1
    var holdMinutes: Int = 30

    /// Rotina de uma vez só pro despertador em `alarmDate`.
    func lampRoutine(alarmDate: Date, calendar: Calendar = .current) -> LampRoutine {
        let comps = calendar.dateComponents([.hour, .minute], from: alarmDate)
        return LampRoutine(
            enabled: true,
            days: LampRoutine.dayBit(for: alarmDate, calendar: calendar),
            onlyNext: true,
            hour: comps.hour ?? 7,
            minute: comps.minute ?? 0,
            rampMinutes: min(max(minutesBefore, LampRoutine.rampRange.lowerBound), LampRoutine.rampRange.upperBound),
            holdMinutes: min(max(holdMinutes, LampRoutine.holdRange.lowerBound), LampRoutine.holdRange.upperBound),
            from: LampColor(mix: fromMix, brightness: 1),
            fromBrightness: UInt8(clamping: Int((fromBrightness * 255).rounded())),
            to: LampColor(mix: toMix, brightness: 1),
            toBrightness: UInt8(clamping: Int((toBrightness * 255).rounded()))
        )
    }
}
