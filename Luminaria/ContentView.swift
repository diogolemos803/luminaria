import SwiftUI

struct ContentView: View {
    @StateObject private var nfcManager = NFCManager()
    @StateObject private var alarmManager = AlarmManager.shared
    @StateObject private var routineStore = SleepRoutineStore()
    @StateObject private var screenTimeManager = ScreenTimeManager.shared
    @StateObject private var sleepReportStore = SleepReportStore.shared
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
            Group {
                if nfcManager.isLinked {
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

                        // Só aparece com o bloqueio de apps realmente ativo — nunca no
                        // Living mode, nunca antes da luminária ser reconhecida. Não
                        // mexe no botão redondo nem no texto "Living/Zleepy mode" acima.
                        if isNightModeArmed && screenTimeManager.isShieldActive {
                            Button {
                                _ = screenTimeManager.useEmergencyPass()
                            } label: {
                                Text("Passe de emergência (\(screenTimeManager.emergencyPassesRemaining) restantes)")
                                    .font(.caption)
                                    .foregroundStyle(inkSleep)
                            }
                            .disabled(screenTimeManager.emergencyPassesRemaining == 0)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .padding(.bottom, 16)
                        }
                    }
                    .animation(.easeInOut(duration: 0.5), value: isNightModeArmed)
                    .animation(.spring(response: 0.25, dampingFraction: 0.55), value: isPressed)
                } else {
                    // Pedido explícito do usuário: o app não faz nada de útil (arma
                    // modo noite, bloqueia apps) sem uma luminária física vinculada.
                    LockedView(nfcManager: nfcManager, onLinkTapped: { nfcManager.beginScanning() })
                }
            }
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
                screenTimeManager.refreshAuthorizationStatus()
                // Cobre o app sendo aberto do zero (cold launch): onChange(of: scenePhase)
                // só reage a mudanças, não à primeira transição pra .active.
                alarmManager.checkForMissedAlarm()
                // O bloqueio de apps (ManagedSettingsStore) continua valendo mesmo se o
                // processo morrer — sem isso, o botão reabriria mostrando "Living mode"
                // com os apps ainda travados e nenhum jeito de desarmar pelo app.
                if screenTimeManager.isShieldActive {
                    isNightModeArmed = true
                }
                nfcManager.onRecognizedTap = {
                    guard isNightModeArmed else { return }
                    // Resolve a rotina automática por calendário só AGORA, no instante
                    // em que a luminária é reconhecida de verdade — pedido explícito do
                    // usuário: antes isso rodava no toque do botão, o que trocava a
                    // rotina ativa mesmo se a pessoa cancelasse a leitura NFC depois,
                    // dando a impressão de que a troca automática "ficava ligada o dia
                    // inteiro" em vez de só valer pra noite em que a tag é lida.
                    Task { @MainActor in
                        if let autoRoutineID = await routineStore.resolveAutoActivateRoutine() {
                            routineStore.setActive(id: autoRoutineID)
                        }
                        guard let routine = routineStore.activeRoutine else { return }
                        ShortcutManager.shared.runSleepShortcut()
                        alarmManager.armAlarm(hour: routine.alarmHour, minute: routine.alarmMinute, soundFileName: routine.soundOption.fileName)
                        screenTimeManager.applyShield(selection: routine.appSelection)
                    }
                }
                // Sem isso, cancelar a leitura, deixar dar timeout (~60s do CoreNFC) ou
                // encostar a tag errada deixava o app preso em "Zleepy mode" sem nada
                // realmente armado — o modo noite só deve "pegar" se a leitura terminar
                // com sucesso.
                nfcManager.onScanEndedWithoutMatch = {
                    isNightModeArmed = false
                }
                // O desbloqueio de apps em si já acontece dentro de AlarmManager
                // (funciona mesmo com o app suspenso) — isso aqui só sincroniza o botão
                // redondo de volta pra "Living mode" quando o app está em primeiro plano
                // na hora que o despertador dispara.
                alarmManager.onAlarmFired = {
                    isNightModeArmed = false
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    alarmManager.checkForMissedAlarm()
                    screenTimeManager.refreshAuthorizationStatus()
                }
            }
            .onOpenURL { _ in
                // Callback do x-callback-url do Atalhos (luminaria://shortcut-done|shortcut-error).
                // Nada a fazer além de aceitar a volta ao app; existe só pra não abrir o app
                // Atalhos por completo ao disparar o Atalho.
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(
                    nfcManager: nfcManager,
                    alarmManager: alarmManager,
                    routineStore: routineStore,
                    screenTimeManager: screenTimeManager,
                    sleepReportStore: sleepReportStore
                )
                .environment(\.isNightModeArmed, isNightModeArmed)
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
            screenTimeManager.removeShield()
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
    @ObservedObject var screenTimeManager: ScreenTimeManager
    @ObservedObject var sleepReportStore: SleepReportStore
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

                        if nfcManager.isLinked {
                            Text("Perdeu ou trocou a luminária física? Não precisa desvincular nada — depois do primeiro vínculo, qualquer tag NFC reconhecida já funciona.")
                                .font(.luminaria(.caption))
                                .foregroundStyle(theme.inkMuted)
                                .padding(.horizontal, 10)
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

                        ThemedCard(title: "Relatório", theme: theme) {
                            NavigationLink {
                                SleepReportView(store: sleepReportStore)
                            } label: {
                                ThemedRow(
                                    theme: theme,
                                    title: "Relatório de sono",
                                    subtitle: "\(sleepReportStore.entries.count) noite\(sleepReportStore.entries.count == 1 ? "" : "s") registrada\(sleepReportStore.entries.count == 1 ? "" : "s")",
                                    leading: { IconBadge(systemName: "moon.zzz", theme: theme) },
                                    accessory: { chevron }
                                )
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
