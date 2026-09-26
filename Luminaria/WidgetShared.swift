import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

// Compilado nos DOIS alvos (app e `LuminariaWidgetExtension`) — é o contrato entre eles:
// as chaves do App Group que o app escreve e o widget lê, a tabela de planetas e o formato
// da Atividade ao Vivo da noite. Nada aqui pode depender de código que só existe no app.

/// Chaves do App Group `group.com.luminaria.app` (o app escreve em `AlarmManager` e
/// `WidgetBridge`; o widget só lê).
enum SharedWidgetData {
    static let suiteName = "group.com.luminaria.app"
    static let widgetKind = "com.luminaria.app.AlarmWidget"

    static let armedKey = "widget.isArmed"
    static let nextFireKey = "widget.nextFireDate"
    static let currentStreakKey = "widget.currentStreak"
    static let longestStreakKey = "widget.longestStreak"
    static let lastCleanNightKey = "widget.lastCleanNight"
}

/// Planetas desbloqueados pela sequência de noites limpas (0/7/15/30). Fonte única dos
/// nomes e marcos — `GrowthDestinations` (app) acrescenta só as cores.
struct PlanetMilestone: Equatable {
    let id: String
    let name: String
    let requiredStreakDays: Int
}

enum PlanetMilestones {
    static let all: [PlanetMilestone] = [
        PlanetMilestone(id: "moon", name: "Lua", requiredStreakDays: 0),
        PlanetMilestone(id: "mars", name: "Marte", requiredStreakDays: 7),
        PlanetMilestone(id: "saturn", name: "Saturno", requiredStreakDays: 15),
        PlanetMilestone(id: "neptune", name: "Netuno", requiredStreakDays: 30),
    ]

    /// Próximo planeta ainda não liberado — o "rumo a…" dos widgets. `nil` = todos liberados.
    static func next(afterStreak streak: Int) -> PlanetMilestone? {
        all.first { $0.requiredStreakDays > streak }
    }

    /// Progresso 0...1 até o próximo planeta (sequência ÷ noites que ele exige).
    static func progressToNext(streak: Int) -> Double {
        guard let next = next(afterStreak: streak) else { return 1 }
        return min(max(Double(streak) / Double(next.requiredStreakDays), 0), 1)
    }
}

enum StreakMath {
    /// Sequência que vale HOJE: o número salvo só muda quando uma noite termina, então se
    /// a última noite limpa foi antes de ontem, a sequência já quebrou (mesma regra de
    /// `FriendProfile.effectiveStreak`).
    static func effective(streak: Int, lastCleanNight: Date?, now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let lastCleanNight,
              let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) else { return 0 }
        return calendar.startOfDay(for: lastCleanNight) >= yesterday ? streak : 0
    }
}

#if canImport(ActivityKit)
/// Atividade ao Vivo da noite (tela bloqueada + Dynamic Island): começa quando a luminária
/// é lida e termina quando a noite acaba. A barra e a contagem andam pelo relógio do
/// sistema (`ProgressView(timerInterval:)`/`Text(_:style:)`), sem o app precisar rodar;
/// o app só atualiza o estado quando um meteoro atinge o foguete (`impactAt`).
@available(iOS 16.1, *)
struct NightSessionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var streak: Int
        /// Último "toque" (reabrir o app / passe) — a viagem recomeça daqui.
        var impactAt: Date?
    }

    var sessionStart: Date
    var alarmDate: Date
    /// Planeta de destino (`PlanetMilestone.id`/`name`) no início da noite.
    var destinationID: String
    var destinationName: String
}
#endif
