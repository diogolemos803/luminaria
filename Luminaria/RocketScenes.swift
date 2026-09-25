import SwiftUI

// Tradução dos protótipos aprovados em design/ (entrada_prototipo.html,
// decolagem_prototipo.html, pouso_prototipo.html). As cenas são desenhadas num
// `Canvas` no MESMO espaço de coordenadas dos protótipos (390×844, foguete
// centralizado em 195×422) e escaladas pra preencher a tela ("aspect fill"), e
// cada elemento é uma função pura do tempo — os mesmos atrasos, durações e curvas
// `cubic-bezier` do CSS. Assim um ajuste no protótipo vira um número trocado aqui.

// MARK: - Curvas e tempo

/// Equivalente ao `cubic-bezier(x1, y1, x2, y2)` do CSS.
struct SceneCurve {
    let x1: Double
    let y1: Double
    let x2: Double
    let y2: Double

    static let linear = SceneCurve(x1: 0, y1: 0, x2: 1, y2: 1)
    static let easeIn = SceneCurve(x1: 0.42, y1: 0, x2: 1, y2: 1)
    static let easeOut = SceneCurve(x1: 0, y1: 0, x2: 0.58, y2: 1)
    static let easeInOut = SceneCurve(x1: 0.42, y1: 0, x2: 0.58, y2: 1)

    func value(_ t: Double) -> Double {
        let t = min(max(t, 0), 1)
        if t == 0 || t == 1 { return t }
        var lo = 0.0
        var hi = 1.0
        var u = t
        for _ in 0..<22 {
            u = (lo + hi) / 2
            if Self.bezier(u, x1, x2) < t { lo = u } else { hi = u }
        }
        return Self.bezier(u, y1, y2)
    }

    private static func bezier(_ u: Double, _ p1: Double, _ p2: Double) -> Double {
        let v = 1 - u
        return 3 * v * v * u * p1 + 3 * v * u * u * p2 + u * u * u
    }
}

enum SceneTime {
    /// Progresso 0...1 de uma animação com `fill-mode: both` (parada no início antes
    /// do atraso, parada no fim depois de terminar).
    static func progress(_ t: Double, delay: Double, duration: Double) -> Double {
        min(max((t - delay) / duration, 0), 1)
    }

    /// Fase 0..<1 de um laço infinito.
    static func loop(_ t: Double, period: Double) -> Double {
        let x = t.truncatingRemainder(dividingBy: period) / period
        return x < 0 ? x + 1 : x
    }

    /// Valor numa trilha de keyframes, com a curva aplicada em cada trecho (como o
    /// `animation-timing-function` do CSS, que vale entre um keyframe e o próximo).
    static func sample(_ offsets: [Double], _ values: [Double], _ p: Double, _ curve: SceneCurve) -> Double {
        if p <= offsets[0] { return values[0] }
        for i in 1..<offsets.count where p <= offsets[i] {
            let span = max(offsets[i] - offsets[i - 1], 0.0001)
            let local = (p - offsets[i - 1]) / span
            return values[i - 1] + (values[i] - values[i - 1]) * curve.value(local)
        }
        return values[values.count - 1]
    }
}

// MARK: - Peças de desenho compartilhadas

extension Color {
    init(sceneHex hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum SceneShapes {
    static func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

    static func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Path {
        Path(CGRect(x: x, y: y, width: w, height: h))
    }

    static func rrect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
    }

    static func circle(_ cx: Double, _ cy: Double, _ r: Double) -> Path {
        Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    }

    static func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }

    static func line(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Path {
        var p = Path()
        p.move(to: pt(x1, y1))
        p.addLine(to: pt(x2, y2))
        return p
    }

    static func polygon(_ points: [(Double, Double)]) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: pt(first.0, first.1))
        for point in points.dropFirst() { p.addLine(to: pt(point.0, point.1)) }
        p.closeSubpath()
        return p
    }

    /// Patch "blob" (Q x1 y1 x y) — as manchas de terreno dos protótipos usam só
    /// curvas quadráticas: início + lista de (controle, ponto).
    static func quadBlob(start: (Double, Double), _ segments: [(Double, Double, Double, Double)]) -> Path {
        var p = Path()
        p.move(to: pt(start.0, start.1))
        for s in segments { p.addQuadCurve(to: pt(s.2, s.3), control: pt(s.0, s.1)) }
        p.closeSubpath()
        return p
    }

    /// Bolha de nuvem ("couve-flor") usada em toda fumaça/poeira, ~84×66 em torno da
    /// origem.
    static let blob: Path = {
        var p = Path()
        p.move(to: pt(-34, 8))
        p.addCurve(to: pt(-5, -14), control1: pt(-37, -9), control2: pt(-19, -19))
        p.addCurve(to: pt(26, -16), control1: pt(-3, -29), control2: pt(20, -31))
        p.addCurve(to: pt(39, 8), control1: pt(41, -21), control2: pt(50, -2))
        p.addCurve(to: pt(21, 27), control1: pt(47, 19), control2: pt(36, 32))
        p.addCurve(to: pt(-11, 25), control1: pt(17, 38), control2: pt(-6, 37))
        p.addCurve(to: pt(-34, 8), control1: pt(-28, 31), control2: pt(-39, 19))
        p.closeSubpath()
        return p
    }()

    static func blobPath(at x: Double, _ y: Double, scale s: Double) -> Path {
        blob.applying(CGAffineTransform(translationX: x, y: y).scaledBy(x: s, y: s))
    }

    static func vertical(_ stops: [Gradient.Stop], _ y0: Double, _ y1: Double) -> GraphicsContext.Shading {
        .linearGradient(Gradient(stops: stops), startPoint: pt(0, y0), endPoint: pt(0, y1))
    }

    static func diagonal(_ c0: Color, _ c1: Color, in r: CGRect) -> GraphicsContext.Shading {
        .linearGradient(Gradient(colors: [c0, c1]), startPoint: CGPoint(x: r.minX, y: r.minY), endPoint: CGPoint(x: r.maxX, y: r.maxY))
    }

    static func radial(_ stops: [Gradient.Stop], center: CGPoint, radius: Double) -> GraphicsContext.Shading {
        .radialGradient(Gradient(stops: stops), center: center, startRadius: 0, endRadius: radius)
    }

    /// Enquadramento dos protótipos: design de 390×844 preenchendo a tela, com o
    /// ponto (195, 422) — centro do foguete — no centro da tela.
    static func applyCamera(_ ctx: inout GraphicsContext, size: CGSize) {
        let s = max(size.width / 390, size.height / 844)
        ctx.translateBy(x: size.width / 2 - 195 * s, y: size.height / 2 - 422 * s)
        ctx.scaleBy(x: s, y: s)
    }
}

// MARK: - Foguete, chama e fumaça (iguais nas duas cenas)

enum RocketArt {
    typealias S = SceneShapes

    static let red0 = Color(sceneHex: 0xEC6B4C)
    static let red1 = Color(sceneHex: 0xCC4A33)

    static let hull: Path = {
        var p = Path()
        p.move(to: S.pt(195, 481))
        p.addCurve(to: S.pt(232, 580), control1: S.pt(214, 490), control2: S.pt(231, 530))
        p.addCurve(to: S.pt(225, 665), control1: S.pt(233, 620), control2: S.pt(228, 650))
        p.addLine(to: S.pt(165, 665))
        p.addCurve(to: S.pt(158, 580), control1: S.pt(162, 650), control2: S.pt(157, 620))
        p.addCurve(to: S.pt(195, 481), control1: S.pt(159, 530), control2: S.pt(176, 490))
        p.closeSubpath()
        return p
    }()

    static let leftFin: Path = {
        var p = Path()
        p.move(to: S.pt(160, 596))
        p.addCurve(to: S.pt(126, 692), control1: S.pt(136, 606), control2: S.pt(124, 640))
        p.addCurve(to: S.pt(167, 662), control1: S.pt(136, 678), control2: S.pt(150, 668))
        p.closeSubpath()
        return p
    }()

    static let rightFin: Path = {
        var p = Path()
        p.move(to: S.pt(230, 596))
        p.addCurve(to: S.pt(264, 692), control1: S.pt(254, 606), control2: S.pt(266, 640))
        p.addCurve(to: S.pt(223, 662), control1: S.pt(254, 678), control2: S.pt(240, 668))
        p.closeSubpath()
        return p
    }()

    static let flameOuter: Path = teardrop(179, 211, tip: 764, c1: (170, 694), c2: (183, 728))
    static let flameMid: Path = teardrop(184, 206, tip: 745, c1: (178, 692), c2: (188, 720))
    static let flameCore: Path = teardrop(188, 202, tip: 720, c1: (185, 686), c2: (191, 704))

    /// Gota da chama: topo reto no bocal (y 672), barriga, ponta fina embaixo.
    private static func teardrop(_ left: Double, _ right: Double, tip: Double, c1: (Double, Double), c2: (Double, Double)) -> Path {
        var p = Path()
        p.move(to: S.pt(left, 672))
        p.addCurve(to: S.pt(195, tip), control1: S.pt(c1.0, c1.1), control2: S.pt(c2.0, c2.1))
        p.addCurve(to: S.pt(right, 672), control1: S.pt(390 - c2.0, c2.1), control2: S.pt(390 - c1.0, c1.1))
        p.closeSubpath()
        return p
    }

