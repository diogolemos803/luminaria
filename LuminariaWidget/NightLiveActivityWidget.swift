import ActivityKit
import SwiftUI
import WidgetKit

/// Atividade ao Vivo da noite (protótipo aprovado em `design/widget_prototipo.html`):
/// cartão colorido na tela bloqueada + Dynamic Island, do reconhecimento da luminária até
/// o fim da noite. A contagem (`Text(_:style: .relative/.timer)`) e a barra
/// (`ProgressView(timerInterval:)`) andam pelo relógio do sistema, sem o app rodar. O app
/// (`WidgetBridge`) inicia, marca o impacto do meteoro e encerra. Depois do meteoro o cartão
/// passa pro estado "em obras" (protótipo `design/meteoro_prototipo.html`): o foguete é
/// reconstruído até o despertador e a noite não conta pra sequência.
///
/// Limite da plataforma: a barra enche sozinha, mas nenhum desenho próprio (o foguete)
/// consegue andar junto com ela — por isso a Terra e o planeta ficam nas pontas.
struct NightLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NightSessionActivityAttributes.self) { context in
            NightLiveActivityCard(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(context.state.impactAt == nil ? NightPalette.card : NightPalette.cardHit)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "luminaria://open"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    NightKicker(state: context.state, compact: true)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    NightStreak(state: context.state)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        NightCountdown(alarmDate: context.attributes.alarmDate)
                        NightTrack(attributes: context.attributes, state: context.state)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                if context.state.impactAt == nil {
                    RocketGlyph()
                        .fill(NightPalette.moon, style: FillStyle(eoFill: true))
                        .rotationEffect(.degrees(90))
                        .frame(width: 13, height: 13)
                } else {
                    BuildGlyph(size: 12)
                }
            } compactTrailing: {
                Text(context.attributes.alarmDate, style: .timer)
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(NightPalette.moon)
                    .frame(maxWidth: 52)
            } minimal: {
                if context.state.impactAt == nil {
                    RocketGlyph()
                        .fill(NightPalette.moon, style: FillStyle(eoFill: true))
                        .rotationEffect(.degrees(90))
                        .frame(width: 12, height: 12)
                } else {
                    BuildGlyph(size: 11)
                }
            }
            .widgetURL(URL(string: "luminaria://open"))
            .keylineTint(NightPalette.moon)
        }
    }
}

// MARK: - Cartão da tela bloqueada

private struct NightLiveActivityCard: View {
    let attributes: NightSessionActivityAttributes
    let state: NightSessionActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                NightKicker(state: state, compact: false)
                Spacer(minLength: 8)
                NightStreak(state: state)
            }
            NightCountdown(alarmDate: attributes.alarmDate)
            NightTrack(attributes: attributes, state: state)
            HStack {
                footerLeft
                Spacer(minLength: 8)
                (Text("Acorda ") + Text(attributes.alarmDate, style: .time))
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(NightPalette.muted)
        }
        .padding(14)
    }

    private var footerLeft: Text {
        if let impact = state.impactAt {
            return Text("Em obras desde ") + Text(impact, style: .time)
        }
        return Text("Desde ") + Text(attributes.sessionStart, style: .time) + Text(" sem mexer")
    }
}

// MARK: - Peças

private enum NightPalette {
    static let card = Color(red: 0.07, green: 0.09, blue: 0.16)
    static let cardHit = Color(red: 0.13, green: 0.09, blue: 0.12)
    static let moon = Color(red: 0.518, green: 0.631, blue: 0.784)   // SoveeColor.noiteAzul
    static let cream = Color(red: 0.992, green: 0.973, blue: 0.780)  // SoveeColor.creme
    static let terra = Color(red: 0.859, green: 0.506, blue: 0.286)  // SoveeColor.terracota
    static let impact = Color(red: 1.0, green: 0.725, blue: 0.541)
    /// Amarelo dos capacetes/guindaste do canteiro de obras.
    static let build = Color(red: 0.957, green: 0.753, blue: 0.180)
    static let muted = Color(red: 0.60, green: 0.63, blue: 0.68)
}

private struct NightKicker: View {
    let state: NightSessionActivityAttributes.ContentState
    let compact: Bool

    var body: some View {
        HStack(spacing: 6) {
            if state.impactAt == nil {
                RocketGlyph()
                    .fill(NightPalette.cream, style: FillStyle(eoFill: true))
                    .frame(width: 14, height: 14)
                Text("Foguete em voo")
            } else {
                BuildGlyph(size: 13)
                Text(compact ? "Em obras" : "Foguete em obras")
            }
        }
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(state.impactAt == nil ? NightPalette.cream : NightPalette.build)
        .lineLimit(1)
    }
}

