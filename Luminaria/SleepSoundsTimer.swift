import Foundation

// EXPERIMENTO "sons pra dormir" (item 6 do plano Hatch, 2026-10-22) — parte pura.
// Pra remover o experimento inteiro: apagar este arquivo e SleepSoundsExperiment.swift
// (e as 2 linhas que os citam, ver CLAUDE.md → "Sons pra dormir").

/// Por quanto tempo o som toca.
enum SleepSoundTimerChoice: Hashable {
    case minutes(Int)
    /// Até o horário do despertador armado.
    case untilAlarm

    static let all: [SleepSoundTimerChoice] = [.minutes(15), .minutes(30), .minutes(60), .minutes(90), .untilAlarm]

    var label: String {
        switch self {
        case .minutes(let m): return "\(m) min"
        case .untilAlarm: return "até o alarme"
        }
    }
}

enum SleepSoundTimer {
    /// Duração da diminuição no fim.
    static let fadeSeconds: TimeInterval = 60

    /// Quando o som termina. `untilAlarm` sem despertador armado (ou já passado) → `nil`.
    static func endDate(for choice: SleepSoundTimerChoice, now: Date, alarmDate: Date?) -> Date? {
        switch choice {
        case .minutes(let m):
            return now.addingTimeInterval(TimeInterval(max(m, 1)) * 60)
        case .untilAlarm:
            guard let alarmDate, alarmDate > now else { return nil }
            return alarmDate
        }
    }

    /// Volume relativo (0…1) em `now`: 1 até faltar 1 minuto, depois desce em linha reta
    /// até 0 no fim.
    static func volume(now: Date, end: Date, fade: TimeInterval = fadeSeconds) -> Float {
        let remaining = end.timeIntervalSince(now)
        if remaining <= 0 { return 0 }
        if remaining >= fade { return 1 }
        return Float(remaining / fade)
    }
}
