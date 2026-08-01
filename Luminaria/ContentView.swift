import SwiftUI

struct ContentView: View {
    @StateObject private var nfcManager = NFCManager()
    @StateObject private var alarmManager = AlarmManager.shared
    @StateObject private var routineStore = SleepRoutineStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var isNightModeArmed = false
    @State private var isPressed = false
    @State private var showSettings = false

    private let awakeBackground = Color(red: 0.957, green: 0.953, blue: 0.941)
    private let sleepBackground = Color(red: 0.129, green: 0.141, blue: 0.165)
    private let buttonAwakeFill = Color.white
    private let buttonSleepFill = Color(red: 0.2, green: 0.216, blue: 0.243)
    private let inkAwake = Color(red: 0.42, green: 0.416, blue: 0.4)
    private let inkSleep = Color(red: 0.545, green: 0.557, blue: 0.58)
    private let menuIconAwake = Color(red: 0.27, green: 0.267, blue: 0.247)
    private let menuIconSleep = Color(red: 0.929, green: 0.937, blue: 0.949)

    private var modeName: String {
        isNightModeArmed ? "Zleepy mode" : "Living mode"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (isNightModeArmed ? sleepBackground : awakeBackground)
                    .ignoresSafeArea()

                Button(action: toggleNightMode) {
                    Image(isNightModeArmed ? "LogoSono" : "LogoAcordado")
                        .resizable()
                        .scaledToFit()
                        .padding(9)
                        .frame(width: 220, height: 220)
                        .background(isNightModeArmed ? buttonSleepFill : buttonAwakeFill)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 12)
                }
                .buttonStyle(.plain)
                .scaleEffect(isPressed ? 0.88 : 1.0)
                .accessibilityLabel(modeName)

                Text(modeName)
                    .font(.footnote)
                    .tracking(0.4)
                    .foregroundStyle(isNightModeArmed ? inkSleep : inkAwake)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 40)
            }
            .animation(.easeInOut(duration: 0.5), value: isNightModeArmed)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: isPressed)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(isNightModeArmed ? menuIconSleep : menuIconAwake)
                    }
                }
            }
            .onAppear {
                alarmManager.requestNotificationPermission()
                nfcManager.onRecognizedTap = {
                    guard isNightModeArmed, let routine = routineStore.activeRoutine else { return }
                    ShortcutManager.shared.runSleepShortcut()
                    alarmManager.armAlarm(hour: routine.alarmHour, minute: routine.alarmMinute, soundFileName: routine.soundOption.fileName)
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    alarmManager.checkForMissedAlarm()
                }
            }
            .onOpenURL { _ in
                // Callback do x-callback-url do Atalhos (luminaria://shortcut-done|shortcut-error).
                // Nada a fazer além de aceitar a volta ao app; existe só pra não abrir o app
                // Atalhos por completo ao disparar o Atalho.
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(nfcManager: nfcManager, alarmManager: alarmManager, routineStore: routineStore)
            }
            .fullScreenCover(isPresented: $alarmManager.isAlarmRinging) {
                AlarmRingingView(alarmManager: alarmManager)
            }
        }
    }

    private func toggleNightMode() {
        isPressed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            isPressed = false
        }
        isNightModeArmed.toggle()
        if isNightModeArmed {
            nfcManager.beginScanning()
        } else {
            nfcManager.stopScanning()
            alarmManager.disarmAlarm()
        }
    }
}

struct AlarmRingingView: View {
    @ObservedObject var alarmManager: AlarmManager

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 28) {
                Image(systemName: "alarm.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                Text("Hora de acordar")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Button {
                    alarmManager.stopRingingAlarm()
                } label: {
                    Text("Parar")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.horizontal, 40)
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var nfcManager: NFCManager
    @ObservedObject var alarmManager: AlarmManager
    @ObservedObject var routineStore: SleepRoutineStore
    @Environment(\.dismiss) private var dismiss
    @State private var showHelp = false

    var body: some View {
        NavigationStack {
            List {
                Section("Luminária") {
                    if nfcManager.isLinked {
                        Label("Vinculada", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Button {
                            nfcManager.beginScanning()
                        } label: {
                            Label("Testar leitura da tag", systemImage: "wave.3.right")
                        }
                        Button(role: .destructive) {
                            nfcManager.unlink()
                        } label: {
                            Label("Desvincular luminária", systemImage: "xmark.circle")
                        }
                    } else {
                        Button {
                            nfcManager.beginScanning()
                        } label: {
                            Label("Vincular luminária", systemImage: "wave.3.right")
                        }
                    }
                }

                Section("Rotina de sono") {
                    NavigationLink {
                        SleepRoutinesView(store: routineStore)
                    } label: {
                        if let routine = routineStore.activeRoutine {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Rotina ativa: \(routine.name)")
                                Text(String(format: "%02d:%02d · %@", routine.alarmHour, routine.alarmMinute, routine.soundOption.displayName))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Gerenciar rotinas de sono")
                        }
                    }
                }

                Section("Ajuda") {
                    Button {
                        showHelp = true
                    } label: {
                        Label("Como configurar o Atalho", systemImage: "questionmark.circle")
                    }
                }

                // Branch de teste sem conta Apple Developer: dispara o Atalho e o despertador
                // direto, sem depender do NFC (que exige a entitlement paga).
                Section("Teste sem NFC") {
                    Button {
                        ShortcutManager.shared.runSleepShortcut()
                    } label: {
                        Label("Testar disparo do Atalho", systemImage: "bolt")
                    }
                    Button {
                        guard let routine = routineStore.activeRoutine else { return }
                        alarmManager.triggerTestAlarm(soundFileName: routine.soundOption.fileName)
                    } label: {
                        Label("Testar tela do despertador", systemImage: "alarm")
                    }
                    .disabled(routineStore.activeRoutine == nil)
                    Button {
                        guard let routine = routineStore.activeRoutine else { return }
                        alarmManager.armAlarm(hour: routine.alarmHour, minute: routine.alarmMinute, soundFileName: routine.soundOption.fileName)
                    } label: {
                        Label("Armar despertador de teste", systemImage: "clock.arrow.circlepath")
                    }
                    .disabled(routineStore.activeRoutine == nil)
                }

                if !nfcManager.statusMessage.isEmpty {
                    Section {
                        Text(nfcManager.statusMessage)
                            .foregroundStyle(.green)
                    }
                }

                if let error = nfcManager.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Configurações")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            .sheet(isPresented: $showHelp) {
                HelpView()
            }
        }
    }
}

#Preview {
    ContentView()
}
