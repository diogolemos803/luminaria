import Foundation
import UserNotifications

/// Lembrete "hora de desligar." (item 4 do plano Hatch, 2026-10-22).
///
/// Uma notificação local por noite, no horário escolhido na rotina ATIVA — sem repetir,
/// sem escalar, sem segunda chamada. Agenda os próximos 7 dias como notificações
/// avulsas (não `repeats: true`) pra poder pular a noite em que a luminária já foi lida.
/// Reagendado ao abrir o app, ao salvar/trocar a rotina e ao reconhecer a luminária.
enum BedtimeReminder {
    static let identifierPrefix = "com.luminaria.bedtime."
    static let message = "hora de desligar."
    private static let daysAhead = 7

    /// - Parameter nightStarted: a noite de hoje já começou (luminária lida / bloqueio
    ///   ativo) — o lembrete das próximas 12 h fica de fora.
    static func reschedule(for routine: SleepRoutine?, nightStarted: Bool? = nil, now: Date = Date()) {
        let started = nightStarted ?? ScreenTimeManager.shared.isShieldActive
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let old = requests.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)
            guard let time = routine?.bedtimeReminder else { return }
            let dates = AlarmSchedule.upcomingDaily(
                hour: time.hour, minute: time.minute, after: now, count: daysAhead,
                skipUntil: started ? now.addingTimeInterval(12 * 3600) : nil
            )
            for date in dates {
                let content = UNMutableNotificationContent()
                content.body = message
                content.sound = .default
                if #available(iOS 15.0, *) {
                    content.interruptionLevel = .active
                }
                content.threadIdentifier = "bedtime"
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let id = identifierPrefix + String(Int(date.timeIntervalSince1970))
                center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }
    }
}
