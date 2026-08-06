import WidgetKit
import SwiftUI

/// Mostra o próximo despertador na Tela Bloqueada — tocar nele abre o app (via
/// `widgetURL`, esquema `luminaria://` já registrado no `Info.plist` do app). Widgets
/// não são notificações, então o Foco/Não Perturbe não filtra isso, diferente da
/// notificação do despertador. Abrir o app já basta: `ContentView.onAppear`/
/// `.onChange(of: scenePhase)` recalculam `isAlarmRinging` de qualquer jeito que o app
/// tenha sido aberto, mostrando a tela de "Parar" sozinha se o alarme estiver tocando.
private let widgetSuiteName = "group.com.luminaria.app"
private let widgetArmedKey = "widget.isArmed"
private let widgetNextFireKey = "widget.nextFireDate"

struct AlarmEntry: TimelineEntry {
    let date: Date
    let isArmed: Bool
    let nextFireDate: Date?
}

struct AlarmTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> AlarmEntry {
        AlarmEntry(date: Date(), isArmed: true, nextFireDate: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (AlarmEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AlarmEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> AlarmEntry {
        let defaults = UserDefaults(suiteName: widgetSuiteName)
        let isArmed = defaults?.bool(forKey: widgetArmedKey) ?? false
        let nextFireDate: Date?
        if let interval = defaults?.object(forKey: widgetNextFireKey) as? Double {
            nextFireDate = Date(timeIntervalSince1970: interval)
        } else {
            nextFireDate = nil
        }
        return AlarmEntry(date: Date(), isArmed: isArmed, nextFireDate: nextFireDate)
    }
}

struct AlarmWidgetView: View {
    var entry: AlarmEntry

    var body: some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(for: .widget) { Color.clear }
        } else {
            content.background(Color.clear)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label {
                Text("Luminária")
                    .font(.luminaria(.caption, weight: .bold))
            } icon: {
                Image(systemName: "moon.stars.fill")
            }
            Text(subtitle)
                .font(.luminaria(.caption2))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .widgetURL(URL(string: "luminaria://open"))
    }

    private var subtitle: String {
        guard entry.isArmed, let nextFireDate = entry.nextFireDate else {
            return "Nenhum despertador armado"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "Despertador às \(formatter.string(from: nextFireDate))"
    }
}

struct AlarmWidget: Widget {
    let kind = "com.luminaria.app.AlarmWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AlarmTimelineProvider()) { entry in
            AlarmWidgetView(entry: entry)
        }
        .configurationDisplayName("Luminária")
        .description("Mostra o próximo despertador na Tela Bloqueada.")
        .supportedFamilies([.accessoryRectangular])
    }
}
