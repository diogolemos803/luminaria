import SwiftUI
import FamilyControls

struct AppBlockingView: View {
    @ObservedObject var screenTimeManager: ScreenTimeManager
    @Environment(\.isNightModeArmed) private var isNightModeArmed
    @State private var isPickerPresented = false

    private var theme: ModeTheme { .current(armed: isNightModeArmed) }

    var body: some View {
        ZStack {
            theme.stage.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ThemedCard(title: "Autorização", theme: theme) {
                        ThemedRow(
                            theme: theme,
                            title: authorizationStatusText,
                            leading: { IconBadge(systemName: "hand.raised", theme: theme) },
                            accessory: { EmptyView() }
                        )
                        if screenTimeManager.isAuthorized != true {
                            Button {
                                screenTimeManager.requestAuthorization()
                            } label: {
                                ThemedRow(
                                    theme: theme,
                                    showsDivider: true,
                                    title: "Autorizar Tempo de Uso",
                                    leading: { IconBadge(systemName: "checkmark.shield", theme: theme) },
                                    accessory: { EmptyView() }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    ThemedCard(title: "Apps bloqueados no modo noite", theme: theme) {
                        Button {
                            isPickerPresented = true
                        } label: {
                            ThemedRow(
                                theme: theme,
                                title: selectionSummary,
                                subtitle: "Toque pra escolher os apps",
                                leading: { IconBadge(systemName: "shield.lefthalf.filled", theme: theme) },
                                accessory: { chevron }
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(screenTimeManager.isAuthorized != true)
                    }

                    Text("Por privacidade, a Apple não deixa o Luminária saber quais apps você escolheu — só quantos. Enquanto o modo noite estiver ativo (depois de reconhecer a luminária via NFC), os apps escolhidos ficam bloqueados de verdade, com a própria tela de bloqueio do iOS.")
                        .font(.luminaria(.caption))
                        .foregroundStyle(theme.inkMuted)
                }
                .padding(16)
                .padding(.top, 4)
            }
        }
        .navigationTitle("Bloqueio de apps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.stage, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(isNightModeArmed ? .dark : .light, for: .navigationBar)
        .tint(theme.accent)
        .familyActivityPicker(
            isPresented: $isPickerPresented,
            selection: Binding(
                get: { screenTimeManager.selection },
                set: { screenTimeManager.updateSelection($0) }
            )
        )
        .onAppear {
            screenTimeManager.refreshAuthorizationStatus()
        }
    }

    private var authorizationStatusText: String {
        switch screenTimeManager.isAuthorized {
        case true: return "Autorizado"
        case false: return "Não autorizado"
        default: return "Ainda não solicitado"
        }
    }

    private var selectionSummary: String {
        let count = screenTimeManager.totalSelectedCount
        if count == 0 { return "Nenhum app escolhido" }
        return "\(count) selecionado\(count == 1 ? "" : "s")"
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.inkMuted.opacity(0.7))
    }
}
