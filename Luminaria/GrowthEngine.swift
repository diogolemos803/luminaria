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

    /// `.liftoff` é o momento da decolagem (transiente — vira `.orbiting` quando a
    /// própria cena visual chama `liftoffAnimationCompleted()`, ao terminar de
    /// desenhar a subida). `.orbiting` é o estado de repouso da sessão —
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

    /// Quanto tempo a animação de explosão fica visível antes da órbita voltar.
    private static let explosionDuration: TimeInterval = 1.4

    private init() {}

    /// Chamado por `ScreenTimeManager.applyShield` — início de uma sessão de bloqueio
    /// nova. Repare que isso NÃO agenda sozinho a virada pra `.orbiting` — quem faz
    /// isso é `liftoffAnimationCompleted()`, chamado pela própria cena visual
    /// (`LiftoffOrbitScene`) quando a animação de decolagem dela termina de verdade.
    /// Bug real corrigido: a primeira versão tinha um timer próprio aqui (contando a
    /// partir do INÍCIO da sessão, antes até do botão redondo sumir da tela), correndo
    /// em paralelo com a duração da animação visual da cena — como a cena só aparece
    /// depois do botão descer (~1s depois), os dois relógios ficavam fora de sincronia
    /// e a fase virava `.orbiting` ANTES da animação de subida visual terminar,
    /// cortando a decolagem pela metade (relatado pelo usuário como "não teve
    /// animação nenhuma"). Delegar o fim da decolagem pra quem está de fato desenhando
    /// a decolagem elimina essa corrida de vez.
    func sessionDidStart() {
        let now = Date()
        sessionStartDate = now
        lastTouchDate = now
        longestGapThisSession = 0
        isExploding = false
        phase = .liftoff
    }

    /// Chamado por `LiftoffOrbitScene` no exato instante em que a animação visual de
    /// decolagem terminou de subir — só então a fase vira `.orbiting`. Guardas:
    /// ignora se a sessão já terminou (`sessionStartDate == nil`) ou se um toque
    /// aconteceu nesse meio-tempo (já explodiu, `phase != .liftoff`).
    func liftoffAnimationCompleted() {
        guard sessionStartDate != nil, phase == .liftoff else { return }
        phase = .orbiting
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

/// Cena de tela cheia baseada numa referência visual dada pelo usuário (ilustração
/// flat de um lançamento: Terra ocupando a base, torre de lançamento treliçada,
/// fumaça na base, foguete branco/vermelho com chama) — versão noturna: o céu já é
/// `theme.stage` (pintado por trás, em `ContentView`), aqui só entram as estrelas, o
/// terreno e a base de lançamento.
///
/// A Terra ocupa só o quinto inferior da tela (pedido explícito, não um círculo
/// grande como na primeira tentativa) — um morro raso (`GroundShape`), não uma
/// esfera. A torre (`LaunchTowerShape`) e os prédios pequenos ficam sobre esse
/// morro, junto do foguete. `.liftoff` sobe o foguete com chama e fumaça saindo da
/// base; `.orbiting` é o estado de repouso da noite inteira — o foguete desliza
/// devagar num arco largo no céu, sem chama; `.exploded` interrompe com uma
/// explosão rápida e volta a orbitar sozinho.
///
/// Sem simulador/device neste ambiente pra cronometrar quadro a quadro — as durações
/// abaixo são estimativas razoáveis, não medidas contra um dispositivo real.
private struct LiftoffOrbitScene: View {
    let phase: NightSessionActivityTracker.Phase
    let destination: CelestialDestination
    let theme: ModeTheme

    @State private var liftoffAltitude: CGFloat = 0
    @State private var showsSmoke = true
    @State private var orbitAngle: Double = -90

    // Duração generosa de propósito: a pessoa acabou de tirar os olhos da tela pra
    // encostar o celular na tag, então precisa de uma folga real até olhar de volta
    // pra tela — 2.2s tinha se mostrado curto demais num teste real (usuário relatou
    // "não teve animação de decolagem").
    private static let liftoffVisualDuration: Double = 3.6
    private static let smokeFadeDelay: Double = 2.6
    private static let orbitPeriod: Double = 18

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            // Topo do quinto inferior — é aqui que o morro/base de lançamento vive.
            let groundY = height * 0.8
            let padX = width * 0.54
            let towerX = width * 0.24
            let orbitCenter = CGPoint(x: width / 2, y: height * 0.34)
            let orbitRadiusX = width * 0.30
            let orbitRadiusY = height * 0.13
            let padAltitudeY = groundY - height * 0.06

            ZStack {
                starsLayer

                GroundShape(groundY: groundY, bulge: height * 0.045)
                    .fill(
                        LinearGradient(
                            colors: [SoveeColor.floresta.opacity(0.55), SoveeColor.floresta.opacity(0.95)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                LaunchTowerShape()
                    .stroke(SoveeColor.carvao.opacity(0.9), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                    .frame(width: 30, height: height * 0.2)
                    .position(x: towerX, y: groundY - height * 0.1)

                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(SoveeColor.carvao.opacity(0.85))
                        .frame(width: 34, height: 20)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(SoveeColor.carvao.opacity(0.75))
                        .frame(width: 20, height: 28)
                }
                .position(x: towerX + 42, y: groundY - 10)

                // Selo do planeta-destino desbloqueado — só um lembrete visual de
                // pra onde o pouso vai acontecer de manhã (ver `RocketLandingView`).
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(destination.color)
                            .frame(width: 20, height: 20)
                            .overlay(Circle().stroke(theme.ink.opacity(0.12), lineWidth: 1))
                    }
                    Spacer()
                }
                .padding(18)

                if showsSmoke && phase == .liftoff {
                    SmokeCluster()
                        .position(x: padX, y: groundY - 4)
                        .transition(.opacity)
                }

                switch phase {
                case .liftoff:
                    // `.scaleEffect`, não `.frame` — o ícone é desenhado com
                    // dimensões fixas por dentro (`RocketIcon`), então só um `.frame`
                    // maior não aumenta nada, apenas dá mais espaço vazio ao redor.
                    RocketWithFlame(showsFlame: true)
                        .scaleEffect(1.6)
                        .position(x: padX, y: padAltitudeY - liftoffAltitude * (padAltitudeY - orbitCenter.y))
                        .transition(.opacity)
                case .orbiting:
                    RocketWithFlame(showsFlame: false)
                        .rotationEffect(.degrees(orbitAngle + 90))
                        .position(
                            x: orbitCenter.x + CGFloat(cos(orbitAngle * .pi / 180)) * orbitRadiusX,
                            y: orbitCenter.y + CGFloat(sin(orbitAngle * .pi / 180)) * orbitRadiusY
                        )
                        .transition(.opacity)
                case .exploded:
                    ExplosionBurst()
                        .position(x: orbitCenter.x, y: orbitCenter.y)
                        .transition(.opacity)
                }
            }
            .onAppear { syncWithPhase() }
            .onChange(of: phase) { _ in syncWithPhase() }
        }
    }

    /// Estrelas fixas (posições fracionárias fixas, não geradas de novo a cada
    /// render) — só pra vender "céu noturno" com mais clareza do que o fundo escuro
    /// sozinho, já que `theme.stage` à noite é um grafite liso, não um azul-marinho.
    private var starsLayer: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Self.starPositions.indices, id: \.self) { index in
                    let star = Self.starPositions[index]
                    Circle()
                        .fill(Color.white.opacity(star.opacity))
                        .frame(width: star.size, height: star.size)
                        .position(x: geo.size.width * star.x, y: geo.size.height * star.y)
                }
            }
        }
    }

    private static let starPositions: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = [
        (0.08, 0.10, 2, 0.8), (0.20, 0.22, 1.5, 0.5), (0.34, 0.08, 2, 0.7),
        (0.46, 0.30, 1.5, 0.4), (0.58, 0.14, 2, 0.9), (0.70, 0.24, 1.5, 0.5),
        (0.82, 0.10, 2, 0.7), (0.90, 0.32, 1.5, 0.6), (0.14, 0.42, 1.5, 0.4),
        (0.28, 0.50, 2, 0.6), (0.50, 0.46, 1.5, 0.5), (0.64, 0.44, 1.5, 0.4),
        (0.76, 0.52, 2, 0.6), (0.92, 0.48, 1.5, 0.5), (0.06, 0.58, 1.5, 0.4),
        (0.38, 0.62, 2, 0.5),
    ]

    /// Sincroniza a animação visual com a fase autoritativa do
    /// `NightSessionActivityTracker` — a cena não guarda seu próprio estado de
    /// "decolando vs orbitando", só reage ao que a fase diz agora (importante porque
    /// a `View` pode ser recriada a qualquer momento pelo SwiftUI). Quando a subida
    /// termina, avisa o tracker (`liftoffAnimationCompleted()`) — é essa chamada, e
    /// não um timer independente no tracker, que decide o momento exato de virar
    /// `.orbiting` (ver comentário em `NightSessionActivityTracker.sessionDidStart`).
    private func syncWithPhase() {
        switch phase {
        case .liftoff:
            showsSmoke = true
            liftoffAltitude = 0
            withAnimation(.easeIn(duration: Self.liftoffVisualDuration)) {
                liftoffAltitude = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.smokeFadeDelay) {
                withAnimation(.easeOut(duration: 0.6)) {
                    showsSmoke = false
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.liftoffVisualDuration) {
                NightSessionActivityTracker.shared.liftoffAnimationCompleted()
            }
        case .orbiting:
            showsSmoke = false
            orbitAngle = -90
            withAnimation(.linear(duration: Self.orbitPeriod).repeatForever(autoreverses: false)) {
                orbitAngle = -90 + 360
            }
        case .exploded:
            break
        }
    }
}

