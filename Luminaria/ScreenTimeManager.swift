import Combine
import Foundation
import FamilyControls
import ManagedSettings

/// Bloqueia os apps/categorias escolhidos pelo usuário enquanto o modo noite estiver
/// ativo, usando a Screen Time API da Apple (`FamilyControls`/`ManagedSettings`) — a
/// mesma base que apps como Brick/Opal usam pra isso. Precisa da entitlement
/// `com.apple.developer.family-controls`, que a Apple aprova manualmente por um
/// pedido separado (não vem só de ter a conta Developer paga) — só funciona de
/// verdade num device físico depois disso, nunca no Simulador.
///
/// Por privacidade, o app NUNCA fica sabendo quais apps foram escolhidos — só tokens
/// opacos (`ApplicationToken`/`ActivityCategoryToken`/`WebDomainToken`). Dá pra saber
/// quantos foram escolhidos, não quais.
final class ScreenTimeManager: ObservableObject {
    static let shared = ScreenTimeManager()

    @Published var isAuthorized: Bool?
    /// Persistido e restaurado no `init()` — sem isso, se o processo morrer com o
    /// bloqueio ativo (o `ManagedSettingsStore` continua valendo mesmo com o app
    /// fechado), o app reabriria mostrando "Living mode" sem nenhum caminho de
    /// código pra desarmar, trancando os apps da pessoa até ela ir manualmente em
    /// Ajustes → Tempo de Uso.
    @Published private(set) var isShieldActive: Bool
    /// Quando o passe de emergência volta a ficar disponível; `nil` = disponível.
    /// **1 passe por noite** (decisão do usuário, 2026-09-25): usar o passe encerra a
    /// noite, e ele só volta no horário em que o despertador daquela noite tocaria —
    /// preso ao ciclo real do sono, não a "24h a partir do uso" (usar às 23h poderia
    /// deixar a pessoa sem passe na noite seguinte). Antes eram 2 passes por sessão, que
    /// deixou de fazer sentido quando o passe passou a encerrar a sessão.
    @Published private(set) var emergencyPassAvailableAgainAt: Date?

    var isEmergencyPassAvailable: Bool {
        guard let date = emergencyPassAvailableAgainAt else { return true }
        return Date() >= date
    }

    private let store = ManagedSettingsStore()
    private var shieldEngagedAt: Date?
    /// Quantidade de apps/categorias/sites aplicados no `applyShield` mais recente —
    /// persistida separado (não a seleção inteira) só pra `removeShield` conseguir
    /// registrar o relatório com o número certo mesmo se o processo tiver morrido e
    /// relançado entre o armar e o desarmar.
    private var lastAppliedCount: Int

    private static let shieldActiveKey = "com.luminaria.screenTime.shieldActive"
    private static let shieldEngagedAtKey = "com.luminaria.screenTime.shieldEngagedAt"
    private static let lastAppliedCountKey = "com.luminaria.screenTime.lastAppliedCount"
    private static let emergencyPassAvailableAtKey = "com.luminaria.screenTime.emergencyPassAvailableAt"
    /// Sem despertador armado pra servir de referência (não deveria acontecer numa
    /// sessão normal), o passe volta depois de 24h.
    private static let emergencyPassFallbackInterval: TimeInterval = 24 * 60 * 60

    private init() {
        let defaults = UserDefaults.standard
        isShieldActive = defaults.bool(forKey: Self.shieldActiveKey)
        lastAppliedCount = defaults.integer(forKey: Self.lastAppliedCountKey)
        if defaults.object(forKey: Self.emergencyPassAvailableAtKey) != nil {
            emergencyPassAvailableAgainAt = Date(timeIntervalSince1970: defaults.double(forKey: Self.emergencyPassAvailableAtKey))
        }
        if defaults.object(forKey: Self.shieldEngagedAtKey) != nil {
            shieldEngagedAt = Date(timeIntervalSince1970: defaults.double(forKey: Self.shieldEngagedAtKey))
        }
        // Nota: o `ManagedSettingsStore` da Apple continua valendo sozinho entre
        // lançamentos do processo (não precisa reaplicar aqui) — só o estado próprio
        // do app (`isShieldActive`/duração/contagem) precisa ser restaurado.
    }

