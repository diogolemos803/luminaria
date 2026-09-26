import SwiftUI

struct ContentView: View {
    @StateObject private var nfcManager = NFCManager()
    @StateObject private var alarmManager = AlarmManager.shared
    @StateObject private var routineStore = SleepRoutineStore()
    @StateObject private var screenTimeManager = ScreenTimeManager.shared
    @StateObject private var sleepReportStore = SleepReportStore.shared
    // `@ObservedObject`, não `@StateObject`: é um singleton compartilhado (dono do
    // ciclo de vida é ele mesmo, `ContentView` só observa) — a fase dele decide se
    // a cena de decolagem mostra o foguete ou a explosão (ver `soveeMainScreen`).
    @ObservedObject private var growthTracker = NightSessionActivityTracker.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var isNightModeArmed = false
    @State private var isPressed = false
    @State private var showSettings = false
    // Controla a saída do botão redondo quando a decolagem assume a tela (sequência
    // aprovada em `design/entrada_prototipo.html`): a luminária é reconhecida → o
    // rostinho azul fica verde → 3s depois o botão sai pela esquerda enquanto o céu
    // desce de cima e a Terra com o foguete sobe de baixo. Ver `onRecognizedTap`.
    @State private var showsRoundButton = true
    @State private var isTagRecognized = false
    @State private var tagPulse = false
    // Instante em que a cena de decolagem começa a entrar; `nil` = app reaberto no
    // meio de uma sessão (mostra direto o foguete em voo, sem repetir a entrada).
    @State private var sceneStartDate: Date?

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
                // Permissão de "Alarmes" (AlarmKit, iOS 26+) — é ela que faz o
                // despertador tocar no silencioso, com Foco e com o app fechado.
                alarmManager.requestSystemAlarmPermission()
                WidgetBridge.publishStats()
                screenTimeManager.refreshAuthorizationStatus()
                // Cobre o app sendo aberto do zero (cold launch): onChange(of: scenePhase)
                // só reage a mudanças, não à primeira transição pra .active.
                alarmManager.checkForMissedAlarm()
                // O bloqueio de apps (ManagedSettingsStore) continua valendo mesmo se o
                // processo morrer — sem isso, o botão reabriria mostrando "Living mode"
                // com os apps ainda travados e nenhum jeito de desarmar pelo app.
                if screenTimeManager.isShieldActive {
                    isNightModeArmed = true
                    // O app pode ter sido reaberto no meio de uma sessão já em
                    // andamento (o momento da decolagem já passou há muito tempo) —
                    // nesse caso o botão já deve nascer escondido, sem repetir a
                    // sequência de saída.
                    showsRoundButton = false
                    isTagRecognized = true
                    sceneStartDate = nil
                }
                nfcManager.onRecognizedTap = {
                    guard isNightModeArmed else { return }
                    // Resolve a rotina automática por calendário só AGORA, no instante
                    // em que a luminária é reconhecida de verdade — pedido explícito do
                    // usuário: antes isso rodava no toque do botão, o que trocava a
                    // rotina ativa mesmo se a pessoa cancelasse a leitura NFC depois,
                    // dando a impressão de que a troca automática "ficava ligada o dia
                    // inteiro" em vez de só valer pra noite em que a tag é lida.
                    let recognizedAt = Date()
                    Task { @MainActor in
                        if let autoRoutineID = await routineStore.resolveAutoActivateRoutine() {
                            routineStore.setActive(id: autoRoutineID)
                        }
                        guard let routine = routineStore.activeRoutine else { return }
                        ShortcutManager.shared.runSleepShortcut()
                        alarmManager.armAlarm(hour: routine.alarmHour, minute: routine.alarmMinute, soundFileName: routine.soundOption.fileName)
                        screenTimeManager.applyShield(selection: routine.appSelection)
                        // cartão da noite na tela bloqueada (ver WidgetBridge)
                        WidgetBridge.startNightActivity(alarmDate: alarmManager.nextFireDate)
                    }
                    // Sequência visual (relógio próprio, independente da consulta ao
                    // calendário acima): disparada direto aqui — no exato instante da
                    // leitura — em vez de observar `screenTimeManager.isShieldActive`
                    // de fora, pra não depender de timing de propagação do `@Published`.
                    Task { @MainActor in
                        showsRoundButton = true
                        // Espera a folha de sistema do NFC terminar de fechar, senão
                        // o verde acontece escondido atrás dela.
                        await sleep(until: recognizedAt.addingTimeInterval(0.9))
                        guard isNightModeArmed else { return }
                        withAnimation(.easeInOut(duration: 0.45)) { isTagRecognized = true }
                        withAnimation(.easeOut(duration: 0.22)) { tagPulse = true }
                        await sleep(until: Date().addingTimeInterval(0.22))
                        withAnimation(.easeOut(duration: 0.33)) { tagPulse = false }
                        // 3s de rostinho verde antes da cena entrar (eram 2s — o
                        // usuário pediu mais 1s depois de testar no device).
                        await sleep(until: recognizedAt.addingTimeInterval(3.9))
                        guard isNightModeArmed else { return }
                        sceneStartDate = Date()
                        showsRoundButton = false
                    }
                }
                // Sem isso, cancelar a leitura, deixar dar timeout (~60s do CoreNFC) ou
                // encostar a tag errada deixava o app preso em "Zleepy mode" sem nada
                // realmente armado — o modo noite só deve "pegar" se a leitura terminar
                // com sucesso.
                nfcManager.onScanEndedWithoutMatch = {
                    isNightModeArmed = false
                    resetEntrance()
                }
                // O desbloqueio de apps em si já acontece dentro de AlarmManager
                // (funciona mesmo com o app suspenso) — isso aqui só sincroniza o botão
                // redondo de volta pra "Living mode" quando o app está em primeiro plano
                // na hora que o despertador dispara.
                alarmManager.onAlarmFired = {
                    isNightModeArmed = false
                    resetEntrance()
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    alarmManager.checkForMissedAlarm()
                    screenTimeManager.refreshAuthorizationStatus()
                    // Atualiza o estado da permissão de Alarmes (pode ter mudado em Ajustes).
                    alarmManager.requestSystemAlarmPermission()
                    // Noite encerrada com o app em segundo plano: desliga o Foco agora.
                    ShortcutManager.shared.runPendingWakeShortcutIfNeeded()
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
        // recorde histórico — se a sequência já quebrou, o pouso de amanhã reflete
        // isso). Ver `GrowthDestinations`/`DetoxStats.currentCleanDayStreak`.
        let destination = GrowthDestinations.furthestUnlocked(
            currentStreak: DetoxStats.currentCleanDayStreak(in: sleepReportStore.entries)
        )
        // Só depois do botão já ter saído de cena — a decolagem assume a tela
        // inteira no lugar dele, nunca por cima (ver `showsRoundButton`).
        let showsJourney = isNightModeArmed && screenTimeManager.isShieldActive && !showsRoundButton
        return ZStack {
            if isNightModeArmed {
                theme.stage.ignoresSafeArea()

                // Pedido do usuário: dá pra "puxar" a tela pra baixo durante a
                // viagem e achar o botão redondo de novo, pra desligar o modo noite
                // manualmente sem depender só do passe de emergência (que libera os
                // apps mas não desarma a sessão). Duas "páginas" empilhadas num
                // ScrollView, cada uma do tamanho exato da tela: a cena decorativa
                // em cima, o botão de desligar embaixo.
                if showsJourney {
                    GeometryReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 0) {
                                RocketGrowthVisual(sceneStart: sceneStartDate, explosionDate: growthTracker.lastExplosionDate)
                                    .render(phase: growthTracker.phase, destination: destination, theme: theme)
                                    .frame(width: proxy.size.width, height: proxy.size.height)

                                nightReturnPage(theme: theme)
                                    .frame(width: proxy.size.width, height: proxy.size.height)
                            }
                        }
                    }
                    .ignoresSafeArea()
                    // A entrada (céu descendo, Terra subindo) é desenhada pela
                    // própria cena a partir de `sceneStartDate` — sem fade por cima.
                    .transition(.identity)
                }
            } else {
                Color.white.ignoresSafeArea()
                soveeDayGlow.ignoresSafeArea()
            }

            if showsRoundButton {
                Button(action: toggleNightMode) {
                    Image(isNightModeArmed ? "LogoSono" : "LogoAcordado")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .padding(9)
                        // pulso só no rostinho (não no botão) quando ele fica verde
                        .scaleEffect(tagPulse ? 1.06 : 1)
                        .frame(width: 220, height: 220)
                        .foregroundStyle(roundButtonIconColor(theme: theme))
                        // De dia o botão é branco puro — `theme.card` de dia virou um
                        // cinza claro (pros cartões do menu aparecerem no fundo branco).
                        .background(isNightModeArmed ? theme.card : Color.white)
                        .clipShape(Circle())
                        .shadow(color: theme.ink.opacity(0.12), radius: 18, x: 0, y: 8)
                }
                .buttonStyle(.plain)
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .accessibilityLabel(modeName)
                .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
            }

            // Tagline da marca ("hora de desligar.") só no modo noite — é o
            // momento que ela descreve (encerrar o dia). No modo dia, silêncio
            // deliberado em vez de repetir uma legenda "Living mode" técnica.
            // Sai junto com o botão quando a decolagem entra.
            if isNightModeArmed && showsRoundButton {
                Text("hora de desligar.")
                    .font(.soveeDisplay(size: 15, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(theme.ink.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 40)
                    .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
            }

            // Só aparece com o bloqueio de apps realmente ativo — nunca antes da
            // luminária ser reconhecida. Continua visível com o botão redondo escondido
            // (sobre a cena da decolagem). Usar o passe encerra a noite e volta pro modo
            // dia, mas mantém o despertador (ver `useEmergencyPass`).
            if isNightModeArmed && screenTimeManager.isShieldActive {
                emergencyPassButton(ink: theme.inkMuted)
            }

            // Depois de um passe de emergência o despertador continua armado mesmo no
            // modo dia — sem esse lembrete, não daria pra saber que ele ainda vai tocar.
            if !isNightModeArmed, let fireDate = alarmManager.nextFireDate, !alarmManager.isAlarmRinging {
                Text("Despertador às \(fireDate.formatted(date: .omitted, time: .shortened))")
                    .font(.soveeBody(.caption))
                    .foregroundStyle(theme.inkMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 40)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: isNightModeArmed)
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isPressed)
        // Saída: aceleração pura (ease-in), como no protótipo — o botão "parte"
        // em vez de deslizar preguiçoso. Volta (desarme/passe): só um fade suave.
        .animation(
            showsRoundButton ? Animation.easeOut(duration: 0.5) : Animation.timingCurve(0.5, 0, 0.75, 0, duration: 0.6),
            value: showsRoundButton
        )
    }

    /// Dia: grafite. Noite: azul de luar enquanto espera a luminária; verde (sage)
    /// assim que a tag é reconhecida.
    private func roundButtonIconColor(theme: ModeTheme) -> Color {
        guard isNightModeArmed else { return SoveeColor.carvao }
        return isTagRecognized ? SoveeColor.sage : theme.accent
    }

    /// 1 passe por noite: some o texto de "disponível" e mostra quando volta.
    private func emergencyPassButton(ink: Color) -> some View {
        let available = screenTimeManager.isEmergencyPassAvailable
        let label: String
        if available {
            label = "Passe de emergência (1 por noite)"
        } else if let date = screenTimeManager.emergencyPassAvailableAgainAt {
            label = "Passe de emergência já usado — volta às \(date.formatted(date: .omitted, time: .shortened))"
        } else {
            label = "Passe de emergência já usado"
        }
        return Button(action: useEmergencyPass) {
            Text(label)
                .font(.soveeBody(.caption))
                .foregroundStyle(ink)
        }
        .disabled(!available)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 16)
    }

    /// Passe de emergência (pedido do usuário, 2026-09-25): libera os apps, encerra a
    /// noite e volta pro modo dia — mas o despertador da manhã continua armado (é isso
    /// que o diferencia do desligar pelo botão redondo, que cancela tudo).
    private func useEmergencyPass() {
        guard screenTimeManager.useEmergencyPass(nextAlarmDate: alarmManager.nextFireDate) else { return }
        ShortcutManager.shared.requestWakeShortcut()
        nfcManager.stopScanning()
        isNightModeArmed = false
        resetEntrance()
    }

    /// Volta o botão redondo pro estado inicial (antes de qualquer leitura).
    private func resetEntrance() {
        showsRoundButton = true
        isTagRecognized = false
        tagPulse = false
        sceneStartDate = nil
    }

    private func sleep(until date: Date) async {
        let wait = date.timeIntervalSinceNow
        guard wait > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
    }

    /// Segunda "página" da viagem, só alcançável rolando a tela pra baixo — o mesmo
    /// botão redondo de sempre (agora chamando `toggleNightMode`, que desarma direto
    /// já que `isNightModeArmed` está `true`), pra quem quer desligar o modo noite
    /// de vez, não só liberar os apps com o passe de emergência.
    private func nightReturnPage(theme: ModeTheme) -> some View {
        ZStack {
            theme.stage
            VStack(spacing: 18) {
                Image(systemName: "chevron.up")
                    .font(.title3)
                    .foregroundStyle(theme.inkMuted.opacity(0.6))
                Button(action: toggleNightMode) {
                    Image("LogoSono")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .padding(9)
                        .frame(width: 180, height: 180)
                        .foregroundStyle(SoveeColor.sage)
                        .background(theme.card)
                        .clipShape(Circle())
                        .shadow(color: theme.ink.opacity(0.12), radius: 18, x: 0, y: 8)
                }
                .buttonStyle(.plain)
                Text("Puxe a tela pra cá pra desligar o modo noite")
                    .font(.soveeBody(.footnote))
                    .foregroundStyle(theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
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

            // Mesma regra da tela SOVEE (1 por noite, volta pro modo dia) — só o botão
            // mudou aqui, o resto da tela antiga segue preservado.
            if isNightModeArmed && screenTimeManager.isShieldActive {
                emergencyPassButton(ink: inkSleep)
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
            isTagRecognized = false
            nfcManager.beginScanning()
        } else {
            nfcManager.stopScanning()
            alarmManager.disarmAlarm()
            screenTimeManager.removeShield(reason: .manualDisarm)
            // Desliga o Foco da noite (Atalho "Acordar") — só roda se o de dormir rodou.
            ShortcutManager.shared.requestWakeShortcut()
            resetEntrance()
        }
    }
}

/// Tela do despertador tocando — mostra a animação de pouso na Lua
/// (`MoonLandingScene`, ver `RocketScenes.swift` e `design/pouso_prototipo.html`)
/// atrás do botão "Parar": a pessoa aguentou a noite inteira (chegar aqui já
/// significa que `AlarmManager.triggerAlarm()` registrou a sessão como
/// `.alarmFired`), então o foguete pousa, o astronauta sai e crava a bandeira com o
/// número de dias da sequência atual.
struct AlarmRingingView: View {
    @ObservedObject var alarmManager: AlarmManager
    @ObservedObject var sleepReportStore: SleepReportStore = .shared

    private let theme = ModeTheme.zleepy

    private var streakDays: Int {
        DetoxStats.currentCleanDayStreak(in: sleepReportStore.entries)
    }

    var body: some View {
        ZStack {
            theme.stage.ignoresSafeArea()

            MoonLandingScene(streakDays: streakDays)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                Spacer()
                Text("Hora de acordar")
                    .font(.soveeDisplay(size: 28, weight: .bold))
                    .foregroundStyle(theme.ink)
                    // fica sobre o chão cinza da Lua — sombra leve pra manter leitura
                    .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 2)
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
                .padding(.top, 12)
                .padding(.bottom, 40)
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

                        ThemedCard(title: "Amigos", theme: theme) {
                            NavigationLink {
                                FriendsView()
                            } label: {
                                ThemedRow(
                                    theme: theme,
                                    title: "Amigos e ranking",
                                    subtitle: "Quem fica mais noites longe do celular",
                                    leading: { IconBadge(systemName: "person.2.fill", theme: theme) },
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
