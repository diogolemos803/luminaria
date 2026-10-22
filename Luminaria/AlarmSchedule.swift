import Foundation

/// Contas de horário do despertador, sem estado e sem iOS — testadas no pacote
/// `Packages/SoveeCore`.
enum AlarmSchedule {
    /// Próxima ocorrência de `hour:minute` estritamente depois de `date` — se já passou
    /// hoje, cai pro dia seguinte. Usar `Calendar` em vez de comparar só minutos-do-dia
    /// evita o bug de virada de meia-noite (armar às 22h pra um alarme às 7h não pode
    /// disparar na hora, tem que ser o 7h de amanhã).
    static func nextOccurrence(hour: Int, minute: Int, after date: Date, calendar: Calendar = .current) -> Date {
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

    /// Próximos `count` horários diários `hour:minute` estritamente depois de `date` —
    /// usado pelo lembrete "hora de desligar." (uma notificação por noite, sem repetir).
    /// `skipUntil`: horários antes dessa data ficam de fora (noite já começada).
    static func upcomingDaily(hour: Int, minute: Int, after date: Date, count: Int, skipUntil: Date? = nil, calendar: Calendar = .current) -> [Date] {
        var result: [Date] = []
        var cursor = date
        while result.count < count {
            let next = nextOccurrence(hour: hour, minute: minute, after: cursor, calendar: calendar)
            if let skipUntil, next < skipUntil {
                cursor = next
                continue
            }
            result.append(next)
            cursor = next
        }
        return result
    }

    /// Despertador com horário que pode mudar por dia da semana: o primeiro horário,
    /// estritamente depois de `date`, olhando hoje, amanhã e depois de amanhã — cada dia
    /// com o SEU horário (`time(weekday)`, `weekday` como no `Calendar`: 1 = domingo … 7 =
    /// sábado). Armar na segunda às 22h com terça às 6h dá terça 6h; armar na terça à 1h
    /// da manhã com terça às 6h dá a mesma terça 6h. Continua sendo uma noite só.
    static func nextAlarm(after date: Date, calendar: Calendar = .current, time: (Int) -> (hour: Int, minute: Int)) -> Date {
        let today = calendar.startOfDay(for: date)
        for offset in 0...2 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let t = time(calendar.component(.weekday, from: day))
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = t.hour
            components.minute = t.minute
            components.second = 0
            if let candidate = calendar.date(from: components), candidate > date {
                return candidate
            }
        }
        let t = time(calendar.component(.weekday, from: date))
        return nextOccurrence(hour: t.hour, minute: t.minute, after: date, calendar: calendar)
    }
}
