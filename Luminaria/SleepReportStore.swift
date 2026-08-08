import Foundation

/// Um registro de uma sessão de bloqueio de apps (do reconhecimento NFC até
/// desarmar). Não guarda quais apps foram bloqueados (a Apple não expõe isso pro
/// app) — só quantos, e por quanto tempo.
struct SleepReportEntry: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var blockedAppCount: Int
    var durationSeconds: TimeInterval
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
    func recordSession(appCount: Int, duration: TimeInterval) {
        guard appCount > 0, duration > 0 else { return }
        hasUserMadeLocalChanges = true
        let entry = SleepReportEntry(date: Date(), blockedAppCount: appCount, durationSeconds: duration)
        entries.insert(entry, at: 0)
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.entriesKey)
            NSUbiquitousKeyValueStore.default.set(data, forKey: Self.icloudEntriesKey)
        }
    }
}
