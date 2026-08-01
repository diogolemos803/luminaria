import Foundation

/// Som do despertador escolhido pela rotina. `fileName` é o nome do recurso .wav
/// no bundle (sem extensão), usado tanto pelo player em loop quanto pelo som
/// customizado da notificação de backup.
enum AlarmSoundOption: String, CaseIterable, Codable, Hashable, Identifiable {
    case classic
    case gentleChime
    case sunrise
    case breathing

    var id: String { rawValue }

    var fileName: String {
        switch self {
        case .classic: return "alarm_tone"
        case .gentleChime: return "alarm_carrilhao"
        case .sunrise: return "alarm_alvorada"
        case .breathing: return "alarm_respiracao"
        }
    }

    var displayName: String {
        switch self {
        case .classic: return "Sirene clássica"
        case .gentleChime: return "Carrilhão suave"
        case .sunrise: return "Alvorada"
        case .breathing: return "Respiração"
        }
    }
}

struct SleepRoutine: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var alarmHour: Int
    var alarmMinute: Int
    var nightShiftOffHour: Int
    var nightShiftOffMinute: Int
    var soundOption: AlarmSoundOption

    init(
        id: UUID = UUID(),
        name: String,
        alarmHour: Int = 7,
        alarmMinute: Int = 0,
        nightShiftOffHour: Int = 7,
        nightShiftOffMinute: Int = 30,
        soundOption: AlarmSoundOption = .gentleChime
    ) {
        self.id = id
        self.name = name
        self.alarmHour = alarmHour
        self.alarmMinute = alarmMinute
        self.nightShiftOffHour = nightShiftOffHour
        self.nightShiftOffMinute = nightShiftOffMinute
        self.soundOption = soundOption
    }
}

/// Guarda a lista de rotinas de sono (nome + horários + som) e qual está ativa.
/// Persiste como JSON no UserDefaults — não precisa de nada mais robusto pro
/// tamanho dessa lista.
final class SleepRoutineStore: ObservableObject {
    @Published private(set) var routines: [SleepRoutine] = []
    @Published var activeRoutineID: UUID?

    private static let routinesKey = "com.luminaria.sleepRoutines"
    private static let activeRoutineKey = "com.luminaria.activeRoutineID"

    var activeRoutine: SleepRoutine? {
        routines.first { $0.id == activeRoutineID }
    }

    init() {
        load()
    }

    private func load() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.routinesKey),
           let decoded = try? JSONDecoder().decode([SleepRoutine].self, from: data),
           !decoded.isEmpty {
            routines = decoded
            if let savedID = defaults.string(forKey: Self.activeRoutineKey), let uuid = UUID(uuidString: savedID) {
                activeRoutineID = uuid
            } else {
                activeRoutineID = routines.first?.id
            }
            return
        }

        let migrated = Self.migrateLegacySettingsIfNeeded(defaults: defaults)
        routines = [migrated]
        activeRoutineID = migrated.id
        persist()
    }

    /// Antes das rotinas existirem, o horário do despertador e do desligar Modo
    /// Noturno ficavam soltos em `@AppStorage`. Se essas chaves já existirem (app
    /// atualizado num device que já tinha valores configurados), preserva exatamente
    /// o que já estava lá numa primeira rotina, em vez de resetar silenciosamente.
    private static func migrateLegacySettingsIfNeeded(defaults: UserDefaults) -> SleepRoutine {
        func existingInt(_ key: String) -> Int? {
            defaults.object(forKey: key) != nil ? defaults.integer(forKey: key) : nil
        }

        let alarmHour = existingInt("alarmHour")
        let nightShiftOffHour = existingInt("nightShiftOffHour")
        guard alarmHour != nil || nightShiftOffHour != nil else {
            return SleepRoutine(name: "Minha rotina")
        }

        return SleepRoutine(
            name: "Minha rotina",
            alarmHour: alarmHour ?? 7,
            alarmMinute: existingInt("alarmMinute") ?? 0,
            nightShiftOffHour: nightShiftOffHour ?? 7,
            nightShiftOffMinute: existingInt("nightShiftOffMinute") ?? 30,
            soundOption: .classic
        )
    }

    private func persist() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(routines) {
            defaults.set(data, forKey: Self.routinesKey)
        }
        if let activeRoutineID {
            defaults.set(activeRoutineID.uuidString, forKey: Self.activeRoutineKey)
        }
    }

    /// Insere uma rotina nova (se o id não existir ainda) ou substitui a existente —
    /// cobre tanto "criar" quanto "editar" com o mesmo método.
    func upsert(_ routine: SleepRoutine) {
        if let index = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[index] = routine
        } else {
            routines.append(routine)
            if activeRoutineID == nil {
                activeRoutineID = routine.id
            }
        }
        persist()
    }

    func remove(id: UUID) {
        routines.removeAll { $0.id == id }
        if activeRoutineID == id {
            activeRoutineID = routines.first?.id
        }
        persist()
    }

    func setActive(id: UUID) {
        activeRoutineID = id
        persist()
    }
}
