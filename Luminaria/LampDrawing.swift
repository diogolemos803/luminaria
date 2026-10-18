import SwiftUI

/// Cor aproximada da LUZ da lâmpada na tela: âmbar e vermelho somados como luz (aditivo) e
/// normalizados pro canal mais forte — a mesma conta de `design/lampada_prototipo.html`.
enum LampDisplayColor {
    private static let amberLED: (Double, Double, Double) = (255, 176, 28)
    private static let redLED: (Double, Double, Double) = (255, 36, 8)

    /// RGB 0…255 da cor cheia de uma mistura.
    static func rgb(mix: Double) -> (Double, Double, Double) {
        let full = LampColor.full(mix: mix)
        let r = amberLED.0 * full.amber / 255 + redLED.0 * full.red / 255
        let g = amberLED.1 * full.amber / 255 + redLED.1 * full.red / 255
        let b = amberLED.2 * full.amber / 255 + redLED.2 * full.red / 255
        let peak = max(r, g, b, 1)
        return (r * 255 / peak, g * 255 / peak, b * 255 / peak)
    }

    static func color(mix: Double) -> Color {
        let c = rgb(mix: mix)
        return Color(red: c.0 / 255, green: c.1 / 255, blue: c.2 / 255)
    }

    /// Degradê do controle de mistura (amarelo → vermelho).
    static let mixGradient: [Color] = stride(from: 0.0, through: 1.0, by: 0.25).map { color(mix: $0) }
}

/// Desenho da luminária (referência do usuário: `design/referencia_luminaria.png`),
/// parado no centro da tela da lâmpada; a cúpula acende na cor e no brilho de agora.
///
/// Mesma geometria do protótipo aprovado, no espaço de coordenadas da referência
/// (1080×1350): câmera só inclinada, então círculos horizontais viram elipses deitadas
/// (altura = 0,49 × largura); base em forma de pílula girada ~29° no chão, com a bandeja
/// rebaixada à direita. Traço de 1,4 pt fixo, em qualquer tamanho.
struct LampIllustration: View {
    var isOn: Bool
    var mix: Double
    var brightness: Double
    var line: Color
    var stage: Color
    var isNight: Bool

    private static let viewBox = CGRect(x: 262, y: 430, width: 756, height: 580)
    private static let yaw = 29.2 * Double.pi / 180
    private static let k = 0.49
    private static let origin = (x: 436.0, y: 765.0)
    private static let baseLength = 468.0
    private static let baseRadius = 150.0
    private static let baseThickness = 40.0

    var body: some View {
        Canvas { context, size in
            let vb = Self.viewBox
            let s = min(size.width / vb.width, size.height / vb.height)
            let ox = (size.width - vb.width * s) / 2 - vb.minX * s
            let oy = (size.height - vb.height * s) / 2 - vb.minY * s
            func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }
            func poly(_ points: [(Double, Double)]) -> Path {
                var path = Path()
                guard let first = points.first else { return path }
                path.move(to: pt(first.0, first.1))
                for p in points.dropFirst() { path.addLine(to: pt(p.0, p.1)) }
                path.closeSubpath()
                return path
            }
            let lineStyle = StrokeStyle(lineWidth: 1.4, lineJoin: .round)

            // Luz em volta da cúpula
            let led = LampDisplayColor.color(mix: mix)
            if isOn {
                context.drawLayer { layer in
                    let r = 300 * s
                    layer.translateBy(x: pt(436, 610).x, y: pt(436, 610).y)
                    layer.scaleBy(x: 1, y: 260.0 / 300.0)
                    layer.fill(
                        Path(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r)),
                        with: .radialGradient(
                            Gradient(colors: [led.opacity((isNight ? 0.55 : 0.35) * brightness), led.opacity(0)]),
                            center: .zero, startRadius: 0, endRadius: r
                        )
                    )
                }
            }

            // Base: fundo deslocado pra baixo (só a borda da frente aparece), laterais, topo
            let baseBottom = poly(Self.pill(radius: Self.baseRadius, drop: Self.baseThickness))
            context.fill(baseBottom, with: .color(stage))
            context.stroke(baseBottom, with: .color(line), style: lineStyle)
            for p in Self.sideEdges() {
                var side = Path()
                side.move(to: pt(p.0, p.1))
                side.addLine(to: pt(p.0, p.1 + Self.baseThickness))
                context.stroke(side, with: .color(line), style: lineStyle)
            }
            let baseTop = poly(Self.pill(radius: Self.baseRadius))
            context.fill(baseTop, with: .color(stage))
            context.stroke(baseTop, with: .color(line), style: lineStyle)

