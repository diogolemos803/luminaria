import SwiftUI

// Canteiro de obras noturno (protótipo aprovado em design/meteoro_prototipo.html): depois
// que o meteoro destrói o foguete, a Terra volta sem ele e quatro bonequinhos reconstroem
// o foguete em loop até o fim da noite — um martela, um solda, um carrega painéis e um
// orienta o guindaste. Desenhado no mesmo espaço de coordenadas do chão da decolagem
// (plataforma em y ~688), por cima de `LaunchPainter.drawTerrain`/`drawLaunchBase`
// (sem a torre). Tudo é função do relógio (`clock`), sem estado.

enum ConstructionSiteArt {
    typealias S = SceneShapes

    private static let hat = Color(sceneHex: 0xF4C02E)
    private static let vest = Color(sceneHex: 0xF08A2C)
    private static let skin = Color(sceneHex: 0xF0C39B)
    private static let pants = Color(sceneHex: 0x2F3D5C)
    private static let steel = Color(sceneHex: 0x8D939C)
    private static let craneYellow = Color(sceneHex: 0xD2A53A)
    private static let ink = Color(sceneHex: 0x1F2228)

    /// Pseudo-aleatório fixo por índice (o mesmo `rnd` do protótipo).
    static func rnd(_ i: Int) -> Double {
        let x = sin(Double(i) * 127.1 + 311.7) * 43758.5453
        return x - floor(x)
    }

    private static func easeOut3(_ p: Double) -> Double { 1 - pow(1 - p, 3) }
    private static func easeIn3(_ p: Double) -> Double { p * p * p }
    private static func easeInOut3(_ p: Double) -> Double {
        p < 0.5 ? 4 * p * p * p : 1 - pow(-2 * p + 2, 3) / 2
    }

    static func draw(_ c: inout GraphicsContext, clock: Double) {
        drawScaffold(&c)
        drawRocketInProgress(&c)
        drawCrane(&c, clock: clock)

        // pilha de peças + caixa de ferramentas
        c.fill(S.rect(256, 676, 18, 4), with: .color(Color(sceneHex: 0xE6E0D4)))
        c.fill(S.rect(258, 672, 16, 4), with: .color(Color(sceneHex: 0xE6E0D4)))
        c.fill(S.rect(259, 668, 13, 4), with: .color(Color(sceneHex: 0xCFC8BA)))
        var finPiece = Path()
        finPiece.move(to: S.pt(274, 686))
        finPiece.addCurve(to: S.pt(286, 669), control1: S.pt(276, 677), control2: S.pt(281, 671))
        finPiece.addLine(to: S.pt(285, 686))
        finPiece.closeSubpath()
        c.fill(finPiece, with: S.diagonal(RocketArt.red0, RocketArt.red1, in: finPiece.boundingRect))
        c.fill(S.rect(120, 681, 12, 7), with: .color(Color(sceneHex: 0xC4422A)))
        c.fill(S.rect(123, 679, 6, 2), with: .color(Color(sceneHex: 0x8F2F1F)))
        for x in [110.0, 138, 252] { drawCone(&c, x: x, y: 688) }
        drawTape(&c, from: 96, to: 136, y: 679)
        drawSign(&c, x: 86, y: 688)

        drawHammerer(&c, clock: clock)
        drawWelder(&c, clock: clock)
        drawCarrier(&c, clock: clock)
        // orienta o guindaste acenando com os dois braços
        let wave = sin(clock * 2.4)
        drawWorker(&c, x: 294, y: 688, facing: -1, pose: Pose(armA: -2.6 + wave * 0.35, armB: -2.5 - wave * 0.35))
    }

    // MARK: Obra

    /// Andaime dos dois lados do foguete, com tábuas, travas em X e holofotes no topo.
    private static func drawScaffold(_ c: inout GraphicsContext) {
        var poles = Path()
        for x in [146.0, 170, 220, 244] { poles.addPath(S.line(x, 688, x, 572)) }
        c.stroke(poles, with: .color(steel), lineWidth: 2)
        var braces = Path()
        for (a, b) in [(146.0, 170.0), (220, 244)] {
            var y = 688.0
            while y > 580 {
                braces.addPath(S.line(a, y, b, y - 28))
                braces.addPath(S.line(b, y, a, y - 28))
                y -= 28
            }
        }
        c.stroke(braces, with: .color(steel.opacity(0.8)), lineWidth: 1.1)
        for y in [632.0, 600] {
            c.fill(S.rect(143, y, 30, 3), with: .color(Color(sceneHex: 0x9B7A4F)))
            c.fill(S.rect(217, y, 30, 3), with: .color(Color(sceneHex: 0x9B7A4F)))
        }
        for (x, dir) in [(146.0, 1.0), (244, -1)] {
            var beam = c
            beam.blendMode = .plusLighter
            beam.fill(S.polygon([(x, 570), (x + dir * 70, 610), (x + dir * 40, 690)]), with: S.radial([
                .init(color: Color(sceneHex: 0xFFECAA, opacity: 0.34), location: 0),
                .init(color: Color(sceneHex: 0xFFECAA, opacity: 0), location: 1),
            ], center: S.pt(x, 570), radius: 90))
            c.fill(S.rect(x - 4, 566, 8, 5), with: .color(Color(sceneHex: 0x3B4049)))
            c.fill(S.rect(x - 3, 570, 6, 1.6), with: .color(Color(sceneHex: 0xFFF2C4)))
        }
    }

