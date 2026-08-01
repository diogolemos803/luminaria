import SwiftUI

struct SleepRoutinesView: View {
    @ObservedObject var store: SleepRoutineStore
    @State private var routineToEdit: SleepRoutine?
    @State private var newRoutine: SleepRoutine?

    var body: some View {
        List {
            ForEach(store.routines) { routine in
                Button {
                    routineToEdit = routine
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(routine.name)
                                .foregroundStyle(.primary)
                            Text(String(format: "%02d:%02d · %@", routine.alarmHour, routine.alarmMinute, routine.soundOption.displayName))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if routine.id == store.activeRoutineID {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .leading) {
                    if routine.id != store.activeRoutineID {
                        Button {
                            store.setActive(id: routine.id)
                        } label: {
                            Label("Ativar", systemImage: "checkmark.circle")
                        }
                        .tint(.green)
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    store.remove(id: store.routines[index].id)
                }
            }
        }
        .navigationTitle("Rotinas de sono")
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
        }
        .sheet(item: $newRoutine) { routine in
            RoutineEditView(store: store, routine: routine, isNew: true)
        }
    }
}

struct RoutineEditView: View {
    @ObservedObject var store: SleepRoutineStore
    @Environment(\.dismiss) private var dismiss
    @State private var routine: SleepRoutine
    var isNew: Bool = false

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

    private static func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nome") {
                    TextField("Nome da rotina", text: $routine.name)
                }

                Section("Horários") {
                    DatePicker("Despertador", selection: alarmTime, displayedComponents: .hourAndMinute)
                    DatePicker("Desligar Modo Noturno às", selection: nightShiftOffTime, displayedComponents: .hourAndMinute)
                }

                Section("Som do despertador") {
                    Picker("Som", selection: $routine.soundOption) {
                        ForEach(AlarmSoundOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    Button {
                        AlarmManager.shared.previewSound(routine.soundOption)
                    } label: {
                        Label("Testar som", systemImage: "play.circle")
                    }
                }

                if !isNew {
                    Section {
                        Button(role: .destructive) {
                            store.remove(id: routine.id)
                            dismiss()
                        } label: {
                            Label("Excluir rotina", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Nova rotina" : "Editar rotina")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        store.upsert(routine)
                        dismiss()
                    }
                    .disabled(routine.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
