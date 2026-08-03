import SwiftUI
import UserNotifications

/// Precisa existir como AppDelegate (em vez de só configurar o delegate no `.onAppear`
/// da view) pra garantir que `UNUserNotificationCenter` já tenha o delegate certo desde o
/// primeiríssimo instante — inclusive quando o processo é relançado do zero pelo toque
/// numa notificação de alarme, caso em que `.onAppear` da SwiftUI roda tarde demais.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = AlarmManager.shared
        return true
    }
}

@main
struct LuminariaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var alarmManager = AlarmManager.shared

    var body: some Scene {
        WindowGroup {
            // O fullScreenCover do despertador precisa ficar aqui, acima do ContentView,
            // e não dentro dele: SwiftUI só permite UMA apresentação modal ativa por view,
            // então se ele ficasse no mesmo nível do .sheet do menu de Configurações, o
            // despertador não conseguiria aparecer por cima com o menu já aberto (bug real
            // encontrado no device físico). Num nível acima, ele cobre tudo, inclusive uma
            // sheet aberta por uma view descendente.
            ContentView()
                .fullScreenCover(isPresented: $alarmManager.isAlarmRinging) {
                    AlarmRingingView(alarmManager: alarmManager)
                }
        }
    }
}
