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
/// padrão de `SleepRoutineStore`.
final class SleepReportStore: ObservableObject {
    static let shared = SleepReportStore()

    @Published private(set) var entries: [SleepReportEntry] = []

    private static let entriesKey = "com.luminaria.sleepReportEntries"

    private init() {
        load()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.entriesKey),
              let decoded = try? JSONDecoder().decode([SleepReportEntry].self, from: data) else { return }
        entries = decoded
    }

    /// Ignora sessões vazias (nenhum app escolhido) ou instantâneas (duração zero) —
    /// não vale a pena poluir o histórico com elas.
    func recordSession(appCount: Int, duration: TimeInterval) {
        guard appCount > 0, duration > 0 else { return }
        let entry = SleepReportEntry(date: Date(), blockedAppCount: appCount, durationSeconds: duration)
        entries.insert(entry, at: 0)
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.entriesKey)
        }
    }
}
