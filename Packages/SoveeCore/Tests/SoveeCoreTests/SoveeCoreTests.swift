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
