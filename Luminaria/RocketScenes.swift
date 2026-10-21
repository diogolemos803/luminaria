import SwiftUI

// Cenas do foguete no traço da marca SOVEE — protótipo aprovado em
// design/foguete_traco_prototipo.html (2026-10-21). Mesma linguagem do logo e do desenho
// da luminária: linha creme fina, cantos redondos, cor só no que é luz (chama, visor,
// escotilha, bandeira) e nas cores da marca que identificam os lugares (Terra verde,
// Marte laranja, Lua creme). A base de lançamento, os bonequinhos das obras e o astronauta
// são os dos protótipos antigos, redesenhados nesse traço (pedido do usuário).
//
// Tudo num `Canvas`, no espaço de 390×844 dos protótipos (foguete centralizado em
// 195×422), escalado pra preencher a tela, e como função pura do tempo — os números são
// os mesmos do protótipo (`t` do protótipo = segundos).

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
    /// Progresso 0...1 de uma animação parada antes do atraso e depois de terminar.
    static func progress(_ t: Double, delay: Double, duration: Double) -> Double {
        min(max((t - delay) / duration, 0), 1)
    }

    /// Fase 0..<1 de um laço infinito.
    static func loop(_ t: Double, period: Double) -> Double {
        let x = t.truncatingRemainder(dividingBy: period) / period
        return x < 0 ? x + 1 : x
    }

    /// Valor numa trilha de keyframes, com a curva aplicada em cada trecho.
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

// MARK: - Peças de desenho

/// Paleta e ajudantes do traço (equivalentes às funções do protótipo).
enum LineArt {
    static let bg = Color(sceneHex: 0x23252C)
    static let ground = Color(sceneHex: 0x292B33)
    static let earth = Color(sceneHex: 0x2A4536)
    static let marsGround = Color(sceneHex: 0x5A3424)
    static let creme = Color(sceneHex: 0xFDF8C7)
    static let amber = Color(sceneHex: 0xF2B05E)
    static let terra = Color(sceneHex: 0xDB8149)
    static let peach = Color(sceneHex: 0xFF9F66)
    static let sage = Color(sceneHex: 0x80A68E)
    static let floresta = Color(sceneHex: 0x417C5A)
    static let luar = Color(sceneHex: 0x84A1C8)
    static let grafite = Color(sceneHex: 0x444444)
    static let ink = Color(sceneHex: 0x2A2A2A)
    static let night = Color(sceneHex: 0x14161B)

    static func cream(_ a: Double) -> Color { creme.opacity(a) }

    static func clamp(_ v: Double, _ a: Double, _ b: Double) -> Double { max(a, min(b, v)) }
    static func seg(_ t: Double, _ a: Double, _ b: Double) -> Double { clamp((t - a) / (b - a), 0, 1) }
    static func lerp(_ a: Double, _ b: Double, _ k: Double) -> Double { a + (b - a) * k }
    static func eOut(_ k: Double) -> Double { 1 - pow(1 - k, 3) }
    static func eIn(_ k: Double) -> Double { k * k * k }
    static func eInOut(_ k: Double) -> Double { k < 0.5 ? 4 * k * k * k : 1 - pow(-2 * k + 2, 3) / 2 }

