import Foundation

// MARK: - Amigos

// Amigos e ranking foram implementados de verdade em `FriendsStore.swift` (CloudKit,
// banco público, amizade por código sem aceite) e `FriendsView.swift`. Os modelos
// provisórios que ficavam aqui (`Friend`, `FriendInvite`, `FriendsRepository`) saíram —
// nunca foram usados por nenhuma tela.

// MARK: - Ranking de detox de tela

/// Funções puras sobre o histórico já existente (`SleepReportEntry`) — sem estado
/// próprio, fáceis de testar e reaproveitar tanto pra um ranking local quanto,
/// depois, social (bastaria comparar os números calculados aqui entre `Friend`s).
enum DetoxStats {
    /// Maior sequência de dias consecutivos com pelo menos uma sessão "limpa" — o
    /// despertador tocou até o fim, sem desarmar manualmente nem usar passe de
    /// emergência (ver `DetoxSessionEndReason` em `SleepReportStore.swift`). Olha só
    /// pro dia civil (`Calendar.startOfDay`) de cada entrada, ignorando duplicatas no
    /// mesmo dia.
    static func longestCleanDayStreak(in entries: [SleepReportEntry], calendar: Calendar = .current) -> Int {
        let cleanDays = Set(
            entries
                .filter { $0.endReason == .alarmFired }
                .map { calendar.startOfDay(for: $0.date) }
        )
        guard !cleanDays.isEmpty else { return 0 }

        var longest = 0
        var current = 0
        var previousDay: Date?
        for day in cleanDays.sorted() {
            if let previousDay,
               let expected = calendar.date(byAdding: .day, value: 1, to: previousDay),
               calendar.isDate(expected, inSameDayAs: day) {
                current += 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            previousDay = day
        }
        return longest
    }

    /// Maior sequência de horas sem "tocar o celular" numa sessão só, olhando pra
    /// `longestUninterruptedSeconds` de cada entrada — ver `NightSessionActivityTracker`
    /// em `GrowthEngine.swift` pra como esse número é calculado durante a sessão
    /// (reabrir o app ou usar um passe de emergência conta como "tocou").
    static func longestUninterruptedStreak(in entries: [SleepReportEntry]) -> TimeInterval {
        entries.map(\.longestUninterruptedSeconds).max() ?? 0
    }

    /// Sequência ATUAL de dias consecutivos com sessão limpa, contando pra trás a
    /// partir de hoje — diferente de `longestCleanDayStreak` (o recorde histórico,
    /// que pode já ter sido quebrado). Usado por `GrowthDestinations` pra decidir
    /// qual planeta está desbloqueado AGORA, não qual já foi alcançado uma vez no
    /// passado. Se hoje ainda não teve sessão limpa (a noite ainda não terminou),
    /// conta a partir de ontem — não zera a sequência só porque o dia ainda não
    /// acabou.
    static func currentCleanDayStreak(in entries: [SleepReportEntry], asOf referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        let cleanDays = Set(
            entries
                .filter { $0.endReason == .alarmFired }
                .map { calendar.startOfDay(for: $0.date) }
        )
        guard !cleanDays.isEmpty else { return 0 }

        var day = calendar.startOfDay(for: referenceDate)
        if !cleanDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }

        var streak = 0
        while cleanDays.contains(day) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previousDay
        }
        return streak
    }
}
