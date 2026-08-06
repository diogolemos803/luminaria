import WidgetKit
import SwiftUI

/// Esqueleto (commit 1): valida só a mecânica do target novo (compila, linka, embute
/// no app). Sem dado real ainda — isso entra no commit 2, junto com o App Group
/// compartilhado com o app principal.
struct AlarmEntry: TimelineEntry {
    let date: Date
}

struct AlarmTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> AlarmEntry {
        AlarmEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (AlarmEntry) -> Void) {
        completion(AlarmEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AlarmEntry>) -> Void) {
        completion(Timeline(entries: [AlarmEntry(date: Date())], policy: .never))
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
            Image(systemName: "moon.stars.fill")
            Text("Luminária")
        }
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