    /// Foguete pela metade: a parte de baixo pronta, a de cima só o contorno tracejado e
    /// as costelas da estrutura.
    private static func drawRocketInProgress(_ c: inout GraphicsContext) {
        var r = c
        RocketArt.applyScale(&r)
        r.fill(RocketArt.leftFin, with: S.diagonal(RocketArt.red0, RocketArt.red1, in: RocketArt.leftFin.boundingRect))
        r.fill(RocketArt.rightFin, with: S.diagonal(RocketArt.red0, RocketArt.red1, in: RocketArt.rightFin.boundingRect))
        var lower = r
        lower.clip(to: RocketArt.hull)
        lower.clip(to: S.rect(100, 600, 200, 100))
        RocketArt.drawRocket(&lower, doorOpen: 0)
        r.fill(S.polygon([(182, 664), (208, 664), (204, 675), (186, 675)]), with: .color(Color(sceneHex: 0x4D525B)))
        r.stroke(RocketArt.hull, with: .color(Color(sceneHex: 0xF3EEE4, opacity: 0.55)), style: StrokeStyle(lineWidth: 2.2, dash: [6, 5]))
        var ribs = Path()
        for y in [520.0, 550, 580] { ribs.addPath(S.line(166, y, 224, y)) }
        ribs.addPath(S.line(195, 486, 195, 600))
        r.stroke(ribs, with: .color(Color(sceneHex: 0xA0A8B4, opacity: 0.7)), lineWidth: 2)
    }

    /// Guindaste à direita, subindo e descendo o bico do foguete devagar (6s por ciclo).
    private static func drawCrane(_ c: inout GraphicsContext, clock: Double) {
        let mastX = 308.0
        var frame = Path()
        frame.addPath(S.line(mastX - 4, 688, mastX - 4, 470))
        frame.addPath(S.line(mastX + 4, 688, mastX + 4, 470))
        frame.addPath(S.line(mastX + 20, 470, 182, 470))
        frame.addPath(S.line(mastX + 20, 476, 190, 476))
        c.stroke(frame, with: .color(craneYellow), lineWidth: 2)
        var lattice = Path()
        var y = 688.0
        while y > 478 {
            lattice.addPath(S.line(mastX - 4, y, mastX + 4, y - 12))
            lattice.addPath(S.line(mastX + 4, y, mastX - 4, y - 12))
            y -= 12
        }
        var x = 190.0
        while x < mastX + 20 {
            lattice.move(to: S.pt(x, 476))
            lattice.addLine(to: S.pt(x + 5, 470))
            lattice.addLine(to: S.pt(x + 10, 476))
            x += 10
        }
        c.stroke(lattice, with: .color(craneYellow), lineWidth: 1)
        c.fill(S.rect(mastX + 8, 476, 12, 10), with: .color(Color(sceneHex: 0x5A606B)))   // contrapeso
        c.fill(S.rect(mastX - 7, 478, 14, 10), with: .color(Color(sceneHex: 0x3B4049)))   // cabine
        c.fill(S.rect(mastX - 5, 480, 10, 4), with: .color(Color(sceneHex: 0xE8B865, opacity: 0.9)))
        let blinkOn = SceneTime.loop(clock, period: 1.2) < 0.42
        c.fill(S.circle(mastX, 466, 2.2), with: .color(Color(sceneHex: 0xFF4A3A, opacity: blinkOn ? 1 : 0.18)))

        let cycle = SceneTime.loop(clock, period: 6)
        let lower = easeInOut3(cycle < 0.5 ? cycle * 2 : 2 - cycle * 2)
        let hookY = 500 + 42 * lower
        let sway = sin(clock * 1.3) * 2.4
        c.fill(S.rect(191, 476, 8, 4), with: .color(Color(sceneHex: 0x3B4049)))
        let cable = Color(sceneHex: 0xC9CCD1)
        c.stroke(S.line(195, 480, 195 + sway, hookY), with: .color(cable), lineWidth: 0.8)

        var hook = c
        hook.translateBy(x: 195 + sway, y: hookY)
        hook.rotate(by: .radians(sway * 0.02))
        var slings = Path()
        slings.addPath(S.line(0, 0, -7, 6))
        slings.addPath(S.line(0, 0, 7, 6))
        hook.stroke(slings, with: .color(cable), lineWidth: 0.8)
        hook.scaleBy(x: RocketArt.scale, y: RocketArt.scale)
        hook.translateBy(x: -195, y: -512)
        var nose = Path()
        nose.move(to: S.pt(167, 512))
        nose.addCurve(to: S.pt(195, 481), control1: S.pt(172, 494), control2: S.pt(183, 485))
        nose.addCurve(to: S.pt(223, 512), control1: S.pt(207, 485), control2: S.pt(218, 494))
        nose.addQuadCurve(to: S.pt(167, 512), control: S.pt(195, 524))
        nose.closeSubpath()
        hook.fill(nose, with: S.diagonal(RocketArt.red0, RocketArt.red1, in: nose.boundingRect))
    }

