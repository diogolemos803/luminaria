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
/// conta sandbox, nenhum dos dois disponível neste ambiente). É o planeta onde o
/// pouso acontece de manhã (ver `RocketLandingView`) — a órbita da noite em si é
/// sempre ao redor da Terra (ver `LiftoffOrbitScene`).
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
    /// UI ainda pra escolher manualmente qual visitar (a pessoa só vê o pouso de
    /// manhã acontecer no destino mais longe que já alcançou); dá pra adicionar um
    /// seletor depois sem mudar essa lógica.
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
///    de emergência durante uma sessão ativa "explode o foguete", que depois volta a
///    orbitar normalmente.
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

    /// `.liftoff` é o momento da decolagem (transiente, dura `liftoffDuration` e
    /// passa sozinho pra `.orbiting`). `.orbiting` é o estado de repouso da sessão —
    /// dura a noite inteira, sem "progresso" nenhum pra calcular (a viagem não avança
    /// mais em direção a um destino durante a noite; o destino só entra em cena no
    /// pouso, de manhã — ver `RocketLandingView` em `ContentView.swift`).
    /// `.exploded` é TRANSIENTE — some sozinho depois de `explosionDuration`,
    /// voltando pra `.orbiting` (a sessão de bloqueio em si não é afetada — ver
    /// `ScreenTimeManager.useEmergencyPass`, que documenta a mesma decisão).
    enum Phase: Equatable {
        case liftoff
        case orbiting
        case exploded
    }

    @Published private(set) var phase: Phase = .liftoff

    private var sessionStartDate: Date?
    private var lastTouchDate: Date?
    private var longestGapThisSession: TimeInterval = 0
    private var isExploding = false

    /// Duração da animação de decolagem antes de virar órbita — não é um número
    /// crítico (não existe "chegada" pra perder), só precisa dar tempo da cena visual
    /// (`LiftoffOrbitScene`) terminar a subida da Terra + foguete antes de virar o
    /// loop de órbita.
    private static let liftoffDuration: TimeInterval = 2.4
    /// Quanto tempo a animação de explosão fica visível antes da órbita voltar.
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
        phase = .liftoff
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.liftoffDuration) { [weak self] in
            guard let self, self.sessionStartDate == now, !self.isExploding else { return }
            self.phase = .orbiting
        }
    }

    /// Chamado por `ScreenTimeManager.removeShield` — fim da sessão (por qualquer
    /// motivo: despertador tocou, desarme manual, ou passe de emergência). Retorna o
    /// maior intervalo sem toque observado durante essa sessão, pra
    /// `SleepReportEntry.longestUninterruptedSeconds`.
    @discardableResult
    func sessionDidEnd() -> TimeInterval {
        if let lastTouchDate {
            longestGapThisSession = max(longestGapThisSession, Date().timeIntervalSince(lastTouchDate))
        }
        let result = longestGapThisSession
        sessionStartDate = nil
        lastTouchDate = nil
        longestGapThisSession = 0
        isExploding = false
        phase = .liftoff
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
            self.phase = .orbiting
        }
    }
}

// MARK: - Visual: decolagem + órbita noturna

/// Implementação concreta de `GrowthVisualizing` — cartoon minimalista (formas
/// geométricas simples, cores chapadas, sem textura/gradiente pesado), pedida
/// explicitamente pelo usuário como "uma mistura, cartoon minimalista". Se um visual
/// diferente for escolhido depois (maré, fase da lua, brasa), basta criar outro tipo
/// conformando `GrowthVisualizing` e trocar qual é instanciado em `ContentView` — a
/// lógica em `NightSessionActivityTracker` não muda nada.
struct RocketGrowthVisual: GrowthVisualizing {
    func render(phase: NightSessionActivityTracker.Phase, destination: CelestialDestination, theme: ModeTheme) -> some View {
        LiftoffOrbitScene(phase: phase, destination: destination, theme: theme)
    }
}

