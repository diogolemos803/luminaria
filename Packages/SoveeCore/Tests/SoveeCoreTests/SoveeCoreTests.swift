import XCTest
@testable import SoveeCore

/// Calendário fixo (gregoriano, UTC) pra os testes não dependerem do fuso da máquina.
private let utc: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    c.firstWeekday = 1
    return c
}()

private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
    utc.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    let decoder = JSONDecoder()
    return try decoder.decode(type, from: Data(json.utf8))
}

// MARK: - Rotina salva: decode tolerante

final class SleepRoutineDecodingTests: XCTestCase {
    /// Rotina gravada antes do bloqueio por rotina, do calendário e da lâmpada: só os
    /// campos originais. Tem que abrir com os padrões, sem perder nome/horário/som.
    func testOldRoutineWithoutNewFieldsDecodes() throws {
        let json = """
        {"id":"6F1C2A5E-0000-4000-8000-000000000001","name":"Semana","alarmHour":6,"alarmMinute":45,
         "nightShiftOffHour":7,"nightShiftOffMinute":15,"soundOption":"birds"}
        """
        let r = try decode(SleepRoutine.self, json)
        XCTAssertEqual(r.name, "Semana")
        XCTAssertEqual(r.alarmHour, 6)
        XCTAssertEqual(r.alarmMinute, 45)
        XCTAssertEqual(r.soundOption, .birds)
        XCTAssertFalse(r.autoActivateWeekday)
        XCTAssertFalse(r.autoActivateWeekend)
        XCTAssertNil(r.autoActivateEventKeyword)
        XCTAssertEqual(r.lampSleep, LampSleepSettings())
        XCTAssertEqual(r.lampWake, LampWakeSettings())
        XCTAssertNil(r.weekdayAlarms, "rotina antiga vira 'igual todos os dias'")
        XCTAssertNil(r.bedtimeReminder, "rotina antiga fica sem lembrete")
    }

    /// Horário por dia com tamanho errado (corrompido) também vira "igual todos os dias".
    func testWeekdayAlarmsWithWrongCountIsIgnored() throws {
        let json = """
        {"id":"6F1C2A5E-0000-4000-8000-000000000002","name":"X","alarmHour":7,"alarmMinute":0,
         "nightShiftOffHour":7,"nightShiftOffMinute":30,"soundOption":"birds",
         "weekdayAlarms":[{"hour":6,"minute":0}]}
        """
        XCTAssertNil(try decode(SleepRoutine.self, json).weekdayAlarms)
    }

    func testWeekdayAlarmsRoundTrip() throws {
        var r = SleepRoutine(name: "Dias", alarmHour: 7, alarmMinute: 0, soundOption: .rain)
        r.setPerDayAlarms(true)
        r.weekdayAlarms?[6] = AlarmTime(hour: 9, minute: 30)
        let data = try JSONEncoder().encode(r)
        XCTAssertEqual(try JSONDecoder().decode(SleepRoutine.self, from: data), r)
    }