/// Sequência de noites limpas — depois do meteoro a noite já não conta, então mostra que
/// a sequência foi perdida (o número salvo só zera quando a noite termina).
private struct NightStreak: View {
    let state: NightSessionActivityAttributes.ContentState

    var body: some View {
        Label {
            if state.impactAt != nil {
                Text("Sequência perdida")
            } else {
                Text(state.streak == 1 ? "1 noite" : "\(state.streak) noites")
            }
        } icon: {
            Image(systemName: state.impactAt == nil ? "flame.fill" : "flame")
        }
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(state.impactAt == nil ? NightPalette.terra : NightPalette.muted)
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
    }
}

private struct NightCountdown: View {
    let alarmDate: Date

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(alarmDate, style: .relative)
                .font(.system(size: 22, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text("até o despertador")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NightPalette.muted)
        }
        .lineLimit(1)
    }
}

/// Rota da noite (protótipo v2): Terra · foguete deitado com chama, apontando pro planeta ·
/// barra que enche pelo relógio · planeta de destino. O foguete fica parado de propósito:
/// a barra é desenhada pelo iOS e anda sozinha, mas desenhos do app só mudam quando o app
/// roda — um foguete "andando" ficaria preso no começo enquanto a barra avança.
private struct NightTrack: View {
    let attributes: NightSessionActivityAttributes
    let state: NightSessionActivityAttributes.ContentState

    var body: some View {
        if state.impactAt == nil {
            flightTrack
        } else {
            constructionTrack
        }
    }

    private var flightTrack: some View {
        HStack(spacing: 6) {
            PlanetGlyph(id: "earth").frame(width: 22, height: 22)
            SidewaysRocket(showsFlame: true).frame(width: 27, height: 16)
            ProgressView(timerInterval: travelInterval, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(state.impactAt == nil ? NightPalette.moon : NightPalette.impact)
            // barra mais grossa: não existe altura configurável pra essa barra do sistema,
            // o jeito que funciona é esticar na vertical
            .scaleEffect(x: 1, y: 2.4, anchor: .center)
            PlanetGlyph(id: attributes.destinationID).frame(width: 34, height: 22)
        }
    }

    /// Em obras: martelo · barra amarela enchendo do impacto até o despertador (a obra) ·
    /// o foguete de pé, que fica pronto pra próxima noite.
    private var constructionTrack: some View {
        HStack(spacing: 6) {
            BuildGlyph(size: 16).frame(width: 22, height: 22)
            ProgressView(timerInterval: travelInterval, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(NightPalette.build)
            .scaleEffect(x: 1, y: 2.4, anchor: .center)
            RocketGlyph()
                .fill(Color(red: 0.95, green: 0.93, blue: 0.89), style: FillStyle(eoFill: true))
                .frame(width: 22, height: 22)
        }
    }

    /// Voo: do início da noite até o despertador. Obra: do impacto até o despertador.
    private var travelInterval: ClosedRange<Date> {
        let start = state.impactAt ?? attributes.sessionStart
        let end = attributes.alarmDate
        return start < end ? start...end : end.addingTimeInterval(-1)...end
    }
}

/// Foguete de lado (bico pro planeta) com uma chaminha atrás.
private struct SidewaysRocket: View {
    let showsFlame: Bool

    var body: some View {
        HStack(spacing: -3) {
            if showsFlame {
                ZStack {
                    FlameTail().fill(Color(red: 1, green: 0.71, blue: 0.36).opacity(0.9))
                    FlameTail().fill(Color(red: 1, green: 0.95, blue: 0.81)).scaleEffect(x: 0.6, y: 0.5, anchor: .trailing)
                }
                .frame(width: 10, height: 7)
            }
            RocketGlyph()
                .fill(Color(red: 0.95, green: 0.93, blue: 0.89), style: FillStyle(eoFill: true))
                .rotationEffect(.degrees(90))
                .frame(width: 17, height: 17)
        }
    }
}

/// Chama deitada: ponta fina à esquerda, larga encostada no foguete.
private struct FlameTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.1))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.1))
        p.closeSubpath()
        return p
    }
}

/// Planetas desenhados com formas simples (sem imagem), nas cores da cena do app — maiores
/// e com mais detalhe na v2 (continente na Terra, crateras em Marte, faixas e anel em
/// Saturno). Corpo sempre com 20pt; Saturno usa a largura extra pro anel.
private struct PlanetGlyph: View {
    let id: String