    /// Foguete completo (design do protótipo), já no lugar: base em y 665.
    /// `doorOpen` 0 = porta fechada, 1 = aberta (só o pouso abre).
    static func drawRocket(_ ctx: inout GraphicsContext, doorOpen: Double) {
        ctx.fill(leftFin, with: S.diagonal(red0, red1, in: leftFin.boundingRect))
        ctx.fill(rightFin, with: S.diagonal(red0, red1, in: rightFin.boundingRect))
        ctx.fill(S.polygon([(182, 664), (208, 664), (204, 675), (186, 675)]), with: .color(Color(sceneHex: 0x4D525B)))

        ctx.fill(hull, with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(sceneHex: 0xE6E0D4), location: 0),
                .init(color: Color(sceneHex: 0xF8F4EC), location: 0.45),
                .init(color: Color(sceneHex: 0xDCD5C7), location: 1),
            ]),
            startPoint: S.pt(157.5, 0),
            endPoint: S.pt(233, 0)
        ))

        var capLayer = ctx
        capLayer.clip(to: hull)
        var cap = Path()
        cap.move(to: S.pt(140, 470))
        cap.addLine(to: S.pt(250, 470))
        cap.addLine(to: S.pt(250, 516))
        cap.addQuadCurve(to: S.pt(140, 516), control: S.pt(195, 534))
        cap.closeSubpath()
        capLayer.fill(cap, with: S.diagonal(red0, red1, in: cap.boundingRect))
        capLayer.fill(S.rect(215, 470, 30, 200), with: .color(Color.black.opacity(0.07)))

        ctx.fill(S.circle(195, 566, 19), with: .color(Color(sceneHex: 0xD4D8DD)))
        let glass = S.circle(195, 566, 14)
        ctx.fill(glass, with: S.diagonal(Color(sceneHex: 0x46668A), Color(sceneHex: 0x28405A), in: glass.boundingRect))
        ctx.fill(S.ellipse(189, 560, 5, 4), with: .color(Color(sceneHex: 0x7F9BB8, opacity: 0.7)))
        ctx.fill(S.circle(187, 558, 1.6), with: .color(Color.white.opacity(0.8)))

        // porta: interior escuro por baixo, painel por cima (abre encolhendo da esquerda)
        let door = S.rrect(181, 592, 28, 34, 6)
        ctx.fill(door, with: .color(Color(sceneHex: 0x1A2030)))
        if doorOpen < 0.999 {
            var panel = ctx
            panel.translateBy(x: 181, y: 0)
            panel.scaleBy(x: 1 - doorOpen, y: 1)
            panel.translateBy(x: -181, y: 0)
            panel.fill(door, with: .color(Color(sceneHex: 0xECE6DA)))
        }
        ctx.stroke(door, with: .color(Color(sceneHex: 0xB9B2A4)), lineWidth: 1.2)

        let centerFin = S.rrect(191, 628, 8, 66, 4)
        ctx.fill(centerFin, with: S.diagonal(red0, red1, in: centerFin.boundingRect))
    }

    /// Chama com oscilação BEM leve (pedido do usuário): cada camada estica um
    /// pouquinho num ritmo próprio, e um balanço lateral mínimo.
    static func drawFlame(_ ctx: inout GraphicsContext, clock: Double) {
        let swayPhase = SceneTime.loop(clock, period: 3.2)
        let tri = swayPhase < 0.5 ? swayPhase * 2 : 2 - swayPhase * 2
        let angle = -0.6 + 1.2 * SceneCurve.easeInOut.value(tri)
        var sway = ctx
        sway.translateBy(x: 195, y: 672)
        sway.rotate(by: .degrees(angle))
        sway.translateBy(x: -195, y: -672)

        let outer = S.vertical([
            .init(color: Color(sceneHex: 0xFFCF6E), location: 0),
            .init(color: Color(sceneHex: 0xF7A53F), location: 0.6),
            .init(color: Color(sceneHex: 0xEC7F2C, opacity: 0.7), location: 1),
        ], 672, 764)
        let mid = S.vertical([
            .init(color: Color(sceneHex: 0xFFF0C4), location: 0),
            .init(color: Color(sceneHex: 0xFFD27A), location: 1),
        ], 672, 745)
        let core = S.radial([
            .init(color: .white, location: 0),
            .init(color: Color(sceneHex: 0xFFF3CF), location: 1),
        ], center: S.pt(195, 679), radius: 41)

        flicker(&sway, flameOuter, outer, period: 0.7, amount: 0.05, clock: clock)
        flicker(&sway, flameMid, mid, period: 0.5, amount: 0.06, clock: clock)
        flicker(&sway, flameCore, core, period: 0.36, amount: 0.07, clock: clock)
    }

    private static func flicker(_ ctx: inout GraphicsContext, _ path: Path, _ shading: GraphicsContext.Shading, period: Double, amount: Double, clock: Double) {
        let phase = SceneTime.loop(clock, period: period)
        let sy = SceneTime.sample([0, 0.5, 1], [1, 1 + amount, 1], phase, .easeInOut)
        var c = ctx
        c.translateBy(x: 195, y: 672)
        c.scaleBy(x: 1, y: sy)
        c.translateBy(x: -195, y: -672)
        c.fill(path, with: shading)
    }

    struct ExhaustPuff {
        let x: Double, y: Double, scale: Double, duration: Double, delay: Double, dx: Double
    }

    static let exhaustPuffs: [ExhaustPuff] = [
        ExhaustPuff(x: 195, y: 758, scale: 0.22, duration: 1.4, delay: 0, dx: -4),
        ExhaustPuff(x: 193, y: 760, scale: 0.18, duration: 1.5, delay: 0.35, dx: 6),
        ExhaustPuff(x: 197, y: 756, scale: 0.2, duration: 1.3, delay: 0.7, dx: -7),
        ExhaustPuff(x: 195, y: 760, scale: 0.24, duration: 1.45, delay: 1.05, dx: 3),
    ]

    /// Um pouco de fumaça clara saindo da ponta da chama e ficando pra trás.
    static func drawExhaust(_ ctx: inout GraphicsContext, clock: Double, count: Int) {
        for puff in exhaustPuffs.prefix(count) {
            let phase = SceneTime.loop(clock - puff.delay, period: puff.duration)
            let opacity = SceneTime.sample([0, 0.18, 1], [0, 0.5, 0], phase, .easeOut)
            guard opacity > 0.001 else { continue }
            let e = SceneCurve.easeOut.value(phase)
            var c = ctx
            c.opacity *= opacity
            c.translateBy(x: puff.x + puff.dx * e, y: puff.y + 92 * e)
            c.scaleBy(x: puff.scale * (0.5 + 1.2 * e), y: puff.scale * (0.5 + 1.2 * e))
            c.fill(S.blob, with: .color(Color(sceneHex: 0xF3EEE4)))
        }
    }

    /// Brilho do motor (mistura "screen", desfocado).
    static func drawGlow(_ ctx: inout GraphicsContext, opacity: Double, scale: Double) {
        guard opacity > 0.001 else { return }
        var c = ctx
        c.blendMode = .screen
        c.opacity *= opacity
        c.addFilter(.blur(radius: 7))
        c.translateBy(x: 195, y: 690)
        c.scaleBy(x: scale, y: scale)
        c.translateBy(x: -195, y: -690)
        c.fill(S.ellipse(195, 702, 40, 46), with: S.radial([
            .init(color: Color(sceneHex: 0xFFCF7A, opacity: 0.9), location: 0),
            .init(color: Color(sceneHex: 0xFF9A45, opacity: 0.35), location: 0.55),
            .init(color: Color(sceneHex: 0xFF9A45, opacity: 0), location: 1),
        ], center: S.pt(195, 688), radius: 55))
    }
}

/// Um puff de fumaça/poeira com trajetória própria (tradução do `.puff` do CSS).
struct ScenePuff {
    let x: Double, y: Double
    let dx: Double, dy: Double, rotation: Double
    let duration: Double, delay: Double, endOpacity: Double
    let sx: Double, sy: Double
    let color: Color?          // nil = creme aquecido pela chama (gradiente)
    let alpha: Double
    let shade: Color?

    struct Track {
        let offsets: [Double]
        let opacity: [Double]      // último valor é trocado pelo endOpacity do puff
        let tx: [Double]
        let ty: [Double]
        let scale: [Double]
        let rotation: [Double]
        let curve: SceneCurve
        let shadeOffset: CGSize
    }

    func draw(_ ctx: inout GraphicsContext, t: Double, track: Track) {
        let p = SceneTime.progress(t, delay: delay, duration: duration)
        var opacities = track.opacity
        opacities[opacities.count - 1] = endOpacity
        let op = SceneTime.sample(track.offsets, opacities, p, track.curve)
        guard op > 0.001 else { return }
        let fx = SceneTime.sample(track.offsets, track.tx, p, track.curve)
        let fy = SceneTime.sample(track.offsets, track.ty, p, track.curve)
        let s = SceneTime.sample(track.offsets, track.scale, p, track.curve)
        let r = SceneTime.sample(track.offsets, track.rotation, p, track.curve)

        var c = ctx
        c.opacity *= op * alpha
        c.translateBy(x: x + dx * fx, y: y + dy * fy)
        c.scaleBy(x: s, y: s)
        c.rotate(by: .degrees(rotation * r))

        if let shade {
            var sh = c
            sh.translateBy(x: track.shadeOffset.width, y: track.shadeOffset.height)
            sh.scaleBy(x: sx, y: sy)
            sh.fill(SceneShapes.blob, with: .color(shade))
        }
        var main = c
        main.scaleBy(x: sx, y: sy)
        if let color {
            main.fill(SceneShapes.blob, with: .color(color))
        } else {
            main.fill(SceneShapes.blob, with: SceneShapes.radial([
                .init(color: Color(sceneHex: 0xFBE6C6), location: 0),
                .init(color: Color(sceneHex: 0xEFE9DC), location: 1),
            ], center: SceneShapes.pt(5.5, -7), radius: 58))
        }
    }
}

