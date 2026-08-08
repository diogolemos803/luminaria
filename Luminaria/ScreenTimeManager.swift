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
    /// Quantas vezes ainda dá pra liberar os apps sem esperar o despertador nesta
    /// sessão de bloqueio (não é um limite mensal — reseta a cada `applyShield`
    /// novo). Pedido do usuário pra casos reais (ligação urgente, saúde), inspirado
    /// nos "passes de emergência" do Brick, mas por sessão em vez de vitalício.
    @Published private(set) var emergencyPassesRemaining: Int

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
    private static let emergencyPassesKey = "com.luminaria.screenTime.emergencyPasses"
    private static let emergencyPassesPerSession = 2

    private init() {
        let defaults = UserDefaults.standard
        isShieldActive = defaults.bool(forKey: Self.shieldActiveKey)
        lastAppliedCount = defaults.integer(forKey: Self.lastAppliedCountKey)
        // `integer(forKey:)` sozinho devolveria 0 numa instalação nova (chave
        // ausente) — checar `object(forKey:)` primeiro garante que quem nunca
        // armou o bloqueio comece com os 2 passes cheios, não com 0.
        emergencyPassesRemaining = defaults.object(forKey: Self.emergencyPassesKey) != nil
            ? defaults.integer(forKey: Self.emergencyPassesKey)
            : Self.emergencyPassesPerSession
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
        // Reseta a cada sessão de bloqueio nova — não é um limite mensal, é "2
        // chances por noite", contado a partir do mesmo instante em que o bloqueio
        // de verdade começa.
        emergencyPassesRemaining = Self.emergencyPassesPerSession
        persistShieldState()
    }

    /// Chamado quando a pessoa desarma o modo noite pelo botão redondo (ou quando o
    /// despertador toca, ver `AlarmManager.triggerAlarm`).
    func removeShield() {
        store.clearAllSettings()
        isShieldActive = false
        let duration = shieldEngagedAt.map { Date().timeIntervalSince($0) } ?? 0
        SleepReportStore.shared.recordSession(appCount: lastAppliedCount, duration: duration)
        shieldEngagedAt = nil
        persistShieldState()
    }

    /// Libera os apps na hora, sem esperar o despertador — pra emergências reais
    /// (ligação urgente, saúde), não pra "desistir da noite". Por isso NÃO desarma o
    /// despertador nem a sessão NFC: só o bloqueio de apps termina cedo, o resto do
    /// modo noite continua exatamente como estava. `isNightModeArmed` na
    /// `ContentView` também não muda por causa disso — a tela continua no tema
    /// escuro, só o botão de passe some sozinho (`isShieldActive` vira `false`).
    func useEmergencyPass() -> Bool {
        guard emergencyPassesRemaining > 0 else { return false }
        emergencyPassesRemaining -= 1
        removeShield()
        return true
    }

    private func persistShieldState() {
        let defaults = UserDefaults.standard
        defaults.set(isShieldActive, forKey: Self.shieldActiveKey)
        defaults.set(lastAppliedCount, forKey: Self.lastAppliedCountKey)
        defaults.set(emergencyPassesRemaining, forKey: Self.emergencyPassesKey)
        if let shieldEngagedAt {
            defaults.set(shieldEngagedAt.timeIntervalSince1970, forKey: Self.shieldEngagedAtKey)
        } else {
            defaults.removeObject(forKey: Self.shieldEngagedAtKey)
        }
    }
}
