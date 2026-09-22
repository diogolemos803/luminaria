import Foundation
import SwiftUI

// MARK: - Protocolo trocável

/// Qualquer visual futuro pro "sistema de crescimento" implementa isso. A lógica de
/// progresso (`NightSessionActivityTracker` abaixo) nunca precisa saber qual metáfora
/// visual está sendo usada — só expõe a fase atual (`NightSessionActivityTracker.
/// Phase`) e o destino corrente, e quem implementa esse protocolo decide como
/// desenhar isso. Trocar a metáfora depois é só trocar QUEM conforma esse protocolo
/// (hoje: `RocketGrowthVisual`), sem tocar em `NightSessionActivityTracker`.
protocol GrowthVisualizing {
    associatedtype Content: View
    @ViewBuilder func render(
        phase: NightSessionActivityTracker.Phase,
        destination: CelestialDestination,
        theme: ModeTheme
    ) -> Content
}

// MARK: - Destinos (planetas desbloqueados por sequência de dias)

/// Um destino que o foguete pode visitar — desbloqueado por sequência de dias
/// consecutivos com sessão "limpa" (`DetoxStats.currentCleanDayStreak`), não por
/// compra (decisão do usuário: só sequência por enquanto, sem StoreKit — isso exigiria
/// configurar produtos no App Store Connect e não dá pra testar sem device real com
/// conta sandbox, nenhum dos dois disponível neste ambiente).
struct CelestialDestination: Identifiable, Equatable {
    let id: String
    let name: String
    let requiredStreakDays: Int
    let color: Color
}

enum GrowthDestinations {
    /// 0/7/15/30 dias — os números exatos pedidos pelo usuário ("7 dias seguidos, 15
    /// dias, 1 mês etc"). A Lua está sempre disponível (0 dias), o resto desbloqueia
    /// progressivamente.
    static let all: [CelestialDestination] = [
        CelestialDestination(id: "moon", name: "Lua", requiredStreakDays: 0, color: Color(red: 0.82, green: 0.82, blue: 0.80)),
        CelestialDestination(id: "mars", name: "Marte", requiredStreakDays: 7, color: Color(red: 0.80, green: 0.42, blue: 0.30)),
        CelestialDestination(id: "saturn", name: "Saturno", requiredStreakDays: 15, color: Color(red: 0.86, green: 0.72, blue: 0.48)),
        CelestialDestination(id: "neptune", name: "Netuno", requiredStreakDays: 30, color: SoveeColor.noiteAzul),
    ]

    static func unlocked(currentStreak: Int) -> [CelestialDestination] {
        all.filter { $0.requiredStreakDays <= currentStreak }
    }

    /// O destino da viagem de hoje — sempre o mais distante já desbloqueado. Não tem
    /// UI ainda pra escolher manualmente qual visitar (a pessoa só vê a viagem
    /// avançar pro destino mais longe que já alcançou); dá pra adicionar um seletor
    /// depois sem mudar essa lógica.
    static func furthestUnlocked(currentStreak: Int) -> CelestialDestination {
        unlocked(currentStreak: currentStreak).max { $0.requiredStreakDays < $1.requiredStreakDays } ?? all[0]
    }
}

// MARK: - Rastreador de atividade / progresso

/// Rastreia atividade dentro de UMA sessão de modo noite ativa — alimenta duas coisas
/// ao mesmo tempo, porque as duas dependem exatamente da mesma pergunta técnica
/// (ver resumo da rodada do brief SOVEE, item 3b): "a pessoa tocou no celular durante
/// a sessão?"
///
/// 1. **Reset do progresso de crescimento** (item 2c): reabrir o app ou usar um passe
///    de emergência durante uma sessão ativa "explode o foguete" e reinicia a viagem.
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

    /// `.exploded` é um estado TRANSIENTE — some sozinho depois de
    /// `explosionDuration`, voltando pra `.traveling(progress: 0)` (a viagem
    /// recomeça, a sessão de bloqueio em si não é afetada — ver `ScreenTimeManager.
    /// useEmergencyPass`, que documenta a mesma decisão).
    enum Phase: Equatable {
        case traveling(progress: Double)
        case exploded
    }

    @Published private(set) var phase: Phase = .traveling(progress: 0)

    private var sessionStartDate: Date?
    private var lastTouchDate: Date?
    private var longestGapThisSession: TimeInterval = 0
    private var progressTimer: Timer?
    private var isExploding = false

    /// Duração de referência pra viagem chegar a 100% — 8h é só um chute inicial
    /// (duração de sono comum); pode virar configurável por rotina depois.
    private static let referenceDuration: TimeInterval = 8 * 3600
    /// Quanto tempo a animação de explosão fica visível antes da viagem recomeçar.
    private static let explosionDuration: TimeInterval = 1.4

    private init() {}

    /// Chamado por `ScreenTimeManager.applyShield` — início de uma sessão de bloqueio
    /// nova.
    func sessionDidStart() {
        let now = Date()
        sessionStartDate = now
        lastTouchDate = now
        longestGapThisSession = 0
        isExploding = false
        phase = .traveling(progress: 0)
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
        isExploding = false
        phase = .traveling(progress: 0)
        return result
    }

    /// Chamado quando o app volta a ficar ativo (`scenePhase == .active`) DURANTE uma
    /// sessão armada, ou quando um passe de emergência é usado — os dois únicos
    /// eventos reais e detectáveis de "a pessoa mexeu no celular" (ver documentação
    /// da classe). "Explode o foguete" (fase transiente) e registra o intervalo
    /// terminado como candidato a "maior sequência sem tocar".
    func registerTouchEvent() {
        guard sessionStartDate != nil else { return }
        let now = Date()
        if let lastTouchDate {
            longestGapThisSession = max(longestGapThisSession, now.timeIntervalSince(lastTouchDate))
        }
        lastTouchDate = now
        isExploding = true
        phase = .exploded
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.explosionDuration) { [weak self] in
            guard let self, self.sessionStartDate != nil else { return }
            self.isExploding = false
            self.phase = .traveling(progress: 0)
        }
    }

    private func updateProgress() {
        // Não pisa na fase de explosão em andamento — o `Timer` de 30s continua
        // rodando durante a explosão, mas `registerTouchEvent` já agenda a volta
        // pra `.traveling(progress: 0)` sozinho.
        guard !isExploding, let lastTouchDate else { return }
        let elapsed = Date().timeIntervalSince(lastTouchDate)
        phase = .traveling(progress: min(1, elapsed / Self.referenceDuration))
    }
}