// MARK: - Cena da decolagem (noite)

/// Cena da decolagem, com a ENTRADA incluída: `sceneStart` é o instante em que o
/// botão redondo começa a sair pela esquerda (ver `ContentView`). A partir dele o
/// céu desce de cima e a Terra com o foguete sobe de baixo (1,6s), e só com a cena
/// assentada a decolagem começa. `sceneStart == nil` = app reaberto no meio da
/// sessão: mostra direto o foguete já em voo, sem repetir nada.
///
/// O foguete NUNCA se move na tela (decisão do usuário) — só o cenário se move.
struct LaunchScene: View {
    let phase: NightSessionActivityTracker.Phase
    let badgeColor: Color
    let sceneStart: Date?

    @State private var isResting = false

    var body: some View {
        TimelineView(.animation(minimumInterval: isResting ? 1.0 / 30.0 : nil)) { timeline in
            let now = timeline.date
            let sceneTime: Double = sceneStart.map { now.timeIntervalSince($0) } ?? 600
            let clock = now.timeIntervalSinceReferenceDate
            let showsRocket = phase != .exploded
            Canvas { context, size in
                LaunchPainter.draw(in: &context, size: size, sceneTime: sceneTime, clock: clock, showsRocket: showsRocket, badgeColor: badgeColor)
            }
        }
        .overlay {
            // O foguete fica exatamente no centro da tela, então a explosão também.
            if phase == .exploded {
                ExplosionBurst()
            }
        }
        .task(id: sceneStart) {
            isResting = false
            if let start = sceneStart {
                let wait = start.addingTimeInterval(LaunchPainter.settleTime).timeIntervalSinceNow
                if wait > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                }
                if Task.isCancelled { return }
            }
            NightSessionActivityTracker.shared.liftoffAnimationCompleted()
            isResting = true
        }
    }
}

enum LaunchPainter {
    typealias S = SceneShapes

    /// Entrada (0,12s de atraso + 1,6s) — e a decolagem começa 1,8s depois do início.
    static let launchDelay: Double = 1.8
    /// Momento em que o chão já saiu de tela e o rastro sumiu: dali pra frente é só o
    /// foguete voando no céu (estado da noite inteira).
    static let settleTime: Double = launchDelay + 7.6

    private static let rocketLift: Double = -164

    static func draw(in ctx: inout GraphicsContext, size: CGSize, sceneTime: Double, clock: Double, showsRocket: Bool, badgeColor: Color) {
        S.applyCamera(&ctx, size: size)

        let entrance = SceneCurve(x1: 0.3, y1: 0, x2: 0.2, y2: 1).value(SceneTime.progress(sceneTime, delay: 0.12, duration: 1.6))
        let t = sceneTime - launchDelay

        var sky = ctx
        sky.translateBy(x: 0, y: -1260 * (1 - entrance))
        drawSky(&sky, badgeColor: badgeColor)

        var world = ctx
        world.translateBy(x: 0, y: 844 * (1 - entrance))
        let groundY = groundOffset(t)

        var ground = world
        ground.translateBy(x: 0, y: groundY)
        if groundY < 900 {
            drawTerrain(&ground)
            drawLaunchBase(&ground, clock: clock)
        }

        drawColumn(&world, t: t, groundY: groundY)
        if showsRocket {
            drawFlame(&world, t: t, clock: clock, groundY: groundY)
        }
        if groundY < 900 {
            drawCloud(&ground, t: t)
        }
        if showsRocket {
            var rocket = world
            rocket.translateBy(x: 0, y: rocketLift)
            let glowIn = SceneTime.sample([0, 0.18, 0.55, 1], [0, 0.5, 0.5, 1], SceneTime.progress(t, delay: 0.15, duration: 1.8), .easeOut)
            let pulse = SceneTime.loop(clock, period: 1.1)
            let pulseOpacity = SceneTime.sample([0, 0.5, 1], [0.62, 0.75, 0.62], pulse, .easeInOut)
            let pulseScale = SceneTime.sample([0, 0.5, 1], [1, 1.04, 1], pulse, .easeInOut)
            RocketArt.drawGlow(&rocket, opacity: 0.8 * glowIn * pulseOpacity, scale: pulseScale)
            RocketArt.drawRocket(&rocket, doorOpen: 0)
        }
    }

    /// Chão parado na ignição, depois desce acelerando a partir do repouso e sai de
    /// tela (as duas curvas se emendam com a mesma velocidade).
    static func groundOffset(_ t: Double) -> Double {
        let p = SceneTime.progress(t, delay: 1.0, duration: 4.8)
        if p <= 0.27 {
            return -164 + 164 * SceneCurve(x1: 0.33, y1: 0, x2: 0.67, y2: 0.33).value(p / 0.27)
        }
        return 900 * (p - 0.27) / 0.73
    }

    // MARK: Céu

    static let stars: [(Double, Double, Double, Double)] = [
        (30, 70, 1.6, 0.85), (70, 140, 1.1, 0.5), (130, 50, 1.6, 0.75), (180, 180, 1.1, 0.4),
        (230, 90, 1.8, 0.9), (280, 150, 1.2, 0.55), (330, 60, 1.6, 0.7), (360, 190, 1.2, 0.6),
        (55, 250, 1.2, 0.45), (110, 300, 1.6, 0.6), (195, 270, 1.2, 0.5), (250, 260, 1.1, 0.4),
        (300, 310, 1.6, 0.6), (20, 340, 1.1, 0.4), (150, 360, 1.6, 0.5), (345, 350, 1.2, 0.5),
        (90, 400, 1.1, 0.4), (260, 410, 1.4, 0.5), (36, 446, 1.3, 0.5), (128, 468, 1.1, 0.4),
        (232, 452, 1.5, 0.6), (318, 478, 1.1, 0.45), (372, 430, 1.4, 0.55), (80, 500, 1.1, 0.35),
        (290, 514, 1.2, 0.35),
    ]

    static func drawSky(_ c: inout GraphicsContext, badgeColor: Color) {
        // telas mais altas/largas que 390×844 mostram um pouco além do quadro:
        // prolonga as cores das pontas pra cima e pros lados
        c.fill(S.rect(-200, -400, 790, 401), with: .color(Color(sceneHex: 0x0C1120)))
        c.fill(S.rect(-200, 0, 790, 844), with: S.vertical([
            .init(color: Color(sceneHex: 0x0C1120), location: 0),
            .init(color: Color(sceneHex: 0x161C31), location: 0.55),
            .init(color: Color(sceneHex: 0x232A42), location: 1),
        ], 0, 844))
        // prolongamento pra baixo: passa por trás da Terra durante a entrada (até
        // y 1253 — com o deslocamento inicial de -1260 o céu começa todo fora de tela)
        c.fill(S.rect(-200, 843, 790, 410), with: .color(Color(sceneHex: 0x232A42)))
        for star in stars {
            c.fill(S.circle(star.0, star.1, star.2), with: .color(Color.white.opacity(star.3)))
        }
        // selo do planeta-destino desbloqueado
        let badge = S.circle(45, 60, 13)
        c.fill(badge, with: .color(badgeColor))
        c.stroke(badge, with: .color(Color.white.opacity(0.15)), lineWidth: 1)
    }

    // MARK: Terra

    static let horizon: Path = {
        var p = Path()
        p.move(to: S.pt(-20, 700))
        p.addCurve(to: S.pt(155, 660), control1: S.pt(55, 700), control2: S.pt(95, 668))
        p.addCurve(to: S.pt(235, 660), control1: S.pt(185, 656), control2: S.pt(205, 656))
        p.addCurve(to: S.pt(410, 700), control1: S.pt(275, 665), control2: S.pt(325, 682))
        return p
    }()

    /// Tudo acima da linha do horizonte — a chama só aparece aí (nasce abaixo do
    /// nível da plataforma e vai sendo revelada conforme o chão se afasta).
    static let aboveGround: Path = {
        var p = Path()
        p.move(to: S.pt(-60, -3000))
        p.addLine(to: S.pt(450, -3000))
        p.addLine(to: S.pt(450, 700))
        p.addLine(to: S.pt(410, 700))
        p.addCurve(to: S.pt(235, 660), control1: S.pt(325, 682), control2: S.pt(275, 665))
        p.addCurve(to: S.pt(155, 660), control1: S.pt(205, 656), control2: S.pt(185, 656))
        p.addCurve(to: S.pt(-20, 700), control1: S.pt(95, 668), control2: S.pt(55, 700))
        p.addLine(to: S.pt(-60, 700))
        p.closeSubpath()
        return p
    }()

