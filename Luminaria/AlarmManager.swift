import AVFoundation
import UserNotifications
import WidgetKit

/// Despertador próprio do app, sem depender do Atalhos nem do app Relógio (a Apple não
/// oferece API pública pra criar um alarme nativo de fora do app Relógio).
///
/// Funciona tocando um áudio quase inaudível em loop o tempo todo enquanto armado — isso
/// mantém o app "vivo" em segundo plano (modo "Audio" do UIBackgroundModes). Quando bate o
/// horário programado, troca esse áudio pelo som do alarme, em loop, até a pessoa abrir o
/// app e parar. Uma notificação local com o MESMO som escolhido serve de reforço — e é ela
/// quem garante o alarme mesmo se o processo tiver sido suspenso, já que quem a dispara e
/// toca o som é o próprio iOS, não o nosso `Timer`.
///
/// Ressalva real: se a pessoa fechar o app manualmente (arrastar pra cima no seletor de
/// apps) ou reiniciar o iPhone, o processo morre e o alarme não toca — mesma limitação de
/// qualquer app de despertador de terceiros.
final class AlarmManager: NSObject, ObservableObject {
    static let shared = AlarmManager()

    @Published var isAlarmRinging = false
    /// `nil` enquanto a permissão ainda não foi pedida/respondida. Exposto pra tela de
    /// Ajuda poder avisar quando o usuário negou notificações (antes isso falhava calado).
    @Published var notificationsAuthorized: Bool?
    /// Chamado sempre que o despertador dispara de verdade (`triggerAlarm`). Usado só pra
    /// sincronizar `isNightModeArmed` na UI quando o app está em primeiro plano — o
    /// desbloqueio de apps em si acontece direto em `triggerAlarm`, sem depender desse
    /// callback, já que o alarme pode disparar com o app em segundo plano/suspenso.
    var onAlarmFired: (() -> Void)?

    private var silentPlayer: AVAudioPlayer?
    private var alarmPlayer: AVAudioPlayer?
    private var previewPlayer: AVAudioPlayer?
    private var checkTimer: Timer?
    private var scheduledHour: Int?
    private var scheduledMinute: Int?
    private var scheduledSoundFileName: String?
    /// Próximo instante de verdade (data + hora) em que o alarme deve tocar. Comparar
    /// contra isso, em vez de só "hora atual == hora agendada", é o que permite pegar o
    /// alarme MESMO que a checagem só rode bem depois do horário (app reaberto tarde) —
    /// antes, uma checagem por igualdade exata perdia a janela e nunca mais disparava
    /// naquele dia.
    private var nextFireDate: Date?

    private static let notificationID = "com.luminaria.alarm"
    /// Segunda notificação de reforço, ~1 minuto depois da primeira — rede de
    /// segurança extra pro caso raro da primeira falhar em soar (hiccup do sistema).
    private static let notificationID2 = notificationID + ".backup2"
    private static let armedKey = "com.luminaria.alarm.armed"
    private static let hourKey = "com.luminaria.alarm.hour"
    private static let minuteKey = "com.luminaria.alarm.minute"
    private static let soundKey = "com.luminaria.alarm.sound"
    private static let nextFireKey = "com.luminaria.alarm.nextFire"
    private static let alarmCategoryID = "com.luminaria.alarmCategory"

    /// App Group compartilhado com a `LuminariaWidgetExtension` — só pra ela saber o
    /// próximo horário de despertador (chaves separadas das já existentes acima, que
    /// continuam em `UserDefaults.standard` sem mudança nenhuma).
    private static let widgetSuiteName = "group.com.luminaria.app"
    private static let widgetArmedKey = "widget.isArmed"
    private static let widgetNextFireKey = "widget.nextFireDate"
    private static let widgetKind = "com.luminaria.app.AlarmWidget"
    private static let stopActionID = "com.luminaria.stopAlarmAction"

    private override init() {
        super.init()
        registerNotificationCategories()
        restorePersistedState()
    }