            // Luz caindo na base
            if isOn {
                context.drawLayer { layer in
                    layer.clip(to: baseTop)
                    let r = 260 * s
                    layer.translateBy(x: pt(470, 790).x, y: pt(470, 790).y)
                    layer.scaleBy(x: 1, y: 110.0 / 260.0)
                    layer.fill(
                        Path(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r)),
                        with: .radialGradient(
                            Gradient(colors: [led.opacity((isNight ? 0.35 : 0.2) * brightness), led.opacity(0)]),
                            center: .zero, startRadius: 0, endRadius: r
                        )
                    )
                }
            }

            // Bandeja: contorno + fundo rebaixado (só visível dentro dela)
            let tray = poly(Self.pill(radius: Self.baseRadius - 24, cutAt: 150))
            context.stroke(tray, with: .color(line), style: lineStyle)
            context.drawLayer { layer in
                layer.clip(to: tray)
                layer.stroke(poly(Self.pill(radius: Self.baseRadius - 24, drop: 13, cutAt: 150)),
                             with: .color(line.opacity(0.45)), style: StrokeStyle(lineWidth: 1.1, lineJoin: .round))
            }

            // Cúpula: colar escuro embaixo, cilindro aceso em cima
            let cx = 436.0, rx = 117.0, ry = rx * Self.k, collarTop = 722.0, shadeTop = 517.0
            func halfEllipse(cy: Double, from a0: Double, to a1: Double) -> [(Double, Double)] {
                (0...24).map { i -> (Double, Double) in
                    let a = a0 + (a1 - a0) * Double(i) / 24
                    return (cx + rx * cos(a), cy + ry * sin(a))
                }
            }
            let collar = poly([(cx - rx, collarTop)] + halfEllipse(cy: Self.origin.y, from: .pi, to: 0) + [(cx + rx, collarTop)])
            context.fill(collar, with: .color(stage))
            context.stroke(collar, with: .color(line), style: lineStyle)

            let shade = poly(halfEllipse(cy: collarTop, from: .pi, to: 0) + halfEllipse(cy: shadeTop, from: 0, to: -.pi))
            context.fill(shade, with: .color(shadeColor))
            let shadeLine = isOn ? stage : line
            context.stroke(shade, with: .color(shadeLine), style: lineStyle)
            let top = Path(ellipseIn: CGRect(x: pt(cx - rx, shadeTop - ry).x, y: pt(cx - rx, shadeTop - ry).y,
                                             width: 2 * rx * s, height: 2 * ry * s))
            context.stroke(top, with: .color(shadeLine), style: lineStyle)
        }
        .accessibilityHidden(true)
    }

    /// Tecido claro tingido pela luz; brilho baixo deixa a cúpula mais escura.
    private var shadeColor: Color {
        guard isOn else { return stage }
        let stageRGB: (Double, Double, Double) = isNight ? (68, 68, 68) : (255, 255, 255)
        let led = LampDisplayColor.rgb(mix: mix)
        func lerp(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ t: Double) -> (Double, Double, Double) {
            (a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t, a.2 + (b.2 - a.2) * t)
        }
        let lit = lerp((255, 247, 214), led, 0.25 + 0.45 * mix)
        let dim = lerp(stageRGB, led, 0.35)
        let c = lerp(dim, lit, pow(max(brightness, 0), 0.6))
        return Color(red: c.0 / 255, green: c.1 / 255, blue: c.2 / 255)
    }

    private static func project(_ u: Double, _ v: Double, drop: Double = 0) -> (Double, Double) {
        (origin.x + u * cos(yaw) - v * sin(yaw), origin.y + (u * sin(yaw) + v * cos(yaw)) * k + drop)
    }

    /// Pílula no chão (centros em u = 0 e u = `baseLength`); `cutAt` corta a ponta
    /// esquerda numa reta (a bandeja).
    private static func pill(radius r: Double, drop: Double = 0, cutAt: Double? = nil) -> [(Double, Double)] {
        var points: [(Double, Double)] = []
        for i in 0...32 {
            let t = -Double.pi / 2 + Double.pi * Double(i) / 32
            points.append(project(baseLength + r * cos(t), r * sin(t), drop: drop))
        }
        if let cutAt {
            points.append(project(cutAt, r, drop: drop))
            points.append(project(cutAt, -r, drop: drop))
        } else {
            for i in 0...32 {
                let t = Double.pi / 2 + Double.pi * Double(i) / 32
                points.append(project(r * cos(t), r * sin(t), drop: drop))
            }
        }
        return points
    }

    /// Pontos mais à esquerda e à direita da base, onde descem as laterais.
    private static func sideEdges() -> [(Double, Double)] {
        let points = (0...64).map { i -> (Double, Double) in
            let t = Double.pi * 2 * Double(i) / 64
            let u = (cos(t) > 0 ? baseLength : 0) + baseRadius * cos(t)
            return project(u, baseRadius * sin(t))
        }
        guard let left = points.min(by: { $0.0 < $1.0 }), let right = points.max(by: { $0.0 < $1.0 }) else { return [] }
        return [left, right]
    }
}

