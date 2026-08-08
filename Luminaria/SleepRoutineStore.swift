import Foundation
import FamilyControls
import EventKit

/// Som do despertador escolhido pela rotina. `fileName` é o nome do recurso .wav
/// no bundle (sem extensão), usado tanto pelo player em loop quanto pelo som
/// customizado da notificação de backup.
///
/// `gentleChime` e `breathing` (tons puros) saíram de uso, substituídos pelos sons de
/// natureza abaixo (ruído filtrado, mais forte e mais parecido com gravação de verdade
/// — mesma linha dos concorrentes de despertador confortável). `Codable` é implementado
/// à mão (em vez do sintetizado) só pra migrar rotinas já salvas que apontavam pros
/// casos antigos, em vez de falhar o decode e resetar as rotinas do usuário.
enum AlarmSoundOption: String, CaseIterable, Hashable, Identifiable {
    case classic
    case sunrise
    case oceanWaves
    case rain
    case birds

    var id: String { rawValue }

    var fileName: String {
        switch self {
        case .classic: return "alarm_tone"
        case .sunrise: return "alarm_alvorada"
        case .oceanWaves: return "alarm_ondas"
        case .rain: return "alarm_chuva"
        case .birds: return "alarm_passaros"
        }
    }

    var displayName: String {
        switch self {
        case .classic: return "Sirene clássica"
        case .sunrise: return "Alvorada"
        case .oceanWaves: return "Ondas do mar"
        case .rain: return "Chuva"
        case .birds: return "Passarinhos ao amanhecer"
        }
    }
}

extension AlarmSoundOption: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "gentleChime": self = .oceanWaves
        case "breathing": self = .birds
        default:
            guard let value = AlarmSoundOption(rawValue: raw) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Som de despertador desconhecido: \(raw)"
                )
            }
            self = value
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
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
    /// Apps/categorias/sites bloqueados quando ESSA rotina estiver ativa e o modo
    /// noite for armado — cada rotina tem a sua própria seleção, não é mais uma
    /// única lista global compartilhada por todas.
    var appSelection: FamilyActivitySelection
    /// Os três campos abaixo controlam a troca automática de rotina ativa por
    /// calendário (ver `SleepRoutineStore.resolveAutoActivateRoutine`) — todos
    /// desligados/vazios por padrão, recurso 100% opt-in. Prioridade quando mais de
    /// uma rotina tem regra configurada: palavra-chave de evento > fim de semana >
    /// dia de semana.
    var autoActivateWeekday: Bool
    var autoActivateWeekend: Bool
    var autoActivateEventKeyword: String?

    init(
        id: UUID = UUID(),
        name: String,
        alarmHour: Int = 7,
        alarmMinute: Int = 0,
        nightShiftOffHour: Int = 7,
        nightShiftOffMinute: Int = 30,
        soundOption: AlarmSoundOption = .oceanWaves,
        appSelection: FamilyActivitySelection = FamilyActivitySelection(),
        autoActivateWeekday: Bool = false,
        autoActivateWeekend: Bool = false,
        autoActivateEventKeyword: String? = nil
    ) {
        self.id = id
        self.name = name
        self.alarmHour = alarmHour
        self.alarmMinute = alarmMinute
        self.nightShiftOffHour = nightShiftOffHour
        self.nightShiftOffMinute = nightShiftOffMinute
        self.soundOption = soundOption
        self.appSelection = appSelection
        self.autoActivateWeekday = autoActivateWeekday
        self.autoActivateWeekend = autoActivateWeekend
        self.autoActivateEventKeyword = autoActivateEventKeyword
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, alarmHour, alarmMinute, nightShiftOffHour, nightShiftOffMinute, soundOption, appSelection
        case autoActivateWeekday, autoActivateWeekend, autoActivateEventKeyword
    }

    /// `init(from:)` escrito à mão só pra tratar `appSelection` e os campos de
    /// calendário como opcionais na leitura — rotinas salvas antes dessas mudanças
    /// não têm essas chaves no JSON, e o decode sintetizado exigiria elas sempre,
    /// resetando as rotinas do usuário. Mesmo espírito da migração já feita pra
    /// `AlarmSoundOption`. `encode(to:)` continua sintetizado automaticamente (não
    /// precisou escrever à mão).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        alarmHour = try container.decode(Int.self, forKey: .alarmHour)
        alarmMinute = try container.decode(Int.self, forKey: .alarmMinute)
        nightShiftOffHour = try container.decode(Int.self, forKey: .nightShiftOffHour)
        nightShiftOffMinute = try container.decode(Int.self, forKey: .nightShiftOffMinute)
        soundOption = try container.decode(AlarmSoundOption.self, forKey: .soundOption)
        if let decoded = (try? container.decodeIfPresent(FamilyActivitySelection.self, forKey: .appSelection)) ?? nil {
            appSelection = decoded
        } else {
            appSelection = FamilyActivitySelection()
        }
        if let decoded = (try? container.decodeIfPresent(Bool.self, forKey: .autoActivateWeekday)) ?? nil {
            autoActivateWeekday = decoded
        } else {
            autoActivateWeekday = false
        }
        if let decoded = (try? container.decodeIfPresent(Bool.self, forKey: .autoActivateWeekend)) ?? nil {
            autoActivateWeekend = decoded
        } else {
            autoActivateWeekend = false
        }
        autoActivateEventKeyword = (try? container.decodeIfPresent(String.self, forKey: .autoActivateEventKeyword)) ?? nil
    }
}