    /// Pede `.timeSensitive` além de `.alert`/`.sound` — sem essa opção, marcar a
    /// notificação como `content.interruptionLevel = .timeSensitive` não tem efeito
    /// nenhum: o iOS trata como notificação normal e ela é filtrada por qualquer Foco
    /// ativo (achado real testando no device: o Atalho liga o "Não Perturbe", que sem
    /// essa permissão bloqueava o despertador mesmo com o nível marcado como sensível
    /// ao tempo no código).
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .timeSensitive]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.notificationsAuthorized = granted
            }
        }
    }

    /// Botão "Parar" direto na notificação (toque longo ou deslizar), sem precisar abrir
    /// o app — funciona até com a tela bloqueada, já que ações de notificação não exigem
    /// desbloquear o iPhone por padrão.
    private func registerNotificationCategories() {
        let stopAction = UNNotificationAction(
            identifier: Self.stopActionID,
            title: "Parar",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.alarmCategoryID,
            actions: [stopAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func armAlarm(hour: Int, minute: Int, soundFileName: String) {
        scheduledHour = hour
        scheduledMinute = minute
        scheduledSoundFileName = soundFileName
        nextFireDate = Self.nextOccurrence(hour: hour, minute: minute, after: Date())
        persistArmedState()
        configureAudioSession()
        startSilentLoop()
        scheduleBackupNotification(hour: hour, minute: minute, soundFileName: soundFileName)
        startCheckTimer()
    }

    func disarmAlarm() {
        scheduledHour = nil
        scheduledMinute = nil
        scheduledSoundFileName = nil
        nextFireDate = nil
        clearPersistedState()
        checkTimer?.invalidate()
        checkTimer = nil
        stopSilentLoop()
        stopAlarmSound()
        isAlarmRinging = false
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notificationID, Self.notificationID2])
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Dispara a tela do alarme na hora, ignorando o horário configurado — só pra testar
    /// como fica sem precisar esperar o horário de verdade chegar.
    func triggerTestAlarm(soundFileName: String) {
        configureAudioSession()
        triggerAlarm(soundFileName: soundFileName)
    }

    /// Toca o som uma única vez, sem loop — prévia usada na edição de rotina, não mexe
    /// no estado do despertador (silêncio/tocando).
    func previewSound(_ option: AlarmSoundOption) {
        configureAudioSession()
        guard let url = Bundle.main.url(forResource: option.fileName, withExtension: "wav") else { return }
        previewPlayer = try? AVAudioPlayer(contentsOf: url)
        previewPlayer?.play()
    }

    /// Chamado quando a pessoa toca "Parar" na tela do alarme tocando.
    func stopRingingAlarm() {
        stopAlarmSound()
        isAlarmRinging = false
        if scheduledHour != nil {
            startSilentLoop()
        }
    }

    /// Chamado quando o app volta a ficar ativo (ver `scenePhase` em `ContentView`) — cobre
    /// o caso de o horário já ter passado com o app suspenso e nem o timer interno nem o
    /// delegate da notificação terem tido chance de rodar a tempo.
    func checkForMissedAlarm() {
        checkAlarmTime()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
    }

    private func startSilentLoop() {
        guard let url = Bundle.main.url(forResource: "silence_loop", withExtension: "wav") else { return }
        silentPlayer = try? AVAudioPlayer(contentsOf: url)
        silentPlayer?.numberOfLoops = -1
        silentPlayer?.volume = 0.01
        silentPlayer?.play()
    }

    private func stopSilentLoop() {
        silentPlayer?.stop()
        silentPlayer = nil
    }

    private func startCheckTimer() {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.checkAlarmTime()
        }
    }

    /// `>=`, não `==`: dispara tanto no instante exato quanto — o que importa de verdade
    /// pro "atraso" — quando a checagem só roda bem depois do horário (app reaberto tarde,
    /// timer perdeu a janela). Uma comparação por igualdade de hora/minuto só pega o alarme
    /// dentro do minuto certo; passado esse minuto, nunca mais dispararia até o dia seguinte.
    private func checkAlarmTime() {
        guard let fireDate = nextFireDate, let soundFileName = scheduledSoundFileName,
              !isAlarmRinging else { return }
        if Date() >= fireDate {
            fireScheduledAlarm(soundFileName: soundFileName)
        }
    }

    /// Alarme disparado pelo agendamento real (timer, notificação, ou checagem ao reabrir
    /// o app) — avança `nextFireDate` pro dia seguinte, pra permitir repetir diariamente
    /// enquanto continuar armado, sem disparar de novo no mesmo dia depois de "Parar".
    private func fireScheduledAlarm(soundFileName: String) {
        // Idempotência: com a segunda notificação de reforço (~60s depois da
        // primeira), se a pessoa ainda não tiver tocado "Parar", ela chegaria aqui
        // de novo enquanto `isAlarmRinging` já é `true` — sem essa guarda,
        // `nextFireDate` avançaria um dia A MAIS do que devia. Não quebra o caso de
        // "Parar" tocado direto da notificação com o app suspenso (handleStopFrom
        // Notification): nesse cenário `isAlarmRinging` ainda é `false` porque o
        // loop de alarme nunca chegou a rodar, então a guarda não bloqueia nada.
        guard !isAlarmRinging else { return }
        if var fireDate = nextFireDate {
            let calendar = Calendar.current
            // Avança em loop, não só +1 dia: se o app ficou dias sem abrir enquanto
            // armado, uma única adição poderia deixar a próxima data ainda no passado,
            // disparando de novo em sequência assim que "Parar" fosse tocado.
            repeat {
                fireDate = calendar.date(byAdding: .day, value: 1, to: fireDate) ?? fireDate.addingTimeInterval(86400)
            } while fireDate <= Date()
            nextFireDate = fireDate
            persistArmedState()
        }
        triggerAlarm(soundFileName: soundFileName)
    }

    private func triggerAlarm(soundFileName: String) {
        guard !isAlarmRinging else { return }
        isAlarmRinging = true
        stopSilentLoop()
        // Bloqueio de apps dura só até o despertador tocar, não exige desarmar
        // manualmente pelo botão — pedido do usuário: "só até a hora que toca o
        // despertador". Chamado direto aqui (não via `onAlarmFired`) porque o alarme
        // pode disparar com o app em segundo plano/suspenso, sem `ContentView` vivo pra
        // reagir a um closure.
        ScreenTimeManager.shared.removeShield()
        onAlarmFired?()
        guard let url = Bundle.main.url(forResource: soundFileName, withExtension: "wav") else { return }
        alarmPlayer = try? AVAudioPlayer(contentsOf: url)
        alarmPlayer?.numberOfLoops = -1
        alarmPlayer?.volume = 1.0
        alarmPlayer?.play()
    }

    /// Próxima ocorrência de `hour:minute` estritamente depois de `date` — se já passou
    /// hoje, cai pro dia seguinte. Usar `Calendar` em vez de comparar só minutos-do-dia
    /// evita o bug de virada de meia-noite (armar às 22h pra um alarme às 7h não pode
    /// disparar na hora, tem que ser o 7h de amanhã).
    private static func nextOccurrence(hour: Int, minute: Int, after date: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        let candidate = calendar.date(from: components) ?? date
        if candidate > date {
            return candidate
        }
        return calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
    }

    private func stopAlarmSound() {
        alarmPlayer?.stop()
        alarmPlayer = nil
    }

    private func scheduleBackupNotification(hour: Int, minute: Int, soundFileName: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID, Self.notificationID2])

        let content = UNMutableNotificationContent()
        content.title = "Despertador"
        content.body = "Toque para abrir o Luminária"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("\(soundFileName).wav"))
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = Self.alarmCategoryID

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger)
        center.add(request)

        // Segunda notificação idêntica, 60s depois — usa `Calendar` pra somar o
        // minuto (não soma manual), senão um alarme em :59 geraria `minute: 60`,
        // um `DateComponents` inválido que o trigger simplesmente não dispararia.
        let calendar = Calendar.current
        let baseDate = calendar.date(from: dateComponents) ?? Date()
        let backupDate = calendar.date(byAdding: .second, value: 60, to: baseDate) ?? baseDate
        let backupComponents = calendar.dateComponents([.hour, .minute], from: backupDate)
        let backupTrigger = UNCalendarNotificationTrigger(dateMatching: backupComponents, repeats: true)
        let backupRequest = UNNotificationRequest(identifier: Self.notificationID2, content: content, trigger: backupTrigger)
        center.add(backupRequest)
    }

    private func persistArmedState() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: Self.armedKey)
        defaults.set(scheduledHour, forKey: Self.hourKey)
        defaults.set(scheduledMinute, forKey: Self.minuteKey)
        defaults.set(scheduledSoundFileName, forKey: Self.soundKey)
        defaults.set(nextFireDate?.timeIntervalSince1970, forKey: Self.nextFireKey)
        updateWidgetState(isArmed: true, nextFireDate: nextFireDate)
    }

    private func clearPersistedState() {
        UserDefaults.standard.set(false, forKey: Self.armedKey)
        updateWidgetState(isArmed: false, nextFireDate: nil)
    }

    /// Ponto único chamado tanto por `persistArmedState()` (armar e reagendar após cada
    /// disparo) quanto por `clearPersistedState()` (desarmar) — cobre os três casos reais
    /// (`armAlarm`, `disarmAlarm`, `fireScheduledAlarm`) sem duplicar a chamada em cada um.
    /// Escreve num App Group separado da persistência normal acima, só pra
    /// `LuminariaWidgetExtension` conseguir ler (processos/sandboxes diferentes).
    private func updateWidgetState(isArmed: Bool, nextFireDate: Date?) {
        guard let sharedDefaults = UserDefaults(suiteName: Self.widgetSuiteName) else { return }
        sharedDefaults.set(isArmed, forKey: Self.widgetArmedKey)
        sharedDefaults.set(nextFireDate?.timeIntervalSince1970, forKey: Self.widgetNextFireKey)
        WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
    }

    /// Restaura o estado armado ao relançar o processo (ex.: o iOS mata o app em segundo
    /// plano e o relança por causa do toque na notificação) — sem isso, o player de alarme
    /// não saberia qual som tocar nem o timer teria o que comparar.
    private func restorePersistedState() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Self.armedKey) else { return }
        guard defaults.object(forKey: Self.hourKey) != nil,
              defaults.object(forKey: Self.minuteKey) != nil,
              let soundFileName = defaults.string(forKey: Self.soundKey) else { return }
        scheduledHour = defaults.integer(forKey: Self.hourKey)
        scheduledMinute = defaults.integer(forKey: Self.minuteKey)
        scheduledSoundFileName = soundFileName
        if defaults.object(forKey: Self.nextFireKey) != nil {
            nextFireDate = Date(timeIntervalSince1970: defaults.double(forKey: Self.nextFireKey))
        } else {
            nextFireDate = Self.nextOccurrence(hour: scheduledHour ?? 7, minute: scheduledMinute ?? 0, after: Date())
        }
        configureAudioSession()
        startSilentLoop()
        startCheckTimer()
    }

    /// Reação imediata à entrega/toque da notificação de alarme — evita depender só do
    /// `Timer` de 15s (que só roda se o processo estiver vivo) pra fazer a tela de tocar
    /// aparecer. A própria entrega da notificação já significa que é hora do alarme.
    private func handleAlarmNotificationFired() {
        guard let soundFileName = scheduledSoundFileName else { return }
        fireScheduledAlarm(soundFileName: soundFileName)
    }

    /// Botão "Parar" tocado direto na notificação, sem abrir o app. Passa pelo mesmo
    /// `fireScheduledAlarm` antes de parar — garante que `nextFireDate` avança pro dia
    /// seguinte mesmo se o app estivesse suspenso e o loop de alarme nunca tivesse
    /// chegado a tocar de verdade (só o som da própria notificação rodou).
    private func handleStopFromNotification() {
        if let soundFileName = scheduledSoundFileName {
            fireScheduledAlarm(soundFileName: soundFileName)
        }
        stopRingingAlarm()
    }
}

extension AlarmManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if [Self.notificationID, Self.notificationID2].contains(notification.request.identifier) {
            handleAlarmNotificationFired()
        }
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if [Self.notificationID, Self.notificationID2].contains(response.notification.request.identifier) {
            if response.actionIdentifier == Self.stopActionID {
                handleStopFromNotification()
            } else {
                handleAlarmNotificationFired()
            }
        }
        completionHandler()
    }
}
