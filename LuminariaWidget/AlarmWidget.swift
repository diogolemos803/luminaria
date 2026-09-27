import WidgetKit
import SwiftUI

/// Widget da tela bloqueada em três tamanhos (protótipo v2 aprovado em
/// `design/widget_prototipo.html`). Olhar a tela bloqueada não conta como "mexer no
/// celular" — é assim que a pessoa acompanha o desafio sem arriscar a noite. Tocar abre
/// o app (`widgetURL`).
///
/// **Um papel pra cada widget** (pedido do usuário: a informação estava repetitiva):
/// - Círculo: a sequência de noites + anel até o próximo planeta — o único lugar com o
///   número da sequência.
/// - Retângulo: de dia, a jornada ("Rumo a Saturno · faltam 8 noites"); à noite, com a
///   jornada já no cartão ao vivo, o ranking dos amigos (sem amigos, volta pra jornada).
/// - Linha acima do relógio: de dia, o recorde; à noite, o despertador.
///
/// Na tela bloqueada o iOS desenha todo widget num tom único translúcido (ignora cores
/// próprias) — por isso aqui é só forma, símbolo e texto, sobre o vidro do sistema
/// (`AccessoryWidgetBackground`). A parte colorida da noite é a Atividade ao Vivo
/// (`NightLiveActivityWidget`). O tamanho de cada formato é fixo pelo iOS.
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
    let rank: RankInfo?

    struct RankInfo {
        let position: Int
        let total: Int
        let aheadName: String?
        let aheadStreak: Int
        let behindName: String?
        let behindStreak: Int
    }
}

struct LuminariaTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> LuminariaEntry {
        LuminariaEntry(
            date: Date(), isArmed: false, nextFireDate: nil, streak: 7, longestStreak: 12,
            rank: .init(position: 2, total: 4, aheadName: "Ana", aheadStreak: 9, behindName: "Leo", behindStreak: 5)
        )
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
        let position = defaults?.integer(forKey: SharedWidgetData.rankPositionKey) ?? 0
        let rank: LuminariaEntry.RankInfo? = position > 0 ? .init(
            position: position,
            total: defaults?.integer(forKey: SharedWidgetData.rankTotalKey) ?? 0,
            aheadName: defaults?.string(forKey: SharedWidgetData.rankAheadNameKey),
            aheadStreak: defaults?.integer(forKey: SharedWidgetData.rankAheadStreakKey) ?? 0,
            behindName: defaults?.string(forKey: SharedWidgetData.rankBehindNameKey),
            behindStreak: defaults?.integer(forKey: SharedWidgetData.rankBehindStreakKey) ?? 0
        ) : nil
        return LuminariaEntry(
            date: date,
            isArmed: defaults?.bool(forKey: SharedWidgetData.armedKey) ?? false,
            nextFireDate: nextFire,
            streak: StreakMath.effective(streak: stored, lastCleanNight: lastClean, now: date),
            longestStreak: defaults?.integer(forKey: SharedWidgetData.longestStreakKey) ?? 0,
            rank: rank
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

    // MARK: Círculo — sequência

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
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
        .widgetURL(Self.openURL)
    }

    // MARK: Linha — recorde (dia) / despertador (noite)

    private var inline: some View {
        Group {
            if let alarm = alarmTimeText {
                Label("Despertador \(alarm)", systemImage: "moon.stars.fill")
            } else if entry.longestStreak > 0 {
                Label("Recorde: \(nights(entry.longestStreak))", systemImage: "trophy.fill")
            } else {
                Label("Comece sua sequência hoje", systemImage: "flame.fill")
            }
        }
        .widgetURL(Self.openURL)
    }

    // MARK: Retângulo — jornada (dia) / ranking (noite)

    private var rectangular: some View {
        ZStack {
            AccessoryWidgetBackground()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Group {
                if isSessionActive, let rank = entry.rank {
                    rankingContent(rank)
                } else {
                    journeyContent
                }
            }
            // margem pequena: o iOS já recua o conteúdo do widget por conta própria
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .widgetURL(Self.openURL)
    }

    private var journeyContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                RocketGlyph()
                    .fill(style: FillStyle(eoFill: true))
                    .rotationEffect(.degrees(45))
                    .frame(width: 13, height: 13)
                Text(nextPlanet.map { "Rumo a \($0.name)" } ?? "Todos os planetas")
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Gauge(value: PlanetMilestones.progressToNext(streak: entry.streak)) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinearCapacity)
            Text(journeySubtitle)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func rankingContent(_ rank: LuminariaEntry.RankInfo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("\(rank.position)º entre os amigos")
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Group {
                if let ahead = rank.aheadName {
                    (Text(ahead).bold() + Text(" na frente · \(nights(rank.aheadStreak))"))
                        .font(.system(size: 11, weight: .semibold))
                    Text("faltam \(max(1, rank.aheadStreak - entry.streak + 1)) pra passar")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Você está na frente")
                        .font(.system(size: 11, weight: .semibold))
                    if let behind = rank.behindName {
                        Text("\(behind) em 2º · \(nights(rank.behindStreak))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
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

    private var journeySubtitle: String {
        guard let next = nextPlanet else {
            return "Recorde: \(nights(entry.longestStreak))"
        }
        let missing = next.requiredStreakDays - entry.streak
        if let alarm = alarmTimeText {
            // noite sem amigos: jornada + despertador, curto pra caber
            return "faltam \(missing) · acorda \(alarm)"
        }
        return "faltam \(nights(missing))"
    }
}

struct AlarmWidget: Widget {
    let kind = SharedWidgetData.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LuminariaTimelineProvider()) { entry in
            LuminariaWidgetView(entry: entry)
        }
        .configurationDisplayName("Luminária")
        .description("Sua sequência de noites, o próximo planeta, o ranking e o despertador.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
