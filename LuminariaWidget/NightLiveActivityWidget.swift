import ActivityKit
import SwiftUI
import WidgetKit

/// Atividade ao Vivo da noite (protótipo aprovado em `design/widget_prototipo.html`):
/// cartão colorido na tela bloqueada + Dynamic Island, do reconhecimento da luminária até
/// o fim da noite. A contagem (`Text(_:style: .relative/.timer)`) e a barra
/// (`ProgressView(timerInterval:)`) andam pelo relógio do sistema, sem o app rodar. O app
/// (`WidgetBridge`) inicia, marca o impacto do meteoro e encerra.
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
                    NightStreak(streak: context.state.streak)
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
                        .frame(width: 13, height: 13)
                } else {
                    BoomGlyph().frame(width: 13, height: 13)
                }
            } compactTrailing: {
                Text(context.attributes.alarmDate, style: .timer)
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(NightPalette.moon)
                    .frame(maxWidth: 52)
            } minimal: {
                RocketGlyph()
                    .fill(NightPalette.moon, style: FillStyle(eoFill: true))
                    .frame(width: 12, height: 12)
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
                NightStreak(streak: state.streak)
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
            return Text("Foguete novo lançado ") + Text(impact, style: .time)
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
                BoomGlyph().frame(width: 16, height: 16)
                Text(compact ? "Meteoro!" : "Um meteoro atingiu o foguete")
            }
        }
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(state.impactAt == nil ? NightPalette.cream : NightPalette.impact)
        .lineLimit(1)
    }
}

private struct NightStreak: View {
    let streak: Int

    var body: some View {
        Label {
            Text(streak == 1 ? "1 noite" : "\(streak) noites")
        } icon: {
            Image(systemName: "flame.fill")
        }
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(NightPalette.terra)
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

/// Terra ——— barra que enche pelo relógio ——— planeta de destino.
private struct NightTrack: View {
    let attributes: NightSessionActivityAttributes
    let state: NightSessionActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            PlanetGlyph(id: "earth").frame(width: 14, height: 14)
            ProgressView(timerInterval: travelInterval, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(state.impactAt == nil ? NightPalette.moon : NightPalette.impact)
            PlanetGlyph(id: attributes.destinationID).frame(width: 22, height: 14)
        }
    }

    /// Depois de um meteoro a viagem recomeça do impacto.
    private var travelInterval: ClosedRange<Date> {
        let start = state.impactAt ?? attributes.sessionStart
        let end = attributes.alarmDate
        return start < end ? start...end : end.addingTimeInterval(-1)...end
    }
}

/// Planetas desenhados com formas simples (sem imagem), nas cores da cena do app.
private struct PlanetGlyph: View {
    let id: String

    var body: some View {
        ZStack {
            switch id {
            case "earth":
                Circle().fill(Color(red: 0.31, green: 0.50, blue: 0.37))
                Circle().fill(Color(red: 0.16, green: 0.34, blue: 0.56)).scaleEffect(0.5).offset(x: 2, y: -2)
            case "mars":
                Circle().fill(Color(red: 0.80, green: 0.42, blue: 0.30)).padding(2)
            case "saturn":
                Circle().fill(Color(red: 0.86, green: 0.72, blue: 0.48)).padding(.vertical, 2.5).padding(.horizontal, 6)
                Ellipse().stroke(Color(red: 0.88, green: 0.78, blue: 0.56), lineWidth: 1.4).padding(.vertical, 4.5)
            case "neptune":
                Circle().fill(NightPalette.moon).padding(2)
            default:
                Circle().fill(Color(red: 0.82, green: 0.82, blue: 0.80)).padding(2)
            }
        }
    }
}

/// Clarão laranja do meteoro.
private struct BoomGlyph: View {
    var body: some View {
        Circle().fill(
            RadialGradient(
                colors: [Color(red: 1, green: 0.95, blue: 0.81), Color(red: 1, green: 0.76, blue: 0.35), Color(red: 0.94, green: 0.44, blue: 0.18)],
                center: .center,
                startRadius: 0,
                endRadius: 8
            )
        )
    }
}

/// Foguete do protótipo (caminho SVG 24×24 convertido), com a janela vazada (eoFill).
private struct RocketGlyph: Shape {
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
