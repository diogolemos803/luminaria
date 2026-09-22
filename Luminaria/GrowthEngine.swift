import Foundation
import SwiftUI

/// Qualquer visual futuro pro "sistema de crescimento" (maré subindo, fase da lua,
/// brasa — ver sugestões no resumo desta rodada) implementa isso. A lógica de
/// progresso (`NightSessionActivityTracker` abaixo) nunca precisa saber qual metáfora
/// visual está sendo usada — só expõe um `Double` de 0 a 1, e quem implementa esse
/// protocolo decide como desenhar isso. Trocar a metáfora depois é só trocar QUEM
/// conforma esse protocolo, sem tocar em `NightSessionActivityTracker`.
protocol GrowthVisualizing {
    associatedtype Content: View
    @ViewBuilder func render(progress: Double) -> Content
}

/// Rastreia atividade dentro de UMA sessão de modo noite ativa — alimenta duas coisas
/// ao mesmo tempo, porque as duas dependem exatamente da mesma pergunta técnica
/// (ver resumo desta rodada, item 3b): "a pessoa tocou no celular durante a sessão?"
///
/// 1. **Reset do progresso de crescimento** (item 2c): reabrir o app ou usar um passe
///    de emergência durante uma sessão ativa zera `growthProgress`.
/// 2. **Métrica de maior sequência sem tocar numa sessão** (item 2b, métrica 1):
///    guarda o maior intervalo entre dois "toques" (ou entre o início da sessão e o
///    primeiro toque, ou entre o último toque e o fim da sessão).
///
/// **Definição de "toque" usada aqui**: reabrir o app OU usar um passe de emergência —
/// não existe API pública no iOS pra detectar "qualquer toque na tela" ou "desbloqueou
/// o celular" com o app em segundo plano (ver investigação de viabilidade do item 3b).
/// Como os apps ficam de fato bloqueados durante o modo noite, essas são as duas
/// únicas ações reais e detectáveis que significam "a pessoa decidiu mexer no
/// celular" — não é uma aproximação frágil, é o que dá pra observar de verdade.
final class NightSessionActivityTracker: ObservableObject {
    static let shared = NightSessionActivityTracker()

    /// 0...1 — por enquanto, proporção do tempo decorrido na sessão atual desde o
    /// último "toque" (ou desde o início, se nenhum toque ainda) contra uma duração
    /// de referência de 8h. Ajustável sem afetar quem consome isso, já que é só um
    /// `Double` — o cálculo exato de "o que é 100%" pode mudar quando a metáfora
    /// visual for escolhida (ex.: talvez fizesse mais sentido crescer até o horário
    /// do despertador da rotina, não um valor fixo).
    @Published private(set) var growthProgress: Double = 0

    private var sessionStartDate: Date?
    private var lastTouchDate: Date?
    private var longestGapThisSession: TimeInterval = 0
    private var progressTimer: Timer?

    /// Duração de referência pra crescimento chegar a 100% — 8h é só um chute inicial
    /// (duração de sono comum); pode virar configurável por rotina depois.
    private static let referenceDuration: TimeInterval = 8 * 3600

    private init() {}

    /// Chamado por `ScreenTimeManager.applyShield` — início de uma sessão de bloqueio
    /// nova.
    func sessionDidStart() {
        let now = Date()
        sessionStartDate = now
        lastTouchDate = now
        longestGapThisSession = 0
        growthProgress = 0
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }

    /// Chamado por `ScreenTimeManager.removeShield` — fim da sessão (por qualquer
    /// motivo: despertador tocou, desarme manual, ou passe de emergência). Retorna o
    /// maior intervalo sem toque observado durante essa sessão, pra
    /// `SleepReportEntry.longestUninterruptedSeconds`.
    @discardableResult
    func sessionDidEnd() -> TimeInterval {
        progressTimer?.invalidate()
        progressTimer = nil
        if let lastTouchDate {
            longestGapThisSession = max(longestGapThisSession, Date().timeIntervalSince(lastTouchDate))
        }
        let result = longestGapThisSession
        sessionStartDate = nil
        lastTouchDate = nil
        longestGapThisSession = 0
        growthProgress = 0
        return result
    }

    /// Chamado quando o app volta a ficar ativo (`scenePhase == .active`) DURANTE uma
    /// sessão armada, ou quando um passe de emergência é usado — os dois únicos
    /// eventos reais e detectáveis de "a pessoa mexeu no celular" (ver documentação
    /// da classe). Zera o progresso de crescimento e registra o intervalo terminado
    /// como candidato a "maior sequência sem tocar".
    func registerTouchEvent() {
        guard sessionStartDate != nil else { return }
        let now = Date()
        if let lastTouchDate {
            longestGapThisSession = max(longestGapThisSession, now.timeIntervalSince(lastTouchDate))
        }
        lastTouchDate = now
        growthProgress = 0
    }

    private func updateProgress() {
        guard let lastTouchDate else { return }
        let elapsed = Date().timeIntervalSince(lastTouchDate)
        growthProgress = min(1, elapsed / Self.referenceDuration)
    }
}