    static func drawTerrain(_ t: inout GraphicsContext) {
        // brilho atmosférico atrás do horizonte (radial elíptico, como o
        // gradiente em objectBoundingBox do SVG: raio 75% da largura/altura)
        var glow = t
        glow.clip(to: S.rect(0, 500, 390, 200))
        glow.translateBy(x: 195, y: 700)
        glow.scaleBy(x: 292.5, y: 150)
        glow.fill(S.circle(0, 0, 1.5), with: S.radial([
            .init(color: Color(sceneHex: 0x3A4A72, opacity: 0.55), location: 0),
            .init(color: Color(sceneHex: 0x3A4A72, opacity: 0), location: 1),
        ], center: .zero, radius: 1))

        var land = horizon
        land.addLine(to: S.pt(410, 1260))
        land.addLine(to: S.pt(-20, 1260))
        land.closeSubpath()
        t.fill(land, with: S.vertical([
            .init(color: Color(sceneHex: 0x4F7F5F), location: 0),
            .init(color: Color(sceneHex: 0x3F7050), location: 0.12),
            .init(color: Color(sceneHex: 0x2C5039), location: 0.45),
            .init(color: Color(sceneHex: 0x1A3325), location: 1),
        ], 656, 1260))

        var haze = horizon
        haze.addLine(to: S.pt(410, 720))
        haze.addLine(to: S.pt(-20, 720))
        haze.closeSubpath()
        t.fill(haze, with: S.vertical([
            .init(color: Color(sceneHex: 0x8FB3A0, opacity: 0.5), location: 0),
            .init(color: Color(sceneHex: 0x8FB3A0, opacity: 0), location: 1),
        ], 656, 720))
        t.stroke(horizon, with: .color(Color(sceneHex: 0xB8D6C2, opacity: 0.35)), lineWidth: 1.5)

        // plataforma bege em cima do morro
        var pad = Path()
        pad.move(to: S.pt(73, 688))
        pad.addCurve(to: S.pt(155, 665), control1: S.pt(100, 677), control2: S.pt(130, 667))
        pad.addCurve(to: S.pt(235, 665), control1: S.pt(180, 662), control2: S.pt(210, 662))
        pad.addCurve(to: S.pt(306, 681), control1: S.pt(262, 669), control2: S.pt(285, 674))
        pad.addCurve(to: S.pt(195, 696), control1: S.pt(280, 692), control2: S.pt(240, 696))
        pad.addCurve(to: S.pt(73, 688), control1: S.pt(150, 696), control2: S.pt(105, 694))
        pad.closeSubpath()
        var padLayer = t
        padLayer.addFilter(.blur(radius: 1.1))
        padLayer.fill(pad, with: S.vertical([
            .init(color: Color(sceneHex: 0x948B76), location: 0),
            .init(color: Color(sceneHex: 0x6D6858), location: 1),
        ], 662, 696))

        // manchas de relevo/vegetação
        var soft = t
        soft.addFilter(.blur(radius: 3))
        let patches: [(Path, UInt32, Double)] = [
            (S.quadBlob(start: (15, 740), [(55, 722, 100, 736), (80, 758, 35, 760), (12, 752, 15, 740)]), 0x5A8F68, 0.55),
            (S.quadBlob(start: (120, 760), [(170, 744, 205, 762), (178, 782, 135, 780)]), 0x254230, 0.6),
            (S.quadBlob(start: (230, 750), [(270, 730, 310, 744), (292, 766, 250, 768)]), 0x5A8F68, 0.45),
            (S.quadBlob(start: (300, 775), [(350, 758, 385, 774), (365, 796, 315, 792)]), 0x6B5A3C, 0.55),
            (S.quadBlob(start: (-10, 780), [(40, 764, 80, 782), (55, 802, 5, 800)]), 0x173322, 0.5),
            (S.quadBlob(start: (40, 880), [(110, 858, 170, 878), (130, 906, 60, 904)]), 0x5A8F68, 0.4),
            (S.quadBlob(start: (220, 900), [(290, 878, 360, 896), (320, 926, 245, 922)]), 0x254230, 0.55),
            (S.quadBlob(start: (-20, 990), [(60, 966, 130, 988), (90, 1018, 10, 1014)]), 0x6B5A3C, 0.45),
            (S.quadBlob(start: (170, 1010), [(250, 986, 330, 1006), (290, 1040, 200, 1036)]), 0x5A8F68, 0.35),
            (S.quadBlob(start: (280, 1100), [(350, 1080, 410, 1098), (370, 1128, 300, 1124)]), 0x173322, 0.5),
            (S.quadBlob(start: (30, 1120), [(100, 1100, 160, 1118), (120, 1146, 50, 1142)]), 0x254230, 0.5),
        ]
        for patch in patches {
            soft.fill(patch.0, with: .color(Color(sceneHex: patch.1, opacity: patch.2)))
        }

        let rocks: [(Double, Double, Double, Double)] = [
            (120, 860, 2.6, 0.55), (300, 940, 3, 0.55), (70, 960, 2.2, 0.55), (240, 1060, 2.8, 0.55),
            (350, 1170, 2.4, 0.55), (150, 1190, 2.6, 0.55), (60, 770, 3, 0.6), (95, 790, 2.2, 0.6),
            (280, 800, 2.6, 0.6), (330, 760, 3, 0.6), (360, 810, 2.2, 0.6), (20, 815, 2.4, 0.6),
        ]
        for rock in rocks {
            t.fill(S.circle(rock.0, rock.1, rock.2), with: .color(Color(sceneHex: 0x1C3826, opacity: rock.3)))
        }

        // estrada de acesso
        var road = Path()
        road.move(to: S.pt(150, 697))
        road.addCurve(to: S.pt(84, 810), control1: S.pt(146, 730), control2: S.pt(118, 770))
        road.addCurve(to: S.pt(36, 940), control1: S.pt(60, 838), control2: S.pt(44, 880))
        t.stroke(road, with: .color(Color(sceneHex: 0x7D765F, opacity: 0.6)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        t.stroke(road, with: .color(Color(sceneHex: 0xA39A7E, opacity: 0.45)), style: StrokeStyle(lineWidth: 1, dash: [5, 6]))

        // campos cultivados
        var fields = t
        fields.opacity *= 0.5
        fields.fill(S.polygon([(196, 900), (286, 880), (312, 924), (214, 946)]), with: .color(Color(sceneHex: 0x4F8662)))
        for l in [(202.0, 912.0, 292.0, 892.0), (207, 923, 298, 903), (210, 934, 304, 913)] {
            fields.stroke(S.line(l.0, l.1, l.2, l.3), with: .color(Color(sceneHex: 0x3A6A4B)), lineWidth: 1.5)
        }
        fields.fill(S.polygon([(96, 960), (170, 948), (186, 984), (108, 998)]), with: .color(Color(sceneHex: 0x6B7A45)))
        for l in [(100.0, 970.0, 174.0, 958.0), (104, 980, 179, 968), (106, 990, 183, 977)] {
            fields.stroke(S.line(l.0, l.1, l.2, l.3), with: .color(Color(sceneHex: 0x56643A)), lineWidth: 1.5)
        }

        // lago
        var lake = Path()
        lake.move(to: S.pt(246, 816))
        lake.addCurve(to: S.pt(350, 818), control1: S.pt(266, 800), control2: S.pt(328, 802))
        lake.addCurve(to: S.pt(286, 844), control1: S.pt(358, 834), control2: S.pt(322, 846))
        lake.addCurve(to: S.pt(246, 816), control1: S.pt(258, 842), control2: S.pt(240, 832))
        lake.closeSubpath()
        t.fill(lake, with: S.vertical([
            .init(color: Color(sceneHex: 0x3A5A74), location: 0),
            .init(color: Color(sceneHex: 0x22384D), location: 1),
        ], 804, 845))
        var lakeRim = Path()
        lakeRim.move(to: S.pt(256, 814))
        lakeRim.addCurve(to: S.pt(340, 816), control1: S.pt(276, 804), control2: S.pt(322, 806))
        t.stroke(lakeRim, with: .color(Color(sceneHex: 0xA9C7D6, opacity: 0.35)), lineWidth: 1.5)

        // árvores
        let trees: [(Double, Double, Double)] = [
            (4, 698, 6), (-4, 700, 5), (330, 684, 4), (360, 690, 5.5), (352, 693, 4), (386, 697, 6),
            (40, 840, 5), (50, 846, 4), (31, 848, 4.5), (330, 880, 5), (342, 886, 6), (320, 889, 4),
            (140, 1040, 5.5), (152, 1046, 4.5), (360, 1010, 5), (372, 1016, 4),
        ]
        for tree in trees {
            t.fill(S.circle(tree.0, tree.1, tree.2), with: .color(Color(sceneHex: 0x1D3A28)))
        }
        for h in [(2.0, 695.0, 3.0), (358, 687, 3), (338, 882, 3), (38, 837, 2.6)] {
            t.fill(S.circle(h.0, h.1, h.2), with: .color(Color(sceneHex: 0x2B5039, opacity: 0.8)))
        }
    }

    // MARK: Base de lançamento (atrás da fumaça)

    static func drawLaunchBase(_ b: inout GraphicsContext, clock: Double) {
        func fill(_ path: Path, _ hex: UInt32, _ opacity: Double = 1) {
            b.fill(path, with: .color(Color(sceneHex: hex, opacity: opacity)))
        }

        // deck elevado
        for x in [70.0, 130, 256, 316] { fill(S.rect(x, 694, 4, 8), 0x2C3037) }
        fill(S.rrect(58, 688, 276, 7, 1.5), 0x3B4049)
        fill(S.rect(58, 688, 276, 2), 0x5A606B)
        for x in [66.0, 104, 286, 326] { fill(S.circle(x, 692, 1.3), 0xFFCF73) }

        // prédio de controle
        fill(S.rect(10, 678, 46, 20), 0x474C56)
        fill(S.rect(10, 678, 46, 4), 0x5D636E)
        for x in [15.0, 24, 33, 45] { fill(S.rect(x, 686, 5, 3), 0xE8B865, 0.85) }
        fill(S.rect(60, 662, 3, 12), 0x3A3F48)
        fill(S.rect(66, 658, 3, 16), 0x3A3F48)

        // torre treliçada
        fill(S.rect(72, 670, 54, 20), 0x262A31)
        fill(S.rect(80, 444, 6, 228), 0x2F343D)
        fill(S.rect(112, 444, 6, 228), 0x2F343D)
        fill(S.rect(78, 440, 42, 6), 0x2F343D)
        fill(S.rect(118, 448, 52, 5), 0x2F343D)
        fill(S.rect(118, 566, 38, 4), 0x2F343D)
        fill(S.rect(97.5, 433, 3, 8), 0x2F343D)
        var braces = Path()
        var y = 446.0
        while y < 670 {
            braces.addPath(S.line(86, y, 112, y + 28))
            braces.addPath(S.line(112, y, 86, y + 28))
            y += 28
        }
        braces.addPath(S.line(118, 476, 148, 453))
        braces.addPath(S.line(118, 586, 140, 570))
        b.stroke(braces, with: .color(Color(sceneHex: 0x2F343D)), style: StrokeStyle(lineWidth: 3, lineCap: .square))

        // luz vermelha piscante no topo da torre
        let blinkOn = SceneTime.loop(clock, period: 1.3) < 0.45
        var light = b
        light.opacity *= blinkOn ? 1 : 0.12
        light.fill(S.circle(99, 432, 12), with: S.radial([
            .init(color: Color(sceneHex: 0xFF5A44, opacity: 0.85), location: 0),
            .init(color: Color(sceneHex: 0xFF5A44, opacity: 0), location: 1),
        ], center: S.pt(99, 432), radius: 12))
        light.fill(S.circle(99, 432, 3), with: .color(Color(sceneHex: 0xFF4A3A)))

        // mesa de lançamento com a boca do fosso de chamas, garras
        fill(S.polygon([(158, 666), (232, 666), (244, 688), (146, 688)]), 0x454A54)
        fill(S.rect(158, 666, 74, 3), 0x5F6570)
        fill(S.polygon([(181, 672), (209, 672), (213, 688), (177, 688)]), 0x17191D)
        fill(S.rect(166, 652, 5, 16), 0x353A42)
        fill(S.rect(219, 652, 5, 16), 0x353A42)

        // tubulação
        b.stroke(S.line(126, 676, 150, 676), with: .color(Color(sceneHex: 0x50565F)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        b.stroke(S.line(126, 682, 148, 682), with: .color(Color(sceneHex: 0x3F444C)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        b.stroke(S.line(268, 680, 242, 680), with: .color(Color(sceneHex: 0x50565F)), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        // tanques de combustível
        fill(S.rect(276, 685, 3, 4), 0x3A3F48)
        fill(S.rect(304, 685, 3, 4), 0x3A3F48)
        fill(S.rrect(268, 668, 48, 18, 9), 0x5A606B)
        fill(S.rrect(272, 670, 40, 4, 2), 0x727985, 0.8)
        fill(S.rect(333, 674, 3, 15), 0x3A3F48)
        fill(S.rect(348, 674, 3, 15), 0x3A3F48)
        fill(S.circle(342, 664, 14), 0x5A606B)
        var tankShine = Path()
        tankShine.move(to: S.pt(331, 657))
        tankShine.addQuadCurve(to: S.pt(348, 652), control: S.pt(338, 649))
        b.stroke(tankShine, with: .color(Color(sceneHex: 0x7D8490, opacity: 0.75)), lineWidth: 2)

        // poste com luz
        fill(S.rect(372, 612, 3, 78), 0x4A4F58)
        fill(S.circle(373.5, 611, 2.2), 0xFFD27A)
    }

    // MARK: Coluna de fumaça (presa ao chão, visível só abaixo do bocal)

    static let columnCore: Path = {
        var p = Path()
        p.move(to: S.pt(143, 668))
        p.addCurve(to: S.pt(171, 470), control1: S.pt(160, 612), control2: S.pt(168, 540))
        p.addLine(to: S.pt(184, -650))
        p.addLine(to: S.pt(206, -650))
        p.addLine(to: S.pt(219, 470))
        p.addCurve(to: S.pt(247, 668), control1: S.pt(222, 540), control2: S.pt(230, 612))
        p.closeSubpath()
        return p
    }()

    static let columnBlobs: [(Double, Double, Double)] = [
        (195, 650, 1.30), (191, 616, 1.12), (198, 586, 0.96), (192, 560, 0.84),
        (197, 537, 0.74), (193, 516, 0.66), (197, 497, 0.60), (193, 479, 0.55),
    ]

    static func drawColumn(_ world: inout GraphicsContext, t: Double, groundY: Double) {
        let fade = SceneTime.sample([0, 0.12, 0.75, 1], [0, 1, 1, 0], SceneTime.progress(t, delay: 0, duration: 7.5), .linear)
        guard fade > 0.001 else { return }
        let spread = 0.8 + 0.55 * SceneCurve(x1: 0.2, y1: 0.6, x2: 0.3, y2: 1).value(SceneTime.progress(t, delay: 1, duration: 6))
        let color = Color(sceneHex: 0xEFE8DA)

        world.drawLayer { layer in
            var content = layer
            content.opacity *= fade
            content.addFilter(.blur(radius: 1.1))
            content.drawLayer { col in
                col.translateBy(x: 0, y: groundY)
                col.translateBy(x: 195, y: 0)
                col.scaleBy(x: spread, y: 1)
                col.translateBy(x: -195, y: 0)
                col.fill(columnCore, with: .color(color.opacity(0.92)))
                for b in columnBlobs {
                    col.fill(S.blobPath(at: b.0, b.1, scale: b.2), with: .color(color))
                }
            }
            // máscara presa ao foguete: só abaixo do bocal (660→684 no foguete)
            layer.blendMode = .destinationIn
            layer.fill(S.rect(-200, -3000, 790, 6000), with: .linearGradient(
                Gradient(colors: [Color.black.opacity(0), Color.black]),
                startPoint: S.pt(0, 660 + rocketLift),
                endPoint: S.pt(0, 684 + rocketLift)
            ))
        }
    }

    // MARK: Chama (só acima do terreno) e brilho

    static func drawFlame(_ world: inout GraphicsContext, t: Double, clock: Double, groundY: Double) {
        let p = SceneTime.progress(t, delay: 1.0, duration: 1.4)
        let curve = SceneCurve(x1: 0.3, y1: 0.6, x2: 0.3, y2: 1)
        let opacity = SceneTime.sample([0, 0.3, 1], [0, 1, 1], p, curve)
        guard opacity > 0.001 else { return }
        let e = curve.value(p)

        var c = world
        c.clip(to: aboveGround.applying(CGAffineTransform(translationX: 0, y: groundY)))
        c.translateBy(x: 0, y: rocketLift)
        c.opacity *= opacity
        c.translateBy(x: 195, y: 672)
        c.scaleBy(x: 0.8 + 0.2 * e, y: 0.6 + 0.4 * e)
        c.translateBy(x: -195, y: -672)
        RocketArt.drawFlame(&c, clock: clock)
        RocketArt.drawExhaust(&c, clock: clock, count: 4)
    }

    // MARK: Nuvem da base (presa ao chão, passa na frente da base)

    static let puffTrack = ScenePuff.Track(
        offsets: [0, 0.14, 0.34, 0.65, 1],
        opacity: [0, 1, 1, 0.85, 0],
        tx: [0, 0.08, 0.32, 0.68, 1],
        ty: [0, 0.05, 0.28, 0.66, 1],
        scale: [0.35, 0.8, 1.15, 1.5, 1.85],
        rotation: [0, 0.1, 0.4, 0.7, 1],
        curve: SceneCurve(x1: 0.22, y1: 0.06, x2: 0.3, y2: 1),
        shadeOffset: CGSize(width: 5, height: 7)
    )

    static let puffs: [ScenePuff] = {
        let shade = Color(sceneHex: 0xC9BEA8)
        func puff(_ x: Double, _ y: Double, _ dx: Double, _ dy: Double, _ rot: Double, _ dur: Double, _ delay: Double, _ end: Double, _ sx: Double, _ sy: Double, _ hex: UInt32?, _ alpha: Double, shaded: Bool = true) -> ScenePuff {
            ScenePuff(x: x, y: y, dx: dx, dy: dy, rotation: rot, duration: dur, delay: delay, endOpacity: end,
                      sx: sx, sy: sy, color: hex.map { Color(sceneHex: $0) }, alpha: alpha, shade: shaded ? shade : nil)
        }
        return [
            puff(195, 672, 0, -8, 3, 7, 0.2, 0.75, 1.9, 1.3, 0xEFE9DC, 0.95),
            puff(150, 684, -24, 0, -5, 7, 0.28, 0.7, 1.4, 1.1, 0xEBE5D8, 0.92),
            puff(240, 684, 24, 0, 5, 7, 0.28, 0.7, 1.4, 1.1, 0xEBE5D8, 0.92),
            puff(195, 642, 0, -22, -4, 6, 0.04, 0.5, 1.3, 1.3, nil, 0.9),
            puff(174, 622, -20, -30, -9, 6, 0.13, 0.45, 1, 1, nil, 0.75),
            puff(216, 622, 20, -30, 9, 6, 0.13, 0.45, 1, 1, nil, 0.75),
            puff(150, 660, -72, 18, -10, 6.2, 0.15, 0.45, 1.15, 1.15, 0xEFE9DC, 0.94),
            puff(108, 666, -112, 30, -16, 6.4, 0.3, 0.4, 1.1, 1.1, 0xE9E3D6, 0.88),
            puff(66, 674, -142, 42, -20, 6.6, 0.46, 0.35, 1, 1, 0xE0DBCF, 0.8),
            puff(26, 686, -160, 50, -24, 6.8, 0.64, 0.3, 0.85, 0.85, 0xD7D2C6, 0.7),
            puff(240, 660, 72, 18, 10, 6.2, 0.18, 0.45, 1.15, 1.15, 0xEFE9DC, 0.94),
            puff(282, 666, 112, 30, 16, 6.4, 0.34, 0.4, 1.1, 1.1, 0xE9E3D6, 0.88),
            puff(324, 674, 142, 42, 20, 6.6, 0.5, 0.35, 1, 1, 0xE0DBCF, 0.8),
            puff(364, 686, 160, 50, 24, 6.8, 0.68, 0.3, 0.85, 0.85, 0xD7D2C6, 0.7),
            puff(150, 692, -64, 10, -6, 1.5, 0.08, 0, 0.55, 0.55, 0xB9A184, 0.5, shaded: false),
            puff(240, 692, 64, 10, 6, 1.5, 0.08, 0, 0.55, 0.55, 0xB9A184, 0.5, shaded: false),
        ]
    }()

    static func drawCloud(_ ground: inout GraphicsContext, t: Double) {
        guard t > 0 else { return }
        var c = ground
        c.addFilter(.blur(radius: 1.1))
        c.drawLayer { layer in
            for puff in puffs { puff.draw(&layer, t: t, track: puffTrack) }
        }
    }
}

// MARK: - Cena do pouso (tela do despertador)

/// Pouso na Lua, tocado quando o despertador dispara (a pessoa aguentou a noite).
/// Mesma regra da decolagem: foguete fixo e centralizado, só o cenário se move.
struct MoonLandingScene: View {
    let streakDays: Int

    @Environment(\.scenePhase) private var scenePhase
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start) - LandingPainter.holdBeforeLanding
            let clock = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                LandingPainter.draw(in: &context, size: size, t: t, clock: clock, days: streakDays)
            }
        }
        .onAppear { start = Date() }
        // Com o alarme do sistema (AlarmKit), esta tela pode ser montada com o app em
        // segundo plano (botão "Parar" na tela bloqueada) — recomeça o pouso quando a
        // pessoa abre o app, em vez de ele já ter acontecido sem ninguém ver.
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                start = Date()
            }
        }
    }
}

enum LandingPainter {
    typealias S = SceneShapes