/// Morro raso ocupando só o quinto inferior da tela (`groundY` fixado em 80% da
/// altura) — não uma esfera/círculo grande como na primeira tentativa. `bulge`
/// controla a curvatura (bem sutil, só o suficiente pra ler como horizonte, não
/// como uma bola).
private struct GroundShape: Shape {
    let groundY: CGFloat
    let bulge: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: groundY))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: groundY), control: CGPoint(x: rect.width / 2, y: groundY - bulge))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

/// Torre de lançamento treliçada — duas colunas verticais + zigue-zague, igual à
/// referência visual (silhueta simples, sem asset nenhum).
private struct LaunchTowerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))

        let steps = 5
        for step in 0..<steps {
            let y0 = rect.maxY - CGFloat(step) / CGFloat(steps) * rect.height
            let y1 = rect.maxY - CGFloat(step + 1) / CGFloat(steps) * rect.height
            if step.isMultiple(of: 2) {
                path.move(to: CGPoint(x: rect.minX, y: y0))
                path.addLine(to: CGPoint(x: rect.maxX, y: y1))
            } else {
                path.move(to: CGPoint(x: rect.maxX, y: y0))
                path.addLine(to: CGPoint(x: rect.minX, y: y1))
            }
        }
        return path
    }
}

/// Nuvem de fumaça na base do lançamento — só durante `.liftoff`, com um pulso leve
/// de escala pra não ficar estática demais. Cluster de círculos sobrepostos em
/// posições fixas (não aleatórias a cada render).
private struct SmokeCluster: View {
    @State private var pulse = false