    static func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
    static func circle(_ x: Double, _ y: Double, _ r: Double) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
    }
    static func ellipse(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double) -> Path {
        Path(ellipseIn: CGRect(x: x - rx, y: y - ry, width: 2 * rx, height: 2 * ry))
    }
    static func rrect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r, style: .continuous)
    }
    static func line(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Path {
        var p = Path()
        p.move(to: pt(x1, y1))
        p.addLine(to: pt(x2, y2))
        return p
    }
    static func lines(_ segs: [(Double, Double, Double, Double)]) -> Path {
        var p = Path()
        for s in segs {
            p.move(to: pt(s.0, s.1))
            p.addLine(to: pt(s.2, s.3))
        }
        return p
    }
    /// Arco de elipse (amostrado), girado de `rot` em volta do centro.
    static func arc(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, rot: Double, from a0: Double, to a1: Double, steps: Int = 36) -> Path {
        var p = Path()
        let c = cos(rot), s = sin(rot)
        for i in 0...steps {
            let a = a0 + (a1 - a0) * Double(i) / Double(steps)
            let ex = rx * cos(a), ey = ry * sin(a)
            let point = pt(cx + ex * c - ey * s, cy + ex * s + ey * c)
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        return p
    }

    /// Caminho em notação SVG simplificada (M, L, C, Q, Z absolutos), pra copiar os
    /// desenhos do protótipo sem reescrever ponto a ponto.
    static func svg(_ d: String) -> Path {
        var p = Path()
        var tokens: [String] = []
        var current = ""
        for ch in d {
            if ch == " " || ch == "," {
                if !current.isEmpty { tokens.append(current); current = "" }
            } else if "MLCQZ".contains(ch) {
                if !current.isEmpty { tokens.append(current); current = "" }
                tokens.append(String(ch))
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        var i = 0
        var cmd = "M"
        func num() -> Double { let v = Double(tokens[i]) ?? 0; i += 1; return v }
        while i < tokens.count {
            if "MLCQZ".contains(tokens[i]) { cmd = tokens[i]; i += 1 }
            switch cmd {
            case "M": let x = num(), y = num(); p.move(to: pt(x, y)); cmd = "L"
            case "L": let x = num(), y = num(); p.addLine(to: pt(x, y))
            case "C":
                let a = num(), b = num(), c = num(), d = num(), e = num(), f = num()
                p.addCurve(to: pt(e, f), control1: pt(a, b), control2: pt(c, d))
            case "Q":
                let a = num(), b = num(), c = num(), d = num()
                p.addQuadCurve(to: pt(c, d), control: pt(a, b))
            case "Z": p.closeSubpath()
            default: i += 1
            }
        }
        return p
    }

    static func stroke(_ c: GraphicsContext, _ p: Path, _ color: Color, _ w: Double, dash: [CGFloat] = []) {
        c.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round, dash: dash))
    }
    static func fillStroke(_ c: GraphicsContext, _ p: Path, fill: Color = bg, line: Color = creme, width: Double = 2) {
        c.fill(p, with: .color(fill))
        stroke(c, p, line, width)
    }
    /// Preenchimento com brilho em volta (luz).
    static func glow(_ c: GraphicsContext, _ p: Path, _ color: Color, blur: Double) {
        var g = c
        if blur > 0.1 { g.addFilter(.shadow(color: color, radius: blur / 2)) }
        g.fill(p, with: .color(color))
    }
    static func bubble(_ c: GraphicsContext, _ x: Double, _ y: Double, _ r: Double, _ a: Double) {
        guard r > 0.3, a > 0.01 else { return }
        let p = circle(x, y, r)
        c.fill(p, with: .color(bg))
        stroke(c, p, cream(a), 1.6)
    }
    static func text(_ c: GraphicsContext, _ s: String, at p: CGPoint, size: Double, weight: Font.Weight = .medium, color: Color) {
        c.draw(Text(s).font(.soveeDisplay(size: size, weight: weight)).foregroundColor(color), at: p, anchor: .center)
    }

    /// Enquadramento dos protótipos: 390×844 preenchendo a tela, (195, 422) no centro.
    static func applyCamera(_ ctx: inout GraphicsContext, size: CGSize) {
        let s = max(size.width / 390, size.height / 844)
        ctx.translateBy(x: size.width / 2 - 195 * s, y: size.height / 2 - 422 * s)
        ctx.scaleBy(x: s, y: s)
    }
}

// MARK: - Foguete

/// O foguete em traço: cápsula de bico redondo com duas linhas curvas no casco, visor
/// aceso, barbatanas e bocal. Coordenadas locais com o centro em (0, 0); o bocal termina
/// em y 57.
enum RocketLine {
    static let nose = LineArt.svg("M 0 -76 C 14 -66 20 -53 21 -40 Q 0 -33 -21 -40 C -20 -53 -14 -66 0 -76 Z")
    static let body = LineArt.svg("M -21 -40 Q 0 -33 21 -40 C 23 -32 24 -24 24 -18 L 24 40 Q 24 48 16 48 L -16 48 Q -24 48 -24 40 L -24 -18 C -24 -24 -23 -32 -21 -40 Z")
    static func fin(_ s: Double) -> Path {
        LineArt.svg("M \(s * 24) 12 C \(s * 38) 20 \(s * 43) 38 \(s * 41) 58 Q \(s * 33) 50 \(s * 24) 46")
    }
    static let finL = fin(-1)
    static let finR = fin(1)
    static let nozzle = LineArt.svg("M -10 48 L -13 57 L 13 57 L 10 48")
    static let band = LineArt.svg("M -24 24 Q 0 31 24 24")
    static let window = LineArt.circle(0, -12, 8.5)
    static let hatch = LineArt.rrect(-7, 4, 14, 22, 6)

    static func closed(_ p: Path) -> Path { var q = p; q.closeSubpath(); return q }

    /// `glow` = visor aceso (0...1); `hatch` = escotilha acesa (0...1, pouso).
    static func draw(_ ctx: GraphicsContext, at center: CGPoint, glow: Double = 1, hatch hatchK: Double = 0,
                     line: Color = LineArt.creme, fill: Color = LineArt.bg) {
        var c = ctx
        c.translateBy(x: center.x, y: center.y)
        for f in [finL, finR] {
            c.fill(closed(f), with: .color(fill))
            LineArt.stroke(c, f, line, 2)
        }
        LineArt.fillStroke(c, body, fill: fill, line: line)
        LineArt.fillStroke(c, nose, fill: fill, line: line)
        LineArt.stroke(c, band, line.opacity(0.55), 1.5)
        LineArt.stroke(c, nozzle, line, 2)
        LineArt.glow(c, window, LineArt.amber.opacity(0.25 + 0.55 * glow), blur: 10 * glow)
        LineArt.stroke(c, window, line, 2)
        if hatchK > 0 {
            LineArt.glow(c, hatch, LineArt.amber.opacity(0.85 * hatchK), blur: 14 * hatchK)
            LineArt.stroke(c, hatch, line, 1.6)
        }
    }

    static func flame(_ ctx: GraphicsContext, clock: Double, power: Double, at p: CGPoint) {
        guard power > 0.01 else { return }
        let f = 1 + 0.07 * sin(clock * 31) + 0.05 * sin(clock * 17.3)
        let L = (30 + 18 * power) * f * power
        let w = 10 * min(1, power + 0.3)
        var c = ctx
        c.translateBy(x: p.x, y: p.y + 1)
        LineArt.glow(c, drop(w: w, l: L), LineArt.amber.opacity(0.95), blur: 26)
        c.fill(drop(w: w * 0.5, l: L * 0.55), with: .color(LineArt.cream(0.95)))
    }

    private static func drop(w: Double, l: Double) -> Path {
        var p = Path()
        p.move(to: LineArt.pt(-w, 0))
        p.addCurve(to: LineArt.pt(0, l), control1: LineArt.pt(-w, l * 0.45), control2: LineArt.pt(-2, l * 0.8))
        p.addCurve(to: LineArt.pt(w, 0), control1: LineArt.pt(2, l * 0.8), control2: LineArt.pt(w, l * 0.45))
        p.closeSubpath()
        return p
    }
}

// MARK: - Planetas

/// Os destinos em traço — cada um com forma e cor próprias (protótipo aprovado).
enum PlanetPainter {
    struct Look { let tint: Color; let fillOpacity: Double }

    static func look(_ id: String) -> Look {
        switch id {
        case "mars": return Look(tint: LineArt.peach, fillOpacity: 0.7)
        case "saturn": return Look(tint: LineArt.amber, fillOpacity: 0.45)
        case "neptune": return Look(tint: LineArt.luar, fillOpacity: 0.55)
        default: return Look(tint: LineArt.creme, fillOpacity: 1)
        }
    }

    /// `dashed` = destino ainda não alcançado (tracejado, sem cor).
    static func draw(_ ctx: GraphicsContext, id: String, x: Double, y: Double, r: Double, dashed: Bool = false,
                     alpha: Double = 1, line: Color = LineArt.creme, fill: Color = LineArt.bg) {
        var c = ctx
        c.opacity = alpha
        let lw = max(1.2, r / 14)
        let dash: [CGFloat] = dashed ? [3, 4] : []
        let tilt = -0.32
        if id == "saturn" {
            LineArt.stroke(c, LineArt.arc(x, y, r * 1.95, r * 0.52, rot: tilt, from: .pi, to: 2 * .pi), line.opacity(0.95), lw, dash: dash)
            LineArt.stroke(c, LineArt.arc(x, y, r * 1.6, r * 0.4, rot: tilt, from: .pi, to: 2 * .pi), line.opacity(0.4), lw * 0.8, dash: dash)
        }
        if id == "neptune" {
            LineArt.stroke(c, LineArt.arc(x, y, r * 1.55, r * 0.3, rot: 0.2, from: .pi, to: 2 * .pi), line.opacity(0.3), lw * 0.7, dash: dash)
        }
        let body = LineArt.circle(x, y, r)
        c.fill(body, with: .color(fill))
        if !dashed {
            let lk = look(id)
            c.fill(body, with: .color(lk.tint.opacity(lk.fillOpacity)))
        }
        LineArt.stroke(c, body, line, lw, dash: dash)

        var inner = c
        inner.clip(to: LineArt.circle(x, y, r - 0.5))
        switch id {
        case "moon":
            var detail = line.opacity(0.55)
            if !dashed {
                inner.fill(LineArt.circle(x + r * 0.55, y - r * 0.1, r * 0.95), with: .color(LineArt.grafite.opacity(0.22)))
                detail = LineArt.grafite.opacity(0.75)
            }
            var craters = LineArt.circle(x - r * 0.35, y - r * 0.3, r * 0.22)
            craters.addPath(LineArt.circle(x - r * 0.05, y + r * 0.35, r * 0.14))
            craters.addPath(LineArt.circle(x - r * 0.45, y + r * 0.25, r * 0.1))
            LineArt.stroke(inner, craters, detail, lw * 0.85, dash: dash)
        case "mars":
            var bands = Path()
            for k in [-0.15, 0.3] {
                let yy = y + r * k
                for i in 0...8 {
                    let px = x - r + Double(i) * r / 4
                    let py = yy + sin(Double(i) * 1.3 + k * 5) * r * 0.07
                    if i == 0 { bands.move(to: LineArt.pt(px, py)) } else { bands.addLine(to: LineArt.pt(px, py)) }
                }
            }
            LineArt.stroke(inner, bands, dashed ? line.opacity(0.55) : Color(sceneHex: 0xA0502D, opacity: 0.85), lw * 0.85, dash: dash)
            if !dashed { inner.fill(LineArt.ellipse(x, y - r * 0.86, r * 0.42, r * 0.16), with: .color(LineArt.cream(0.8))) }
        case "saturn":
            var bands = Path()
            for k in [0.42, 0.7] {
                bands.move(to: LineArt.pt(-r, r * k))
                bands.addQuadCurve(to: LineArt.pt(r, r * k), control: LineArt.pt(0, r * k + r * 0.08))
            }
            let rotated = bands.applying(CGAffineTransform(rotationAngle: tilt)).applying(CGAffineTransform(translationX: x, y: y))
            LineArt.stroke(inner, rotated, line.opacity(0.22), lw * 0.6, dash: dash)
            // metade de trás do anel vista "através" do planeta
            LineArt.stroke(inner, LineArt.arc(x, y, r * 1.95, r * 0.52, rot: tilt, from: .pi, to: 2 * .pi), line.opacity(0.6), lw, dash: dash)
            LineArt.stroke(inner, LineArt.arc(x, y, r * 1.6, r * 0.4, rot: tilt, from: .pi, to: 2 * .pi), line.opacity(0.32), lw * 0.8, dash: dash)
        case "neptune":
            LineArt.stroke(inner, LineArt.lines([(x - r, y - r * 0.5, x + r, y - r * 0.5), (x - r, y + r * 0.05, x + r, y + r * 0.05), (x - r, y + r * 0.5, x + r, y + r * 0.5)]), line.opacity(0.55), lw * 0.85, dash: dash)
            let spot = LineArt.ellipse(x - r * 0.3, y - r * 0.2, r * 0.2, r * 0.11)
            inner.fill(spot, with: .color(LineArt.bg.opacity(0.55)))
            LineArt.stroke(inner, spot, line.opacity(0.55), lw * 0.85, dash: dash)
        default:
            break
        }
        if id == "saturn" {
            LineArt.stroke(c, LineArt.arc(x, y, r * 1.95, r * 0.52, rot: tilt, from: 0, to: .pi), line.opacity(0.95), lw, dash: dash)
            LineArt.stroke(c, LineArt.arc(x, y, r * 1.6, r * 0.4, rot: tilt, from: 0, to: .pi), line.opacity(0.4), lw * 0.8, dash: dash)
        }
    }

    /// "rumo à lua" / "rumo a marte".
    static func heading(_ id: String) -> String {
        id == "moon" ? "rumo à lua" : "rumo a \(name(id))"
    }

    static func landingTitle(_ id: String) -> String {
        id == "moon" ? "pouso na lua" : "pouso em \(name(id))"
    }

    static func name(_ id: String) -> String {
        (PlanetMilestones.all.first { $0.id == id }?.name ?? "Lua").lowercased()
    }
}

// MARK: - Céu

enum SkyArt {
    struct Star { let x: Double, y: Double, s: Double, d: Double, p: Double }

    /// Mesmas estrelas do protótipo (gerador com semente 7).
    static let stars: [Star] = {
        var seed: Int64 = 7
        func r() -> Double { seed = (seed * 16807) % 2147483647; return Double(seed - 1) / 2147483646 }
        return (0..<70).map { _ -> Star in
            let x = r() * 390, y = r() * 844, s = r(), d = 0.35 + r() * 0.65, p = r() * 6.28
            return Star(x: x, y: y, s: s, d: d, p: p)
        }
    }()

    /// Céu grafite com estrelas em pontos e brilhos em cruz. `scroll` desce as estrelas
    /// (sensação de subir); negativo sobe (descendo no pouso).
    static func draw(_ c: GraphicsContext, clock: Double, scroll: Double) {
        c.fill(Path(CGRect(x: -400, y: -1400, width: 1190, height: 3200)), with: .color(LineArt.bg))
        c.fill(Path(CGRect(x: -400, y: -1400, width: 1190, height: 3200)),
               with: .radialGradient(Gradient(colors: [LineArt.amber.opacity(0.12), LineArt.amber.opacity(0)]),
                                     center: LineArt.pt(195, 924), startRadius: 0, endRadius: 520))
        for s in stars {
            let raw = (s.y + scroll * s.d).truncatingRemainder(dividingBy: 844)
            let y = raw < 0 ? raw + 844 : raw
            let tw = 0.45 + 0.35 * sin(clock * 1.6 + s.p)
            if s.s > 0.9 {
                let l = 4 + s.s * 2
                LineArt.stroke(c, LineArt.lines([(s.x - l, y, s.x + l, y), (s.x, y - l, s.x, y + l)]), LineArt.cream(tw), 1.2)
            } else {
                c.fill(LineArt.circle(s.x, y, 0.8 + s.s * 0.9), with: .color(LineArt.cream(tw * (0.4 + s.s * 0.6))))
            }
        }
    }

    /// Planeta de destino no alto do céu, com "rumo a…" embaixo.
    static func destination(_ c: GraphicsContext, id: String) {
        let saturn = id == "saturn"
        PlanetPainter.draw(c, id: id, x: 306, y: 126, r: saturn ? 17 : 21)
        LineArt.text(c, PlanetPainter.heading(id), at: LineArt.pt(306, saturn ? 164 : 162), size: 11, color: LineArt.cream(0.6))
    }
}

// MARK: - Terra e base de lançamento

/// A Terra verde e a base de lançamento do protótipo antigo da decolagem, redesenhadas em
/// traço. Desenhadas nas coordenadas daquele protótipo (mesa de lançamento em y 666),
/// encolhidas 10% e encaixadas com o topo da mesa em `mesaY`.
enum LaunchBaseArt {
    static let scale = 0.9

    static func space(_ ctx: GraphicsContext, mesaY: Double) -> GraphicsContext {
        var c = ctx
        c.translateBy(x: 195, y: mesaY)
        c.scaleBy(x: scale, y: scale)
        c.translateBy(x: -195, y: -666)
        return c
    }

    private static let hill = "M -60 700 C 55 700 95 668 155 660 C 185 656 205 656 235 660 C 275 665 325 682 450 700"
    private static let hillLine = LineArt.svg(hill)
    private static let hillFill = LineArt.svg(hill + " L 450 3200 L -60 3200 Z")
    private static let hillHaze = LineArt.svg("M -60 714 C 55 714 95 682 155 674 C 185 670 205 670 235 674 C 275 679 325 696 450 714")
    private static let plateau = LineArt.svg("M 73 688 C 100 677 130 667 155 665 C 180 662 210 662 235 665 C 262 669 285 674 306 681 C 280 692 240 696 195 696 C 150 696 105 694 73 688 Z")
    private static let road = LineArt.svg("M 150 697 C 146 730 118 770 84 810 C 60 838 44 880 36 940")
    private static let fields: [(Path, Path)] = [
        (LineArt.svg("M 196 900 L 286 880 L 312 924 L 214 946 Z"), LineArt.lines([(202, 912, 292, 892), (207, 923, 298, 903), (210, 934, 304, 913)])),
        (LineArt.svg("M 96 960 L 170 948 L 186 984 L 108 998 Z"), LineArt.lines([(100, 970, 174, 958), (104, 980, 179, 968), (106, 990, 183, 977)])),
    ]
    private static let lake = LineArt.svg("M 246 816 C 266 800 328 802 350 818 C 358 834 322 846 286 844 C 258 842 240 832 246 816 Z")
    private static let trees: [(Double, Double, Double)] = [
        (4, 698, 6), (-4, 700, 5), (330, 684, 4), (360, 690, 5.5), (352, 693, 4), (386, 697, 6), (40, 840, 5), (50, 846, 4), (31, 848, 4.5),
        (330, 880, 5), (342, 886, 6), (320, 889, 4), (140, 1040, 5.5), (152, 1046, 4.5), (360, 1010, 5), (372, 1016, 4), (120, 860, 3), (300, 940, 3.4), (70, 960, 2.8),
    ]

    /// Terra verde (cor da marca): morro com platô, estrada, campos, lago e árvores.
    static func earth(_ ctx: GraphicsContext, mesaY: Double) {
        let c = space(ctx, mesaY: mesaY)
        c.fill(hillFill, with: .color(LineArt.earth))
        LineArt.stroke(c, hillLine, LineArt.cream(0.95), 2)
        LineArt.stroke(c, hillHaze, LineArt.sage.opacity(0.5), 1.3)
        c.fill(plateau, with: .color(Color(sceneHex: 0x39443A)))
        LineArt.stroke(c, plateau, LineArt.cream(0.55), 1.3)
        LineArt.stroke(c, road, LineArt.cream(0.35), 1.3, dash: [5, 6])
        for (shape, hatch) in fields {
            c.fill(shape, with: .color(LineArt.floresta.opacity(0.55)))
            LineArt.stroke(c, shape, LineArt.sage.opacity(0.75), 1.3)
            LineArt.stroke(c, hatch, LineArt.sage.opacity(0.45), 1.3)
        }
        c.fill(lake, with: .color(LineArt.luar.opacity(0.4)))
        LineArt.stroke(c, lake, LineArt.cream(0.6), 1.3)
        for t in trees {
            let p = LineArt.circle(t.0, t.1, t.2)
            c.fill(p, with: .color(LineArt.floresta))
            LineArt.stroke(c, p, LineArt.sage.opacity(0.95), 1.1)
        }
    }

    /// Base: deck com luzes, prédio de controle, torre treliçada com luz piscando e braço
    /// que recolhe (`armK`), mesa com fosso de chamas, garras que abrem (`clampK`),
    /// tubulação, tanques e poste.
    static func base(_ ctx: GraphicsContext, mesaY: Double, clock: Double, armK: Double = 0, clampK: Double = 0,
                     tower: Bool = true, post: Bool = true) {
        let c = space(ctx, mesaY: mesaY)
        func box(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double = 0, _ a: Double = 0.9, in g: GraphicsContext? = nil) {
            LineArt.fillStroke(g ?? c, LineArt.rrect(x, y, w, h, r), line: LineArt.cream(a), width: 1.5)
        }
        func dot(_ x: Double, _ y: Double, _ r: Double, _ color: Color, _ blur: Double) {
            LineArt.glow(c, LineArt.circle(x, y, r), color, blur: blur)
        }
        // deck elevado
        LineArt.stroke(c, LineArt.lines([(72, 695, 72, 703), (132, 695, 132, 703), (258, 695, 258, 703), (318, 695, 318, 703)]), LineArt.cream(0.7), 1.5)
        box(58, 688, 276, 7, 2)
        for x in [66.0, 104, 286, 326] { dot(x, 691.5, 1.6, LineArt.amber, 6) }
        // prédio de controle
        box(10, 676, 46, 22, 2)
        LineArt.stroke(c, LineArt.line(10, 681, 56, 681), LineArt.cream(0.5), 1.1)
        for x in [15.0, 24, 33, 45] { c.fill(Path(CGRect(x: x, y: 686, width: 5, height: 4)), with: .color(LineArt.amber.opacity(0.9))) }
        LineArt.stroke(c, LineArt.lines([(61.5, 674, 61.5, 662), (67.5, 674, 67.5, 657)]), LineArt.cream(0.75), 1.3)
        dot(67.5, 656, 1.5, LineArt.amber, 5)
        if tower {
            box(72, 670, 54, 20, 2)
            box(80, 444, 6, 228, 1)
            box(112, 444, 6, 228, 1)
            box(78, 440, 42, 6, 2)
            var braces: [(Double, Double, Double, Double)] = []
            var y = 446.0
            while y < 670 { braces.append((86, y, 112, y + 28)); braces.append((112, y, 86, y + 28)); y += 28 }
            LineArt.stroke(c, LineArt.lines(braces), LineArt.cream(0.45), 1.2)
            var arm = c
            arm.translateBy(x: 118, y: 450)
            arm.rotate(by: .radians(-armK * 1.05))
            box(0, -2, 52, 5, 2, in: arm)
            LineArt.stroke(arm, LineArt.line(0, 26, 30, 3), LineArt.cream(0.55), 1.3)
            box(118, 566, 38, 4, 2)
            LineArt.stroke(c, LineArt.line(118, 586, 140, 570), LineArt.cream(0.55), 1.3)
            box(97.5, 431, 3, 10, 1, 0.7)
            let blink = 0.5 + 0.5 * sin(clock * 4)
            var light = c
            light.opacity = 0.35 + 0.65 * blink
            LineArt.glow(light, LineArt.circle(99, 430, 3.2), LineArt.terra, blur: 16 * blink)
        }
        // mesa de lançamento com o fosso de chamas
        let mesa = LineArt.svg("M 158 666 L 232 666 L 244 688 L 146 688 Z")
        LineArt.fillStroke(c, mesa, line: LineArt.cream(0.95), width: 1.6)
        let trench = LineArt.svg("M 181 672 L 209 672 L 213 688 L 177 688 Z")
        LineArt.fillStroke(c, trench, fill: LineArt.night, line: LineArt.cream(0.45), width: 1.1)
        let open = clampK * 6
        box(166 - open, 652, 5, 16, 1.5)
        box(219 + open, 652, 5, 16, 1.5)
        // tubulação
        LineArt.stroke(c, LineArt.lines([(126, 676, 150, 676), (126, 682, 148, 682), (268, 680, 242, 680)]), LineArt.cream(0.6), 1.4)
        // tanques
        LineArt.stroke(c, LineArt.lines([(277.5, 686, 277.5, 690), (305.5, 686, 305.5, 690), (334.5, 676, 334.5, 689), (349.5, 676, 349.5, 689)]), LineArt.cream(0.7), 1.4)
        box(268, 668, 48, 18, 9)
        LineArt.stroke(c, LineArt.line(276, 672, 306, 672), LineArt.cream(0.4), 1.1)
        LineArt.fillStroke(c, LineArt.circle(342, 664, 14), line: LineArt.cream(0.9), width: 1.5)
        LineArt.stroke(c, LineArt.arc(342, 664, 10, 10, rot: 0, from: .pi * 1.15, to: .pi * 1.55), LineArt.cream(0.45), 1.2)
        if post {
            LineArt.stroke(c, LineArt.line(373.5, 690, 373.5, 614), LineArt.cream(0.75), 1.4)
            dot(373.5, 612, 2.4, LineArt.amber, 10)
        }
    }
}

// MARK: - Decolagem, voo, meteoro e canteiro

/// Cena da noite: entrada (céu descendo, Terra subindo), decolagem e voo até o destino.
/// O foguete NUNCA se move na tela — só o cenário. Com `destroyedAt`, um meteoro atinge o
/// foguete, ele se parte, e a Terra volta com o canteiro de obras em loop até o fim da
/// noite (`ConstructionSiteArt`). O foguete só fica pronto pra próxima ativação.
struct LaunchScene: View {
    /// Destino de hoje (`GrowthDestinations.furthestUnlocked`): aparece no alto do céu.
    let destinationID: String
    let sceneStart: Date?
    let destroyedAt: Date?

    @State private var isResting = false

    private struct AnimationKey: Equatable {
        let sceneStart: Date?
        let destroyedAt: Date?
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: isResting ? 1.0 / 30.0 : nil)) { timeline in
            let frame = LaunchPainter.frame(at: timeline.date, sceneStart: sceneStart, destroyedAt: destroyedAt)
            let clock = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                LaunchPainter.draw(in: &context, size: size, frame: frame, clock: clock, destinationID: destinationID)
            }
        }
        .task(id: AnimationKey(sceneStart: sceneStart, destroyedAt: destroyedAt)) {
            isResting = false
            let settleAt: Date?
            if let destroyedAt {
                settleAt = destroyedAt.addingTimeInterval(LaunchPainter.siteSettledTime)
            } else {
                settleAt = sceneStart.map { $0.addingTimeInterval(LaunchPainter.settleTime) }
            }
            if let settleAt {
                let wait = settleAt.timeIntervalSinceNow
                if wait > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                }
                if Task.isCancelled { return }
            }
            // com o foguete destruído quem muda a fase (pra `.rebuilding`) é o rastreador
            if destroyedAt == nil {
                NightSessionActivityTracker.shared.liftoffAnimationCompleted()
            }
            // em repouso (voo ou canteiro) 30 quadros por segundo bastam
            isResting = true
        }
    }
}