    /// Tempo com o foguete descendo no céu, motor ligado, antes de a Lua começar a
    /// subir (pedido do usuário depois de testar no device: "mais um segundo antes de
    /// começar o pouso"). Os tempos do protótipo contam a partir do fim dessa espera.
    static let holdBeforeLanding: Double = 1

    static func draw(in ctx: inout GraphicsContext, size: CGSize, t: Double, clock: Double, days: Int) {
        S.applyCamera(&ctx, size: size)
        drawSky(&ctx)

        var world = ctx
        world.translateBy(x: 0, y: -164)
        let moonY = moonOffset(t)

        var moon = world
        moon.translateBy(x: 0, y: moonY)
        drawSurface(&moon)
        drawDust(&moon, t: t)

        // chama do motor de descida — só acima da superfície, desliga após o toque
        let off = SceneCurve.easeIn.value(SceneTime.progress(t, delay: 3.3, duration: 0.6))
        if off < 0.999 {
            var flame = world
            flame.clip(to: aboveMoon.applying(CGAffineTransform(translationX: 0, y: moonY)))
            flame.opacity *= 1 - off
            flame.translateBy(x: 195, y: 672)
            flame.scaleBy(x: 1 - 0.4 * off, y: 1 - 0.85 * off)
            flame.translateBy(x: -195, y: -672)
            RocketArt.drawFlame(&flame, clock: clock)
            var exhaust = flame
            exhaust.opacity *= 1 - SceneTime.progress(t, delay: 2.5, duration: 0.5)
            RocketArt.drawExhaust(&exhaust, clock: clock, count: 3)
        }
        let glowOff = SceneCurve.easeIn.value(SceneTime.progress(t, delay: 3.3, duration: 0.8))
        RocketArt.drawGlow(&world, opacity: 0.75 * (1 - glowOff), scale: 1)

        let door = SceneCurve.easeInOut.value(SceneTime.progress(t, delay: 4.0, duration: 0.5))
        RocketArt.drawRocket(&world, doorOpen: door)

        drawRamp(&world, t: t)
        drawFootprints(&world, t: t)
        drawFlag(&world, t: t, clock: clock, days: days)
        drawAstronaut(&world, t: t)
    }

