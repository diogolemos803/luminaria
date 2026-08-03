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
                // Cobre o app sendo aberto do zero (cold launch): onChange(of: scenePhase)
                // só reage a mudanças, não à primeira transição pra .active.
                alarmManager.checkForMissedAlarm()
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
                    .environment(\.isNightModeArmed, isNightModeArmed)
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
    @Environment(\.isNightModeArmed) private var isNightModeArmed
    @State private var showHelp = false

    private var theme: ModeTheme { .current(armed: isNightModeArmed) }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.stage.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ThemedCard(title: "Luminária", theme: theme) {
                            if nfcManager.isLinked {
                                Button {
                                    nfcManager.beginScanning()
                                } label: {
                                    ThemedRow(
                                        theme: theme,
                                        title: "Vinculada",
                                        subtitle: "Testar leitura da tag",
                                        leading: { IconBadge(systemName: "checkmark", theme: theme) },
                                        accessory: { chevron }
                                    )
                                }
                                .buttonStyle(.plain)
                                Button {
                                    nfcManager.unlink()
                                } label: {
                                    ThemedRow(
                                        theme: theme,
                                        showsDivider: true,
                                        title: "Desvincular luminária",
                                        leading: { IconBadge(systemName: "xmark", isDanger: true, theme: theme) },
                                        accessory: { EmptyView() }
                                    )
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button {
                                    nfcManager.beginScanning()
                                } label: {
                                    ThemedRow(
                                        theme: theme,
                                        title: "Vincular luminária",
                                        leading: { IconBadge(systemName: "wave.3.right", theme: theme) },
                                        accessory: { chevron }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        ThemedCard(title: "Rotina de sono", theme: theme) {
                            NavigationLink {
                                SleepRoutinesView(store: routineStore)
                            } label: {
                                if let routine = routineStore.activeRoutine {
                                    ThemedRow(
                                        theme: theme,
                                        title: routine.name,
                                        subtitle: String(format: "%02d:%02d · %@", routine.alarmHour, routine.alarmMinute, routine.soundOption.displayName),
                                        leading: { ActiveDot(theme: theme) },
                                        accessory: { chevron }
                                    )
                                } else {
                                    ThemedRow(
                                        theme: theme,
                                        title: "Gerenciar rotinas de sono",
                                        leading: { ActiveDot(theme: theme) },
                                        accessory: { chevron }
                                    )
                                }
                            }
                        }

                        ThemedCard(title: "Ajuda", theme: theme) {
                            Button {
                                showHelp = true
                            } label: {
                                ThemedRow(
                                    theme: theme,
                                    title: "Como configurar o Atalho",
                                    leading: { IconBadge(systemName: "questionmark", theme: theme) },
                                    accessory: { chevron }
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if !nfcManager.statusMessage.isEmpty {
                            Text(nfcManager.statusMessage)
                                .font(.luminaria(.footnote, weight: .medium))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 10)
                        }

                        if let error = nfcManager.errorMessage {
                            Text(error)
                                .font(.luminaria(.footnote, weight: .medium))
                                .foregroundStyle(theme.danger)
                                .padding(.horizontal, 10)
                        }
                    }
                    .padding(16)
                    .padding(.top, 4)
                }
            }
            .navigationTitle("Configurações")
            .toolbarBackground(theme.stage, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(isNightModeArmed ? .dark : .light, for: .navigationBar)
            .tint(theme.accent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            .sheet(isPresented: $showHelp) {
                HelpView()
                    .environment(\.isNightModeArmed, isNightModeArmed)
            }
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.inkMuted.opacity(0.7))
    }
}

#Preview {
    ContentView()
}