    private static func drawCone(_ c: inout GraphicsContext, x: Double, y: Double) {
        c.fill(S.polygon([(x - 4, y), (x, y - 11), (x + 4, y)]), with: .color(vest))
        c.fill(S.rect(x - 2.4, y - 6.5, 4.8, 1.8), with: .color(Color(sceneHex: 0xF3EEE4)))
        c.fill(S.rect(x - 5.5, y - 0.8, 11, 1.6), with: .color(Color(sceneHex: 0x3B4049)))
    }

    /// Fita zebrada entre duas estacas.
    private static func drawTape(_ c: inout GraphicsContext, from x0: Double, to x1: Double, y: Double) {
        let post = Color(sceneHex: 0x6B6F78)
        c.fill(S.rect(x0 - 1, y - 2, 2, 12), with: .color(post))
        c.fill(S.rect(x1 - 1, y - 2, 2, 12), with: .color(post))
        var tape = c
        tape.clip(to: S.rect(x0, y, x1 - x0, 3.2))
        tape.fill(S.rect(x0, y, x1 - x0, 3.2), with: .color(hat))
        var x = x0 - 6
        while x < x1 + 6 {
            tape.fill(S.polygon([(x, y + 3.2), (x + 3, y), (x + 6, y), (x + 3, y + 3.2)]), with: .color(ink))
            x += 6
        }
    }

    private static func drawSign(_ c: inout GraphicsContext, x: Double, y: Double) {
        c.fill(S.rect(x - 0.8, y - 18, 1.6, 18), with: .color(Color(sceneHex: 0x6B6F78)))
        let board = S.rrect(x - 13, y - 30, 26, 13, 2)
        c.fill(board, with: .color(hat))
        c.stroke(board, with: .color(ink), lineWidth: 1)
        c.draw(
            Text("EM OBRAS").font(.system(size: 5.4, weight: .bold)).foregroundColor(ink),
            at: S.pt(x, y - 23.5),
            anchor: .center
        )
    }

    // MARK: Bonequinhos

    struct Pose {
        var armA: Double = -0.2
        var armB: Double = 0.2
        var legA: Double = 0
        var legB: Double = 0
    }

