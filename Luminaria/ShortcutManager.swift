import UIKit

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
    /// Atalhos por completo (mostra só um aviso rápido e volta pro Luminária sozinho).
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
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            ?? name
        let successURL = "luminaria://shortcut-done".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let errorURL = "luminaria://shortcut-error".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "shortcuts://x-callback-url/run-shortcut?name=\(encodedName)&x-success=\(successURL)&x-error=\(errorURL)"
        guard let url = URL(string: urlString) else {
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
