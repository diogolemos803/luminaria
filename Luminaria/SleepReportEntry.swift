import Foundation

// Modelo de uma noite registrada no relatório, separado do `SleepReportStore` pra ser
// testado no pacote `Packages/SoveeCore` (decode tolerante, `DetoxStats`).

/// Como uma sessão de bloqueio terminou — usado por `DetoxStats.longestCleanDayStreak`
/// (item 2b) pra saber quais sessões contam como "limpas": só as que o despertador
/// tocou até o fim, sem a pessoa desarmar na mão nem usar um passe de emergência.
enum DetoxSessionEndReason: String, Codable {
    case alarmFired
    case manualDisarm
    case emergencyPass
    /// O despertador tocou, mas a pessoa mexeu no celular durante a noite e o meteoro
    /// destruiu o foguete — não conta como noite limpa (pedido do usuário, 2026-09-28:
    /// "só perde a streak"). Versões antigas do app leem este valor como `.alarmFired`
    /// (decode tolerante abaixo), sem quebrar o histórico.
    case rocketDestroyed
}

/// Um registro de uma sessão de bloqueio de apps (do reconhecimento NFC até
/// desarmar). Não guarda quais apps foram bloqueados (a Apple não expõe isso pro
/// app) — só quantos, e por quanto tempo.
struct SleepReportEntry: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var blockedAppCount: Int
    var durationSeconds: TimeInterval
    /// Como a sessão terminou — ver `DetoxSessionEndReason`. Opcional na leitura (não
    /// existia antes desta rodada), decodifica pra `.alarmFired` quando ausente —
    /// mesmo espírito de toda migração já feita nesse projeto (`appSelection` em
    /// `SleepRoutine`, por exemplo): default otimista, não falha o decode nem reseta
    /// o histórico do usuário.
    var endReason: DetoxSessionEndReason
    /// Maior intervalo (em segundos) sem "tocar o celular" durante essa sessão — ver
    /// `NightSessionActivityTracker` em `GrowthEngine.swift` pra definição exata de
    /// "toque" e por que não dá pra medir isso com mais precisão no iOS. `0` quando
    /// ausente (sessões registradas antes desta rodada).
    var longestUninterruptedSeconds: TimeInterval

    init(id: UUID = UUID(), date: Date, blockedAppCount: Int, durationSeconds: TimeInterval, endReason: DetoxSessionEndReason, longestUninterruptedSeconds: TimeInterval) {
        self.id = id
        self.date = date
        self.blockedAppCount = blockedAppCount
        self.durationSeconds = durationSeconds
        self.endReason = endReason
        self.longestUninterruptedSeconds = longestUninterruptedSeconds
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, blockedAppCount, durationSeconds, endReason, longestUninterruptedSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        blockedAppCount = try container.decode(Int.self, forKey: .blockedAppCount)
        durationSeconds = try container.decode(TimeInterval.self, forKey: .durationSeconds)
        if let decoded = (try? container.decodeIfPresent(DetoxSessionEndReason.self, forKey: .endReason)) ?? nil {
            endReason = decoded
        } else {
            endReason = .alarmFired
        }
        if let decoded = (try? container.decodeIfPresent(TimeInterval.self, forKey: .longestUninterruptedSeconds)) ?? nil {
            longestUninterruptedSeconds = decoded
        } else {
            longestUninterruptedSeconds = 0
        }
    }
}