enum LaunchPainter {
    typealias A = LineArt

    /// Entrada (0,12s de atraso + 1,6s); a sequência de ignição começa em `launchDelay`.
    static let launchDelay: Double = 1.8
    /// Chão fora de tela e fumaça desfeita: dali pra frente é só o voo.
    static let settleTime: Double = launchDelay + 7.6
    static let meteorTravel: Double = 1.5
    static let explosionLength: Double = 2.2
    /// A Terra volta com o canteiro 1,6s depois do impacto, subindo em 1,6s.
    static let siteRiseDelay: Double = meteorTravel + 1.6
    static let siteRiseLength: Double = 1.6
    static let siteSettledTime: Double = siteRiseDelay + siteRiseLength
    private static let entranceCurve = SceneCurve(x1: 0.3, y1: 0, x2: 0.2, y2: 1)

    static let center = CGPoint(x: 195, y: 422)
    /// Topo da mesa de lançamento, logo abaixo do bocal.
    static let mesa0: Double = 480
    static let siteMesaY: Double = 590

    struct Frame {
        var sceneTime: Double
        var destroyedTime: Double?
    }

    static func frame(at now: Date, sceneStart: Date?, destroyedAt: Date?) -> Frame {
        let sceneTime = sceneStart.map { now.timeIntervalSince($0) } ?? 600
        guard let destroyedAt, now >= destroyedAt else {
            return Frame(sceneTime: sceneTime, destroyedTime: nil)
        }
        return Frame(sceneTime: sceneTime, destroyedTime: now.timeIntervalSince(destroyedAt))
    }

