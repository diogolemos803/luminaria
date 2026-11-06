import AppIntents
import Foundation
import WidgetKit

// SIRI E ATALHOS PRA LÂMPADA (2026-11-06, pedido do dono). Só controla a luz — começar a
// noite continua exigindo encostar o celular na luminária (regra do produto).
//
// Os comandos rodam no processo do app, abrindo em segundo plano quando preciso
// (`openAppWhenRun = false`); o Bluetooth em segundo plano (`UIBackgroundModes:
// bluetooth-central`) deixa conectar e mandar o comando sem abrir a tela. Precisa estar
// perto da lâmpada, como sempre. iOS 17+ (o app continua iOS 16; abaixo do 17 não aparece).

// MARK: - Ponte com o LampManager

enum LampControlBridge {
    /// Acende (na última cor escolhida) ou apaga. `false` = sem lâmpada ou não conectou.
    @MainActor
    static func setLit(_ on: Bool) async -> Bool {
        await run { lamp in on ? lamp.turnOn() : lamp.turnOff() }
    }

    /// Conecta (se preciso), roda o comando e espera um instante pra ele sair antes de o
    /// iOS suspender o app de novo.
    @MainActor
    static func run(_ action: (LampManager) -> Void) async -> Bool {
        let lamp = LampManager.shared
        guard await lamp.waitUntilReady() else { return false }
        action(lamp)
        try? await Task.sleep(nanoseconds: 700_000_000)
        return true
    }
}

/// Grava no App Group se a lâmpada está acesa, pro botão da Central de Controle.
enum LampControlState {
    private static var lastPublished: Bool?

    static func publish(isLit: Bool) {
        guard isLit != lastPublished else { return }
        lastPublished = isLit
        UserDefaults(suiteName: SharedWidgetData.suiteName)?.set(isLit, forKey: LampControlShared.isLitKey)
        if #available(iOS 18.0, *) {
            ControlCenter.shared.reloadControls(ofKind: LampControlShared.controlKind)
        }
    }
}

// MARK: - Erros falados pela Siri

@available(iOS 17.0, *)
enum LampIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noLamp
    case unreachable
    case scenesOff

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noLamp: return "nenhuma luminária pareada no sovee."
        case .unreachable: return "não achei a luminária. ela está na tomada e perto do celular?"
        case .scenesOff: return "os cenários estão em teste. ligue em lâmpada, cenários (teste), no app."
        }
    }
}

@available(iOS 17.0, *)
@MainActor
private func runOnLamp(_ action: (LampManager) -> Void) async throws {
    guard LampManager.shared.hasLamp else { throw LampIntentError.noLamp }
    guard await LampControlBridge.run(action) else { throw LampIntentError.unreachable }
}

// MARK: - Opções

@available(iOS 17.0, *)
enum LampColorOption: String, AppEnum {
    case amarelo, ambar, laranja, laranjaVermelho, vermelho

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Cor"
    static let caseDisplayRepresentations: [LampColorOption: DisplayRepresentation] = [
        .amarelo: DisplayRepresentation(title: "amarelo", synonyms: ["amarela"]),
        .ambar: DisplayRepresentation(title: "âmbar", synonyms: ["âmbar quente", "ambar"]),
        .laranja: DisplayRepresentation(title: "laranja"),
        .laranjaVermelho: DisplayRepresentation(title: "laranja-avermelhado", synonyms: ["laranja avermelhado", "laranja avermelhada"]),
        .vermelho: DisplayRepresentation(title: "vermelho", synonyms: ["vermelha"]),
    ]

    var preset: LampPreset? { LampPreset.all.first { $0.id == rawValue } }
}

@available(iOS 17.0, *)
enum LampSceneOption: String, AppEnum {
    case fogueira, vela, brasa, entardecer

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Cenário"
    static let caseDisplayRepresentations: [LampSceneOption: DisplayRepresentation] = [
        .fogueira: DisplayRepresentation(title: "fogueira", synonyms: ["fogo", "lareira"]),
        .vela: DisplayRepresentation(title: "vela"),
        .brasa: DisplayRepresentation(title: "brasa"),
        .entardecer: DisplayRepresentation(title: "entardecer", synonyms: ["pôr do sol"]),
    ]

    var scene: LampScene {
        switch self {
        case .fogueira: return .fogueira
        case .vela: return .vela
        case .brasa: return .brasa
        case .entardecer: return .entardecer
        }
    }
}

// MARK: - Comandos

