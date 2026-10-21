import SwiftUI

// Canteiro de obras noturno do foguete destruído, no traço da marca (protótipo aprovado
// em design/foguete_traco_prototipo.html): a Terra verde volta com a base de lançamento
// sem a torre, o foguete pela metade (de baixo pronto, de cima tracejado), andaime com
// holofotes, guindaste subindo e descendo o bico, cones, fita zebrada, placa "em obras" e
// os quatro bonequinhos do protótipo antigo (colete, calça, botas e capacete, agora com
// contorno creme) — um martela, um solda, um carrega painéis e um orienta o guindaste.
// Tudo função do relógio (`clock`), sem estado.

enum ConstructionSiteArt {
    typealias A = LineArt

    private static let vest = Color(sceneHex: 0xFF9F66)
    private static let pants = Color(sceneHex: 0x3A4256)
    private static let skin = Color(sceneHex: 0xF0C9A0)
    private static let boots = Color(sceneHex: 0x2A2C33)
    private static let workerScale = 1.45

    /// `mesaY` = topo da mesa de lançamento (o chão do deck fica 20 abaixo).
    static func draw(_ ctx: GraphicsContext, mesaY M: Double, clock t: Double) {
        let G = M + 20
        LaunchBaseArt.earth(ctx, mesaY: M)
        LaunchBaseArt.base(ctx, mesaY: M, clock: t, tower: false, post: false)
        let rc = M - 58
        let cx = 195.0
        let L = cx - 50, R = cx + 50, top = rc - 64

        // andaime atrás do foguete: postes e travas em X
        var posts = Path()
        for x in [L - 14, L, R, R + 14] { posts.move(to: A.pt(x, G - 2)); posts.addLine(to: A.pt(x, top)) }
        A.stroke(ctx, posts, A.cream(0.8), 1.5)
        var braces = Path()
        for (a, b) in [(L - 14, L), (R, R + 14)] {
            var y = G - 2
            while y > top + 20 {
                braces.move(to: A.pt(a, y)); braces.addLine(to: A.pt(b, y - 28))
                braces.move(to: A.pt(b, y)); braces.addLine(to: A.pt(a, y - 28))
                y -= 28
            }
        }
        A.stroke(ctx, braces, A.cream(0.3), 1.1)

        // foguete: metade de baixo pronta, de cima tracejada com as costelas
        var lower = ctx
        lower.clip(to: Path(CGRect(x: -400, y: rc + 8, width: 1190, height: 1600)))
        RocketLine.draw(lower, at: A.pt(cx, rc), glow: 0)
        var upper = ctx
        upper.translateBy(x: cx, y: rc)
        upper.clip(to: Path(CGRect(x: -60, y: -90, width: 120, height: 98)))
        A.stroke(upper, RocketLine.body, A.cream(0.5), 1.6, dash: [4, 6])
        A.stroke(upper, A.lines([(-21, -28, 21, -28), (-21, -10, 21, -10), (0, -36, 0, 8)]), A.cream(0.3), 1.2)

        // tábuas dos dois lados
        let p1 = G - 52, p2 = G - 96
        for y in [p1, p2] {
            for (a, b) in [(L - 20, L + 6), (R - 6, R + 20)] {
                A.fillStroke(ctx, A.rrect(a, y, b - a, 3.4, 1), fill: Color(sceneHex: 0x5A4A3A), line: A.cream(0.85), width: 1)
            }
        }
        // holofotes no topo, apontados pro foguete
        for (hx, dir) in [(L - 7, 1.0), (R + 7, -1.0)] {
            var beam = Path()
            beam.move(to: A.pt(hx, top))
            beam.addLine(to: A.pt(hx + dir * 90, top + 40))
            beam.addLine(to: A.pt(hx + dir * 50, G))
            beam.closeSubpath()
            ctx.fill(beam, with: .radialGradient(Gradient(colors: [A.amber.opacity(0.22), A.amber.opacity(0)]), center: A.pt(hx, top), startRadius: 0, endRadius: 110))
            A.fillStroke(ctx, A.rrect(hx - 5, top - 5, 10, 6, 1.5), line: A.cream(0.85), width: 1.1)
            A.glow(ctx, A.circle(hx, top - 1, 1.6), A.amber, blur: 8)
        }

        drawCrane(ctx, rc: rc, G: G, t: t)

        // pilha de peças, caixa de ferramentas, cones, fita e placa
        for (x, y, w) in [(262.0, G - 6, 22.0), (264, G - 11, 19), (267, G - 16, 14)] {
            A.fillStroke(ctx, A.rrect(x, y, w, 5, 1), line: A.cream(0.85), width: 1)
        }
        A.fillStroke(ctx, A.rrect(108, G - 9, 15, 8, 1.5), fill: A.terra, line: A.cream(0.9), width: 1)
        for x in [100.0, 146, 250] { cone(ctx, x: x, y: G) }
        tape(ctx, from: 86, to: 142, y: G - 12)
        A.stroke(ctx, A.line(56, G, 56, G - 22), A.cream(0.7), 1.3)
        ctx.fill(A.rrect(24, G - 42, 64, 20, 10), with: .color(A.amber))
        A.text(ctx, "em obras", at: A.pt(56, G - 32), size: 11, color: A.ink)

        // 1) martelando na plataforma da esquerda
        let hit = (t * 2.2).truncatingRemainder(dividingBy: 1)
        let swing = hit < 0.35 ? A.eIn(hit / 0.35) : 1 - A.eOut((hit - 0.35) / 0.65)
        let hammer = -2.3 + 1.5 * swing
        _ = worker(ctx, x: L - 7, y: p2, facing: 1, armA: hammer, armB: 0.5) { g in
            var h = g
            h.translateBy(x: 3.2, y: -16.5)
            h.rotate(by: .radians(hammer))
            h.translateBy(x: 0, y: 7)
            h.rotate(by: .radians(.pi))
            A.stroke(h, A.line(0, -1, 0, 7), A.cream(0.9), 1.3)
            A.fillStroke(h, A.rrect(-2.8, 5.4, 5.6, 2.6, 0.6), fill: boots, line: A.cream(0.9), width: 0.7)
        }
        if hit > 0.33 && hit < 0.45 {
            for i in 0..<4 { A.glow(ctx, A.circle(L + 8 + Double(i) * 2, p2 - 22 - Double(i) * 3, 1), A.amber, blur: 4) }
        }

        // 2) soldando na plataforma da direita, com faíscas
        let hand = worker(ctx, x: R + 9, y: p1, facing: -1, armA: -1.1 + sin(t * 3) * 0.06, armB: 0.6)
        let tipX = hand.x - 6, tipY = hand.y
        let flick = 0.6 + 0.4 * abs(sin(t * 37))
        ctx.fill(A.circle(tipX, tipY, 16), with: .radialGradient(Gradient(colors: [A.luar.opacity(0.75 * flick), A.luar.opacity(0)]), center: A.pt(tipX, tipY), startRadius: 0, endRadius: 16))
        A.stroke(ctx, A.line(hand.x, hand.y, tipX, tipY), A.cream(0.9), 1.4)
        for k in 0..<9 {
            let life = (t * 1.6 + Double(k) * 0.137).truncatingRemainder(dividingBy: 1)
            let ang = -Double.pi * (0.2 + Double((k * 37) % 10) / 16)
            let sp = 12 + Double(k % 4) * 5
            let sx = tipX + cos(ang) * sp * life
            let sy = tipY + sin(ang) * sp * life + 30 * life * life
            ctx.fill(Path(CGRect(x: sx, y: sy, width: 1.4, height: 1.4)), with: .color(A.amber.opacity(1 - life)))
        }

        // 3) carregando painel entre a pilha e o andaime (ida com carga, volta vazio)
        let cycle = (t / 5).truncatingRemainder(dividingBy: 1)
        let going = cycle < 0.5
        let p3 = A.eInOut(going ? cycle * 2 : (cycle - 0.5) * 2)
        let x3 = going ? 258 - 26 * p3 : 232 + 26 * p3
        let step = sin(t * 9) * 0.45
        let hand3 = worker(ctx, x: x3, y: G, facing: going ? -1 : 1, armA: going ? -1.35 : -0.2 + step * 0.3,
                           armB: going ? -1.2 : 0.2 - step * 0.3, legA: step, legB: -step)
        if going { A.fillStroke(ctx, A.rrect(x3 - 12, hand3.y - 8, 24, 6, 1), line: A.cream(0.9), width: 1) }

        // 4) orientando o guindaste (acenando com os dois braços)
        let wave = sin(t * 2.4)
        _ = worker(ctx, x: 318, y: G, facing: -1, armA: -2.6 + wave * 0.35, armB: -2.5 - wave * 0.35)
    }