    /// Tempo no relógio do protótipo (braço recolhe em 1,0; chão começa a descer em 2,6).
    private static func protoTime(_ sceneTime: Double) -> Double { sceneTime - launchDelay + 1.0 }

    /// Quanto o chão já desceu: arranque acelerado e depois velocidade constante.
    static func liftOffset(_ t: Double) -> Double {
        let k = max(0, t - 2.6), k1 = 3.4641
        return k <= k1 ? 75 * k * k : 900 + 519.6 * (k - k1)
    }

    /// Estrelas descendo: acompanham a decolagem e depois seguem devagar no voo.
    static func starScroll(_ t: Double) -> Double {
        let k = max(0, t - 2.6), k1 = 3.4641
        let lift = k <= k1 ? 0.18 * 75 * k * k : 162 + 22 * (k - k1)
        return lift + t * 2
    }

    static func draw(in ctx: inout GraphicsContext, size: CGSize, frame: Frame, clock: Double, destinationID: String) {
        let screen = ctx
        A.applyCamera(&ctx, size: size)
        let d = frame.destroyedTime

        if let d, d >= siteRiseDelay {
            let frozen = starScroll(protoTime(frame.sceneTime - d))
            SkyArt.draw(ctx, clock: clock, scroll: frozen)
            SkyArt.destination(ctx, id: destinationID)
            let rise = entranceCurve.value(SceneTime.progress(d, delay: siteRiseDelay, duration: siteRiseLength))
            ConstructionSiteArt.draw(ctx, mesaY: A.lerp(844 + 220, siteMesaY, rise), clock: clock)
        } else {
            drawFlight(ctx, sceneTime: frame.sceneTime, showsRocket: d.map { $0 < meteorTravel } ?? true, clock: clock, destinationID: destinationID)
        }

        guard let d else { return }
        if d < meteorTravel {
            let e = A.eIn(d / meteorTravel)
            let x0 = 440.0, y0 = -70.0, x1 = 205.0, y1 = 404.0
            drawMeteor(ctx, x: A.lerp(x0, x1, e), y: A.lerp(y0, y1, e), rot: clock * 3, dir: atan2(y1 - y0, x1 - x0))
        } else if d < meteorTravel + explosionLength {
            drawExplosion(ctx, d: d - meteorTravel)
            let flash = 1 - A.seg(d - meteorTravel, 0, 0.35)
            if flash > 0.001 {
                screen.fill(Path(CGRect(origin: .zero, size: size)), with: .color(A.cream(0.22 * flash)))
            }
        }
    }