    /// Sons antigos removidos do app migram pro equivalente em vez de falhar o decode.
    func testRetiredSoundsMigrate() throws {
        XCTAssertEqual(try decode([AlarmSoundOption].self, #"["gentleChime","breathing"]"#), [.oceanWaves, .birds])
    }

    func testUnknownSoundFails() {
        XCTAssertThrowsError(try decode([AlarmSoundOption].self, #"["somQueNaoExiste"]"#))
    }

    /// Ida e volta: o que o app grava, ele lê igual.
    func testRoundTrip() throws {
        let original = SleepRoutine(name: "Fim de semana", alarmHour: 9, alarmMinute: 5, soundOption: .rain,
                                    autoActivateWeekend: true, autoActivateEventKeyword: "Viagem")
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(SleepRoutine.self, from: data), original)
    }
}

// MARK: - Relatório: decode tolerante

final class SleepReportEntryDecodingTests: XCTestCase {
    private let base = #""id":"6F1C2A5E-0000-4000-8000-000000000002","date":700000000,"blockedAppCount":3,"durationSeconds":25200"#

    func testOldEntryDefaultsToCleanNight() throws {
        let e = try decode(SleepReportEntry.self, "{\(base)}")
        XCTAssertEqual(e.endReason, .alarmFired)
        XCTAssertEqual(e.longestUninterruptedSeconds, 0)
        XCTAssertEqual(e.blockedAppCount, 3)
    }

    func testKnownReasonIsKept() throws {
        let e = try decode(SleepReportEntry.self, #"{\#(base),"endReason":"rocketDestroyed","longestUninterruptedSeconds":3600}"#)
        XCTAssertEqual(e.endReason, .rocketDestroyed)
        XCTAssertEqual(e.longestUninterruptedSeconds, 3600)
    }

    /// Motivo que esta versão não conhece (gravado por uma versão mais nova): não quebra o
    /// histórico, lê como noite limpa.
    func testUnknownReasonFallsBack() throws {
        let e = try decode(SleepReportEntry.self, #"{\#(base),"endReason":"motivoDoFuturo"}"#)
        XCTAssertEqual(e.endReason, .alarmFired)
    }
}

// MARK: - Sequência de noites

final class DetoxStatsTests: XCTestCase {
    private func entry(_ d: Date, _ reason: DetoxSessionEndReason = .alarmFired, gap: TimeInterval = 0) -> SleepReportEntry {
        SleepReportEntry(date: d, blockedAppCount: 1, durationSeconds: 1, endReason: reason, longestUninterruptedSeconds: gap)
    }

    func testCurrentStreakCountsBackFromToday() {
        let entries = [entry(date(2026, 10, 20, 7)), entry(date(2026, 10, 21, 7)), entry(date(2026, 10, 22, 7))]
        XCTAssertEqual(DetoxStats.currentCleanDayStreak(in: entries, asOf: date(2026, 10, 22, 12), calendar: utc), 3)
    }

    /// De noite (hoje ainda sem registro), a sequência conta a partir de ontem.
    func testCurrentStreakStartsYesterdayWhenTodayIsEmpty() {
        let entries = [entry(date(2026, 10, 20, 7)), entry(date(2026, 10, 21, 7))]
        XCTAssertEqual(DetoxStats.currentCleanDayStreak(in: entries, asOf: date(2026, 10, 22, 22), calendar: utc), 2)
    }

    func testCurrentStreakBreaksOnGapAndOnDirtyNights() {
        let entries = [
            entry(date(2026, 10, 18, 7)),
            entry(date(2026, 10, 20, 7), .rocketDestroyed),
            entry(date(2026, 10, 21, 7)),
        ]
        XCTAssertEqual(DetoxStats.currentCleanDayStreak(in: entries, asOf: date(2026, 10, 21, 12), calendar: utc), 1)
        XCTAssertEqual(DetoxStats.currentCleanDayStreak(in: entries, asOf: date(2026, 10, 24, 12), calendar: utc), 0)
    }

    func testLongestStreakIgnoresDuplicatesAndManualDisarm() {
        let entries = [
            entry(date(2026, 10, 1, 7)), entry(date(2026, 10, 1, 9)),
            entry(date(2026, 10, 2, 7)), entry(date(2026, 10, 3, 7)),
            entry(date(2026, 10, 4, 7), .manualDisarm),
            entry(date(2026, 10, 5, 7)), entry(date(2026, 10, 6, 7)),
        ]
        XCTAssertEqual(DetoxStats.longestCleanDayStreak(in: entries, calendar: utc), 3)
        XCTAssertEqual(DetoxStats.longestCleanDayStreak(in: [], calendar: utc), 0)
    }

    func testLongestUninterrupted() {
        let entries = [entry(date(2026, 10, 1), gap: 1200), entry(date(2026, 10, 2), gap: 9000)]
        XCTAssertEqual(DetoxStats.longestUninterruptedStreak(in: entries), 9000)
    }
}

// MARK: - Despertador

final class AlarmScheduleTests: XCTestCase {
    /// Armar às 22h pra 7h: é o 7h de amanhã, não agora.
    func testCrossesMidnight() {
        let next = AlarmSchedule.nextOccurrence(hour: 7, minute: 0, after: date(2026, 10, 21, 22, 30), calendar: utc)
        XCTAssertEqual(next, date(2026, 10, 22, 7, 0))
    }

    func testLaterTodayStaysToday() {
        let next = AlarmSchedule.nextOccurrence(hour: 23, minute: 50, after: date(2026, 10, 21, 22, 30), calendar: utc)
        XCTAssertEqual(next, date(2026, 10, 21, 23, 50))
    }

    /// Exatamente no horário: estritamente depois, então vai pro dia seguinte.
    func testSameMinuteGoesToTomorrow() {
        let next = AlarmSchedule.nextOccurrence(hour: 7, minute: 0, after: date(2026, 10, 21, 7, 0), calendar: utc)
        XCTAssertEqual(next, date(2026, 10, 22, 7, 0))
    }

    func testEndOfMonthAndYear() {
        XCTAssertEqual(AlarmSchedule.nextOccurrence(hour: 6, minute: 0, after: date(2026, 12, 31, 23, 0), calendar: utc),
                       date(2027, 1, 1, 6, 0))
    }

    /// 22/10/2026 é quinta, 23 sexta, 24 sábado.
    private func weekRoutine() -> SleepRoutine {
        var r = SleepRoutine(name: "Semana", alarmHour: 6, alarmMinute: 30, soundOption: .rain)
        r.setPerDayAlarms(true)
        r.weekdayAlarms?[6] = AlarmTime(hour: 9, minute: 0)   // sábado
        r.weekdayAlarms?[0] = AlarmTime(hour: 9, minute: 30)  // domingo
        return r
    }

    func testPerDayUsesNextMorningTime() {
        let r = weekRoutine()
        // Quinta 22h → sexta 6h30.
        XCTAssertEqual(r.nextAlarmDate(after: date(2026, 10, 22, 22), calendar: utc), date(2026, 10, 23, 6, 30))
        // Sexta 23h → sábado 9h, não 6h30.
        XCTAssertEqual(r.nextAlarmDate(after: date(2026, 10, 23, 23), calendar: utc), date(2026, 10, 24, 9, 0))
        // Sábado 0h40 (já passou da meia-noite) → o mesmo sábado 9h.
        XCTAssertEqual(r.nextAlarmDate(after: date(2026, 10, 24, 0, 40), calendar: utc), date(2026, 10, 24, 9, 0))
        // Sábado 23h → domingo 9h30.
        XCTAssertEqual(r.nextAlarmDate(after: date(2026, 10, 24, 23), calendar: utc), date(2026, 10, 25, 9, 30))
    }

    func testReminderNextSevenNights() {
        let dates = AlarmSchedule.upcomingDaily(hour: 22, minute: 30, after: date(2026, 10, 22, 23), count: 7, calendar: utc)
        XCTAssertEqual(dates.count, 7)
        XCTAssertEqual(dates.first, date(2026, 10, 23, 22, 30))
        XCTAssertEqual(dates.last, date(2026, 10, 29, 22, 30))
    }

    /// Luminária lida às 21h: o lembrete das 22h30 de hoje sai, o de amanhã fica.
    func testReminderSkipsTonightWhenNightStarted() {
        let now = date(2026, 10, 22, 21)
        let dates = AlarmSchedule.upcomingDaily(hour: 22, minute: 30, after: now, count: 7,
                                                skipUntil: now.addingTimeInterval(12 * 3600), calendar: utc)
        XCTAssertEqual(dates.first, date(2026, 10, 23, 22, 30))
        XCTAssertEqual(dates.count, 7)
    }

    func testReminderRoundTripAndBadValue() throws {
        var r = SleepRoutine(name: "L", soundOption: .rain)
        r.bedtimeReminder = AlarmTime(hour: 22, minute: 15)
        XCTAssertEqual(try JSONDecoder().decode(SleepRoutine.self, from: JSONEncoder().encode(r)), r)
        let json = """
        {"id":"6F1C2A5E-0000-4000-8000-000000000003","name":"X","alarmHour":7,"alarmMinute":0,
         "nightShiftOffHour":7,"nightShiftOffMinute":30,"soundOption":"birds",
         "bedtimeReminder":{"hour":27,"minute":0}}
        """
        XCTAssertNil(try decode(SleepRoutine.self, json).bedtimeReminder)
    }

    func testSameEveryDayMatchesNextOccurrence() {
        let r = SleepRoutine(name: "Igual", alarmHour: 7, alarmMinute: 0, soundOption: .rain)
        let now = date(2026, 10, 23, 23, 15)
        XCTAssertEqual(r.nextAlarmDate(after: now, calendar: utc),
                       AlarmSchedule.nextOccurrence(hour: 7, minute: 0, after: now, calendar: utc))
        XCTAssertEqual(r.alarmSummary, "07:00")
    }

    func testTogglePerDayKeepsTimes() {
        var r = weekRoutine()
        XCTAssertEqual(r.alarmSummary, "varia por dia")
        r.setPerDayAlarms(false)
        XCTAssertNil(r.weekdayAlarms)
        XCTAssertEqual(r.alarmHour, 6)       // o horário de segunda
        XCTAssertEqual(r.alarmMinute, 30)
    }
}

// MARK: - Protocolo da lâmpada (bytes)

final class LampProtocolTests: XCTestCase {
    func testColorFromMixRespectsLimiter() {
        let laranja = LampColor(mix: 0.5, brightness: 1)
        // Mistura meio a meio: 255 + 255 passaria do limite de 408 → divide igual.
        XCTAssertEqual(Int(laranja.amber) + Int(laranja.red), Int(LampProtocol.powerLimit))
        XCTAssertEqual(laranja.amber, laranja.red)
        XCTAssertEqual(LampColor(mix: 0, brightness: 1), LampColor(amber: 255, red: 0))
        XCTAssertEqual(LampColor(mix: 1, brightness: 1), LampColor(amber: 0, red: 255))
        XCTAssertEqual(LampColor(mix: 1, brightness: 0), .off)
    }

    func testColorMixAndBrightnessRoundTrip() {
        let c = LampColor(mix: 0.25, brightness: 0.6)
        XCTAssertEqual(c.mix, 0.25, accuracy: 0.02)
        XCTAssertEqual(c.brightness, 0.6, accuracy: 0.02)
    }

    /// "Ao dormir": apaga a partir da luz acesa; apagada continua apagada; 15–60 min.
    func testSleepFadeStartsFromCurrentLight() {
        var s = LampSleepSettings()
        s.minutes = 30
        let lit = LampColor(amber: 120, red: 40)
        XCTAssertEqual(s.fadeCommand(current: lit), .fadeOut(from: lit, minutes: 30))
        XCTAssertNil(s.fadeCommand(current: .off))
        XCTAssertNil(s.fadeCommand(current: nil))
        s.enabled = false
        XCTAssertNil(s.fadeCommand(current: lit))
    }

    func testSleepFadeMinutesClampedForOldRoutines() {
        var s = LampSleepSettings()
        s.minutes = 5
        XCTAssertEqual(s.fadeMinutes, 15)
        s.minutes = 120
        XCTAssertEqual(s.fadeMinutes, 60)
        XCTAssertEqual(LampSleepSettings().fadeMinutes, 15)
    }

    func testCommandBytes() {
        XCTAssertEqual(LampCommand.color(LampColor(amber: 10, red: 20)).bytes(), [0x01, 10, 20])
        XCTAssertEqual(LampCommand.off.bytes(), [0x02])
        XCTAssertEqual(LampCommand.cancelToday.bytes(), [0x05])
        XCTAssertEqual(LampCommand.identify.bytes(), [0x06])
        XCTAssertEqual(LampCommand.fadeOut(from: LampColor(amber: 200, red: 50), minutes: 30).bytes(), [0x07, 200, 50, 30])
        XCTAssertEqual(LampCommand.setClock(date(2026, 10, 22, 23, 5)).bytes(calendar: utc), [0x03, 26, 10, 22, 23, 5, 0])
    }

    func testRoutinePayloadRoundTrip() {
        let r = LampRoutine(enabled: true, days: 0b0000100, onlyNext: true, hour: 6, minute: 45, rampMinutes: 15,
                            holdMinutes: 30, from: LampColor(amber: 0, red: 255), fromBrightness: 0,
                            to: LampColor(amber: 255, red: 0), toBrightness: 255)
        XCTAssertEqual(r.payload, [1, 0b1000_0100, 6, 45, 15, 30, 0, 255, 0, 255, 0, 255])
        XCTAssertEqual(LampRoutine(payload: r.payload), r)
        XCTAssertEqual(LampCommand.writeRoutine(r).bytes().first, 0x04)
        XCTAssertNil(LampRoutine(payload: [1, 2, 3]))
    }

    /// A rampa que começa antes da meia-noite volta pro dia anterior.
    func testRoutineStartTimeWrapsMidnight() {
        var r = LampRoutine.disabled
        r.hour = 0; r.minute = 10; r.rampMinutes = 15
        XCTAssertEqual(r.startTime.hour, 23)
        XCTAssertEqual(r.startTime.minute, 55)
    }

    func testDayBitMondayToSunday() {
        // 19/10/2026 é segunda-feira.
        XCTAssertEqual(LampRoutine.dayBit(for: date(2026, 10, 19), calendar: utc), 0b0000001)
        XCTAssertEqual(LampRoutine.dayBit(for: date(2026, 10, 25), calendar: utc), 0b1000000)
    }

    func testWakeSettingsMakeOneShotRoutine() {
        let r = LampWakeSettings().lampRoutine(alarmDate: date(2026, 10, 22, 7, 0), calendar: utc)
        XCTAssertTrue(r.onlyNext)
        XCTAssertEqual(r.hour, 7)
        XCTAssertEqual(r.days, LampRoutine.dayBit(for: date(2026, 10, 22), calendar: utc))
        XCTAssertTrue(r.isValid)
    }

    func testStateBytesRoundTripAndVersionCheck() {
        var clock = DateComponents()
        clock.year = 2026; clock.month = 10; clock.day = 22; clock.hour = 6; clock.minute = 30; clock.second = 5
        let s = LampState(mode: .fading, color: LampColor(amber: 100, red: 40), clockValid: true, limiterActive: false,
                          pairingWindowOpen: true, routineEnabled: true, clock: clock, lastResult: .ok)
        XCTAssertEqual(s.bytes.count, LampState.byteCount)
        XCTAssertEqual(LampState(bytes: s.bytes), s)
        var v1 = s.bytes
        v1[0] = 1
        XCTAssertNil(LampState(bytes: v1), "versão de protocolo desconhecida tem que ser recusada")
        XCTAssertEqual(LampState.version(of: v1), 1)
    }
}


// MARK: - Quiz da primeira noite

final class FirstNightAnswersTests: XCTestCase {
    func testAnswersBuildRoutine() {
        var r = SleepRoutine(name: "Minha rotina", alarmHour: 7, alarmMinute: 0, soundOption: .rain)
        FirstNightAnswers(wakeMinutes: 6 * 60 + 45, relaxMinutes: 45, light: .morningOnly, reminderMinutes: 22 * 60 + 15)
            .apply(to: &r)
        XCTAssertEqual(r.alarmHour, 6)
        XCTAssertEqual(r.alarmMinute, 45)
        XCTAssertEqual(r.lampSleep.minutes, 45)
        XCTAssertFalse(r.lampSleep.enabled)
        XCTAssertTrue(r.lampWake.enabled)
        XCTAssertEqual(r.bedtimeReminder, AlarmTime(hour: 22, minute: 15))
    }

    func testNoLampQuestionKeepsLampSettingsAndNoReminderClearsIt() {
        var r = SleepRoutine(name: "R", soundOption: .rain)
        r.lampWake.enabled = false
        r.bedtimeReminder = AlarmTime(hour: 23, minute: 0)
        FirstNightAnswers(wakeMinutes: 8 * 60, light: nil, reminderMinutes: nil).apply(to: &r)
        XCTAssertFalse(r.lampWake.enabled, "sem a pergunta da luz, nada muda na lâmpada")
        XCTAssertNil(r.bedtimeReminder)
    }

    func testPerDayAlarmsKeptWhenWakeTimeUnchanged() {
        var r = SleepRoutine(name: "R", alarmHour: 7, alarmMinute: 0, soundOption: .rain)
        r.setPerDayAlarms(true)
        FirstNightAnswers(wakeMinutes: 7 * 60).apply(to: &r)
        XCTAssertNotNil(r.weekdayAlarms)
        FirstNightAnswers(wakeMinutes: 7 * 60 + 15).apply(to: &r)
        XCTAssertNil(r.weekdayAlarms)
    }
}
