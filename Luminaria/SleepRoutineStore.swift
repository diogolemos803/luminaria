import Foundation
import FamilyControls
import EventKit

/// Som do despertador escolhido pela rotina. `fileName` é o nome do recurso .wav
/// no bundle (sem extensão), usado pelo alarme do sistema (AlarmKit), pelo player em
/// loop do despertador antigo e pelo som customizado da notificação de backup.
///
/// Biblioteca de gravações reais (2026-09-25), CC0/domínio público do Wikimedia Commons
/// — autores em `SOUND_CREDITS.md`, processadas por `scripts/process_alarm_recordings.js`.
/// Substituíram os sons sintetizados de ondas/chuva/passarinhos: `oceanWaves`, `rain` e
/// `birds` mantêm o mesmo `rawValue` e só apontam pra gravação equivalente, então
/// rotinas já salvas migram sozinhas, sem mexer no decode. Ordem dos casos = ordem na
/// tela de escolha (agrupada por `category`).
///
/// `gentleChime` e `breathing` (tons puros bem antigos) continuam migrados no `Codable`
/// manual abaixo, em vez de falhar o decode e resetar as rotinas do usuário.
enum AlarmSoundOption: String, CaseIterable, Hashable, Identifiable {
    // Pássaros
    case birds
    case nightingale
    case blackbirds
    case breezeBirds
    // Água
    case oceanWaves
    case seaWaves
    case pebbleBeach
    case stream
    case trickle
    case rain
    case countryNight
    // Sinos
    case koshiChimes
    case windChimes
    case littleBells
    case tubularBells
    case pottery
    case singingBowl
    // Música
    case musicBox
    case lullaby
    // Clássicos (sintetizados)
    case sunrise
    case classic

    enum Category: String, CaseIterable, Identifiable {
        case birds = "Pássaros"
        case water = "Água"
        case bells = "Sinos"
        case music = "Música"
        case classic = "Clássicos"

        var id: String { rawValue }
    }

    var id: String { rawValue }

    var category: Category {
        switch self {
        case .birds, .nightingale, .blackbirds, .breezeBirds: return .birds
        case .oceanWaves, .seaWaves, .pebbleBeach, .stream, .trickle, .rain, .countryNight: return .water
        case .koshiChimes, .windChimes, .littleBells, .tubularBells, .pottery, .singingBowl: return .bells
        case .musicBox, .lullaby: return .music
        case .sunrise, .classic: return .classic
        }
    }

    var fileName: String {
        switch self {
        case .birds: return "alarm_passaros_acordando"
        case .nightingale: return "alarm_rouxinol"
        case .blackbirds: return "alarm_melros"
        case .breezeBirds: return "alarm_brisa_passaros"
        case .oceanWaves: return "alarm_ondas_praia"
        case .seaWaves: return "alarm_ondas_mar"
        case .pebbleBeach: return "alarm_praia_pedrinhas"
        case .stream: return "alarm_riacho"
        case .trickle: return "alarm_fio_dagua"
        case .rain: return "alarm_chuva_leve"
        case .countryNight: return "alarm_noite_campo"
        case .koshiChimes: return "alarm_sinos_koshi"
        case .windChimes: return "alarm_sinos_vento"
        case .littleBells: return "alarm_sininhos"
        case .tubularBells: return "alarm_sinos_tubulares"
        case .pottery: return "alarm_ceramica"
        case .singingBowl: return "alarm_tigela"
        case .musicBox: return "alarm_caixinha"
        case .lullaby: return "alarm_cancao_ninar"
        case .sunrise: return "alarm_alvorada"
        case .classic: return "alarm_tone"
        }
    }

    var displayName: String {
        switch self {
        case .birds: return "Pássaros acordando"
        case .nightingale: return "Rouxinol"
        case .blackbirds: return "Melros de manhã"
        case .breezeBirds: return "Brisa com pássaros"
        case .oceanWaves: return "Ondas na praia"
        case .seaWaves: return "Ondas do mar"
        case .pebbleBeach: return "Praia de pedrinhas"
        case .stream: return "Riacho"
        case .trickle: return "Fio d'água"
        case .rain: return "Chuva leve"
        case .countryNight: return "Noite no campo"
        case .koshiChimes: return "Sinos de vento Koshi"
        case .windChimes: return "Sinos de vento"
        case .littleBells: return "Sininhos"
        case .tubularBells: return "Sinos tubulares"
        case .pottery: return "Cerâmica tilintando"
        case .singingBowl: return "Tigela tibetana"
        case .musicBox: return "Caixinha de música"
        case .lullaby: return "Canção de ninar"
        case .sunrise: return "Alvorada"
        case .classic: return "Sirene clássica"
        }
    }

    /// Ícone SF Symbols da grade de escolha (`RoutineEditView`). Todos existem desde o
    /// iOS 16 (alvo mínimo do app).
    var iconName: String {
        switch self {
        case .birds: return "bird.fill"
        case .nightingale: return "music.note"
        case .blackbirds: return "sunrise"
        case .breezeBirds: return "wind"
        case .oceanWaves: return "water.waves"
        case .seaWaves: return "beach.umbrella"
        case .pebbleBeach: return "circle.hexagongrid.fill"
        case .stream: return "drop.fill"
        case .trickle: return "drop"
        case .rain: return "cloud.rain.fill"
        case .countryNight: return "moon.stars.fill"
        case .koshiChimes: return "bell.and.waves.left.and.right"
        case .windChimes: return "wind.snow"
        case .littleBells: return "bell"
        case .tubularBells: return "bell.fill"
        case .pottery: return "cup.and.saucer.fill"
        case .singingBowl: return "circle.circle"
        case .musicBox: return "gift.fill"
        case .lullaby: return "moon.zzz.fill"
        case .sunrise: return "sunrise.fill"
        case .classic: return "alarm.fill"
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