    private static let cloud: [(dx: Double, dy: Double, r: Double, d: Double)] = {
        var seed: Int64 = 21
        func r() -> Double { seed = (seed * 16807) % 2147483647; return Double(seed - 1) / 2147483646 }
        return (0..<16).map { _ -> (dx: Double, dy: Double, r: Double, d: Double) in
            let side: Double = r() < 0.5 ? -1 : 1
            let dx = side * (18 + r() * 120), dy = -6 - r() * 26, rad = 9 + r() * 15, dl = r() * 0.9
            return (dx, dy, rad, dl)
        }
    }()

    private static func drawFlight(_ ctx: GraphicsContext, sceneTime: Double, showsRocket: Bool, clock: Double, destinationID: String) {
        let entrance = entranceCurve.value(SceneTime.progress(sceneTime, delay: 0.12, duration: 1.6))
        let t = protoTime(sceneTime)

        var sky = ctx
        sky.translateBy(x: 0, y: -1260 * (1 - entrance))
        SkyArt.draw(sky, clock: clock, scroll: starScroll(t))
        SkyArt.destination(sky, id: destinationID)

        var world = ctx
        world.translateBy(x: 0, y: 844 * (1 - entrance))
        let off = liftOffset(t)
        let mesaY = mesa0 + off
        if mesaY < 844 + 320 {
            LaunchBaseArt.earth(world, mesaY: mesaY)
            LaunchBaseArt.base(world, mesaY: mesaY, clock: clock, armK: A.eInOut(A.seg(t, 1.0, 1.7)), clampK: A.eOut(A.seg(t, 2.2, 2.6)))
        }
        // nuvem da ignição, presa ao chão
        let ign = A.seg(t, 1.4, 3.4)
        let fade = 1 - A.seg(off, 300, 700)
        if fade > 0 {
            for b in cloud {
                let k = A.eOut(A.clamp((ign - b.d * 0.4) / 0.6, 0, 1))
                A.bubble(world, 195 + b.dx * (0.4 + 0.6 * k), mesaY + 20 + b.dy - 6, b.r * k, 0.7 * fade)
            }
        }
        // coluna de fumaça: bolhas presas ao chão, deixadas pelo bocal
        for j in 0..<60 {
            let h = Double(j) * 13
            if h > off { break }
            let age = off - h
            let a = 0.7 * (1 - A.seg(age, 120, 520))
            if a <= 0.01 { continue }
            let r = 7 + min(age * 0.03, 16)
            A.bubble(world, 195 + sin(Double(j) * 1.9) * 3 * (1 + age * 0.004), mesaY - h, r, a)
        }
        if showsRocket {
            let power = A.eOut(A.seg(t, 1.3, 2.2)) * (1 + 0.15 * A.seg(t, 2.6, 4))
            RocketLine.flame(world, clock: clock, power: power, at: CGPoint(x: center.x, y: center.y + 57))
            RocketLine.draw(world, at: center)
        }
    }

    private static let rock: [Double] = {
        var seed: Int64 = 5
        func r() -> Double { seed = (seed * 16807) % 2147483647; return Double(seed - 1) / 2147483646 }
        return (0..<9).map { _ -> Double in 15 + r() * 6 }
    }()