    var body: some View {
        ZStack {
            switch id {
            case "earth":
                Circle().fill(Color(red: 0.25, green: 0.44, blue: 0.31)).frame(width: 20, height: 20)
                Ellipse().fill(Color(red: 0.16, green: 0.34, blue: 0.56))
                    .frame(width: 12, height: 8).rotationEffect(.degrees(-20)).offset(x: 2, y: -2)
                Ellipse().fill(Color(red: 0.16, green: 0.34, blue: 0.56))
                    .frame(width: 6, height: 4).offset(x: -5, y: 5)
                Circle().stroke(Color(red: 0.72, green: 0.84, blue: 0.76).opacity(0.5), lineWidth: 1).frame(width: 20, height: 20)
            case "mars":
                Circle().fill(Color(red: 0.80, green: 0.42, blue: 0.30)).frame(width: 20, height: 20)
                Circle().fill(Color(red: 0.62, green: 0.30, blue: 0.21)).frame(width: 5, height: 5).offset(x: -4, y: -3)
                Circle().fill(Color(red: 0.62, green: 0.30, blue: 0.21)).frame(width: 3.5, height: 3.5).offset(x: 4, y: 4)
                Circle().fill(Color(red: 0.62, green: 0.30, blue: 0.21)).frame(width: 2.5, height: 2.5).offset(x: 5, y: -4)
            case "saturn":
                Ellipse().stroke(Color(red: 0.91, green: 0.83, blue: 0.64), lineWidth: 1.8).frame(width: 33, height: 9)
                Circle().fill(Color(red: 0.86, green: 0.72, blue: 0.48)).frame(width: 16, height: 16)
                Rectangle().fill(Color(red: 0.72, green: 0.58, blue: 0.35)).frame(width: 15, height: 1.2).offset(y: -2)
                Rectangle().fill(Color(red: 0.72, green: 0.58, blue: 0.35)).frame(width: 15, height: 1.2).offset(y: 2)
                // metade da frente do anel passa por cima do planeta
                SaturnRingFront().stroke(Color(red: 0.91, green: 0.83, blue: 0.64), lineWidth: 1.8).frame(width: 33, height: 9)
            case "neptune":
                Circle().fill(NightPalette.moon).frame(width: 20, height: 20)
                Capsule().fill(Color(red: 0.72, green: 0.80, blue: 0.91).opacity(0.7)).frame(width: 14, height: 2.5).offset(y: -2)
            default: // Lua
                Circle().fill(Color(red: 0.82, green: 0.82, blue: 0.80)).frame(width: 20, height: 20)
                Circle().fill(Color(red: 0.62, green: 0.63, blue: 0.64)).frame(width: 5, height: 5).offset(x: -4, y: -2)
                Circle().fill(Color(red: 0.62, green: 0.63, blue: 0.64)).frame(width: 3, height: 3).offset(x: 4, y: 4)
            }
        }
    }
}

/// Metade de baixo da elipse do anel (a que fica na frente do planeta).
private struct SaturnRingFront: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width / 2,
                 startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        return p.applying(
            CGAffineTransform(translationX: rect.midX, y: rect.midY)
                .scaledBy(x: 1, y: rect.height / rect.width)
                .translatedBy(x: -rect.midX, y: -rect.midY)
        )
    }
}

/// Martelo amarelo do canteiro de obras.
private struct BuildGlyph: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "hammer.fill")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(NightPalette.build)
    }
}

/// Foguete do protótipo (caminho SVG 24×24 convertido), com a janela vazada (eoFill).
/// Também usado pelo retângulo da tela bloqueada (`AlarmWidget`), por isso não é privado.
struct RocketGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let ox = rect.midX - 12 * s
        let oy = rect.midY - 12 * s
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }

        var path = Path()
        // corpo
        path.move(to: p(12, 2))
        path.addCurve(to: p(16.6, 11.4), control1: p(15, 4.2), control2: p(16.6, 7.6))
        path.addCurve(to: p(15.7, 16), control1: p(16.6, 13.1), control2: p(16.3, 14.7))
        path.addLine(to: p(8.3, 16))
        path.addCurve(to: p(7.4, 11.4), control1: p(7.7, 14.7), control2: p(7.4, 13.1))
        path.addCurve(to: p(12, 2), control1: p(7.4, 7.6), control2: p(9, 4.2))
        path.closeSubpath()
        // janela (vazada)
        path.addEllipse(in: CGRect(x: ox + 10.1 * s, y: oy + 8.2 * s, width: 3.8 * s, height: 3.8 * s))
        // barbatanas
        path.move(to: p(7.6, 14.6)); path.addLine(to: p(5.2, 17.9)); path.addLine(to: p(8.1, 17.3)); path.addLine(to: p(8.5, 15.7)); path.closeSubpath()
        path.move(to: p(16.4, 14.6)); path.addLine(to: p(18.8, 17.9)); path.addLine(to: p(15.9, 17.3)); path.addLine(to: p(15.5, 15.7)); path.closeSubpath()
        // bocal
        path.move(to: p(10, 17.2)); path.addLine(to: p(14, 17.2)); path.addLine(to: p(13.2, 20.8)); path.addLine(to: p(10.8, 20.8)); path.closeSubpath()
        return path
    }
}
