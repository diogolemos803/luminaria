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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