    private static func drawMeteor(_ ctx: GraphicsContext, x: Double, y: Double, rot: Double, dir: Double) {
        var c = ctx
        c.translateBy(x: x, y: y)
        for k in 0..<3 {
            let off = Double(k - 1) * 7
            let len = [70.0, 95, 60][k]
            let gx = -cos(dir) * len, gy = -sin(dir) * len
            let px = -sin(dir) * off, py = cos(dir) * off
            c.stroke(A.line(px, py, px + gx, py + gy),
                     with: .linearGradient(Gradient(colors: [A.amber.opacity(0.95), A.amber.opacity(0)]), startPoint: A.pt(px, py), endPoint: A.pt(px + gx, py + gy)),
                     style: StrokeStyle(lineWidth: k == 1 ? 3 : 2, lineCap: .round))
        }
        c.rotate(by: .radians(rot))
        var body = Path()
        for (i, r) in rock.enumerated() {
            let a = Double(i) / Double(rock.count) * 2 * .pi
            let p = A.pt(cos(a) * r, sin(a) * r)
            if i == 0 { body.move(to: p) } else { body.addLine(to: p) }
        }
        body.closeSubpath()
        A.fillStroke(c, body)
        var craters = A.circle(-5, -3, 4)
        craters.addPath(A.circle(6, 5, 2.6))
        A.stroke(c, craters, A.cream(0.5), 1.3)
    }

    private struct Shard { let path: Path; let vx: Double; let vy: Double; let vr: Double }
    private static let shards: [Shard] = [
        Shard(path: RocketLine.nose, vx: -40, vy: -120, vr: -2.4),
        Shard(path: RocketLine.body, vx: 30, vy: 40, vr: 1.2),
        Shard(path: RocketLine.closed(RocketLine.finL), vx: -110, vy: 60, vr: -3),
        Shard(path: RocketLine.closed(RocketLine.finR), vx: 120, vy: 30, vr: 2.8),
        Shard(path: RocketLine.closed(RocketLine.nozzle), vx: 20, vy: 140, vr: 4),
    ]
    private static let sparks: [(a: Double, v: Double, l: Double)] = {
        var seed: Int64 = 11
        func r() -> Double { seed = (seed * 16807) % 2147483647; return Double(seed - 1) / 2147483646 }
        return (0..<18).map { _ -> (a: Double, v: Double, l: Double) in (r() * 2 * .pi, 90 + r() * 140, 6 + r() * 10) }
    }()

    private static func drawExplosion(_ ctx: GraphicsContext, d: Double) {
        let cx = 195.0, cy = 422.0
        // pedaços do foguete girando e caindo
        for s in shards {
            var c = ctx
            c.opacity = 1 - A.seg(d, 1.2, 2.2)
            c.translateBy(x: cx + s.vx * d, y: cy + s.vy * d + 60 * d * d)
            c.rotate(by: .radians(s.vr * d))
            A.fillStroke(c, s.path)
        }
        // anéis de choque
        for lag in [0.0, 0.25] {
            let k = A.seg(d, lag, lag + 1.1)
            if k > 0 && k < 1 {
                A.stroke(ctx, A.circle(cx, cy, 20 + 170 * A.eOut(k)), A.amber.opacity(1 - k), 2.4 * (1 - k) + 0.6)
            }
        }
        // fumaça em bolhas
        let k2 = A.seg(d, 0.05, 1.8)
        for i in 0..<9 {
            let a = Double(i) * 0.7
            let r = (10 + Double(i % 3) * 5) * (1 - 0.4 * k2) * min(1, d * 6)
            A.bubble(ctx, cx + cos(a) * 40 * A.eOut(k2), cy + sin(a) * 30 * A.eOut(k2) - 20 * k2, r, 0.6 * (1 - A.seg(d, 1.2, 2.2)))
        }
        // fagulhas
        let p = A.seg(d, 0, 1.3)
        if p < 1 {
            for s in sparks {
                let r = s.v * A.eOut(p)
                A.stroke(ctx, A.line(cx + cos(s.a) * r, cy + sin(s.a) * r, cx + cos(s.a) * (r + s.l), cy + sin(s.a) * (r + s.l)), A.amber.opacity(1 - p), 1.6)
            }
        }
        // bola de fogo
        let fk = A.seg(d, 0, 0.7)
        if fk < 1 {
            A.glow(ctx, A.circle(cx, cy, 18 + 30 * A.eOut(fk)), A.amber.opacity(0.85 * (1 - fk)), blur: 40)
        }
    }
}

// MARK: - Pouso

/// Pouso na tela do despertador, no destino de hoje: o chão do planeta sobe, poeira,
/// motor desliga, a escotilha acende, a rampa desce, o astronauta caminha quicando e crava
/// a bandeira com as noites seguidas. Lua creme com a Terra no céu; Marte laranja com
/// Fobos e Deimos; Saturno com o anel nascendo do horizonte; Netuno com cristais de gelo e
/// Tritão no céu.
struct LandingScene: View {
    let destinationID: String
    let streakDays: Int

    @Environment(\.scenePhase) private var scenePhase
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            let clock = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                LandingPainter.draw(in: &context, size: size, t: t, clock: clock, destinationID: destinationID, days: streakDays)
            }
        }
        .onAppear { start = Date() }
        // Com o alarme do sistema (AlarmKit), esta tela pode ser montada com o app em
        // segundo plano — recomeça o pouso quando a pessoa abre o app.
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                start = Date()
            }
        }
    }
}

enum LandingPainter {
    typealias A = LineArt

    /// Primeiro segundo: foguete descendo no céu antes de o chão subir (pedido do usuário).
    static let holdBeforeLanding: Double = 1
    private static let surface: Double = 482
    private static let center = CGPoint(x: 195, y: 422)

    private static let craters: [(Double, Double, Double)] = [(-150, 30, 26), (-60, 90, 34), (70, 40, 20), (140, 120, 30), (-120, 190, 22), (30, 220, 40), (150, 250, 18)]
    private static let rocks: [(Double, Double, Double)] = [(-140, 22, 9), (-96, 64, 6), (104, 30, 7), (150, 88, 11), (-40, 150, 8), (60, 190, 6)]
    private static let crystals: [(Double, Double, Double)] = [(-150, 18, 14), (-88, 60, 10), (96, 26, 12), (142, 74, 16), (-30, 130, 11), (70, 170, 14), (-130, 210, 9)]

    static func surfaceY(_ t: Double) -> Double {
        t < holdBeforeLanding ? 844 + 120 : A.lerp(844 + 120, surface, A.eOut(A.seg(t, holdBeforeLanding, 4.6)))
    }

