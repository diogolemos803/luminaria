import UIKit

/// Dispara o Atalho "Dormir sem celular" via URL scheme do app Atalhos.
///
/// A Apple não oferece API pública para um app terceiro criar ou ativar um Focus Mode
/// diretamente, nem para gravar programaticamente um Atalho com a ação "Definir Foco".
/// Por isso o fluxo real é: o usuário cria esse Atalho uma única vez no app Atalhos
/// (com a ação "Definir Foco"), e este app apenas o executa a cada reconhecimento da tag.
final class ShortcutManager {
    static let shared = ShortcutManager()
    static let shortcutName = "Dormir sem celular"

    private init() {}

    var isShortcutsAppAvailable: Bool {
        guard let url = URL(string: "shortcuts://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// Executa o atalho já configurado pelo usuário.
    func runSleepShortcut(completion: ((Bool) -> Void)? = nil) {
        let encodedName = Self.shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            ?? Self.shortcutName
        guard let url = URL(string: "shortcuts://run-shortcut?name=\(encodedName)") else {
            completion?(false)
            return
        }
        UIApplication.shared.open(url, options: [:]) { success in
            completion?(success)
        }
    }

    /// Abre o app Atalhos para o usuário criar o atalho manualmente (passo único de configuração).
    func openShortcutsAppToCreate() {
        let url = URL(string: "shortcuts://create-shortcut") ?? URL(string: "shortcuts://")!
        UIApplication.shared.open(url)
    }
}