@available(iOS 17.0, *)
struct TurnOnLampIntent: AppIntent {
    static let title: LocalizedStringResource = "Acender a luminária"
    static let description = IntentDescription("Acende a luminária na última cor escolhida.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await runOnLamp { $0.turnOn() }
        return .result(dialog: "luminária acesa.")
    }
}

@available(iOS 17.0, *)
struct TurnOffLampIntent: AppIntent {
    static let title: LocalizedStringResource = "Apagar a luminária"
    static let description = IntentDescription("Apaga a luminária.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await runOnLamp { $0.turnOff() }
        return .result(dialog: "luminária apagada.")
    }
}

@available(iOS 17.0, *)
struct SetLampColorIntent: AppIntent {
    static let title: LocalizedStringResource = "Mudar a cor da luminária"
    static let description = IntentDescription("Acende a luminária numa das cores prontas, no brilho atual.")
    static let openAppWhenRun = false

    @Parameter(title: "Cor")
    var color: LampColorOption

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let preset = color.preset else { throw LampIntentError.unreachable }
        try await runOnLamp { lamp in
            let brightness = lamp.manualBrightness > 0.04 ? lamp.manualBrightness : preset.color.brightness
            lamp.setManual(mix: preset.color.mix, brightness: brightness)
        }
        return .result(dialog: "luminária em \(preset.name.lowercased()).")
    }
}

@available(iOS 17.0, *)
struct SetLampBrightnessIntent: AppIntent {
    static let title: LocalizedStringResource = "Mudar o brilho da luminária"
    static let description = IntentDescription("Muda o brilho da luminária, de 5% a 100%.")
    static let openAppWhenRun = false

    @Parameter(title: "Brilho (%)", inclusiveRange: (5, 100))
    var percent: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let value = Double(min(max(percent, 5), 100)) / 100
        try await runOnLamp { lamp in
            if lamp.activeScene != nil {
                lamp.setSceneBrightness(value)
            } else {
                lamp.setManual(mix: lamp.manualMix, brightness: value)
            }
        }
        return .result(dialog: "brilho em \(Int((value * 100).rounded()))%.")
    }
}

@available(iOS 17.0, *)
struct StartLampSceneIntent: AppIntent {
    static let title: LocalizedStringResource = "Cenário na luminária"
    static let description = IntentDescription("Liga um cenário animado na luminária (em teste).")
    static let openAppWhenRun = false

    @Parameter(title: "Cenário")
    var scene: LampSceneOption

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard LampScenesFlag.isEnabled else { throw LampIntentError.scenesOff }
        let chosen = scene.scene
        try await runOnLamp { $0.startScene(chosen) }
        return .result(dialog: "\(chosen.name.lowercased()) na luminária.")
    }
}

// MARK: - Frases da Siri

@available(iOS 17.0, *)
struct SoveeAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TurnOnLampIntent(),
            phrases: [
                "Acender a luminária no \(.applicationName)",
                "Acender a luminária do \(.applicationName)",
                "Ligar a luminária no \(.applicationName)",
            ],
            shortTitle: "Acender a luminária",
            systemImageName: "lamp.table.fill"
        )
        AppShortcut(
            intent: TurnOffLampIntent(),
            phrases: [
                "Apagar a luminária no \(.applicationName)",
                "Apagar a luminária do \(.applicationName)",
                "Desligar a luminária no \(.applicationName)",
            ],
            shortTitle: "Apagar a luminária",
            systemImageName: "lamp.table"
        )
        AppShortcut(
            intent: SetLampColorIntent(),
            phrases: [
                "Luminária \(\.$color) no \(.applicationName)",
                "Deixar a luminária \(\.$color) no \(.applicationName)",
                "Mudar a cor da luminária no \(.applicationName)",
            ],
            shortTitle: "Cor da luminária",
            systemImageName: "paintpalette"
        )
        AppShortcut(
            intent: SetLampBrightnessIntent(),
            phrases: [
                "Mudar o brilho da luminária no \(.applicationName)",
                "Brilho da luminária no \(.applicationName)",
            ],
            shortTitle: "Brilho da luminária",
            systemImageName: "sun.max"
        )
        AppShortcut(
            intent: StartLampSceneIntent(),
            phrases: [
                "\(\.$scene) na luminária do \(.applicationName)",
                "\(\.$scene) na luminária no \(.applicationName)",
                "Cenário da luminária no \(.applicationName)",
            ],
            shortTitle: "Cenário da luminária",
            systemImageName: "flame"
        )
    }
}