    static func draw(in ctx: inout GraphicsContext, size: CGSize, t rawT: Double, clock: Double, destinationID id: String, days: Int) {
        A.applyCamera(&ctx, size: size)
        let t = min(max(rawT, 0), 13)
        let S = surfaceY(t)
        let descending = 1 - A.seg(t, 1, 4.6)
        SkyArt.draw(ctx, clock: clock, scroll: -(t * 30 * descending))
        drawSky(ctx, id: id)
        if id == "saturn" && S < 844 + 500 { saturnRing(ctx, surface: S) }
        if S < 844 + 100 { drawGround(ctx, id: id, surface: S) }

        // poeira no toque
        let dk = A.seg(t, 4.3, 6.2)
        if dk > 0 && dk < 1 {
            for i in 0..<10 {
                let side: Double = i % 2 == 1 ? 1 : -1
                let n = Double(i / 2)
                A.bubble(ctx, 195 + side * (30 + n * 16 + 60 * A.eOut(dk)), S - 6 - n * 2, (7 + n * 2) * (1 - dk * 0.5), 0.7 * (1 - dk))
            }
        }
        RocketLine.flame(ctx, clock: clock, power: 1 - A.seg(t, 3.4, 4.8), at: CGPoint(x: center.x, y: center.y + 57))
        RocketLine.draw(ctx, at: center, hatch: A.seg(t, 5.2, 5.8))

        // rampa
        let rk = A.eOut(A.seg(t, 5.8, 6.4))
        let hx = 202.0, hy = 448.0
        if rk > 0 { A.stroke(ctx, A.line(hx, hy, A.lerp(hx, 239, rk), A.lerp(hy, S, rk)), A.cream(0.9), 2) }

        // astronauta + bandeira
        let at = t - 6.5
        let flagX = 316.0
        guard at > 0 else { title(ctx, id: id, t: t); return }
        let x: Double, y: Double, walking: Bool
        if at < 0.9 {
            let k = at / 0.9
            x = A.lerp(hx, 239, k)
            y = A.lerp(hy, S, k)
            walking = true
        } else {
            let k2 = A.clamp((at - 0.9) / 2.9, 0, 1)
            x = A.lerp(239, flagX - 16, A.eInOut(k2))
            y = S - (k2 < 1 ? abs(sin(k2 * .pi * 5)) * 9 : 0)
            walking = k2 < 1
        }
        // pegadas
        var steps = Path()
        var px = 247.0
        while px < x - 6 { steps.move(to: A.pt(px, S + 3)); steps.addLine(to: A.pt(px + 4, S + 3)); px += 12 }
        A.stroke(ctx, steps, id == "moon" ? A.grafite.opacity(0.5) : A.cream(0.4), 1.4)

        let fk = A.seg(t, 10.3, 10.8), ck = A.eOut(A.seg(t, 10.8, 11.3))
        if fk > 0 {
            let poleTop = S - 64 * A.eOut(fk)
            A.stroke(ctx, A.line(flagX, S, flagX, poleTop), A.cream(0.95), 2)
            if ck > 0 {
                let fw = 60 * ck, wave = sin(clock * 3) * 1.5
                var cloth = Path()
                cloth.move(to: A.pt(flagX, poleTop + 2))
                cloth.addQuadCurve(to: A.pt(flagX + fw, poleTop + 2), control: A.pt(flagX + fw / 2, poleTop + 2 + wave))
                cloth.addLine(to: A.pt(flagX + fw, poleTop + 38))
                cloth.addQuadCurve(to: A.pt(flagX, poleTop + 38), control: A.pt(flagX + fw / 2, poleTop + 38 + wave))
                cloth.closeSubpath()
                A.glow(ctx, cloth, A.amber, blur: 12)
                if ck > 0.9 {
                    A.text(ctx, "\(days)", at: A.pt(flagX + 30, poleTop + 17), size: 20, weight: .bold, color: A.ink)
                    A.text(ctx, days == 1 ? "noite" : "noites", at: A.pt(flagX + 30, poleTop + 31), size: 9, weight: .medium, color: A.ink)
                }
            }
        }
        AstronautArt.draw(ctx, x: x, y: y, clock: clock, walking: walking, waving: t >= 11.4)
        title(ctx, id: id, t: t)
    }

    private static func title(_ ctx: GraphicsContext, id: String, t: Double) {
        let lk = A.seg(t, 11.6, 12.4)
        if lk > 0 { A.text(ctx, PlanetPainter.landingTitle(id), at: A.pt(195, 262), size: 24, color: A.cream(0.85 * lk)) }
    }

    private static func drawSky(_ c: GraphicsContext, id: String) {
        switch id {
        case "moon":
            // a Terra: oceano azul de luar e continentes verdes
            let x = 72.0, y = 118.0, r = 20.0
            let disc = A.circle(x, y, r)
            c.fill(disc, with: .color(A.bg))
            c.fill(disc, with: .color(A.luar.opacity(0.55)))
            A.stroke(c, disc, A.cream(0.9), 1.6)
            var inner = c
            inner.clip(to: A.circle(x, y, r - 1))
            var land = Path()
            land.move(to: A.pt(x - 14, y - 6))
            land.addCurve(to: A.pt(x - 2, y + 2), control1: A.pt(x - 6, y - 14), control2: A.pt(x + 2, y - 4))
            land.addCurve(to: A.pt(x - 14, y - 6), control1: A.pt(x - 6, y + 8), control2: A.pt(x - 14, y + 4))
            land.move(to: A.pt(x + 6, y + 6))
            land.addCurve(to: A.pt(x + 12, y + 14), control1: A.pt(x + 12, y + 2), control2: A.pt(x + 18, y + 8))
            land.addCurve(to: A.pt(x + 6, y + 6), control1: A.pt(x + 8, y + 16), control2: A.pt(x + 4, y + 12))
            inner.fill(land, with: .color(A.floresta))
            A.stroke(inner, land, A.sage.opacity(0.9), 1)
        case "mars":
            // Fobos e Deimos, pequenos e irregulares
            for (x, y, rx, ry, rot) in [(78.0, 112.0, 9.0, 6.5, 0.4), (132.0, 74.0, 5.0, 4.0, -0.3)] {
                let moon = A.ellipse(0, 0, rx, ry).applying(CGAffineTransform(rotationAngle: rot)).applying(CGAffineTransform(translationX: x, y: y))
                A.fillStroke(c, moon, line: A.cream(0.85), width: 1.4)
            }
        case "neptune":
            // Tritão, a lua de Netuno
            let disc = A.circle(92, 118, 12)
            c.fill(disc, with: .color(A.bg))
            c.fill(disc, with: .color(A.luar.opacity(0.2)))
            A.stroke(c, disc, A.cream(0.85), 1.4)
        default:
            break
        }
    }

    /// Pousando EM Saturno: o anel nasce do horizonte e cruza o céu na diagonal, por trás
    /// do foguete e do chão. Preso ao chão, então sobe junto com ele.
    private static func saturnRing(_ ctx: GraphicsContext, surface S: Double) {
        var c = ctx
        c.translateBy(x: 75, y: S + 150)
        c.rotate(by: .radians(-0.55))
        let k = 0.2
        var band = A.ellipse(0, 0, 760, 760 * k)
        band.addPath(A.ellipse(0, 0, 580, 580 * k))
        c.fill(band, with: .color(A.amber.opacity(0.08)), style: FillStyle(eoFill: true))
        for (r, a, w) in [(760.0, 1.0, 1.8), (730, 0.45, 1.1), (700, 0.75, 1.4), (652, 0.3, 1), (622, 0.6, 1.3), (580, 0.25, 1)] {
            A.stroke(c, A.ellipse(0, 0, r, r * k), A.cream(a), w)
        }
        // divisão de Cassini
        A.stroke(c, A.ellipse(0, 0, 676, 676 * k), A.bg.opacity(0.75), 7)
    }

    private static func drawGround(_ ctx: GraphicsContext, id: String, surface S: Double) {
        let R = 1800.0
        let disc = A.circle(195, S + R, R)
        ctx.fill(disc, with: .color(A.ground))
        A.stroke(ctx, disc, A.cream(0.9), 2)
        var c = ctx
        c.clip(to: disc)
        let area = Path(CGRect(x: -400, y: S - 20, width: 1190, height: 1300))
        switch id {
        case "moon": c.fill(area, with: .color(A.creme))
        case "mars": c.fill(area, with: .color(A.marsGround))
        default:
            let lk = PlanetPainter.look(id)
            c.fill(area, with: .color(lk.tint.opacity(0.07)))
        }
        switch id {
        case "moon":
            for k in craters { A.stroke(c, A.ellipse(195 + k.0, S + k.1, k.2, k.2 * 0.24), A.grafite.opacity(0.55), 1.3) }
        case "mars":
            let line = A.peach.opacity(0.55)
            for (i, d) in [34.0, 78, 132, 196, 270].enumerated() {
                var dune = Path()
                var x = -10.0
                let fi = Double(i)
                while x <= 400 {
                    let y = S + d + sin(x / (38 + fi * 9) + fi) * (5 + fi * 1.5)
                    if x == -10 { dune.move(to: A.pt(x, y)) } else { dune.addLine(to: A.pt(x, y)) }
                    x += 6
                }
                A.stroke(c, dune, line, 1.3)
            }
            for k in rocks {
                let x = 195 + k.0, y = S + k.1, r = k.2
                var rock = Path()
                rock.move(to: A.pt(x - r, y))
                rock.addQuadCurve(to: A.pt(x, y - r * 0.8), control: A.pt(x - r * 0.8, y - r * 0.9))
                rock.addQuadCurve(to: A.pt(x + r, y), control: A.pt(x + r * 0.9, y - r * 0.7))
                rock.closeSubpath()
                A.fillStroke(c, rock, fill: Color(sceneHex: 0x7A4630), line: line, width: 1.3)
            }
        case "saturn":
            for k in [(-120.0, 40.0, 70.0), (40, 30, 90), (-40, 120, 120), (110, 150, 80)] {
                let x = 195 + k.0, y = S + k.1, w = k.2
                var crack = Path()
                crack.move(to: A.pt(x - w / 2, y))
                crack.addLine(to: A.pt(x - w / 6, y - 4))
                crack.addLine(to: A.pt(x + w / 5, y + 3))
                crack.addLine(to: A.pt(x + w / 2, y - 2))
                A.stroke(c, crack, A.cream(0.3), 1.3)
            }
            for k in rocks { c.fill(A.circle(195 + k.0, S + k.1 + 6, k.2 * 0.35), with: .color(A.cream(0.35))) }
        case "neptune":
            for k in crystals {
                let x = 195 + k.0, y = S + k.1, h = k.2
                for q in [(-0.5, 0.8), (0.0, 1.3), (0.55, 0.9)] {
                    let bx = x + q.0 * h * 0.7, hh = h * q.1
                    var shard = Path()
                    shard.move(to: A.pt(bx - h * 0.22, y))
                    shard.addLine(to: A.pt(bx, y - hh))
                    shard.addLine(to: A.pt(bx + h * 0.22, y))
                    shard.closeSubpath()
                    A.fillStroke(c, shard, fill: A.luar.opacity(0.18), line: A.cream(0.3), width: 1.3)
                }
            }
        default:
            break
        }
    }
}

