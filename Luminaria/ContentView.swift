import SwiftUI

struct ContentView: View {
    @StateObject private var nfcManager = NFCManager()
    @StateObject private var alarmManager = AlarmManager.shared
    @StateObject private var routineStore = SleepRoutineStore()
    @StateObject private var screenTimeManager = ScreenTimeManager.shared
    @StateObject private var sleepReportStore = SleepReportStore.shared
    // `@ObservedObject`, não `@StateObject`: é um singleton compartilhado (dono do
    // ciclo de vida é ele mesmo, `ContentView` só observa) — usado hoje só pelo
    // indicador de debug do crescimento (ver `soveeMainScreen`).
    @ObservedObject private var growthTracker = NightSessionActivityTracker.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var isNightModeArmed = false
    @State private var isPressed = false
    @State private var showSettings = false

    /// Alterna entre a tela principal nova (SOVEE) e a antiga (Zleepy Lamp) — pedido
    /// explícito do usuário: "crie uma nova, mas deixe no código uma opção de
    /// retorno". Não é uma preferência do usuário final, é um interruptor de
    /// desenvolvimento — mude pra `false` aqui pra voltar à tela antiga inteira,
    /// sem precisar reverter nenhum commit.
    private static let useSoveeMainScreen = true

    /// Cores da tela principal ANTIGA (Zleepy Lamp) — preservadas exatamente como
    /// estavam, só usadas por `legacyMainScreen` quando `useSoveeMainScreen == false`.
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

    private var menuIconColor: Color {
        Self.useSoveeMainScreen
            ? ModeTheme.current(armed: isNightModeArmed).ink
            : (isNightModeArmed ? menuIconSleep : menuIconAwake)
    }