// MARK: - Visual: viagem de foguete até a lua/planetas

/// Implementação concreta de `GrowthVisualizing` — cartoon minimalista (formas
/// geométricas simples, cores chapadas, sem textura/gradiente pesado), pedida
/// explicitamente pelo usuário como "uma mistura, cartoon minimalista". Se um visual
/// diferente for escolhido depois (maré, fase da lua, brasa), basta criar outro tipo
/// conformando `GrowthVisualizing` e trocar qual é instanciado em `ContentView` — a
/// lógica em `NightSessionActivityTracker` não muda nada.
struct RocketGrowthVisual: GrowthVisualizing {
    func render(phase: NightSessionActivityTracker.Phase, destination: CelestialDestination, theme: ModeTheme) -> some View {
        RocketJourneyView(phase: phase, destination: destination, theme: theme)
    }
}

private struct RocketJourneyView: View {
    let phase: NightSessionActivityTracker.Phase
    let destination: CelestialDestination
    let theme: ModeTheme

    var body: some View {
        GeometryReader { geo in
            let topY: CGFloat = 70
            let bottomY = geo.size.height - 90
            let midX = geo.size.width / 2

            ZStack {
                // Trilha pontilhada Terra → destino.
                Path { path in
                    path.move(to: CGPoint(x: midX, y: bottomY))
                    path.addLine(to: CGPoint(x: midX, y: topY))
                }
                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 9]))
                .foregroundStyle(theme.inkMuted.opacity(0.25))

                // Planeta/destino no topo — cor muda conforme o mais distante já
                // desbloqueado (Lua/Marte/Saturno/Netuno).
                Circle()
                    .fill(destination.color)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(theme.ink.opacity(0.12), lineWidth: 1))
                    .position(x: midX, y: topY)

                switch phase {
                case .traveling(let progress):
                    RocketIcon(bodyColor: theme.card, accentColor: theme.accent)
                        .frame(width: 34, height: 58)
                        .position(x: midX, y: bottomY - CGFloat(progress) * (bottomY - topY))
                        .animation(.easeInOut(duration: 1.0), value: progress)
                        .transition(.opacity)
                case .exploded:
                    ExplosionBurst(tint: theme.accent)
                        .position(x: midX, y: bottomY * 0.7)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: phase)
        }
    }
}

/// Foguete simples desenhado só com formas primitivas do SwiftUI (triângulos +
/// retângulo arredondado + círculo) — sem depender de nenhum asset de imagem que eu
/// não tenho como produzir (ilustração de personagem de verdade precisaria de um
/// designer). Estilo flat/chapado, combina com o pedido de "cartoon minimalista".
private struct RocketIcon: View {
    let bodyColor: Color
    let accentColor: Color

    var body: some View {
        VStack(spacing: -6) {
            TriangleShape()
                .fill(accentColor)
                .frame(width: 22, height: 18)

            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(bodyColor)
                .frame(width: 26, height: 34)
                .overlay(
                    Circle()
                        .fill(accentColor.opacity(0.85))
                        .frame(width: 11, height: 11)
                )

            HStack(spacing: 16) {
                TriangleShape()
                    .fill(accentColor)
                    .frame(width: 12, height: 14)
                    .rotationEffect(.degrees(-100))
                TriangleShape()
                    .fill(accentColor)
                    .frame(width: 12, height: 14)
                    .rotationEffect(.degrees(100))
            }
            .offset(y: -8)
        }
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Explosão simples: um núcleo que aumenta e desaparece, com partículas pequenas
/// espalhando pra fora — mesma técnica cartoon/flat do resto do visual, só formas e
/// cor, sem imagem nenhuma.
private struct ExplosionBurst: View {
    let tint: Color
    @State private var animate = false

    private let particleColors: [Color] = [.orange, .yellow, .red]

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) / 8 * 2 * .pi
                Circle()
                    .fill(particleColors[index % particleColors.count])
                    .frame(width: 8, height: 8)
                    .offset(
                        x: animate ? CGFloat(cos(angle)) * 58 : 0,
                        y: animate ? CGFloat(sin(angle)) * 58 : 0
                    )
                    .opacity(animate ? 0 : 1)
            }
            Circle()
                .fill(Color.orange)
                .frame(width: animate ? 90 : 18, height: animate ? 90 : 18)
                .opacity(animate ? 0 : 0.9)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animate = true
            }
        }
    }
}