/// Espelho de `SleepRoutine` pro backup no iCloud (`NSUbiquitousKeyValueStore`), SEM
/// `appSelection` — a portabilidade dos tokens opacos do `FamilyActivitySelection`
/// entre apagar/reinstalar o app (ou entre devices) não está confirmada, então esse
/// campo propositalmente não entra no backup. Depois de restaurar, os apps
/// bloqueados de cada rotina precisam ser escolhidos de novo.
private struct SyncableRoutine: Codable {
    var id: UUID
    var name: String
    var alarmHour: Int
    var alarmMinute: Int
    var nightShiftOffHour: Int
    var nightShiftOffMinute: Int
    var soundOption: AlarmSoundOption
    var autoActivateWeekday: Bool
    var autoActivateWeekend: Bool
    var autoActivateEventKeyword: String?

    init(_ routine: SleepRoutine) {
        id = routine.id
        name = routine.name
        alarmHour = routine.alarmHour
        alarmMinute = routine.alarmMinute
        nightShiftOffHour = routine.nightShiftOffHour
        nightShiftOffMinute = routine.nightShiftOffMinute
        soundOption = routine.soundOption
        autoActivateWeekday = routine.autoActivateWeekday
        autoActivateWeekend = routine.autoActivateWeekend
        autoActivateEventKeyword = routine.autoActivateEventKeyword
    }

    func toRoutine() -> SleepRoutine {
        SleepRoutine(
            id: id,
            name: name,
            alarmHour: alarmHour,
            alarmMinute: alarmMinute,
            nightShiftOffHour: nightShiftOffHour,
            nightShiftOffMinute: nightShiftOffMinute,
            soundOption: soundOption,
            autoActivateWeekday: autoActivateWeekday,
            autoActivateWeekend: autoActivateWeekend,
            autoActivateEventKeyword: autoActivateEventKeyword
        )
    }
}

/// Guarda a lista de rotinas de sono (nome + horários + som) e qual está ativa.
/// Persiste como JSON no UserDefaults — não precisa de nada mais robusto pro
/// tamanho dessa lista. Também espelha (nome/horários/som/gatilhos de calendário,
/// sem os apps escolhidos) no iCloud Key-Value Storage — só pra sobreviver a
/// apagar/reinstalar o app, que zera o UserDefaults local mas não o iCloud. O
/// UserDefaults local continua sendo a fonte principal em uso normal; o iCloud só
/// entra em jogo pra "semear" de novo um local vazio.
final class SleepRoutineStore: ObservableObject {
    @Published private(set) var routines: [SleepRoutine] = []
    @Published var activeRoutineID: UUID?
    /// `nil` enquanto a permissão de Calendário ainda não foi pedida/respondida —
    /// mesmo padrão de `ScreenTimeManager.isAuthorized`.
    @Published private(set) var isCalendarAuthorized: Bool?