    var body: some View {
        NavigationStack {
            Group {
                if nfcManager.isLinked {
                    if Self.useSoveeMainScreen {
                        soveeMainScreen
                    } else {
                        legacyMainScreen
                    }
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
                            .foregroundStyle(menuIconColor)
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
                    // Reabrir o app durante uma sessão de bloqueio ativa conta como
                    // "tocou no celular" (ver GrowthEngine.swift) — zera o progresso
                    // de crescimento e alimenta a métrica de maior sequência sem
                    // tocar. Não existe API pública pra detectar um desbloqueio ou
                    // toque em outro app, então essa é a aproximação real e honesta
                    // (ver item 3b do resumo desta rodada).
                    if screenTimeManager.isShieldActive {
                        NightSessionActivityTracker.shared.registerTouchEvent()
                    }
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

    /// Tela principal SOVEE — mesmo botão redondo (identidade central do produto,
    /// intocada), com paleta/tipografia da marca. Ícones existentes (`LogoAcordado`/
    /// `LogoSono`) são retintados via `.renderingMode(.template)` — são traços de
    /// cor única sobre fundo transparente, dá pra recolorir sem precisar de arte
    /// nova. Sombra bem mais suave que a versão antiga (25% preto/24pt) — pedido do
    /// brief de evitar UI agressiva, um "ritual calmo" não pede sombra dura.
    ///
    /// Ajustes de cor pedidos depois de ver o primeiro protótipo: ícone de dia fica
    /// grafite (`SoveeColor.carvao`) direto, não o acento terracota; fundo de dia
    /// ganha um brilho de "nascer do sol" (ver `soveeDayGlow`); acento de noite virou
    /// azul de luar (`SoveeColor.noiteAzul`, ver `ModeTheme.zleepy`) em vez do sage
    /// original — a sombra do botão à noite já estava aprovada, não mudou.
    private var soveeMainScreen: some View {
        let theme = ModeTheme.current(armed: isNightModeArmed)
        // Mais distante já desbloqueado pela sequência ATUAL de dias limpos (não o
        // recorde histórico — se a sequência já quebrou, a viagem de hoje reflete
        // isso). Ver `GrowthDestinations`/`DetoxStats.currentCleanDayStreak`.
        let destination = GrowthDestinations.furthestUnlocked(
            currentStreak: DetoxStats.currentCleanDayStreak(in: sleepReportStore.entries)
        )
        return ZStack {
            if isNightModeArmed {
                theme.stage.ignoresSafeArea()

                // Viagem de foguete só com o bloqueio de apps realmente ativo (mesma
                // condição do passe de emergência) — fica no topo da tela, bem acima
                // do botão redondo, pra nunca sobrepor a identidade central do
                // produto. `allowsHitTesting(false)`: é só decorativo, não deve
                // roubar toques do botão nem de nada embaixo dele.
                if screenTimeManager.isShieldActive {
                    RocketGrowthVisual()
                        .render(phase: growthTracker.phase, destination: destination, theme: theme)
                        .frame(height: 240)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 24)
                        .allowsHitTesting(false)
                }
            } else {
                Color.white.ignoresSafeArea()
                soveeDayGlow.ignoresSafeArea()
            }

            Button(action: toggleNightMode) {
                Image(isNightModeArmed ? "LogoSono" : "LogoAcordado")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .padding(9)
                    .frame(width: 220, height: 220)
                    .foregroundStyle(isNightModeArmed ? theme.accent : SoveeColor.carvao)
                    .background(theme.card)
                    .clipShape(Circle())
                    .shadow(color: theme.ink.opacity(0.12), radius: 18, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .accessibilityLabel(modeName)

            // Tagline da marca ("hora de desligar.") só no modo noite — é o
            // momento que ela descreve (encerrar o dia). No modo dia, silêncio
            // deliberado em vez de repetir uma legenda "Living mode" técnica.
            if isNightModeArmed {
                Text("hora de desligar.")
                    .font(.soveeDisplay(size: 15, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(theme.ink.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 40)
            }

            // Só aparece com o bloqueio de apps realmente ativo — nunca no modo dia,
            // nunca antes da luminária ser reconhecida.
            if isNightModeArmed && screenTimeManager.isShieldActive {
                Button {
                    _ = screenTimeManager.useEmergencyPass()
                } label: {
                    Text("Passe de emergência (\(screenTimeManager.emergencyPassesRemaining) restantes)")
                        .font(.soveeBody(.caption))
                        .foregroundStyle(theme.inkMuted)
                }
                .disabled(screenTimeManager.emergencyPassesRemaining == 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 16)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: isNightModeArmed)
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isPressed)
    }

    /// Brilho de "nascer do sol" no fundo do modo dia — pedido específico depois de
    /// ver o protótipo: degradê bem suave de amarelo claro (creme, já da paleta) pra
    /// branco, de baixo pra cima, com aparência circular só o suficiente pra sugerir
    /// um sol nascendo, mas alongado o bastante pra não ser lido como um círculo
    /// completo. Técnica: `RadialGradient` centrado exatamente na borda inferior
    /// (`.bottom`) — isso já corta o círculo pela metade, só a parte de cima fica
    /// visível na tela — depois esticado no eixo Y a partir da própria borda inferior,
    /// o que alonga esse meio-círculo pra cima e é o que dá a sensação de
    /// alongamento em vez de um brilho circular óbvio.
    private var soveeDayGlow: some View {
        RadialGradient(
            colors: [SoveeColor.creme.opacity(0.85), SoveeColor.creme.opacity(0)],
            center: .bottom,
            startRadius: 0,
            endRadius: 260
        )
        .scaleEffect(x: 1, y: 2.4, anchor: .bottom)
    }

    /// Tela principal ANTIGA (Zleepy Lamp) — preservada byte a byte, sem nenhuma
    /// mudança, como opção de retorno rápido (`Self.useSoveeMainScreen = false`).
    private var legacyMainScreen: some View {
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
            screenTimeManager.removeShield(reason: .manualDisarm)
        }
    }
}

/// Tela mais "protótipo" do app antes desta rodada (fundo preto liso, botão vermelho
/// padrão do sistema) — retocada pra usar a mesma paleta SOVEE do resto do app em vez
/// de cores hardcoded, sem mudar a hierarquia/fluxo (ainda é: ícone, texto, botão
/// grande de parar). Layout/microinteração mais elaborados ficam pra uma passada
/// futura dedicada — essa mudança é só a paleta.
struct AlarmRingingView: View {
    @ObservedObject var alarmManager: AlarmManager

    private let theme = ModeTheme.zleepy

    var body: some View {
        ZStack {
            theme.stage.ignoresSafeArea()
            VStack(spacing: 28) {
                Image(systemName: "alarm.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(theme.accent)
                Text("Hora de acordar")
                    .font(.soveeDisplay(size: 28, weight: .bold))
                    .foregroundStyle(theme.ink)
                Button {
                    alarmManager.stopRingingAlarm()
                } label: {
                    Text("Parar")
                        .font(.soveeBody(.title2, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .foregroundStyle(theme.accentForeground)
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