// MARK: - Astronauta

/// O astronauta do protótipo antigo do pouso: roupa clara preenchida com contorno grafite
/// (igual à cúpula acesa do desenho da luminária), mochila, botas, painel terracota no
/// peito e visor azul. Pés em (x, y), virado pra direita.
enum AstronautArt {
    static let suit = Color(sceneHex: 0xEFE8D6)

    static func draw(_ ctx: GraphicsContext, x: Double, y: Double, clock: Double, walking: Bool, waving: Bool) {
        let ph = walking ? sin(clock * 7) : 0
        var c = ctx
        c.translateBy(x: x, y: y)
        c.scaleBy(x: 1.25, y: 1.25)
        func part(_ g: GraphicsContext, _ px: Double, _ py: Double, _ w: Double, _ h: Double, _ r: Double, _ fill: Color) {
            LineArt.fillStroke(g, LineArt.rrect(px, py, w, h, r), fill: fill, line: LineArt.grafite, width: 0.9)
        }
        func leg(_ dx: Double, _ angle: Double, _ shade: Color) {
            var g = c
            g.translateBy(x: dx + 2.25, y: -10)
            g.rotate(by: .radians(angle))
            part(g, -2.25, 0, 4.5, 10, 2, shade)
            part(g, -2.75, 7.5, 5.5, 2.8, 1, Color(sceneHex: 0x5A5D66))
        }
        part(c, -10, -25, 6, 13, 2, Color(sceneHex: 0xD9D1BC))   // mochila
        leg(-5, ph * 0.4, Color(sceneHex: 0xE2DBC8))             // perna de trás
        leg(0.5, -ph * 0.4, suit)                                 // perna da frente
        part(c, -10, -20, 4, 10, 2, Color(sceneHex: 0xE2DBC8))   // braço de trás
        part(c, -7, -22, 14, 13, 4, suit)                         // corpo
        c.fill(LineArt.rrect(-3, -18, 6, 3.6, 1), with: .color(LineArt.terra))
        LineArt.fillStroke(c, LineArt.circle(0, -27, 7.5), fill: suit, line: LineArt.grafite, width: 0.9)
        LineArt.fillStroke(c, LineArt.ellipse(1.8, -27, 5, 4), fill: Color(sceneHex: 0x2F3A4D), line: LineArt.grafite, width: 0.9)
        c.fill(LineArt.ellipse(3.4, -28.4, 1.6, 1), with: .color(LineArt.luar))
        var arm = c
        arm.translateBy(x: 7.5, y: -19)
        arm.rotate(by: .radians(waving ? -2.5 + 0.45 * sin(clock * 5) : ph * -0.3))
        part(arm, -2, -1, 4, 10, 2, suit)
    }
}

// MARK: - Mapa da jornada

/// Os quatro destinos ligados por uma rota: o trecho feito em âmbar, o que falta
/// pontilhado; planeta alcançado em traço cheio, o que falta tracejado; um foguetinho
/// mostra onde a sequência atual está. Usado no relatório de sono.
struct JourneyMapView: View {
    let streak: Int
    let theme: ModeTheme

    var body: some View {
        Canvas { ctx, size in
            JourneyMapPainter.draw(ctx, size: size, streak: streak, line: theme.ink, fill: theme.stage, muted: theme.inkMuted)
        }
        .frame(height: 132)
        .accessibilityElement()
        .accessibilityLabel(JourneyMapPainter.accessibilityText(streak: streak))
    }
}

enum JourneyMapPainter {
    typealias A = LineArt

    static func draw(_ ctx: GraphicsContext, size: CGSize, streak: Int, line: Color, fill: Color, muted: Color) {
        let planets = PlanetMilestones.all
        let w = size.width
        let xs = planets.indices.map { w * (0.1 + 0.8 * Double($0) / Double(max(planets.count - 1, 1))) }
        let y = 56.0
        let s = Double(streak)
        // posição do foguete na rota
        var rocketX = xs[xs.count - 1]
        var nextIndex: Int?
        for i in 0..<(planets.count - 1) where s < Double(planets[i + 1].requiredStreakDays) {
            let a = Double(planets[i].requiredStreakDays), b = Double(planets[i + 1].requiredStreakDays)
            rocketX = A.lerp(xs[i], xs[i + 1], (s - a) / (b - a))
            nextIndex = i + 1
            break
        }
        A.stroke(ctx, A.line(xs[0], y, rocketX, y), A.amber.opacity(0.95), 2)
        A.stroke(ctx, A.line(rocketX, y, xs[xs.count - 1], y), line.opacity(0.4), 2, dash: [2, 8])
        for (i, p) in planets.enumerated() {
            let reached = streak >= p.requiredStreakDays
            PlanetPainter.draw(ctx, id: p.id, x: xs[i], y: y, r: p.id == "saturn" ? 13 : 16, dashed: !reached,
                               alpha: reached ? 1 : 0.6, line: line, fill: fill)
            A.text(ctx, p.name.lowercased(), at: A.pt(xs[i], 98), size: 13, color: reached ? line : muted)
            A.text(ctx, p.requiredStreakDays == 0 ? "1ª noite" : "\(p.requiredStreakDays) noites", at: A.pt(xs[i], 116), size: 11, weight: .regular, color: muted)
        }
        if let nextIndex {
            var r = ctx
            r.translateBy(x: rocketX, y: y - 22)
            r.rotate(by: .radians(.pi / 2))
            r.scaleBy(x: 0.26, y: 0.26)
            RocketLine.draw(r, at: .zero, line: line, fill: fill)
            let left = planets[nextIndex].requiredStreakDays - streak
            A.text(ctx, "faltam \(left) \(left == 1 ? "noite" : "noites")", at: A.pt(rocketX, y - 40), size: 11, color: line)
        }
    }

    static func accessibilityText(streak: Int) -> String {
        guard let next = PlanetMilestones.next(afterStreak: streak) else {
            return "Jornada completa: todos os planetas alcançados."
        }
        let left = next.requiredStreakDays - streak
        return "Rumo a \(next.name): faltam \(left) \(left == 1 ? "noite" : "noites")."
    }
}