    private static let routinesKey = "com.luminaria.sleepRoutines"
    private static let activeRoutineKey = "com.luminaria.activeRoutineID"
    private static let icloudRoutinesKey = "com.luminaria.sleepRoutines.icloud"
    private let eventStore = EKEventStore()
    /// Vira `true` assim que o usuário mexe em alguma rotina depois do cold launch —
    /// protege contra um valor do iCloud chegando atrasado (a sincronização do
    /// `NSUbiquitousKeyValueStore` é assíncrona, não instantânea) e sobrescrever uma
    /// mudança que a pessoa já fez nos primeiros segundos do app.
    private var hasUserMadeLocalChanges = false
    /// Token do observer — `SleepRoutineStore` é uma classe Swift pura (não herda de
    /// `NSObject`), então o registro usa a variante de closure do `NotificationCenter`
    /// em vez de `addObserver(_:selector:...)`, que exigiria isso.
    private var iCloudObserver: NSObjectProtocol?
    /// `true` só quando `routines` é o placeholder "Minha rotina" recém-criado por
    /// não haver NADA salvo (nem local, nem migração de `@AppStorage` legado) — não
    /// dá pra usar `routines.isEmpty` como sinal, porque `load()` sempre cria pelo
    /// menos essa rotina padrão, nunca deixa a lista vazia de verdade. Sem esse
    /// rastreamento à parte, um valor do iCloud chegando atrasado (sincronização é
    /// assíncrona) nunca teria uma janela pra ser aplicado.
    private var isFreshInstallPlaceholder = false

    var activeRoutine: SleepRoutine? {
        routines.first { $0.id == activeRoutineID }
    }

    init() {
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
        // Local vazio mas o iCloud tem algo (ex.: app apagado e reinstalado) —
        // semeia o UserDefaults local uma vez ANTES de continuar; o resto do método
        // encontra esses dados como se sempre tivessem estado aí, sem duplicar
        // lógica de carregamento.
        if defaults.data(forKey: Self.routinesKey) == nil,
           let seeded = Self.decodeFromICloud() {
            if let data = try? JSONEncoder().encode(seeded) {
                defaults.set(data, forKey: Self.routinesKey)
            }
        }

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

        let (migrated, isPlaceholder) = Self.migrateLegacySettingsIfNeeded(defaults: defaults)
        routines = [migrated]
        activeRoutineID = migrated.id
        isFreshInstallPlaceholder = isPlaceholder
        persist()
    }

    private static func decodeFromICloud() -> [SleepRoutine]? {
        guard let data = NSUbiquitousKeyValueStore.default.data(forKey: icloudRoutinesKey),
              let syncable = try? JSONDecoder().decode([SyncableRoutine].self, from: data),
              !syncable.isEmpty else { return nil }
        return syncable.map { $0.toRoutine() }
    }

    /// Chamado quando um valor novo chega do iCloud depois do cold launch (device
    /// novo terminando de sincronizar, por exemplo). Só aplica se a pessoa ainda não
    /// tiver mexido em nada localmente nesse meio-tempo — evita apagar uma mudança
    /// recente por causa de um valor antigo/atrasado do iCloud.
    private func handleICloudChangeExternally() {
        // Duas guardas, não só uma: `hasUserMadeLocalChanges` cobre "a pessoa já
        // mexeu em algo nesse lançamento"; `isFreshInstallPlaceholder` cobre "o que
        // está carregado agora é só o placeholder de instalação nova, não dado real"
        // — sem essa segunda checagem, rotinas locais boas (de um device que já
        // tinha configuração própria) seriam sobrescritas só por um valor do iCloud
        // de outro device chegando atrasado.
        guard !hasUserMadeLocalChanges, isFreshInstallPlaceholder else { return }
        guard let seeded = Self.decodeFromICloud() else { return }
        routines = seeded
        activeRoutineID = seeded.first?.id
        isFreshInstallPlaceholder = false
        persist()
    }

