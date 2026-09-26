import WidgetKit
import SwiftUI

/// Widget da tela bloqueada em três tamanhos (protótipo aprovado em
/// `design/widget_prototipo.html`): círculo com a sequência de noites e o anel até o
/// próximo planeta, retângulo com planeta/barra/despertador, e a linha curta acima do
/// relógio. Olhar a tela bloqueada não conta como "mexer no celular" — é assim que a
/// pessoa acompanha o desafio sem arriscar a noite. Tocar abre o app (`widgetURL`).
///
/// Na tela bloqueada o iOS desenha todo widget num tom único translúcido (ignora cores
/// próprias) — por isso aqui é só forma, símbolo e texto. A parte colorida da noite é a
/// Atividade ao Vivo (`NightLiveActivityWidget`).
///
/// O `kind` continua o do widget antigo (só despertador), então quem já tinha adicionado
/// recebe a versão nova sem precisar colocar de novo.
struct LuminariaEntry: TimelineEntry {
    let date: Date
    let isArmed: Bool
    let nextFireDate: Date?
    /// Sequência que vale no instante da entrada (ver `StreakMath.effective`).
    let streak: Int
    let longestStreak: Int
}

struct LuminariaTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> LuminariaEntry {
        LuminariaEntry(date: Date(), isArmed: true, nextFireDate: Date().addingTimeInterval(7 * 3600), streak: 7, longestStreak: 12)
    }

    func getSnapshot(in context: Context, completion: @escaping (LuminariaEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: Date()))
    }

    /// Uma entrada agora e outra na próxima meia-noite — a sequência pode "quebrar" na
    /// virada do dia sem o app abrir (quem não teve noite limpa ontem volta pra 0).
    func getTimeline(in context: Context, completion: @escaping (Timeline<LuminariaEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)
        completion(Timeline(entries: [entry(at: now), entry(at: midnight)], policy: .after(midnight.addingTimeInterval(60))))
    }

    private func entry(at date: Date) -> LuminariaEntry {
        let defaults = UserDefaults(suiteName: SharedWidgetData.suiteName)
        let nextFire = (defaults?.object(forKey: SharedWidgetData.nextFireKey) as? Double).map { Date(timeIntervalSince1970: $0) }
        let lastClean = (defaults?.object(forKey: SharedWidgetData.lastCleanNightKey) as? Double).map { Date(timeIntervalSince1970: $0) }
        let stored = defaults?.integer(forKey: SharedWidgetData.currentStreakKey) ?? 0
        return LuminariaEntry(
            date: date,
            isArmed: defaults?.bool(forKey: SharedWidgetData.armedKey) ?? false,
            nextFireDate: nextFire,
            streak: StreakMath.effective(streak: stored, lastCleanNight: lastClean, now: date),
            longestStreak: defaults?.integer(forKey: SharedWidgetData.longestStreakKey) ?? 0
        )
    }
}

struct LuminariaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: LuminariaEntry

    var body: some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(for: .widget) { Color.clear }
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryInline:
            inline
        default:
            rectangular
        }
    }

    // MARK: Tamanhos

    /// Fundo de vidro do sistema (`AccessoryWidgetBackground`) atrás do anel — é o
    /// cartão translúcido do protótipo; sem ele o conteúdo fica solto sobre o papel de
    /// parede e some em fundos claros (achado no primeiro teste no iPhone).
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            circularGauge
        }
        .widgetURL(Self.openURL)
    }

    private var circularGauge: some View {
        Gauge(value: PlanetMilestones.progressToNext(streak: entry.streak)) {
            Image(systemName: "flame.fill")
        } currentValueLabel: {
            VStack(spacing: -1) {
                Text("\(entry.streak)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(entry.streak == 1 ? "noite" : "noites")
                    .font(.system(size: 8, weight: .semibold))
                    .textCase(.uppercase)
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var inline: some View {
        Label {
            Text(inlineText)
        } icon: {
            Image(systemName: isSessionActive ? "moon.stars.fill" : "flame.fill")
        }
        .widgetURL(Self.openURL)
    }

    /// Mesmo fundo de vidro do círculo, com cantos arredondados, como no protótipo.
    private var rectangular: some View {
        ZStack {
            AccessoryWidgetBackground()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            rectangularContent
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .widgetURL(Self.openURL)
    }

    private var rectangularContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label {
                Text(rectangularTitle)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
            } icon: {
                Image(systemName: isSessionActive ? "moon.stars.fill" : "flame.fill")
            }
            Gauge(value: PlanetMilestones.progressToNext(streak: entry.streak)) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinearCapacity)
            Text(rectangularSubtitle)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    // MARK: Textos

    private static let openURL = URL(string: "luminaria://open")

    /// Noite em andamento = despertador armado e ainda no futuro.
    private var isSessionActive: Bool {
        guard entry.isArmed, let fire = entry.nextFireDate else { return false }
        return fire > entry.date
    }

    private var nextPlanet: PlanetMilestone? { PlanetMilestones.next(afterStreak: entry.streak) }

    private var alarmTimeText: String? {
        guard isSessionActive, let fire = entry.nextFireDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: fire)
    }

    private func nights(_ count: Int) -> String {
        count == 1 ? "1 noite" : "\(count) noites"
    }

    private var inlineText: String {
        if let alarm = alarmTimeText {
            return "\(nights(entry.streak)) · despertador \(alarm)"
        }
        return entry.streak == 0 ? "Comece sua sequência hoje" : "\(nights(entry.streak)) seguidas"
    }

    private var rectangularTitle: String {
        if isSessionActive {
            return "Rumo a \(nextPlanet?.name ?? "Netuno")"
        }
        return entry.streak == 0 ? "Sem sequência ainda" : "\(nights(entry.streak)) seguidas"
    }

    private var rectangularSubtitle: String {
        guard let next = nextPlanet else {
            return "Todos os planetas · recorde \(entry.longestStreak)"
        }
        let missing = next.requiredStreakDays - entry.streak
        if let alarm = alarmTimeText {
            return "faltam \(nights(missing)) · acorda \(alarm)"
        }
        return "\(next.name) em \(missing) · recorde \(entry.longestStreak)"
    }
}

struct AlarmWidget: Widget {
    let kind = SharedWidgetData.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LuminariaTimelineProvider()) { entry in
            LuminariaWidgetView(entry: entry)
        }
        .configurationDisplayName("Luminária")
        .description("Sua sequência de noites, o próximo planeta e o despertador.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
