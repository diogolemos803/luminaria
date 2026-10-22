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
}
