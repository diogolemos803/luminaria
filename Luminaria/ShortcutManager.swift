import UIKit
import Combine

/// Dispara o Atalho "Dormir sem celular" via URL scheme do app Atalhos.
///
/// A Apple não oferece API pública para um app terceiro criar ou ativar um Focus Mode
/// diretamente, nem para gravar programaticamente um Atalho com a ação "Definir Foco".
/// Por isso o fluxo real é: o usuário cria esse Atalho uma única vez no app Atalhos
/// (com a ação "Definir Foco"), e este app apenas o executa a cada reconhecimento da tag.
///
/// Desligar o Foco quando a noite termina segue a mesma regra: nenhum app terceiro
/// consegue desligar um Foco sozinho, então existe um segundo Atalho, "Acordar"
/// (`wakeShortcutName`, com "Definir Foco" desligado), que o app executa quando o modo
/// noite é desligado, um passe de emergência é usado ou o despertador é parado no app
/// (`requestWakeShortcut()`). Abrir URL do Atalhos só funciona com o app em primeiro
/// plano — se a noite terminar com o app em segundo plano (ex.: "Parar" na notificação),
/// fica pendente e roda na próxima vez que o app abrir.
final class ShortcutManager {
    static let shared = ShortcutManager()
    static let shortcutName = "Dormir sem celular"
    static let wakeShortcutName = "Acordar"

    /// Links do iCloud pra instalar os dois Atalhos prontos (onboarding, 2026-10-22). Os
    /// atalhos NÃO têm horário: "Dormir sem celular" liga o Não Perturbe até desligar e
    /// "Acordar" desliga; o horário do despertador mora só no app. `nil` = link ainda não
    /// definido pelo dono (o botão "instalar" mostra "link em breve"). O app chama cada
    /// atalho pelo NOME exato acima — por isso o onboarding avisa pra não renomear e o
    /// "testar atalhos" (`ShortcutTester`) confere os dois.
    static let sleepShortcutInstallLink: String? = "https://www.icloud.com/shortcuts/8dda4d2564ea44d6977ed15bcea6210d"
    static let wakeShortcutInstallLink: String? = "https://www.icloud.com/shortcuts/89ad05d1a0a0461b9812173dfcf3824f"

    static func installURL(forShortcutNamed name: String) -> URL? {
        let link = name == shortcutName ? sleepShortcutInstallLink : wakeShortcutInstallLink
        return link.flatMap(URL.init(string:))
    }

    /// O Atalho de dormir rodou e o de acordar ainda não — só nesse caso vale abrir o
    /// Atalhos pra desligar o Foco (evita piscar o Atalhos à toa, ex.: armou o modo noite
    /// e cancelou antes de encostar a luminária).
    private static let sleepFocusOnKey = "com.luminaria.shortcut.sleepFocusOn"
    private static let wakePendingKey = "com.luminaria.shortcut.wakePending"

    private init() {}

    var isShortcutsAppAvailable: Bool {
        guard let url = URL(string: "shortcuts://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// Executa o atalho já configurado pelo usuário via x-callback-url: evita abrir o app
    /// Atalhos por completo (mostra só um aviso rápido e volta pro SOVEE sozinho).
    ///
    /// O despertador NÃO passa mais por aqui — é tratado nativamente pelo `AlarmManager`,
    /// sem depender do Atalho. Este método só cuida do Foco e do Modo Noturno.
    func runSleepShortcut(completion: ((Bool) -> Void)? = nil) {
        UserDefaults.standard.set(true, forKey: Self.sleepFocusOnKey)
        runShortcut(named: Self.shortcutName, completion: completion)
    }

    /// Fim da noite: executa o Atalho "Acordar" agora (app aberto) ou deixa pendente pra
    /// próxima abertura do app. Não faz nada se o Atalho de dormir não rodou.
    func requestWakeShortcut() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Self.sleepFocusOnKey) else {
            defaults.set(false, forKey: Self.wakePendingKey)
            return
        }
        guard UIApplication.shared.applicationState == .active else {
            defaults.set(true, forKey: Self.wakePendingKey)
            return
        }
        defaults.set(false, forKey: Self.sleepFocusOnKey)
        defaults.set(false, forKey: Self.wakePendingKey)
        runShortcut(named: Self.wakeShortcutName, completion: nil)
    }

    /// Chamado quando o app volta a ficar ativo.
    func runPendingWakeShortcutIfNeeded() {
        guard UserDefaults.standard.bool(forKey: Self.wakePendingKey) else { return }
        requestWakeShortcut()
    }

    private func runShortcut(named name: String, completion: ((Bool) -> Void)?) {
        guard let url = Self.runURL(named: name) else {
            completion?(false)
            return
        }
        UIApplication.shared.open(url, options: [:]) { success in
            completion?(success)
        }
    }