    /// Bonequinho de capacete e colete, pés em (x, y), ~24 de altura. Devolve a posição da
    /// mão da frente, pra desenhar a ferramenta/carga nela.
    @discardableResult
    static func drawWorker(_ c: inout GraphicsContext, x: Double, y: Double, facing: Double, pose: Pose) -> CGPoint {
        var w = c
        w.translateBy(x: x, y: y)
        w.scaleBy(x: facing, y: 1)
        func limb(_ x0: Double, _ y0: Double, _ length: Double, _ angle: Double, _ color: Color) {
            var l = w
            l.translateBy(x: x0, y: y0)
            l.rotate(by: .radians(angle))
            l.stroke(S.line(0, 0, 0, length), with: .color(color), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        }
        limb(-1.8, -9, 8.5, pose.legB, pants)
        limb(1.8, -9, 8.5, pose.legA, pants)
        let boot = Color(sceneHex: 0x3A2F28)
        w.fill(S.rect(-4.3 - sin(pose.legB) * 6, -1.4, 4, 2), with: .color(boot))
        w.fill(S.rect(-sin(pose.legA) * 6, -1.4, 4, 2), with: .color(boot))
        limb(-3.2, -16.5, 7, pose.armB, vest)
        w.fill(S.rrect(-4.5, -18, 9, 10, 2.5), with: .color(vest))
        w.fill(S.rect(-4.5, -13.2, 9, 1.4), with: .color(Color(sceneHex: 0xF3EEE4, opacity: 0.9)))   // faixa refletiva
        w.fill(S.circle(0, -21.5, 3.6), with: .color(skin))
        w.fill(S.rect(1.2, -22.3, 1, 1.2), with: .color(Color(sceneHex: 0x2A2320)))
        var helmet = Path()
        helmet.addArc(center: S.pt(0, -22.6), radius: 4.1, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        helmet.closeSubpath()
        w.fill(helmet, with: .color(hat))
        w.fill(S.rect(-4.1, -23, 9.6, 1.3), with: .color(hat))
        limb(3.2, -16.5, 7, pose.armA, vest)
        let hx = 3.2 - sin(pose.armA) * 7
        let hy = -16.5 + cos(pose.armA) * 7
        w.fill(S.circle(hx, hy, 1.4), with: .color(skin))
        return CGPoint(x: x + facing * hx, y: y + hy)
    }

    /// No andaime da esquerda, martelando o casco (com faisquinhas a cada batida).
    private static func drawHammerer(_ c: inout GraphicsContext, clock: Double) {
        let hit = SceneTime.loop(clock * 2.2, period: 1)
        let swing = hit < 0.35 ? easeIn3(hit / 0.35) : 1 - easeOut3((hit - 0.35) / 0.65)
        let hammer = -2.3 + 1.5 * swing
        let hand = drawWorker(&c, x: 160, y: 632, facing: 1, pose: Pose(armA: hammer, armB: 0.5))
        var tool = c
        tool.translateBy(x: hand.x, y: hand.y)
        tool.rotate(by: .radians(hammer + .pi))
        tool.fill(S.rect(-0.8, -1, 1.6, 7), with: .color(Color(sceneHex: 0x6B4A2E)))
        tool.fill(S.rect(-2.5, 5, 5, 2.4), with: .color(Color(sceneHex: 0x9AA0AB)))
        if hit > 0.33 && hit < 0.45 {
            var spark = c
            spark.blendMode = .plusLighter
            for i in 0..<4 {
                spark.fill(S.rect(172 + Double(i) * 1.6, 614 - Double(i) * 2, 1.2, 1.2), with: .color(Color(sceneHex: 0xFFE6A0, opacity: 0.9)))
            }
        }
    }

    /// No andaime da direita, soldando: clarão azulado piscando e faíscas caindo.
    private static func drawWelder(_ c: inout GraphicsContext, clock: Double) {
        let hand = drawWorker(&c, x: 232, y: 600, facing: -1, pose: Pose(armA: -1.1 + sin(clock * 3) * 0.06, armB: 0.6))
        c.fill(S.rect(hand.x - 3, hand.y - 1, 4, 2), with: .color(Color(sceneHex: 0x4D525B)))
        let tip = CGPoint(x: hand.x - 4, y: hand.y)
        var glow = c
        glow.blendMode = .plusLighter
        let flicker = 0.6 + 0.4 * abs(sin(clock * 37))
        glow.fill(S.circle(tip.x, tip.y, 14), with: S.radial([
            .init(color: Color(sceneHex: 0xAAD2FF, opacity: 0.7 * flicker), location: 0),
            .init(color: Color(sceneHex: 0xAAD2FF, opacity: 0), location: 1),
        ], center: tip, radius: 14))
        for i in 0..<9 {
            let life = SceneTime.loop(clock * 1.6 + rnd(i), period: 1)
            let angle = -.pi * (0.2 + rnd(i + 9) * 0.6)
            let speed = 12 + rnd(i + 3) * 14
            let sx = tip.x + cos(angle) * speed * life
            let sy = tip.y + sin(angle) * speed * life + 30 * life * life
            glow.fill(S.rect(sx, sy, 1.3, 1.3), with: .color(Color(.sRGB, red: 1, green: (200 - 80 * life) / 255, blue: 90.0 / 255, opacity: 1 - life)))
        }
    }

    /// Leva painéis da pilha até o andaime (ida com carga, volta vazio), 5s por viagem.
    private static func drawCarrier(_ c: inout GraphicsContext, clock: Double) {
        let cycle = SceneTime.loop(clock, period: 5)
        let going = cycle < 0.5
        let p = easeInOut3(going ? cycle * 2 : (cycle - 0.5) * 2)
        let x = going ? 262 - 32 * p : 230 + 32 * p
        let step = sin(clock * 9) * 0.45
        let pose = Pose(
            armA: going ? -1.35 : -0.2 + step * 0.3,
            armB: going ? -1.2 : 0.2 - step * 0.3,
            legA: step,
            legB: -step
        )
        let hand = drawWorker(&c, x: x, y: 688, facing: going ? -1 : 1, pose: pose)
        if going {
            let panel = S.rect(x - 9, hand.y - 6, 18, 5)
            c.fill(panel, with: .color(Color(sceneHex: 0xECE6DA)))
            c.stroke(panel, with: .color(Color(sceneHex: 0xB9B2A4)), lineWidth: 0.6)
        }
    }
}