    /// Antes das rotinas existirem, o horário do despertador e do desligar Modo
    /// Noturno ficavam soltos em `@AppStorage`. Se essas chaves já existirem (app
    /// atualizado num device que já tinha valores configurados), preserva exatamente
    /// o que já estava lá numa primeira rotina, em vez de resetar silenciosamente.
    /// Segundo valor do retorno: `true` quando não havia NADA salvo (nem rotina
    /// local, nem `@AppStorage` legado) — usado por `isFreshInstallPlaceholder` pra
    /// saber se é seguro sobrescrever com um valor do iCloud chegando atrasado.
    private static func migrateLegacySettingsIfNeeded(defaults: UserDefaults) -> (SleepRoutine, isPlaceholder: Bool) {
        func existingInt(_ key: String) -> Int? {
            defaults.object(forKey: key) != nil ? defaults.integer(forKey: key) : nil
        }

        let alarmHour = existingInt("alarmHour")
        let nightShiftOffHour = existingInt("nightShiftOffHour")
        guard alarmHour != nil || nightShiftOffHour != nil else {
            return (SleepRoutine(name: "Minha rotina"), true)
        }

        return (
            SleepRoutine(
                name: "Minha rotina",
                alarmHour: alarmHour ?? 7,
                alarmMinute: existingInt("alarmMinute") ?? 0,
                nightShiftOffHour: nightShiftOffHour ?? 7,
                nightShiftOffMinute: existingInt("nightShiftOffMinute") ?? 30,
                soundOption: .classic
            ),
            false
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
        if let syncData = try? JSONEncoder().encode(routines.map(SyncableRoutine.init)) {
            NSUbiquitousKeyValueStore.default.set(syncData, forKey: Self.icloudRoutinesKey)
        }
    }

    /// Insere uma rotina nova (se o id não existir ainda) ou substitui a existente —
    /// cobre tanto "criar" quanto "editar" com o mesmo método.
    func upsert(_ routine: SleepRoutine) {
        hasUserMadeLocalChanges = true
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
        hasUserMadeLocalChanges = true
        routines.removeAll { $0.id == id }
        if activeRoutineID == id {
            activeRoutineID = routines.first?.id
        }
        persist()
    }

    func setActive(id: UUID) {
        hasUserMadeLocalChanges = true
        activeRoutineID = id
        persist()
    }

    // MARK: - Rotina automática por calendário

    /// Revalida junto do sistema — a autorização pode ser revogada nos Ajustes do
    /// iPhone a qualquer momento. Chamado a partir de `SleepRoutinesView.onAppear`,
    /// nunca daqui de dentro sozinho.
    func refreshCalendarAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized:
            // `.authorized` e o `.fullAccess` do iOS 17+ compartilham o mesmo
            // rawValue — comparar contra o caso antigo (disponível desde sempre,
            // sem exigir `#available`) também cobre concessão de acesso total num
            // device rodando iOS 17+.
            isCalendarAuthorized = true
        case .notDetermined:
            isCalendarAuthorized = nil
        default:
            isCalendarAuthorized = false
        }
    }

    /// Só deve ser chamado a partir de uma ação explícita do usuário (toggle/botão
    /// em `SleepRoutinesView`) — nunca automaticamente, e nunca na hora de armar o
    /// modo noite.
    func requestCalendarAccess(completion: @escaping (Bool) -> Void = { _ in }) {
        let handleResult: (Bool, Error?) -> Void = { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.refreshCalendarAuthorizationStatus()
                completion(granted)
            }
        }
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents(completion: handleResult)
        } else {
            eventStore.requestAccess(to: .event, completion: handleResult)
        }
    }

    /// Resolve qual rotina deveria ficar ativa agora, olhando pros gatilhos de
    /// calendário configurados em cada `SleepRoutine`. Chamado uma ÚNICA vez, no
    /// instante de armar o modo noite (`ContentView.toggleNightMode`) — nunca em
    /// segundo plano, porque este projeto já aprendeu (com o NFC) que não dá pra
    /// contar com execução garantida em background no iOS. Nunca pede autorização
    /// sozinho — se `isCalendarAuthorized` não for `true`, ou nenhuma rotina tiver
    /// regra configurada, retorna `nil` e a seleção manual continua valendo.
    /// A consulta ao EventKit roda numa fila de fundo (`withCheckedContinuation`)
    /// pra não travar a UI no instante em que a pessoa toca o botão redondo.
    func resolveAutoActivateRoutine() async -> UUID? {
        guard EKEventStore.authorizationStatus(for: .event) == .authorized else { return nil }
        let snapshot = routines
        let store = eventStore
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: Self.matchRoutine(among: snapshot, using: store))
            }
        }
    }

    private static func matchRoutine(among routines: [SleepRoutine], using eventStore: EKEventStore) -> UUID? {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfDay = calendar.date(from: calendar.dateComponents([.year, .month, .day], from: now)),
              let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return nil }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let titles = eventStore.events(matching: predicate).compactMap { $0.title?.lowercased() }

        if let keywordMatch = routines.first(where: { routine in
            guard let keyword = routine.autoActivateEventKeyword?.trimmingCharacters(in: .whitespaces).lowercased(),
                  !keyword.isEmpty else { return false }
            return titles.contains { $0.contains(keyword) }
        }) {
            return keywordMatch.id
        }

        let isWeekend = calendar.isDateInWeekend(now)
        if isWeekend, let weekendRoutine = routines.first(where: { $0.autoActivateWeekend }) {
            return weekendRoutine.id
        }
        if !isWeekend, let weekdayRoutine = routines.first(where: { $0.autoActivateWeekday }) {
            return weekdayRoutine.id
        }
        return nil
    }
}
