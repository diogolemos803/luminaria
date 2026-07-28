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

    /// Executa o atalho já configurado pelo usuário via x-callback-url: evita abrir o app
    /// Atalhos por completo (mostra só um aviso rápido e volta pro Luminária sozinho).
    ///
    /// Manda o horário do despertador (escolhido em Configurações) como texto de entrada —
    /// o Atalho precisa ter a ação "Obter Datas da Entrada" logo no início pra converter esse
    /// texto num horário de verdade antes de "Definir Despertador".
    func runSleepShortcut(completion: ((Bool) -> Void)? = nil) {
        let encodedName = Self.shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            ?? Self.shortcutName
        let successURL = "luminaria://shortcut-done".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let errorURL = "luminaria://shortcut-error".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let alarmInput = Self.formattedAlarmTime()
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "shortcuts://x-callback-url/run-shortcut?name=\(encodedName)&input=text&text=\(alarmInput)&x-success=\(successURL)&x-error=\(errorURL)"
        guard let url = URL(string: urlString) else {
            completion?(false)
            return
        }
        UIApplication.shared.open(url, options: [:]) { success in
            completion?(success)
        }
    }

    /// Horário do despertador escolhido em Configurações, formatado num padrão que a ação
    /// "Obter Datas da Entrada" do Atalhos reconhece de forma confiável.
    private static func formattedAlarmTime() -> String {
        let defaults = UserDefaults.standard
        let hour = defaults.object(forKey: "alarmHour") as? Int ?? 7
        let minute = defaults.object(forKey: "alarmMinute") as? Int ?? 0

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        let date = Calendar.current.date(from: components) ?? Date()

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    /// Abre o app Atalhos para o usuário criar o atalho manualmente (passo único de configuração).
    func openShortcutsAppToCreate() {
        let url = URL(string: "shortcuts://create-shortcut") ?? URL(string: "shortcuts://")!
        UIApplication.shared.open(url)
    }
}
