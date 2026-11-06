import AppIntents
import SwiftUI
import WidgetKit

/// Botão "luminária" da Central de Controle, da tela bloqueada e do Botão de Ação
/// (iOS 18+). Acende/apaga a lâmpada Bluetooth na última cor escolhida. O estado vem do
/// App Group (o app grava a cada mudança); tocar roda `ToggleLampControlIntent` no
/// processo do app (ver `LampControlShared.swift`).
@available(iOS 18.0, *)
struct LampControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: LampControlShared.controlKind, provider: Provider()) { isOn in
            ControlWidgetToggle("Luminária", isOn: isOn, action: ToggleLampControlIntent()) { on in
                Label(on ? "Acesa" : "Apagada", systemImage: on ? "lamp.table.fill" : "lamp.table")
            }
        }
        .displayName("luminária")
        .description("acende e apaga a luminária sovee.")
    }

    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }

        func currentValue() async throws -> Bool {
            LampControlShared.lastKnownLit
        }
    }
}

/// Versão da extensão: nunca roda de verdade (a intenção roda no processo do app, que tem
/// a versão real em `LampIntents.swift`). Existe só pra `ToggleLampControlIntent` compilar
/// aqui.
enum LampControlBridge {
    static func setLit(_ on: Bool) async -> Bool { false }
}