    /// Lua sobe por baixo desacelerando, com um leve assentamento no toque.
    static func moonOffset(_ t: Double) -> Double {
        let p = SceneTime.progress(t, delay: 0, duration: 3.4)
        if p <= 0.9 {
            return 900 + (-3 - 900) * SceneCurve(x1: 0.12, y1: 0.62, x2: 0.3, y2: 1).value(p / 0.9)
        }
        return -3 + 3 * SceneCurve.easeInOut.value((p - 0.9) / 0.1)
    }

    // MARK: Céu com a Terra (à esquerda)

    static func drawSky(_ c: inout GraphicsContext) {
        c.fill(S.rect(-200, -400, 790, 401), with: .color(Color(sceneHex: 0x0A0E1B)))
        c.fill(S.rect(-200, 0, 790, 844), with: S.vertical([
            .init(color: Color(sceneHex: 0x0A0E1B), location: 0),
            .init(color: Color(sceneHex: 0x131A2E), location: 0.6),
            .init(color: Color(sceneHex: 0x1C233A), location: 1),
        ], 0, 844))
        c.fill(S.rect(-200, 843, 790, 400), with: .color(Color(sceneHex: 0x1C233A)))
        let stars: [(Double, Double, Double, Double)] = [
            (30, 70, 1.6, 0.85), (70, 140, 1.1, 0.5), (130, 50, 1.6, 0.75), (180, 180, 1.1, 0.4),
            (230, 90, 1.8, 0.9), (360, 190, 1.2, 0.6), (55, 250, 1.2, 0.45), (110, 300, 1.6, 0.6),
            (195, 270, 1.2, 0.5), (250, 260, 1.1, 0.4), (300, 310, 1.6, 0.6), (20, 340, 1.1, 0.4),
            (150, 360, 1.6, 0.5), (345, 350, 1.2, 0.5), (90, 400, 1.1, 0.4), (260, 410, 1.4, 0.5),
            (36, 446, 1.3, 0.5), (128, 468, 1.1, 0.4), (232, 452, 1.5, 0.6), (318, 478, 1.1, 0.45),
            (372, 430, 1.4, 0.55), (80, 500, 1.1, 0.35),
        ]
        for star in stars {
            c.fill(S.circle(star.0, star.1, star.2), with: .color(Color.white.opacity(star.3)))
        }

        // a Terra (casa), no canto esquerdo
        let cx = 72.0, cy = 120.0
        c.fill(S.circle(cx, cy, 34), with: S.radial([
            .init(color: Color(sceneHex: 0x7FB0FF, opacity: 0.25), location: 0),
            .init(color: Color(sceneHex: 0x7FB0FF, opacity: 0.25), location: 0.7),
            .init(color: Color(sceneHex: 0x7FB0FF, opacity: 0), location: 1),
        ], center: S.pt(cx, cy), radius: 34))
        let earth = S.circle(cx, cy, 24)
        c.fill(earth, with: S.radial([
            .init(color: Color(sceneHex: 0x5D93D6), location: 0),
            .init(color: Color(sceneHex: 0x2A568F), location: 1),
        ], center: S.pt(cx - 7, cy - 9.6), radius: 36))
        var land = c
        land.clip(to: earth)
        let green = Color(sceneHex: 0x5F9D66)
        var c1 = Path()
        c1.move(to: S.pt(54, 104))
        c1.addCurve(to: S.pt(70, 110), control1: S.pt(62, 98), control2: S.pt(72, 102))
        c1.addCurve(to: S.pt(56, 126), control1: S.pt(68, 118), control2: S.pt(58, 118))
        c1.addCurve(to: S.pt(48, 122), control1: S.pt(54, 132), control2: S.pt(48, 130))
        c1.addCurve(to: S.pt(54, 104), control1: S.pt(48, 114), control2: S.pt(50, 108))
        c1.closeSubpath()
        land.fill(c1, with: .color(green))
        var c2 = Path()
        c2.move(to: S.pt(76, 118))
        c2.addCurve(to: S.pt(92, 126), control1: S.pt(84, 112), control2: S.pt(94, 116))
        c2.addCurve(to: S.pt(74, 136), control1: S.pt(90, 136), control2: S.pt(80, 140))
        c2.addCurve(to: S.pt(76, 118), control1: S.pt(70, 132), control2: S.pt(72, 124))
        c2.closeSubpath()
        land.fill(c2, with: .color(green))
        var c3 = Path()
        c3.move(to: S.pt(66, 136))
        c3.addCurve(to: S.pt(74, 140), control1: S.pt(70, 134), control2: S.pt(76, 136))
        c3.addCurve(to: S.pt(66, 136), control1: S.pt(72, 144), control2: S.pt(66, 143))
        c3.closeSubpath()
        land.fill(c3, with: .color(Color(sceneHex: 0x6AA76F)))
        var cloud1 = Path()
        cloud1.move(to: S.pt(56, 112))
        cloud1.addCurve(to: S.pt(82, 112), control1: S.pt(64, 108), control2: S.pt(74, 108))
        land.stroke(cloud1, with: .color(Color.white.opacity(0.5)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        var cloud2 = Path()
        cloud2.move(to: S.pt(70, 130))
        cloud2.addCurve(to: S.pt(92, 134), control1: S.pt(78, 128), control2: S.pt(86, 130))
        land.stroke(cloud2, with: .color(Color.white.opacity(0.45)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        land.fill(S.circle(84, 128, 24), with: .color(Color(sceneHex: 0x0A0E1B, opacity: 0.5)))
    }

    // MARK: Superfície da Lua

    static let moonHorizon: Path = {
        var p = Path()
        p.move(to: S.pt(-20, 712))
        p.addCurve(to: S.pt(195, 692), control1: S.pt(60, 704), control2: S.pt(130, 694))
        p.addCurve(to: S.pt(410, 712), control1: S.pt(260, 694), control2: S.pt(330, 704))
        return p
    }()

    static let aboveMoon: Path = {
        var p = Path()
        p.move(to: S.pt(-60, -3000))
        p.addLine(to: S.pt(450, -3000))
        p.addLine(to: S.pt(450, 712))
        p.addLine(to: S.pt(410, 712))
        p.addCurve(to: S.pt(195, 692), control1: S.pt(330, 704), control2: S.pt(260, 694))
        p.addCurve(to: S.pt(-20, 712), control1: S.pt(130, 694), control2: S.pt(60, 704))
        p.addLine(to: S.pt(-60, 712))
        p.closeSubpath()
        return p
    }()

    static func drawSurface(_ m: inout GraphicsContext) {
        var ground = moonHorizon
        ground.addLine(to: S.pt(410, 1300))
        ground.addLine(to: S.pt(-20, 1300))
        ground.closeSubpath()
        m.fill(ground, with: S.vertical([
            .init(color: Color(sceneHex: 0xB3B7BD), location: 0),
            .init(color: Color(sceneHex: 0x9A9FA7), location: 0.12),
            .init(color: Color(sceneHex: 0x6F747D), location: 0.5),
            .init(color: Color(sceneHex: 0x4A4E57), location: 1),
        ], 692, 1300))
        m.stroke(moonHorizon, with: .color(Color(sceneHex: 0xE4E7EB, opacity: 0.45)), lineWidth: 1.5)

        var soft = m
        soft.addFilter(.blur(radius: 3))
        let maria: [(Path, UInt32, Double)] = [
            (S.quadBlob(start: (10, 780), [(80, 756, 150, 776), (120, 806, 30, 804)]), 0x5F646D, 0.45),
            (S.quadBlob(start: (230, 800), [(300, 780, 380, 796), (340, 826, 250, 824)]), 0x5F646D, 0.4),
            (S.quadBlob(start: (120, 900), [(200, 876, 280, 896), (240, 930, 140, 926)]), 0x8C9199, 0.4),
            (S.quadBlob(start: (-10, 980), [(70, 956, 150, 978), (110, 1010, 10, 1006)]), 0x555A63, 0.4),
        ]
        for patch in maria {
            soft.fill(patch.0, with: .color(Color(sceneHex: patch.1, opacity: patch.2)))
        }

        // crateras: borda de baixo iluminada, fundo escuro
        struct Crater {
            let x: Double, y: Double, rx: Double, ry: Double, rim: UInt32
            let innerY: Double, innerRX: Double, innerRY: Double, floor: UInt32
            var lit: (x1: Double, y1: Double, cy: Double, x2: Double, hex: UInt32, width: Double, opacity: Double)? = nil
        }
        let craters: [Crater] = [
            Crater(x: 70, y: 730, rx: 26, ry: 7, rim: 0x7B8089, innerY: 732, innerRX: 20, innerRY: 4.6, floor: 0x5C6169,
                   lit: (48, 733, 741, 92, 0xC9CCD1, 1.2, 0.55)),
            Crater(x: 330, y: 742, rx: 18, ry: 5, rim: 0x7B8089, innerY: 743.5, innerRX: 13, innerRY: 3.2, floor: 0x5C6169,
                   lit: (314, 744, 750, 346, 0xC9CCD1, 1, 0.55)),
            Crater(x: 250, y: 830, rx: 34, ry: 10, rim: 0x6C717A, innerY: 833, innerRX: 27, innerRY: 6.5, floor: 0x50555D,
                   lit: (221, 835, 847, 279, 0xB9BCC2, 1.4, 0.5)),
            Crater(x: 90, y: 850, rx: 22, ry: 6.5, rim: 0x6C717A, innerY: 852, innerRX: 16, innerRY: 4, floor: 0x50555D),
            Crater(x: 170, y: 960, rx: 40, ry: 12, rim: 0x62676F, innerY: 963, innerRX: 32, innerRY: 8, floor: 0x474B53,
                   lit: (136, 966, 980, 204, 0xA9ADB3, 1.4, 0.45)),
            Crater(x: 340, y: 930, rx: 20, ry: 6, rim: 0x62676F, innerY: 932, innerRX: 14, innerRY: 3.8, floor: 0x474B53),
            Crater(x: 30, y: 1080, rx: 28, ry: 8, rim: 0x5A5F67, innerY: 1082, innerRX: 21, innerRY: 5, floor: 0x40444C),
            Crater(x: 290, y: 1060, rx: 24, ry: 7, rim: 0x5A5F67, innerY: 1062, innerRX: 18, innerRY: 4.4, floor: 0x40444C),
        ]
        for cr in craters {
            m.fill(S.ellipse(cr.x, cr.y, cr.rx, cr.ry), with: .color(Color(sceneHex: cr.rim)))
            m.fill(S.ellipse(cr.x, cr.innerY, cr.innerRX, cr.innerRY), with: .color(Color(sceneHex: cr.floor)))
            if let lit = cr.lit {
                var edge = Path()
                edge.move(to: S.pt(lit.x1, lit.y1))
                edge.addQuadCurve(to: S.pt(lit.x2, lit.y1), control: S.pt(cr.x, lit.cy))
                m.stroke(edge, with: .color(Color(sceneHex: lit.hex, opacity: lit.opacity)), lineWidth: lit.width)
            }
        }

        for r in [(40.0, 760.0, 3.0), (118, 742, 2.2), (286, 762, 2.6), (372, 772, 3), (210, 880, 2.4), (60, 920, 2.8), (320, 990, 2.4), (130, 1040, 3)] {
            m.fill(S.circle(r.0, r.1, r.2), with: .color(Color(sceneHex: 0x5B6068)))
        }
        for h in [(39.0, 758.5, 1.1), (285, 760.8, 1), (371, 770.5, 1.1)] {
            m.fill(S.circle(h.0, h.1, h.2), with: .color(Color(sceneHex: 0xC3C6CB, opacity: 0.6)))
        }
    }

    // MARK: Poeira lunar

    static let dustTrack = ScenePuff.Track(
        offsets: [0, 0.14, 0.45, 1],
        opacity: [0, 1, 0.9, 0],
        tx: [0, 0.1, 0.5, 1],
        ty: [0, 0.08, 0.45, 1],
        scale: [0.35, 0.85, 1.3, 1.8],
        rotation: [0, 0, 0, 0],
        curve: SceneCurve(x1: 0.22, y1: 0.06, x2: 0.3, y2: 1),
        shadeOffset: CGSize(width: 4, height: 6)
    )

    static let dust: [ScenePuff] = {
        let shade = Color(sceneHex: 0x8E939B)
        func puff(_ x: Double, _ y: Double, _ dx: Double, _ dy: Double, _ dur: Double, _ delay: Double, _ sx: Double, _ sy: Double, _ hex: UInt32, shaded: Bool) -> ScenePuff {
            ScenePuff(x: x, y: y, dx: dx, dy: dy, rotation: 0, duration: dur, delay: delay, endOpacity: 0,
                      sx: sx, sy: sy, color: Color(sceneHex: hex), alpha: 1, shade: shaded ? shade : nil)
        }
        return [
            puff(195, 688, 0, -12, 2.4, 2.2, 1.1, 0.8, 0xB7BBC1, shaded: true),
            puff(160, 693, -95, 8, 2.6, 2.25, 0.85, 0.65, 0xB3B7BD, shaded: true),
            puff(230, 693, 95, 8, 2.6, 2.25, 0.85, 0.65, 0xB3B7BD, shaded: true),
            puff(130, 698, -140, 12, 2.8, 2.4, 0.7, 0.55, 0xADB1B7, shaded: true),
            puff(260, 698, 140, 12, 2.8, 2.4, 0.7, 0.55, 0xADB1B7, shaded: true),
            puff(100, 704, -160, 16, 3, 2.55, 0.55, 0.45, 0xA7ABB1, shaded: false),
            puff(290, 704, 160, 16, 3, 2.55, 0.55, 0.45, 0xA7ABB1, shaded: false),
            // poeirinha da bandeira sendo cravada
            puff(310, 702, -14, -2, 1, 7.62, 0.22, 0.16, 0xB3B7BD, shaded: false),
            puff(311, 702, 14, -2, 1, 7.62, 0.22, 0.16, 0xB3B7BD, shaded: false),
        ]
    }()

    static func drawDust(_ m: inout GraphicsContext, t: Double) {
        var c = m
        c.addFilter(.blur(radius: 1.1))
        c.drawLayer { layer in
            for puff in dust { puff.draw(&layer, t: t, track: dustTrack) }
        }
    }

    // MARK: Rampa, pegadas, bandeira, astronauta

    static func drawRamp(_ w: inout GraphicsContext, t: Double) {
        let e = SceneCurve(x1: 0.3, y1: 0.7, x2: 0.4, y2: 1).value(SceneTime.progress(t, delay: 4.3, duration: 0.6))
        guard e > 0.001 else { return }
        var c = w
        c.translateBy(x: 207, y: 626)
        c.scaleBy(x: e, y: e)
        c.translateBy(x: -207, y: -626)
        c.fill(S.polygon([(207, 626), (214, 626), (252, 695), (244, 695)]), with: .color(Color(sceneHex: 0x9CA2AA)))
        var rungs = Path()
        rungs.addPath(S.line(215, 642, 222, 642))
        rungs.addPath(S.line(224, 658, 231, 658))
        rungs.addPath(S.line(233, 674, 240, 674))
        c.stroke(rungs, with: .color(Color(sceneHex: 0x6F757E)), lineWidth: 1.2)
    }

    static func drawFootprints(_ w: inout GraphicsContext, t: Double) {
        let prints: [(Double, Double, Double)] = [(258, 696, 6.4), (268, 697.5, 6.65), (278, 698, 6.9), (287, 699, 7.15)]
        for fp in prints {
            let o = 0.55 * SceneCurve.easeOut.value(SceneTime.progress(t, delay: fp.2, duration: 0.3))
            guard o > 0.001 else { continue }
            w.fill(S.ellipse(fp.0, fp.1, 2.6, 1.2), with: .color(Color(sceneHex: 0x62676F, opacity: o)))
        }
    }

    static func drawFlag(_ w: inout GraphicsContext, t: Double, clock: Double, days: Int) {
        let plantCurve = SceneCurve(x1: 0.5, y1: 0, x2: 0.9, y2: 0.6)
        let p = SceneTime.progress(t, delay: 7.35, duration: 0.35)
        let opacity = SceneTime.sample([0, 0.25, 1], [0, 1, 1], p, plantCurve)
        guard opacity > 0.001 else { return }
        var flag = w
        flag.opacity *= opacity
        flag.translateBy(x: 0, y: -18 * (1 - plantCurve.value(p)))
        flag.fill(S.rrect(308.5, 628, 3, 75, 1.2), with: .color(Color(sceneHex: 0xD3D7DD)))
        flag.fill(S.circle(310, 628, 2.4), with: .color(Color(sceneHex: 0xE9ECEF)))

        let unfurl = SceneCurve(x1: 0.3, y1: 0.8, x2: 0.4, y2: 1).value(SceneTime.progress(t, delay: 7.8, duration: 0.5))
        guard unfurl > 0.001 else { return }
        var skew = 0.0
        if t >= 8.3 {
            let ph = SceneTime.loop(t - 8.3, period: 3.2)
            let tri = ph < 0.5 ? ph * 2 : 2 - ph * 2
            skew = -4 * SceneCurve.easeInOut.value(tri)
        }
        var cloth = flag
        cloth.translateBy(x: 311, y: 651)
        cloth.scaleBy(x: unfurl, y: 1)
        cloth.concatenate(CGAffineTransform(a: 1, b: CGFloat(tan(skew * .pi / 180)), c: 0, d: 1, tx: 0, ty: 0))
        cloth.translateBy(x: -311, y: -651)
        let rect = S.rrect(311, 631, 60, 40, 2)
        cloth.fill(rect, with: SceneShapes.diagonal(RocketArt.red0, RocketArt.red1, in: rect.boundingRect))
        cloth.draw(
            Text("\(days)").font(.system(size: 22, weight: .bold)).foregroundColor(.white),
            at: S.pt(341, 649),
            anchor: .center
        )
        cloth.draw(
            Text("DIAS").font(.system(size: 7, weight: .semibold)).tracking(1).foregroundColor(Color(sceneHex: 0xFFE6DD)),
            at: S.pt(341, 664),
            anchor: .center
        )
    }

    static func drawAstronaut(_ w: inout GraphicsContext, t: Double) {
        let appear = SceneCurve.easeOut.value(SceneTime.progress(t, delay: 4.4, duration: 0.4))
        guard appear > 0.001 else { return }

        // trajeto: porta → topo da rampa → chão → perto da bandeira
        let pathP = SceneTime.progress(t, delay: 4.4, duration: 3)
        let offsets = [0, 0.13, 0.27, 0.6, 0.93, 1]
        let x = SceneTime.sample(offsets, [195, 195, 213, 248, 292, 292], pathP, .linear)
        let y = SceneTime.sample(offsets, [626, 626, 627, 695, 699, 699], pathP, .linear)

        // quique da gravidade baixa + pernas alternando, enquanto caminha
        let walking = t >= 4.8 && t < 7.3
        let stepPhase = walking ? SceneTime.loop(t - 4.8, period: 0.5) : 0
        let bob = walking ? SceneTime.sample([0, 0.5, 1], [0, -4, 0], stepPhase, .easeInOut) : 0
        let leg = walking ? SceneTime.sample([0, 0.25, 0.75, 1], [0, 18, -18, 0], stepPhase, .easeInOut) : 0

        // braço: crava a bandeira, depois acena
        var arm = SceneTime.sample([0, 0.4, 0.75, 1], [0, -125, -55, -25], SceneTime.progress(t, delay: 7.25, duration: 0.6), .easeInOut)
        if t >= 8.6 && t < 8.6 + 0.45 * 4 {
            let k = Int((t - 8.6) / 0.45)
            var local = (t - 8.6) / 0.45 - Double(k)
            if k % 2 == 1 { local = 1 - local }
            arm = -150 + 45 * SceneCurve.easeInOut.value(local)
        }

        var c = w
        c.translateBy(x: x, y: y)
        c.opacity *= appear
        let s = 0.7 + 0.3 * appear
        c.scaleBy(x: s, y: s)
        c.translateBy(x: 0, y: bob)

        func fill(_ ctx: inout GraphicsContext, _ path: Path, _ hex: UInt32) {
            ctx.fill(path, with: .color(Color(sceneHex: hex)))
        }

        fill(&c, S.rrect(-10, -25, 6, 13, 2), 0xC3C7CE)
        var legB = c
        legB.translateBy(x: -2.75, y: -10)
        legB.rotate(by: .degrees(-leg))
        legB.translateBy(x: 2.75, y: 10)
        fill(&legB, S.rrect(-5, -10, 4.5, 10, 2), 0xE3E6EA)
        fill(&legB, S.rrect(-5.5, -2.5, 5.5, 2.8, 1), 0x7C828C)
        var legA = c
        legA.translateBy(x: 2.75, y: -10)
        legA.rotate(by: .degrees(leg))
        legA.translateBy(x: -2.75, y: 10)
        fill(&legA, S.rrect(0.5, -10, 4.5, 10, 2), 0xF2F3F5)
        fill(&legA, S.rrect(0, -2.5, 5.5, 2.8, 1), 0x7C828C)
        fill(&c, S.rrect(-10, -20, 4, 10, 2), 0xE3E6EA)
        fill(&c, S.rrect(-7, -22, 14, 13, 4), 0xF2F3F5)
        fill(&c, S.rrect(-3, -18, 6, 3.6, 1), 0xD9573E)
        fill(&c, S.circle(0, -27, 7.5), 0xF2F3F5)
        fill(&c, S.ellipse(1.8, -27, 5, 4), 0x2A4058)
        fill(&c, S.ellipse(3.4, -28.4, 1.6, 1), 0x8FB0D0)
        var armR = c
        armR.translateBy(x: 7.5, y: -19)
        armR.rotate(by: .degrees(arm))
        armR.translateBy(x: -7.5, y: 19)
        fill(&armR, S.rrect(5.5, -20, 4, 10, 2), 0xF2F3F5)
    }
}