/// Cena de tela cheia: a Terra sobe de baixo da tela junto com o foguete decolando
/// (`.liftoff`), depois o foguete fica orbitando a Terra continuamente (`.orbiting`)
/// até a sessão terminar. `.exploded` interrompe a órbita com uma explosão rápida e
/// volta a orbitar sozinho. O planeta-destino (Lua/Marte/Saturno/Netuno, conforme a
/// sequência de dias) aparece só como um selo discreto no canto — o pouso nele de
/// verdade acontece em `RocketLandingView`, na tela do despertador.
///
/// Sem simulador/device neste ambiente pra cronometrar quadro a quadro — as durações
/// abaixo (`liftoffVisualDuration`, `orbitPeriod`) são estimativas razoáveis, não
/// medidas contra um dispositivo real.
private struct LiftoffOrbitScene: View {
    let phase: NightSessionActivityTracker.Phase
    let destination: CelestialDestination
    let theme: ModeTheme

    @State private var earthRisen = false
    @State private var orbitAngle: Double = -90

    private static let liftoffVisualDuration: Double = 2.0
    private static let orbitPeriod: Double = 16

    var body: some View {
        GeometryReader { geo in
            let earthRadius: CGFloat = min(geo.size.width, geo.size.height) * 0.22
            let earthRestingCenter = CGPoint(x: geo.size.width / 2, y: geo.size.height - earthRadius * 0.6)
            let earthHiddenCenter = CGPoint(x: geo.size.width / 2, y: geo.size.height + earthRadius)
            let orbitRadiusX = geo.size.width * 0.34
            let orbitRadiusY = earthRadius * 1.35

            ZStack {
                // Selo do planeta-destino desbloqueado — só um lembrete visual de
                // pra onde a viagem vai terminar de manhã, sem interação nenhuma.
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(destination.color)
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(theme.ink.opacity(0.12), lineWidth: 1))
                    }
                    Spacer()
                }
                .padding(20)

                // Terra — some fora da tela por baixo até a sessão começar, depois
                // sobe pra posição de repouso e fica ali (cortada como um horizonte)
                // durante toda a órbita.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [SoveeColor.floresta, SoveeColor.floresta.opacity(0.7)],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: earthRadius * 2
                        )
                    )
                    .frame(width: earthRadius * 2, height: earthRadius * 2)
                    .position(earthRisen ? earthRestingCenter : earthHiddenCenter)

                switch phase {
                case .liftoff:
                    RocketIcon(bodyColor: theme.card, accentColor: theme.accent)
                        .frame(width: 30, height: 50)
                        .position(
                            x: earthRestingCenter.x,
                            y: earthRisen
                                ? earthRestingCenter.y - earthRadius - 34
                                : earthHiddenCenter.y - earthRadius * 0.4
                        )
                        .transition(.opacity)
                case .orbiting:
                    RocketIcon(bodyColor: theme.card, accentColor: theme.accent)
                        .frame(width: 24, height: 40)
                        .rotationEffect(.degrees(orbitAngle + 90))
                        .position(
                            x: earthRestingCenter.x + CGFloat(cos(orbitAngle * .pi / 180)) * orbitRadiusX,
                            y: earthRestingCenter.y - earthRadius * 0.3 + CGFloat(sin(orbitAngle * .pi / 180)) * orbitRadiusY
                        )
                        .transition(.opacity)
                case .exploded:
                    ExplosionBurst()
                        .position(x: earthRestingCenter.x, y: earthRestingCenter.y - earthRadius - 24)
                        .transition(.opacity)
                }
            }
            .onAppear { syncWithPhase() }
            .onChange(of: phase) { _ in syncWithPhase() }
        }
    }

    /// Sincroniza a animação visual com a fase autoritativa do
    /// `NightSessionActivityTracker` — a cena não guarda seu próprio estado de
    /// "decolando vs orbitando", só reage ao que a fase diz agora (importante porque
    /// a `View` pode ser recriada a qualquer momento pelo SwiftUI).
    private func syncWithPhase() {
        switch phase {
        case .liftoff:
            earthRisen = false
            withAnimation(.easeOut(duration: Self.liftoffVisualDuration)) {
                earthRisen = true
            }
        case .orbiting:
            earthRisen = true
            orbitAngle = -90
            withAnimation(.linear(duration: Self.orbitPeriod).repeatForever(autoreverses: false)) {
                orbitAngle = -90 + 360
            }
        case .exploded:
            break
        }
    }
}

