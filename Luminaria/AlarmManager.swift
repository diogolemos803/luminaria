import AVFoundation
import UserNotifications

/// Despertador próprio do app, sem depender do Atalhos nem do app Relógio (a Apple não
/// oferece API pública pra criar um alarme nativo de fora do app Relógio).
///
/// Funciona tocando um áudio quase inaudível em loop o tempo todo enquanto armado — isso
/// mantém o app "vivo" em segundo plano (modo "Audio" do UIBackgroundModes). Quando bate o
/// horário programado, troca esse áudio pelo som do alarme, em loop, até a pessoa abrir o
/// app e parar. Uma notificação local serve de reforço, caso o app tenha sido encerrado.
///
/// Ressalva real: se a pessoa fechar o app manualmente (arrastar pra cima no seletor de
/// apps) ou reiniciar o iPhone, o processo morre e o alarme não toca — mesma limitação de
/// qualquer app de despertador de terceiros.
final class AlarmManager: NSObject, ObservableObject {
    @Published var isAlarmRinging = false

    private var silentPlayer: AVAudioPlayer?
    private var alarmPlayer: AVAudioPlayer?
    private var checkTimer: Timer?
    private var scheduledHour: Int?
    private var scheduledMinute: Int?

    private static let notificationID = "com.luminaria.alarm"

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func armAlarm(hour: Int, minute: Int) {
        scheduledHour = hour
        scheduledMinute = minute
        configureAudioSession()
        startSilentLoop()
        scheduleBackupNotification(hour: hour, minute: minute)
        startCheckTimer()
    }

    func disarmAlarm() {
        scheduledHour = nil
        scheduledMinute = nil
        checkTimer?.invalidate()
        checkTimer = nil
        stopSilentLoop()
        stopAlarmSound()
        isAlarmRinging = false
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Dispara a tela do alarme na hora, ignorando o horário configurado — só pra testar
    /// como fica sem precisar esperar o horário de verdade chegar.
    func triggerTestAlarm() {
        configureAudioSession()
        triggerAlarm()
    }

    /// Chamado quando a pessoa toca "Parar" na tela do alarme tocando.
    func stopRingingAlarm() {
        stopAlarmSound()
        isAlarmRinging = false
        if scheduledHour != nil {
            startSilentLoop()
        }
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

    private func checkAlarmTime() {
        guard let hour = scheduledHour, let minute = scheduledMinute, !isAlarmRinging else { return }
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        if now.hour == hour && now.minute == minute {
            triggerAlarm()
        }
    }

    private func triggerAlarm() {
        isAlarmRinging = true
        stopSilentLoop()
        guard let url = Bundle.main.url(forResource: "alarm_tone", withExtension: "wav") else { return }
        alarmPlayer = try? AVAudioPlayer(contentsOf: url)
        alarmPlayer?.numberOfLoops = -1
        alarmPlayer?.volume = 1.0
        alarmPlayer?.play()
    }

    private func stopAlarmSound() {
        alarmPlayer?.stop()
        alarmPlayer = nil
    }

    private func scheduleBackupNotification(hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])

        let content = UNMutableNotificationContent()
        content.title = "Despertador"
        content.body = "Toque para abrir o Luminária"
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger)
        center.add(request)
    }
}