/// Ícone da bolinha do canto na tela inicial: cúpula em miniatura, preenchida com a cor
/// atual da lâmpada (vazia quando apagada).
struct LampGlyph: View {
    var fill: Color?
    var line: Color

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height) / 24
            func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            // Cúpula: laterais retas, fundo em meia elipse achatada (mesma câmera do desenho grande)
            let cx = 12.0, rx = 5.5, ry = 2.4, top = 5.5, bottom = 15.0
            var shade = Path()
            shade.move(to: p(cx - rx, top))
            shade.addLine(to: p(cx - rx, bottom))
            for i in 1...16 {
                let a = Double.pi - Double.pi * Double(i) / 16
                shade.addLine(to: p(cx + rx * cos(a), bottom + ry * sin(a)))
            }
            shade.addLine(to: p(cx + rx, top))
            for i in 1...16 {
                let a = -Double.pi * Double(i) / 16
                shade.addLine(to: p(cx + rx * cos(a), top + ry * sin(a)))
            }
            shade.closeSubpath()
            if let fill { context.fill(shade, with: .color(fill)) }
            context.stroke(shade, with: .color(line), style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
            let rim = Path(ellipseIn: CGRect(x: (cx - rx) * s, y: (top - ry) * s, width: 2 * rx * s, height: 2 * ry * s))
            context.stroke(rim, with: .color(line.opacity(0.7)), lineWidth: 1.1)
            var base = Path()
            base.move(to: p(3, 20.5))
            base.addLine(to: p(21, 20.5))
            context.stroke(base, with: .color(line), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}

/// Controle deslizante com trilho em degradê (o `Slider` do sistema não deixa pintar o
/// trilho). Valor de 0 a 1.
struct GradientSlider: View {
    @Binding var value: Double
    var lowerBound: Double = 0
    var colors: [Color]
    var accessibilityLabel: String

    private let thumb: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let usable = max(geo.size.width - thumb, 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .frame(height: 10)
                    .padding(.horizontal, thumb / 2 - 5)
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .frame(width: thumb, height: thumb)
                    .offset(x: usable * value)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { g in
                    let t = Double((g.location.x - thumb / 2) / usable)
                    value = min(max(t, lowerBound), 1)
                }
            )
        }
        .frame(height: 32)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue("\(Int((value * 100).rounded()))%")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 0.05, 1)
            case .decrement: value = max(value - 0.05, lowerBound)
            @unknown default: break
            }
        }
    }
}

/// Faixa com a prévia de uma luz no tempo (apagar devagar, amanhecer) — fundo escuro de
/// quarto, a luz por cima com a opacidade do brilho.
struct LampTimelinePreview: View {
    /// (mistura, brilho) em cada ponto de 0 a 1 do tempo.
    var sample: (Double) -> (mix: Double, brightness: Double)

    var body: some View {
        let stops = (0...32).map { i -> Gradient.Stop in
            let t = Double(i) / 32
            let v = sample(t)
            return Gradient.Stop(color: LampDisplayColor.color(mix: v.mix).opacity(v.brightness), location: t)
        }
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(red: 0.12, green: 0.118, blue: 0.11))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(gradient: Gradient(stops: stops), startPoint: .leading, endPoint: .trailing))
            )
            .frame(height: 34)
            .accessibilityHidden(true)
    }
}