/// Foguete simples desenhado só com formas primitivas do SwiftUI (triângulos +
/// retângulo arredondado + círculo) — sem depender de nenhum asset de imagem que eu
/// não tenho como produzir (ilustração de personagem de verdade precisaria de um
/// designer). Estilo flat/chapado, combina com o pedido de "cartoon minimalista".
struct RocketIcon: View {
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
struct ExplosionBurst: View {
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

// MARK: - Visual: pouso (mostrado na tela do despertador)

/// Animação de "chegada" — tocada uma única vez quando o despertador realmente
/// dispara (ou seja, a pessoa aguentou a noite inteira sem desarmar: `AlarmManager.
/// triggerAlarm()` já registrou a sessão como `.alarmFired` antes dessa tela
/// aparecer). O foguete desce até o planeta-destino, um astronauta sai e crava uma
/// bandeira mostrando o número de dias da sequência atual.
///
/// De propósito independente de `NightSessionActivityTracker` — essa tela pode
/// aparecer depois de o processo do app ter sido suspenso e retomado pelo sistema
/// pra tocar o alarme, então não dá pra confiar em estado transiente de sessão; ela
/// só lê o destino/sequência já persistidos (`GrowthDestinations`, `DetoxStats`).
struct RocketLandingView: View {
    let destination: CelestialDestination
    let streakDays: Int
    let theme: ModeTheme

    @State private var rocketLanded = false
    @State private var astronautOut = false
    @State private var flagPlanted = false

    private static let descendDuration: Double = 1.6
    private static let astronautDelay: Double = 0.5
    private static let flagDelay: Double = 0.9

    var body: some View {
        GeometryReader { geo in
            let planetRadius: CGFloat = min(geo.size.width, geo.size.height) * 0.24
            let planetCenter = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.62)
            let rocketRestingY = planetCenter.y - planetRadius * 0.55

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [destination.color, destination.color.opacity(0.75)],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: planetRadius * 2
                        )
                    )
                    .frame(width: planetRadius * 2, height: planetRadius * 2)
                    .position(planetCenter)

                RocketIcon(bodyColor: theme.card, accentColor: theme.accent)
                    .frame(width: 28, height: 46)
                    .position(x: planetCenter.x, y: rocketLanded ? rocketRestingY : rocketRestingY - 160)
                    .opacity(astronautOut ? 0.85 : 1)

                if astronautOut {
                    AstronautFigure(suitColor: theme.card, accentColor: theme.accent)
                        .frame(width: 20, height: 32)
                        .position(x: planetCenter.x + 26, y: rocketRestingY + 6)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if flagPlanted {
                    VStack(spacing: 4) {
                        FlagShape(fillColor: theme.accent)
                            .frame(width: 34, height: 24)
                        Text("\(streakDays) dia\(streakDays == 1 ? "" : "s")")
                            .font(.soveeDisplay(size: 14, weight: .bold))
                            .foregroundStyle(theme.ink)
                    }
                    .position(x: planetCenter.x + 26, y: rocketRestingY - 30)
                    .transition(.opacity.combined(with: .scale(scale: 0.6)))
                }
            }
            .onAppear { runLandingSequence() }
        }
    }

    private func runLandingSequence() {
        withAnimation(.easeIn(duration: Self.descendDuration)) {
            rocketLanded = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.descendDuration + Self.astronautDelay) {
            withAnimation(.easeOut(duration: 0.4)) {
                astronautOut = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.descendDuration + Self.astronautDelay + Self.flagDelay) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                flagPlanted = true
            }
        }
    }
}

/// Astronauta bem simples — mesma técnica de formas primitivas do foguete, sem
/// nenhum asset de imagem.
private struct AstronautFigure: View {
    let suitColor: Color
    let accentColor: Color

    var body: some View {
        VStack(spacing: -2) {
            Circle()
                .fill(suitColor)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(accentColor.opacity(0.6), lineWidth: 1.5))
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(suitColor)
                .frame(width: 16, height: 20)
        }
    }
}

/// Bandeirinha triangular numa haste — desenhada com `Path`, sem asset.
private struct FlagShape: View {
    let fillColor: Color

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(Color.gray.opacity(0.6))
                .frame(width: 2, height: 24)
            Path { path in
                path.move(to: CGPoint(x: 2, y: 2))
                path.addLine(to: CGPoint(x: 26, y: 8))
                path.addLine(to: CGPoint(x: 2, y: 14))
                path.closeSubpath()
            }
            .fill(fillColor)
        }
    }
}
