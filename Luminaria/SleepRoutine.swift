import Foundation
// Nos testes (pacote `Packages/SoveeCore`, compilado fora do iPhone) o Screen Time não
// existe: lá `FamilyActivitySelection` é um substituto vazio (`TestSupport`).
#if !SOVEE_TESTS
import FamilyControls
#endif

// Modelo da rotina de sono (sem o `SleepRoutineStore`), separado num arquivo próprio pra
// ser testado: o decode tolerante de rotinas antigas é coberto pelos testes do pacote.

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

/// Um horário do despertador (hora e minuto).
struct AlarmTime: Codable, Equatable {
    var hour: Int
    var minute: Int
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
    /// Lâmpada SOVEE (Bluetooth): apagar devagar ao encostar na luminária e amanhecer
    /// antes do despertador. Sem lâmpada pareada não fazem nada. Ver `LampManager`.
    var lampSleep: LampSleepSettings
    var lampWake: LampWakeSettings
    /// Horário do despertador por dia da semana (item 2 do plano Hatch, 2026-10-22).
    /// `nil` = "igual todos os dias" (`alarmHour`/`alarmMinute`). Com valor, são 7 horários
    /// indexados por `weekday − 1` do `Calendar` (0 = domingo … 6 = sábado) — o dia em que
    /// o despertador TOCA. Ao armar, vale o horário da manhã seguinte
    /// (`nextAlarmDate`). Rotinas antigas não têm a chave e viram "igual todos os dias".
    var weekdayAlarms: [AlarmTime]?

    /// Horário que toca no dia `weekday` (1 = domingo … 7 = sábado).
    func alarmTime(forWeekday weekday: Int) -> AlarmTime {
        if let weekdayAlarms, weekdayAlarms.count == 7, (1...7).contains(weekday) {
            return weekdayAlarms[weekday - 1]
        }
        return AlarmTime(hour: alarmHour, minute: alarmMinute)
    }

    /// "07:00" ou, com horário por dia, "varia por dia" — legenda das listas.
    var alarmSummary: String {
        if let weekdayAlarms, weekdayAlarms.count == 7, Set(weekdayAlarms.map { $0.hour * 60 + $0.minute }).count > 1 {
            return "varia por dia"
        }
        let t = alarmTime(forWeekday: 1)
        return String(format: "%02d:%02d", t.hour, t.minute)
    }

    /// Liga/desliga o horário por dia. Ligar copia o horário único pros 7 dias; desligar
    /// volta pro horário único (o de segunda, se os dias variavam).
    mutating func setPerDayAlarms(_ on: Bool) {
        if on {
            guard weekdayAlarms == nil else { return }
            weekdayAlarms = Array(repeating: AlarmTime(hour: alarmHour, minute: alarmMinute), count: 7)
        } else if let weekdayAlarms, weekdayAlarms.count == 7 {
            alarmHour = weekdayAlarms[1].hour
            alarmMinute = weekdayAlarms[1].minute
            self.weekdayAlarms = nil
        }
    }

    /// Próximo despertador desta rotina depois de `date` (uma noite só).
    func nextAlarmDate(after date: Date = Date(), calendar: Calendar = .current) -> Date {
        AlarmSchedule.nextAlarm(after: date, calendar: calendar) { weekday in
            let t = alarmTime(forWeekday: weekday)
            return (t.hour, t.minute)
        }
    }

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
        autoActivateEventKeyword: String? = nil,
        lampSleep: LampSleepSettings = LampSleepSettings(),
        lampWake: LampWakeSettings = LampWakeSettings(),
        weekdayAlarms: [AlarmTime]? = nil
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
        self.lampSleep = lampSleep
        self.lampWake = lampWake
        self.weekdayAlarms = weekdayAlarms
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, alarmHour, alarmMinute, nightShiftOffHour, nightShiftOffMinute, soundOption, appSelection
        case autoActivateWeekday, autoActivateWeekend, autoActivateEventKeyword
        case lampSleep, lampWake
        case weekdayAlarms
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
        // Rotinas salvas antes da lâmpada existir não têm essas chaves — padrão em vez de falhar.
        lampSleep = ((try? container.decodeIfPresent(LampSleepSettings.self, forKey: .lampSleep)) ?? nil) ?? LampSleepSettings()
        lampWake = ((try? container.decodeIfPresent(LampWakeSettings.self, forKey: .lampWake)) ?? nil) ?? LampWakeSettings()
        // Ausente, ilegível ou sem os 7 dias: "igual todos os dias".
        let perDay = (try? container.decodeIfPresent([AlarmTime].self, forKey: .weekdayAlarms)) ?? nil
        weekdayAlarms = perDay?.count == 7 ? perDay : nil
    }
}