    private static func drawCrane(_ ctx: GraphicsContext, rc: Double, G: Double, t: Double) {
        let mx = 356.0, jy = rc - 120, cx = 195.0
        A.stroke(ctx, A.lines([(mx - 4, G - 2, mx - 4, jy), (mx + 4, G - 2, mx + 4, jy), (150, jy, mx + 26, jy), (158, jy + 6, mx + 26, jy + 6)]), A.cream(0.85), 1.5)
        var lattice = Path()
        var yy = G - 2
        while yy > jy {
            lattice.move(to: A.pt(mx - 4, yy)); lattice.addLine(to: A.pt(mx + 4, yy - 12))
            lattice.move(to: A.pt(mx + 4, yy)); lattice.addLine(to: A.pt(mx - 4, yy - 12))
            yy -= 12
        }
        var xx = 158.0
        while xx < mx + 20 {
            lattice.move(to: A.pt(xx, jy + 6)); lattice.addLine(to: A.pt(xx + 5, jy)); lattice.addLine(to: A.pt(xx + 10, jy + 6))
            xx += 10
        }
        A.stroke(ctx, lattice, A.cream(0.3), 1)
        A.fillStroke(ctx, A.rrect(mx - 8, jy + 8, 16, 11, 2), line: A.cream(0.85), width: 1.2)
        ctx.fill(Path(CGRect(x: mx - 5, y: jy + 10, width: 10, height: 4)), with: .color(A.amber.opacity(0.9)))
        let blink = 0.5 + 0.5 * sin(t * 4.2)
        var light = ctx
        light.opacity = 0.35 + 0.65 * blink
        A.glow(light, A.circle(mx, jy - 4, 2.4), A.terra, blur: 10 * blink)
        // carrinho, cabo e o bico pendurado subindo e descendo devagar
        let cycle = (t / 6).truncatingRemainder(dividingBy: 1)
        let low = A.eInOut(cycle < 0.5 ? cycle * 2 : 2 - cycle * 2)
        let hookY = jy + 22 + 22 * low
        let sway = sin(t * 1.3) * 2.4
        A.fillStroke(ctx, A.rrect(cx - 5, jy + 6, 10, 5, 1), line: A.cream(0.85), width: 1)
        A.stroke(ctx, A.lines([(cx, jy + 11, cx + sway, hookY), (cx + sway, hookY, cx + sway - 8, hookY + 7), (cx + sway, hookY, cx + sway + 8, hookY + 7)]), A.cream(0.7), 1)
        var nose = ctx
        nose.translateBy(x: cx + sway, y: hookY + 84)
        nose.rotate(by: .radians(sway * 0.02))
        A.fillStroke(nose, RocketLine.nose)
    }

