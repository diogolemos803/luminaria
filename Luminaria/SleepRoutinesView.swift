import SwiftUI

struct SleepRoutinesView: View {
    @ObservedObject var store: SleepRoutineStore
    @Environment(\.isNightModeArmed) private var isNightModeArmed
    @State private var routineToEdit: SleepRoutine?
    @State private var newRoutine: SleepRoutine?

    private var theme: ModeTheme { .current(armed: isNightModeArmed) }

    var body: some View {
        List {
            Section {
                calendarAutoActivateCard
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            ForEach(store.routines) { routine in
                Button {
                    routineToEdit = routine
                } label: {
                    ThemedRow(
                        theme: theme,
                        title: routine.name,
                        subtitle: Self.subtitle(for: routine),
                        leading: {
                            if routine.id == store.activeRoutineID {
                                ActiveDot(theme: theme)
                            } else {
                                Circle().fill(Color.clear).frame(width: 9, height: 9)
                            }
                        },
                        accessory: {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.inkMuted.opacity(0.7))
                        }
                    )
                }
                .buttonStyle(.plain)
                .padding(4)
                .background(theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .leading) {
                    if routine.id != store.activeRoutineID {
                        Button {
                            store.setActive(id: routine.id)
                        } label: {
                            Label("Ativar", systemImage: "checkmark.circle")
                        }
                        .tint(Color(uiColor: .systemGreen))
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    store.remove(id: store.routines[index].id)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(theme.stage.ignoresSafeArea())
        .navigationTitle("Rotinas de sono")
        .toolbarBackground(theme.stage, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(isNightModeArmed ? .dark : .light, for: .navigationBar)
        .tint(theme.accent)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newRoutine = SleepRoutine(name: "Nova rotina")
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $routineToEdit) { routine in
            RoutineEditView(store: store, routine: routine)
                .environment(\.isNightModeArmed, isNightModeArmed)
        }
        .sheet(item: $newRoutine) { routine in
            RoutineEditView(store: store, routine: routine, isNew: true)
                .environment(\.isNightModeArmed, isNightModeArmed)
        }
        .onAppear {
            store.refreshCalendarAuthorizationStatus()
        }
    }

    private var calendarAutoActivateCard: some View {
        ThemedCard(title: "Rotina automática por calendário", theme: theme) {
            ThemedRow(
                theme: theme,
                title: calendarStatusText,
                subtitle: "Ative por rotina em \"Ativar automaticamente quando\", ao editar cada uma",
                leading: { IconBadge(systemName: "calendar", theme: theme) },
                accessory: { EmptyView() }
            )
            if store.isCalendarAuthorized != true {
                Button {
                    store.requestCalendarAccess()
                } label: {
                    ThemedRow(
                        theme: theme,
                        showsDivider: true,
                        title: "Autorizar Calendário",
                        leading: { IconBadge(systemName: "checkmark.circle", theme: theme) },
                        accessory: { EmptyView() }
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var calendarStatusText: String {
        switch store.isCalendarAuthorized {
        case true: return "Autorizado"
        case false: return "Não autorizado"
        default: return "Ainda não solicitado"
        }
    }

    private static func subtitle(for routine: SleepRoutine) -> String {
        let base = String(format: "%02d:%02d · %@", routine.alarmHour, routine.alarmMinute, routine.soundOption.displayName)
        let count = routine.appSelection.applicationTokens.count
            + routine.appSelection.categoryTokens.count
            + routine.appSelection.webDomainTokens.count
        guard count > 0 else { return base }
        return base + " · \(count) app\(count == 1 ? "" : "s")"
    }
}

struct RoutineEditView: View {
    @ObservedObject var store: SleepRoutineStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isNightModeArmed) private var isNightModeArmed
    @State private var routine: SleepRoutine
    var isNew: Bool = false

    private var theme: ModeTheme { .current(armed: isNightModeArmed) }

    init(store: SleepRoutineStore, routine: SleepRoutine, isNew: Bool = false) {
        self.store = store
        self._routine = State(initialValue: routine)
        self.isNew = isNew
    }

    private var alarmTime: Binding<Date> {
        Binding(
            get: { Self.date(hour: routine.alarmHour, minute: routine.alarmMinute) },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                routine.alarmHour = comps.hour ?? 7
                routine.alarmMinute = comps.minute ?? 0
            }
        )
    }

    private var nightShiftOffTime: Binding<Date> {
        Binding(
            get: { Self.date(hour: routine.nightShiftOffHour, minute: routine.nightShiftOffMinute) },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                routine.nightShiftOffHour = comps.hour ?? 7
                routine.nightShiftOffMinute = comps.minute ?? 30
            }
        )
    }

    private var eventKeywordBinding: Binding<String> {
        Binding(
            get: { routine.autoActivateEventKeyword ?? "" },
            set: { newValue in
                routine.autoActivateEventKeyword = newValue.isEmpty ? nil : newValue
            }
        )
    }

    private static func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.stage.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ThemedCard(title: "Nome", theme: theme) {
                            TextField("Nome da rotina", text: $routine.name)
                                .font(.luminaria(.body, weight: .medium))
                                .foregroundStyle(theme.ink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 11)
                        }

                        ThemedCard(title: "Horários", theme: theme) {
                            HStack {
                                Text("Despertador")
                                    .font(.luminaria(.subheadline, weight: .medium))
                                    .foregroundStyle(theme.ink)
                                Spacer()
                                DatePicker("", selection: alarmTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .tint(theme.accent)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)

                            Rectangle()
                                .fill(theme.hairline)
                                .frame(height: 1)
                                .padding(.leading, 10)

                            HStack {
                                Text("Desligar Modo Noturno às")
                                    .font(.luminaria(.subheadline, weight: .medium))
                                    .foregroundStyle(theme.ink)
                                Spacer()
                                DatePicker("", selection: nightShiftOffTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .tint(theme.accent)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                        }

                        ThemedCard(title: "Som do despertador", theme: theme) {
                            HStack(spacing: 10) {
                                ForEach(AlarmSoundOption.allCases) { option in
                                    soundSwatch(for: option)
                                }
                            }
                            .padding(8)

                            Button {
                                AlarmManager.shared.previewSound(routine.soundOption)
                            } label: {
                                ThemedRow(
                                    theme: theme,
                                    title: "Testar som",
                                    leading: { IconBadge(systemName: "play.fill", theme: theme) },
                                    accessory: { EmptyView() }
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        ThemedCard(title: "Bloqueio de apps", theme: theme) {
                            NavigationLink {
                                AppBlockingView(screenTimeManager: ScreenTimeManager.shared, selection: $routine.appSelection)
                            } label: {
                                ThemedRow(
                                    theme: theme,
                                    title: "Apps bloqueados nesta rotina",
                                    subtitle: appBlockingSubtitle,
                                    leading: { IconBadge(systemName: "shield.lefthalf.filled", theme: theme) },
                                    accessory: {
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(theme.inkMuted.opacity(0.7))
                                    }
                                )
                            }
                        }

                        ThemedCard(title: "Ativar automaticamente quando", theme: theme) {
                            HStack {
                                Text("Dias de semana")
                                    .font(.luminaria(.subheadline, weight: .medium))
                                    .foregroundStyle(theme.ink)
                                Spacer()
                                Toggle("", isOn: $routine.autoActivateWeekday)
                                    .labelsHidden()
                                    .tint(theme.accent)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)

                            Rectangle()
                                .fill(theme.hairline)
                                .frame(height: 1)
                                .padding(.leading, 10)

                            HStack {
                                Text("Fins de semana")
                                    .font(.luminaria(.subheadline, weight: .medium))
                                    .foregroundStyle(theme.ink)
                                Spacer()
                                Toggle("", isOn: $routine.autoActivateWeekend)
                                    .labelsHidden()
                                    .tint(theme.accent)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)

                            Rectangle()
                                .fill(theme.hairline)
                                .frame(height: 1)
                                .padding(.leading, 10)

                            TextField("Ou evento no Calendário contendo (ex.: Viagem)", text: eventKeywordBinding)
                                .font(.luminaria(.subheadline))
                                .foregroundStyle(theme.ink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 11)
                        }

                        Text("Precisa de \"Rotina automática por calendário\" autorizado na tela anterior. Quando mais de uma rotina bate, a palavra-chave de evento ganha de fim de semana, que ganha de dia de semana.")
                            .font(.luminaria(.caption))
                            .foregroundStyle(theme.inkMuted)

                        if !isNew && routine.id != store.activeRoutineID {
                            FullPillButton(title: "Tornar rotina ativa", theme: theme) {
                                store.setActive(id: routine.id)
                            }
                        }

                        if !isNew {
                            GhostDangerButton(title: "Excluir rotina", theme: theme) {
                                store.remove(id: routine.id)
                                dismiss()
                            }
                        }
                    }
                    .padding(16)
                    .padding(.top, 4)
                }
            }
            .navigationTitle(isNew ? "Nova rotina" : "Editar rotina")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.stage, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(isNightModeArmed ? .dark : .light, for: .navigationBar)
            .tint(theme.accent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        store.upsert(routine)
                        dismiss()
                    } label: {
                        Text("Salvar")
                            .font(.luminaria(.subheadline, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(theme.accent)
                            .foregroundStyle(theme.accentForeground)
                            .clipShape(Capsule())
                    }
                    .disabled(routine.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var appBlockingSubtitle: String {
        let count = routine.appSelection.applicationTokens.count
            + routine.appSelection.categoryTokens.count
            + routine.appSelection.webDomainTokens.count
        return count == 0 ? "Nenhum app escolhido" : "\(count) selecionado\(count == 1 ? "" : "s")"
    }

    private func soundSwatch(for option: AlarmSoundOption) -> some View {
        let isSelected = routine.soundOption == option
        return Button {
            routine.soundOption = option
        } label: {
            Image(systemName: iconName(for: option))
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(isSelected ? theme.accent : theme.inkMuted)
                .background(isSelected ? theme.accentWash : theme.ink.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? theme.accent : Color.clear, lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func iconName(for option: AlarmSoundOption) -> String {
        switch option {
        case .classic: return "bell.fill"
        case .sunrise: return "sunrise.fill"
        case .oceanWaves: return "water.waves"
        case .rain: return "cloud.rain.fill"
        case .birds: return "bird.fill"
        }
    }
}
