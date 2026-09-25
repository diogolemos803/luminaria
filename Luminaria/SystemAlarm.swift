import Foundation
import SwiftUI
#if canImport(AlarmKit)
import ActivityKit
import AlarmKit
import AppIntents
#endif

// Despertador de sistema via AlarmKit (iOS 26+) — a API que a Apple abriu pra apps de
// terceiros terem alarme de verdade: toca mesmo no modo silencioso e com Foco ativo,
// aparece em tela cheia na tela bloqueada e toca com o app fechado (quem toca é o
// sistema, não o nosso processo). Substitui, quando autorizado, o esquema antigo de
// áudio silencioso em loop + notificação (ver `AlarmManager`), que o iOS não garante
// manter vivo a noite inteira — achado real testando no device: o alarme só tocava
// depois de abrir a notificação e entrar no app.
//
// Todo o AlarmKit fica isolado neste arquivo, atrás de `#if canImport(AlarmKit)` +
// `#available(iOS 26, *)`: o app continua com alvo mínimo iOS 16 e compila com SDKs
// antigos. Cuidado com o nome: o AlarmKit também tem um tipo `AlarmManager` — aqui
// ele é sempre escrito `AlarmKit.AlarmManager`; o `AlarmManager` do app não é citado
// neste arquivo (os intents chamam `luminariaHandleSystemAlarmStopped()`, definido em
// `AlarmManager.swift`).

/// Só o que o `AlarmManager` do app precisa saber de cada alarme do sistema, sem expor
/// tipos do AlarmKit pro resto do código.
struct SystemAlarmSnapshot {
    let id: UUID
    let isAlerting: Bool
}

enum SystemAlarmAuthorization {
    case authorized
    case denied
    case notDetermined
    /// iOS abaixo do 26 (ou SDK sem AlarmKit): usa o despertador antigo.
    case unavailable
}

enum SystemAlarm {
    static var authorization: SystemAlarmAuthorization {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            switch AlarmKit.AlarmManager.shared.authorizationState {
            case .authorized: return .authorized
            case .denied: return .denied
            case .notDetermined: return .notDetermined
            @unknown default: return .denied
            }
        }
        #endif
        return .unavailable
    }

    /// Mostra o pedido de permissão do sistema (texto de `NSAlarmKitUsageDescription`)
    /// só se ainda não foi respondido — depois disso, só Ajustes muda a resposta.
    static func requestAuthorization() async -> SystemAlarmAuthorization {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            _ = try? await AlarmKit.AlarmManager.shared.requestAuthorization()
        }
        #endif
        return authorization
    }

    /// Agenda um alarme de UMA vez só (`.fixed`) — mesma regra do despertador antigo:
    /// vale pra noite em que a luminária foi lida, não se repete sozinho. Devolve
    /// `false` se não deu pra agendar (sem permissão, limite do sistema etc.), pra quem
    /// chamou cair no despertador antigo em vez de ficar sem alarme nenhum.
    static func schedule(id: UUID, at date: Date, soundFileName: String) async -> Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            // `stopButton` foi marcado como obsoleto no iOS 26.1 (o sistema passou a
            // desenhar o botão de parar sozinho), mas é o único inicializador que
            // existe desde o 26.0 — fica este pra funcionar em qualquer iOS 26.
            let alert = AlarmPresentation.Alert(
                title: "Hora de acordar",
                stopButton: AlarmButton(text: "Parar", textColor: .white, systemImageName: "stop.circle"),
                secondaryButton: AlarmButton(text: "Abrir", textColor: .white, systemImageName: "moon.stars"),
                secondaryButtonBehavior: .custom
            )
            let attributes = AlarmAttributes<LuminariaAlarmMetadata>(
                presentation: AlarmPresentation(alert: alert, countdown: nil, paused: nil),
                metadata: LuminariaAlarmMetadata(),
                tintColor: SoveeColor.noiteAzul
            )
            let configuration = AlarmKit.AlarmManager.AlarmConfiguration<LuminariaAlarmMetadata>.alarm(
                schedule: .fixed(date),
                attributes: attributes,
                stopIntent: StopLuminariaAlarmIntent(alarmID: id.uuidString),
                secondaryIntent: OpenLuminariaAlarmIntent(alarmID: id.uuidString),
                // O mesmo `.wav` da rotina, que já está no bundle principal do app.
                sound: .named("\(soundFileName).wav")
            )
            do {
                _ = try await AlarmKit.AlarmManager.shared.schedule(id: id, configuration: configuration)
                return true
            } catch {
                return false
            }
        }
        #endif
        return false
    }

    /// Para (se estiver tocando) e remove o alarme. Os dois podem falhar dependendo do
    /// estado (ex.: `stop` num alarme que ainda não tocou) — ignorado de propósito.
    static func cancel(id: UUID) {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            try? AlarmKit.AlarmManager.shared.stop(id: id)
            try? AlarmKit.AlarmManager.shared.cancel(id: id)
        }
        #endif
    }

    static func stop(id: UUID) {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            try? AlarmKit.AlarmManager.shared.stop(id: id)
        }
        #endif
    }

    /// Lista atual dos alarmes do app a cada mudança (agendado → tocando → removido).
    /// Em iOS sem AlarmKit, termina na hora sem emitir nada.
    static func updates() -> AsyncStream<[SystemAlarmSnapshot]> {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            return AsyncStream { continuation in
                let task = Task {
                    for await alarms in AlarmKit.AlarmManager.shared.alarmUpdates {
                        continuation.yield(alarms.map { SystemAlarmSnapshot(id: $0.id, isAlerting: $0.state == .alerting) })
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
        #endif
        return AsyncStream { $0.finish() }
    }
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
struct LuminariaAlarmMetadata: AlarmMetadata {}

/// Botão "Parar" do alarme do sistema (tela bloqueada, Dynamic Island, banner). Roda no
/// processo do app — o iOS abre o app em segundo plano se preciso — pra liberar o
/// bloqueio de apps e deixar o pouso na Lua pronto pra quando a pessoa abrir o app.
@available(iOS 26.0, *)
struct StopLuminariaAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Parar despertador"
    static let isDiscoverable = false

    @Parameter(title: "Alarme")
    var alarmID: String

    init() {
        self.alarmID = ""
    }

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            SystemAlarm.stop(id: id)
        }
        await MainActor.run { luminariaHandleSystemAlarmStopped() }
        return .result()
    }
}

/// Botão "Abrir": para o alarme e abre o app direto na tela do pouso.
@available(iOS 26.0, *)
struct OpenLuminariaAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Abrir o Luminária"
    static let isDiscoverable = false
    static let openAppWhenRun = true

    @Parameter(title: "Alarme")
    var alarmID: String

    init() {
        self.alarmID = ""
    }

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            SystemAlarm.stop(id: id)
        }
        await MainActor.run { luminariaHandleSystemAlarmStopped() }
        return .result()
    }
}
#endif
