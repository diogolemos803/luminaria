import WidgetKit
import SwiftUI

@main
struct LuminariaWidgetBundle: WidgetBundle {
    var body: some Widget {
        // widget da tela bloqueada (círculo, retângulo e linha)
        AlarmWidget()
        // Atividade ao Vivo da noite (tela bloqueada + Dynamic Island) — a extensão tem
        // alvo mínimo iOS 16.2 por causa dela
        NightLiveActivityWidget()
    }
}
