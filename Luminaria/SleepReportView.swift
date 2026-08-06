import SwiftUI

/// Período mostrado no relatório — filtra por `SleepReportEntry.date`, não altera o
/// histórico salvo (é só uma lente sobre `store.entries`, nada é apagado).
private enum ReportDateFilter: String, CaseIterable, Identifiable {
    case day, week, month, all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return "Último dia"
        case .week: return "Últimos 7 dias"
        case .month: return "Último mês"
        case .all: return "Tudo"
        }
    }

    /// `nil` = sem corte (caso `.all`).
    var cutoffDate: Date? {
        let calendar = Calendar.current
        switch self {
        case .day: return calendar.date(byAdding: .day, value: -1, to: Date())
        case .week: return calendar.date(byAdding: .day, value: -7, to: Date())
        case .month: return calendar.date(byAdding: .month, value: -1, to: Date())
        case .all: return nil
        }
    }
}

struct SleepReportView: View {
    @ObservedObject var store: SleepReportStore
    @Environment(\.isNightModeArmed) private var isNightModeArmed
    @State private var filter: ReportDateFilter = .all

    private var theme: ModeTheme { .current(armed: isNightModeArmed) }

    private var filteredEntries: [SleepReportEntry] {
        guard let cutoff = filter.cutoffDate else { return store.entries }
        return store.entries.filter { $0.date >= cutoff }
    }

    var body: some View {
        ZStack {
            theme.stage.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    filterSelector

                    if filteredEntries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "moon.zzz")
                                .font(.system(size: 40))
                                .foregroundStyle(theme.inkMuted)
                            Text(store.entries.isEmpty ? "Nenhuma noite registrada ainda" : "Nenhuma noite nesse período")
                                .font(.luminaria(.subheadline, weight: .medium))
                                .foregroundStyle(theme.inkMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        ThemedCard(theme: theme) {
                            ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { index, entry in
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
                    }

                    Text("Não é possível saber quantas notificações ou ligações foram bloqueadas — a Apple não expõe essa informação pra nenhum app terceiro. O que dá pra medir de verdade é quantos apps ficaram bloqueados e por quanto tempo.")
                        .font(.luminaria(.caption))
                        .foregroundStyle(theme.inkMuted)
                }
                .padding(16)
                .padding(.top, 4)
            }
        }
        .navigationTitle("Relatório de sono")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.stage, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(isNightModeArmed ? .dark : .light, for: .navigationBar)
        .tint(theme.accent)
    }

    private var filterSelector: some View {
        HStack(spacing: 8) {
            ForEach(ReportDateFilter.allCases) { option in
                let isSelected = filter == option
                Button {
                    filter = option
                } label: {
                    Text(option.title)
                        .font(.luminaria(.caption, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundStyle(isSelected ? theme.accentForeground : theme.inkMuted)
                        .background(isSelected ? theme.accent : theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
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
