import Foundation
#if canImport(AppIntents)
import AppIntents
#endif
#if canImport(ActivityKit)
import ActivityKit
#endif

// Compilado nos DOIS alvos (app e `LuminariaWidgetExtension`): o botão "luminária" da
// Central de Controle (iOS 18+, `LampControlWidget`) mora na extensão, mas quem fala
// Bluetooth com a lâmpada é o app. A intenção abaixo é `LiveActivityIntent` (o iOS roda o
// `perform` no processo do APP, abrindo o app em segundo plano se preciso — mesmo truque
// do "Parar" do AlarmKit) e chama `LampControlBridge`, que tem duas versões: a de verdade
// no app (`LampIntents.swift`) e uma vazia na extensão (`LampControlWidget.swift`), só pra
// compilar.

enum LampControlShared {
    static let controlKind = "com.luminaria.app.LampControl"
    /// Última vez que o app viu a lâmpada: acesa ou apagada (App Group). O botão mostra
    /// esse valor; o app regrava a cada STATE que muda.
    static let isLitKey = "lamp.isLit"

    static var lastKnownLit: Bool {
        UserDefaults(suiteName: SharedWidgetData.suiteName)?.bool(forKey: isLitKey) ?? false
    }
}

#if canImport(AppIntents)
@available(iOS 18.0, *)
struct ToggleLampControlIntent: SetValueIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Luminária"
    static let isDiscoverable = false

    @Parameter(title: "Acesa")
    var value: Bool

    init() {}

    func perform() async throws -> some IntentResult {
        _ = await LampControlBridge.setLit(value)
        return .result()
    }
}
#endif