    /// URL do x-callback-url do Atalhos. `success`/`error` são as URLs de volta pro app.
    static func runURL(named name: String, success: String = "luminaria://shortcut-done",
                       error: String = "luminaria://shortcut-error") -> URL? {
        // Codifica tudo que não for letra/número/-._~ — as URLs de volta têm "?", "&" e
        // "=" que precisam ir escapados dentro do parâmetro.
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s }
        return URL(string: "shortcuts://x-callback-url/run-shortcut?name=\(enc(name))&x-success=\(enc(success))&x-error=\(enc(error))&x-cancel=\(enc(error))")
    }

    // MARK: - Diagnóstico do botão "Parar" do alarme (investigação de 2026-10-22)

    /// Resultado da última tentativa de rodar o "Acordar" a partir do "Parar" do alarme do
    /// sistema (que roda com o app em segundo plano). Mostrado na Ajuda pra o dono testar
    /// no iPhone: se `opened` vier `true` E o Não Perturbe tiver desligado de fato, a
    /// automação de segurança da manhã deixa de ser necessária.
    struct StopButtonDiagnostic: Codable {
        var date: Date
        /// Estado do app no momento: "ativo", "inativo" ou "segundo plano".
        var appState: String
        /// Havia um "Acordar" a rodar (o atalho de dormir tinha rodado nesta noite)?
        var attempted: Bool
        /// O iOS aceitou abrir a URL do Atalhos?
        var opened: Bool
    }

    private static let stopDiagnosticKey = "com.luminaria.shortcut.stopDiagnostic"

    static var lastStopDiagnostic: StopButtonDiagnostic? {
        guard let data = UserDefaults.standard.data(forKey: stopDiagnosticKey) else { return nil }
        return try? JSONDecoder().decode(StopButtonDiagnostic.self, from: data)
    }

    /// Chamado pelo "Parar" do AlarmKit. Tenta abrir o "Acordar" mesmo com o app em segundo
    /// plano e grava o que aconteceu. Não limpa os marcadores de pendência: se não tiver
    /// funcionado de verdade, o "Acordar" continua rodando quando o app abrir.
    @MainActor
    func attemptWakeFromAlarmStop() async {
        let defaults = UserDefaults.standard
        let stateName: String
        switch UIApplication.shared.applicationState {
        case .active: stateName = "ativo"
        case .inactive: stateName = "inativo"
        default: stateName = "segundo plano"
        }
        let needed = defaults.bool(forKey: Self.sleepFocusOnKey) || defaults.bool(forKey: Self.wakePendingKey)
        var opened = false
        if needed, let url = Self.runURL(named: Self.wakeShortcutName) {
            opened = await withCheckedContinuation { continuation in
                UIApplication.shared.open(url, options: [:]) { continuation.resume(returning: $0) }
            }
        }
        let record = StopButtonDiagnostic(date: Date(), appState: stateName, attempted: needed, opened: opened)
        if let data = try? JSONEncoder().encode(record) {
            defaults.set(data, forKey: Self.stopDiagnosticKey)
        }
    }

    /// Abre o app Atalhos para o usuário criar o atalho manualmente (passo único de configuração).
    func openShortcutsAppToCreate() {
        let url = URL(string: "shortcuts://create-shortcut") ?? URL(string: "shortcuts://")!
        UIApplication.shared.open(url)
    }
}

/// "Testar atalhos" do onboarding: roda "Dormir sem celular" e depois "Acordar" (liga e
/// desliga o Não Perturbe) e confere pelo x-callback-url se os dois existem com o nome
/// certo. O app não tem como listar os atalhos instalados; o que ele consegue saber é se o
/// Atalhos voltou pelo `x-success` ou pelo `x-error`.
final class ShortcutTester: ObservableObject {
    static let shared = ShortcutTester()

    enum State: Equatable {
        case idle
        case running
        case ok
        /// Nomes dos atalhos que o Atalhos não achou.
        case missing([String])
        /// O Atalhos não respondeu (ex.: mostrou um aviso e ficou lá).
        case noAnswer
    }

    @Published private(set) var state: State = .idle
    private var missing: [String] = []
    private var runID = UUID()

    private init() {}

    func start() {
        missing = []
        runID = UUID()
        state = .running
        run(step: "sleep")
        let id = runID
        DispatchQueue.main.asyncAfter(deadline: .now() + 40) { [weak self] in
            guard let self, self.runID == id, self.state == .running else { return }
            self.state = .noAnswer
        }
    }

    private func run(step: String) {
        let name = step == "sleep" ? ShortcutManager.shortcutName : ShortcutManager.wakeShortcutName
        let back = "luminaria://shortcut-test?run=\(runID.uuidString)&step=\(step)"
        guard let url = ShortcutManager.runURL(named: name, success: back + "&ok=1", error: back + "&ok=0") else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    /// Volta do Atalhos. Devolve `true` se a URL era deste teste.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme == "luminaria", url.host == "shortcut-test",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return false }
        func value(_ key: String) -> String? { items.first { $0.name == key }?.value }
        guard state == .running, value("run") == runID.uuidString, let step = value("step") else { return true }
        if value("ok") != "1" {
            missing.append(step == "sleep" ? ShortcutManager.shortcutName : ShortcutManager.wakeShortcutName)
        }
        if step == "sleep" {
            run(step: "wake")
        } else {
            state = missing.isEmpty ? .ok : .missing(missing)
        }
        return true
    }
}