    private static func cone(_ ctx: GraphicsContext, x: Double, y: Double) {
        var body = Path()
        body.move(to: A.pt(x - 5, y - 1))
        body.addLine(to: A.pt(x, y - 14))
        body.addLine(to: A.pt(x + 5, y - 1))
        body.closeSubpath()
        A.fillStroke(ctx, body, fill: A.terra, line: A.cream(0.9), width: 1)
        ctx.fill(Path(CGRect(x: x - 2.6, y: y - 8, width: 5.2, height: 1.8)), with: .color(A.cream(0.95)))
        A.fillStroke(ctx, A.rrect(x - 7, y - 1.6, 14, 2.4, 1), line: A.cream(0.9), width: 1)
    }

    private static func tape(_ ctx: GraphicsContext, from x0: Double, to x1: Double, y: Double) {
        A.stroke(ctx, A.lines([(x0, y - 2, x0, y + 12), (x1, y - 2, x1, y + 12)]), A.cream(0.8), 1.3)
        var c = ctx
        c.clip(to: Path(CGRect(x: x0, y: y, width: x1 - x0, height: 3.4)))
        c.fill(Path(CGRect(x: x0, y: y, width: x1 - x0, height: 3.4)), with: .color(A.amber))
        var stripes = Path()
        var x = x0 - 6
        while x < x1 + 6 {
            stripes.move(to: A.pt(x, y + 3.4))
            stripes.addLine(to: A.pt(x + 3, y))
            stripes.addLine(to: A.pt(x + 6, y))
            stripes.addLine(to: A.pt(x + 3, y + 3.4))
            stripes.closeSubpath()
            x += 7
        }
        c.fill(stripes, with: .color(boots))
    }

