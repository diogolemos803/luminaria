import SwiftUI

struct SleepReportView: View {
    @ObservedObject var store: SleepReportStore
    @Environment(\.isNightModeArmed) private var isNightModeArmed

    private var theme: ModeTheme { .current(armed: isNightModeArmed) }

    var body: some View {
        ZStack {
            theme.stage.ignoresSafeArea()
            if store.entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 40))
                        .foregroundStyle(theme.inkMuted)
                    Text("Nenhuma noite registrada ainda")
                        .font(.luminaria(.subheadline, weight: .medium))
                        .foregroundStyle(theme.inkMuted)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ThemedCard(theme: theme) {
                            ForEach(Array(store.entries.enumerated()), id: \.element.id) { index, entry in
                                ThemedRow(
                                    theme: theme,
                                    showsDivider: index > 0,
                                    title: Self.dateFormatter.string(from: entry.date),
                                    subtitle: "\(entry.blockedAppCount) app\(entry.blockedAppCount == 1 ? "" : "s") bloqueado\(entry.blockedAppCount == 1 ? "" : "s") · \(Self.durationText(entry.durationSeconds))",
                                    leading: { IconBadge(systemName: "shield.lefthalf.filled", theme: theme) },
                                    accessory: { EmptyView() }
                                )
                            }
                        }

                        Text("Não é possível saber quantas notificações ou ligações foram bloqueadas — a Apple não expõe essa informação pra nenhum app terceiro. O que dá pra medir de verdade é quantos apps ficaram bloqueados e por quanto tempo.")
                            .font(.luminaria(.caption))
                            .foregroundStyle(theme.inkMuted)
                    }
                    .padding(16)
                    .padding(.top, 4)
                }
            }
        }
        .navigationTitle("Relatório de sono")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.stage, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(isNightModeArmed ? .dark : .light, for: .navigationBar)
        .tint(theme.accent)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter
    }()

    private static func durationText(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h\(String(format: "%02d", minutes))m"
        }
        return "\(minutes)m"
    }
}
