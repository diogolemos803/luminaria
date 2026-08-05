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
    @Published var selection: FamilyActivitySelection
    /// Persistido e restaurado no `init()` — sem isso, se o processo morrer com o
    /// bloqueio ativo (o `ManagedSettingsStore` continua valendo mesmo com o app
    /// fechado), o app reabriria mostrando "Living mode" sem nenhum caminho de
    /// código pra desarmar, trancando os apps da pessoa até ela ir manualmente em
    /// Ajustes → Tempo de Uso.
    @Published private(set) var isShieldActive: Bool

    private let store = ManagedSettingsStore()
    private var shieldEngagedAt: Date?

    private static let selectionKey = "com.luminaria.screenTime.selection"
    private static let shieldActiveKey = "com.luminaria.screenTime.shieldActive"
    private static let shieldEngagedAtKey = "com.luminaria.screenTime.shieldEngagedAt"

    private init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.selectionKey),
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = decoded
        } else {
            selection = FamilyActivitySelection()
        }
        isShieldActive = defaults.bool(forKey: Self.shieldActiveKey)
        if defaults.object(forKey: Self.shieldEngagedAtKey) != nil {
            shieldEngagedAt = Date(timeIntervalSince1970: defaults.double(forKey: Self.shieldEngagedAtKey))
        }
        if isShieldActive {
            applyStoreSettings()
        }
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

    func updateSelection(_ newSelection: FamilyActivitySelection) {
        selection = newSelection
        if let data = try? JSONEncoder().encode(selection) {
            UserDefaults.standard.set(data, forKey: Self.selectionKey)
        }
        if isShieldActive {
            applyStoreSettings()
        }
    }

    var totalSelectedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    /// Chamado quando a luminária é reconhecida via NFC com o modo noite armado —
    /// mesmo instante em que o Atalho e o despertador nativo também disparam.
    func applyShield() {
        applyStoreSettings()
        isShieldActive = true
        shieldEngagedAt = Date()
        persistShieldState()
    }

    /// Chamado quando a pessoa desarma o modo noite pelo botão redondo.
    func removeShield() {
        store.clearAllSettings()
        isShieldActive = false
        let duration = shieldEngagedAt.map { Date().timeIntervalSince($0) } ?? 0
        SleepReportStore.shared.recordSession(appCount: totalSelectedCount, duration: duration)
        shieldEngagedAt = nil
        persistShieldState()
    }

    private func applyStoreSettings() {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    private func persistShieldState() {
        let defaults = UserDefaults.standard
        defaults.set(isShieldActive, forKey: Self.shieldActiveKey)
        if let shieldEngagedAt {
            defaults.set(shieldEngagedAt.timeIntervalSince1970, forKey: Self.shieldEngagedAtKey)
        } else {
            defaults.removeObject(forKey: Self.shieldEngagedAtKey)
        }
    }
}
