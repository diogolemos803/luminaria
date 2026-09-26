import Foundation

/// Como uma sessão de bloqueio terminou — usado por `DetoxStats.longestCleanDayStreak`
/// (item 2b) pra saber quais sessões contam como "limpas": só as que o despertador
/// tocou até o fim, sem a pessoa desarmar na mão nem usar um passe de emergência.
enum DetoxSessionEndReason: String, Codable {
    case alarmFired
    case manualDisarm
    case emergencyPass
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

/// Histórico das sessões de bloqueio, persistido como JSON no UserDefaults — mesmo
/// padrão de `SleepRoutineStore`. Também espelha no iCloud Key-Value Storage (só pra
/// sobreviver a apagar/reinstalar o app) — sem token nenhum aqui, `SleepReportEntry`
/// é só data/contagem/duração, então (diferente de `SleepRoutineStore`) não precisa
/// de um DTO separado pra excluir campo nenhum.
final class SleepReportStore: ObservableObject {
    static let shared = SleepReportStore()

    @Published private(set) var entries: [SleepReportEntry] = []

    private static let entriesKey = "com.luminaria.sleepReportEntries"
    private static let icloudEntriesKey = "com.luminaria.sleepReportEntries.icloud"
    /// Mesmo espírito do campo homônimo em `SleepRoutineStore` — evita que um valor
    /// do iCloud chegando atrasado sobrescreva uma sessão registrada nos primeiros
    /// segundos do app.
    private var hasUserMadeLocalChanges = false
    private var iCloudObserver: NSObjectProtocol?

    private init() {
        load()
        iCloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            self?.handleICloudChangeExternally()
        }
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    private func load() {
        let defaults = UserDefaults.standard
        if defaults.data(forKey: Self.entriesKey) == nil, let seeded = Self.decodeFromICloud() {
            if let data = try? JSONEncoder().encode(seeded) {
                defaults.set(data, forKey: Self.entriesKey)
            }
        }
        guard let data = defaults.data(forKey: Self.entriesKey),
              let decoded = try? JSONDecoder().decode([SleepReportEntry].self, from: data) else { return }
        entries = decoded
    }

    private static func decodeFromICloud() -> [SleepReportEntry]? {
        guard let data = NSUbiquitousKeyValueStore.default.data(forKey: icloudEntriesKey),
              let decoded = try? JSONDecoder().decode([SleepReportEntry].self, from: data),
              !decoded.isEmpty else { return nil }
        return decoded
    }

    /// Diferente de `SleepRoutineStore`, aqui `entries.isEmpty` já é um sinal
    /// confiável de "nada real ainda" — não existe um placeholder criado
    /// automaticamente pra essa lista (uma instalação nova genuinamente começa
    /// vazia e continua assim até a primeira sessão de bloqueio de verdade).
    private func handleICloudChangeExternally() {
        guard !hasUserMadeLocalChanges, entries.isEmpty else { return }
        guard let seeded = Self.decodeFromICloud() else { return }
        entries = seeded
        persist()
    }

    /// Ignora sessões vazias (nenhum app escolhido) ou instantâneas (duração zero) —
    /// não vale a pena poluir o histórico com elas.
    func recordSession(appCount: Int, duration: TimeInterval, endReason: DetoxSessionEndReason, longestUninterruptedSeconds: TimeInterval) {
        guard appCount > 0, duration > 0 else { return }
        hasUserMadeLocalChanges = true
        let entry = SleepReportEntry(
            date: Date(),
            blockedAppCount: appCount,
            durationSeconds: duration,
            endReason: endReason,
            longestUninterruptedSeconds: longestUninterruptedSeconds
        )
        entries.insert(entry, at: 0)
        persist()
        // mantém os números do perfil público em dia pros amigos (ver `FriendsStore`)
        Task { @MainActor in
            await FriendsStore.shared.publishMyStatsQuietly()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.entriesKey)
            NSUbiquitousKeyValueStore.default.set(data, forKey: Self.icloudEntriesKey)
        }
    }
}