    /// Revalida junto do sistema — a autorização pode ser revogada nos Ajustes do
    /// iPhone a qualquer momento, sem o app saber. Chamado sempre que o app volta a
    /// ficar ativo (mesmo padrão do `scenePhase` já usado pro despertador).
    func refreshAuthorizationStatus() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    func requestAuthorization() {
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                await MainActor.run { self.isAuthorized = true }
            } catch {
                await MainActor.run { self.isAuthorized = false }
            }
        }
    }

    /// Chamado quando a luminária é reconhecida via NFC com o modo noite armado —
    /// mesmo instante em que o Atalho e o despertador nativo também disparam. A
    /// seleção vem da rotina ativa no momento (`SleepRoutine.appSelection`), não mais
    /// de um estado global — cada rotina bloqueia seus próprios apps.
    func applyShield(selection: FamilyActivitySelection) {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        isShieldActive = true
        shieldEngagedAt = Date()
        lastAppliedCount = selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
        NightSessionActivityTracker.shared.sessionDidStart()
        persistShieldState()
    }

    /// Chamado quando a pessoa desarma o modo noite pelo botão redondo (ou quando o
    /// despertador toca, ver `AlarmManager.triggerAlarm`, ou um passe de emergência é
    /// usado, ver `useEmergencyPass`). `reason` alimenta `DetoxStats.
    /// longestCleanDayStreak` (item 2b) — só sessões que terminam com `.alarmFired`
    /// contam como "limpas".
    ///
    /// Sem bloqueio ativo, não faz nada — bug real corrigido (2026-09-25): depois de um
    /// passe de emergência, o despertador ainda toca de manhã e chamava isto de novo,
    /// gravando uma segunda sessão como `.alarmFired` ("limpa"), o que anulava o efeito
    /// do passe na sequência de dias.
    func removeShield(reason: DetoxSessionEndReason) {
        guard isShieldActive else { return }
        store.clearAllSettings()
        WidgetBridge.endNightActivity()
        isShieldActive = false
        let duration = shieldEngagedAt.map { Date().timeIntervalSince($0) } ?? 0
        let longestUninterrupted = NightSessionActivityTracker.shared.sessionDidEnd()
        SleepReportStore.shared.recordSession(
            appCount: lastAppliedCount,
            duration: duration,
            endReason: reason,
            longestUninterruptedSeconds: longestUninterrupted
        )
        shieldEngagedAt = nil
        persistShieldState()
    }

    /// Pra emergências reais (ligação urgente, saúde): libera os apps e encerra a noite
    /// — a `ContentView` volta pro modo dia (pedido do usuário, 2026-09-25). O
    /// despertador da manhã **continua armado** (decisão do usuário): é isso que
    /// diferencia o passe de desligar pelo botão redondo, que cancela tudo.
    /// `nextAlarmDate` é o horário do despertador desta noite — o passe só volta a
    /// ficar disponível a partir dele (ver `emergencyPassAvailableAgainAt`).
    ///
    /// Também conta como um "toque" pro `NightSessionActivityTracker` (item 3b/2c) —
    /// é uma das duas únicas ações reais e detectáveis que significam "a pessoa
    /// mexeu no celular" durante a sessão.
    func useEmergencyPass(nextAlarmDate: Date?) -> Bool {
        guard isEmergencyPassAvailable, isShieldActive else { return false }
        emergencyPassAvailableAgainAt = nextAlarmDate ?? Date().addingTimeInterval(Self.emergencyPassFallbackInterval)
        NightSessionActivityTracker.shared.registerTouchEvent()
        removeShield(reason: .emergencyPass)
        return true
    }

    private func persistShieldState() {
        let defaults = UserDefaults.standard
        defaults.set(isShieldActive, forKey: Self.shieldActiveKey)
        defaults.set(lastAppliedCount, forKey: Self.lastAppliedCountKey)
        defaults.set(emergencyPassAvailableAgainAt?.timeIntervalSince1970, forKey: Self.emergencyPassAvailableAtKey)
        if let shieldEngagedAt {
            defaults.set(shieldEngagedAt.timeIntervalSince1970, forKey: Self.shieldEngagedAtKey)
        } else {
            defaults.removeObject(forKey: Self.shieldEngagedAtKey)
        }
    }
}