    /// Bonequinho de capacete com os pés em (x, y). Ângulos em radianos (0 = pra baixo).
    /// `extra` desenha a ferramenta (no espaço do bonequinho) antes do braço da frente.
    /// Devolve a posição da mão da frente, nas coordenadas da cena.
    @discardableResult
    private static func worker(_ ctx: GraphicsContext, x: Double, y: Double, facing: Double,
                               armA: Double = -0.2, armB: Double = 0.2, legA: Double = 0, legB: Double = 0,
                               extra: ((GraphicsContext) -> Void)? = nil) -> CGPoint {
        let s = workerScale
        var c = ctx
        c.translateBy(x: x, y: y)
        c.scaleBy(x: facing * s, y: s)
        func limb(_ x0: Double, _ y0: Double, _ len: Double, _ angle: Double, _ color: Color) {
            var g = c
            g.translateBy(x: x0, y: y0)
            g.rotate(by: .radians(angle))
            let bone = A.line(0, 0, 0, len)
            A.stroke(g, bone, A.cream(0.95), 3.8)
            A.stroke(g, bone, color, 2.3)
        }
        func boot(_ dx: Double) {
            A.fillStroke(c, A.rrect(dx, -1.6, 4.2, 2.2, 0.8), fill: boots, line: A.cream(0.9), width: 0.7)
        }
        limb(-1.8, -9, 8.3, legB, pants)
        limb(1.8, -9, 8.3, legA, pants)
        boot(-4.3 + sin(legB) * -6)
        boot(sin(legA) * -6)
        limb(-3.2, -16.5, 7, armB, vest)
        A.fillStroke(c, A.rrect(-4.6, -18.2, 9.2, 10.2, 2.6), fill: vest, line: A.cream(0.95), width: 0.8)
        c.fill(Path(CGRect(x: -4.2, y: -13.4, width: 8.4, height: 1.4)), with: .color(A.cream(0.95)))
        A.fillStroke(c, A.circle(0, -21.6, 3.6), fill: skin, line: A.cream(0.95), width: 0.7)
        c.fill(Path(CGRect(x: 1.3, y: -22.3, width: 0.9, height: 1.1)), with: .color(A.ink))
        var helmet = A.arc(0, -22.7, 4.2, 4.2, rot: 0, from: .pi, to: 2 * .pi, steps: 16)
        helmet.closeSubpath()
        c.fill(helmet, with: .color(A.amber))
        c.fill(A.rrect(-4.2, -23.2, 9.8, 1.4, 0.6), with: .color(A.amber))
        extra?(c)
        limb(3.2, -16.5, 7, armA, vest)
        let ax = 3.2 + sin(-armA) * 7, ay = -16.5 + cos(armA) * 7
        c.fill(A.circle(ax, ay, 1.4), with: .color(skin))
        return CGPoint(x: x + facing * s * ax, y: y + s * ay)
    }
}