    private struct Puff {
        let dx: CGFloat
        let dy: CGFloat
        let size: CGFloat
        let opacity: Double
    }

    private static let puffs: [Puff] = [
        Puff(dx: -46, dy: 8, size: 52, opacity: 0.55),
        Puff(dx: -14, dy: 16, size: 68, opacity: 0.72),
        Puff(dx: 26, dy: 10, size: 58, opacity: 0.62),
        Puff(dx: 54, dy: 18, size: 46, opacity: 0.5),
        Puff(dx: 6, dy: -10, size: 40, opacity: 0.55),
        Puff(dx: -30, dy: -6, size: 34, opacity: 0.4),
        Puff(dx: 40, dy: -4, size: 32, opacity: 0.4),
    ]

    var body: some View {
        ZStack {
            ForEach(Self.puffs.indices, id: \.self) { index in
                let puff = Self.puffs[index]
                Circle()
                    .fill(Color.white.opacity(puff.opacity))
                    .frame(width: puff.size * (pulse ? 1.08 : 1.0), height: puff.size * (pulse ? 1.08 : 1.0))
                    .offset(x: puff.dx, y: puff.dy)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

/// Foguete simples desenhado só com formas primitivas do SwiftUI (triângulos +
/// retângulo arredondado + círculo) — sem depender de nenhum asset de imagem que eu
/// não tenho como produzir (ilustração de personagem de verdade precisaria de um
/// designer). Cores fixas (creme + terracota da própria paleta SOVEE), não ligadas
/// ao tema dia/noite — o foguete é sempre o mesmo objeto reconhecível, só o cenário
/// em volta muda.
struct RocketIcon: View {
    private let bodyColor = Color(red: 0.97, green: 0.96, blue: 0.93)
    private let trimColor = SoveeColor.terracota

    var body: some View {
        VStack(spacing: -6) {
            TriangleShape()
                .fill(trimColor)
                .frame(width: 22, height: 18)

            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(bodyColor)
                .frame(width: 26, height: 34)
                .overlay(
                    Circle()
                        .fill(SoveeColor.carvao.opacity(0.85))
                        .frame(width: 11, height: 11)
                )

            HStack(spacing: 16) {
                TriangleShape()
                    .fill(trimColor)
                    .frame(width: 12, height: 14)
                    .rotationEffect(.degrees(-100))
                TriangleShape()
                    .fill(trimColor)
                    .frame(width: 12, height: 14)
                    .rotationEffect(.degrees(100))
            }
            .offset(y: -8)
        }
    }
}

/// Foguete + chama — a chama só aparece durante a decolagem (`showsFlame: true`);
/// em órbita o foguete desliza sozinho, sem propulsão visível.
private struct RocketWithFlame: View {
    let showsFlame: Bool
    @State private var flicker = false

    var body: some View {
        VStack(spacing: 0) {
            RocketIcon()
            if showsFlame {
                FlameShape()
                    .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                    .frame(width: 20, height: flicker ? 38 : 26)
                    .offset(y: -8)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.18).repeatForever(autoreverses: true)) {
                            flicker = true
                        }
                    }
            }
        }
    }
}

private struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.3), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.1))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.3), control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.1))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
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

                RocketIcon()
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
