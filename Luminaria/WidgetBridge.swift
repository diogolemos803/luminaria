import Foundation
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Lado do app da ponte com a `LuminariaWidgetExtension` (protótipo aprovado em
/// `design/widget_prototipo.html`): publica sequência/recorde no App Group pros widgets da
/// tela bloqueada e controla a Atividade ao Vivo da noite. Olhar a tela bloqueada não
/// conta como "mexer no celular", então é por aqui que a pessoa acompanha o desafio sem
/// arriscar a noite.
///
/// O estado armado/horário do despertador continua sendo escrito por
/// `AlarmManager.updateWidgetState` — aqui ficam só as estatísticas de detox.
enum WidgetBridge {
    // MARK: Widgets da tela bloqueada

    /// Chamado ao abrir o app e sempre que uma noite é registrada.
    static func publishStats() {
        guard let defaults = UserDefaults(suiteName: SharedWidgetData.suiteName) else { return }
        let entries = SleepReportStore.shared.entries
        let cleanDates = entries.filter { $0.endReason == .alarmFired }.map(\.date)
        defaults.set(DetoxStats.currentCleanDayStreak(in: entries), forKey: SharedWidgetData.currentStreakKey)
        defaults.set(DetoxStats.longestCleanDayStreak(in: entries), forKey: SharedWidgetData.longestStreakKey)
        defaults.set(cleanDates.max()?.timeIntervalSince1970, forKey: SharedWidgetData.lastCleanNightKey)
        WidgetCenter.shared.reloadTimelines(ofKind: SharedWidgetData.widgetKind)
    }

    // MARK: Atividade ao Vivo da noite

    /// Começa quando a luminária é lida (app em primeiro plano — a Apple só deixa iniciar
    /// assim). Encerra antes qualquer atividade que tenha sobrado de uma noite anterior.
    static func startNightActivity(alarmDate: Date?) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        guard let alarmDate, alarmDate > Date(), ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let streak = DetoxStats.currentCleanDayStreak(in: SleepReportStore.shared.entries)
        let destination = PlanetMilestones.next(afterStreak: streak) ?? PlanetMilestones.all[PlanetMilestones.all.count - 1]
        let attributes = NightSessionActivityAttributes(
            sessionStart: Date(),
            alarmDate: alarmDate,
            destinationID: destination.id,
            destinationName: destination.name
        )
        let state = NightSessionActivityAttributes.ContentState(streak: streak, impactAt: nil)
        Task {
            await endAllNightActivities()
            // fica "velha" 15 min depois do despertador, caso o app não chegue a encerrar
            let content = ActivityContent(state: state, staleDate: alarmDate.addingTimeInterval(15 * 60))
            _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
        }
        #endif
    }

    /// Meteoro: a pessoa reabriu o app (ou usou o passe) — o cartão mostra o impacto e a
    /// barra recomeça desse instante.
    static func markImpact(at date: Date) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        Task {
            for activity in Activity<NightSessionActivityAttributes>.activities {
                var state = activity.content.state
                state.impactAt = date
                await activity.update(ActivityContent(state: state, staleDate: activity.content.staleDate))
            }
        }
        #endif
    }

    /// Noite encerrada (despertador, desarme ou passe de emergência).
    static func endNightActivity() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }
        Task { await endAllNightActivities() }
        #endif
    }

    #if canImport(ActivityKit)
    @available(iOS 16.2, *)
    private static func endAllNightActivities() async {
        for activity in Activity<NightSessionActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
    #endif
}
