import SwiftUI
import UIKit

/// Se o onboarding já foi feito. Quem já usava o app antes dele existir (luminária já
/// vinculada) é marcado como feito no lançamento (`migrateExistingUser`), sem ver as telas.
enum OnboardingGate {
    static let doneKey = "com.luminaria.onboarding.done"
    /// Pedido de reabrir o onboarding (botão "rever configuração" da Ajuda).
    static let reopenNotification = Notification.Name("com.luminaria.onboarding.reopen")

    static var isDone: Bool { UserDefaults.standard.bool(forKey: doneKey) }

    static func markDone() { UserDefaults.standard.set(true, forKey: doneKey) }

    /// Chamado no lançamento (`AppDelegate`): instalação antiga com luminária vinculada
    /// já passou por tudo isso à mão.
    static func migrateExistingUser() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: doneKey) == nil else { return }
        if defaults.string(forKey: "com.luminaria.linkedTagID") != nil {
            defaults.set(true, forKey: doneKey)
        }
    }
}

/// Primeira abertura — 6 telas (protótipo aprovado em `design/onboarding_prototipo.html`):
/// boas-vindas → vincular a luminária → instalar os 2 Atalhos → permissões uma por vez →
/// primeira noite (horário de acordar) → ensaio do ritual (lê a tag sem armar nada).
/// Meta: menos de 3 minutos. A tela Ajuda vira consulta.
struct OnboardingView: View {
    @ObservedObject var nfcManager: NFCManager
    @ObservedObject var routineStore: SleepRoutineStore
    @ObservedObject var alarmManager: AlarmManager
    @ObservedObject var screenTimeManager: ScreenTimeManager
    @ObservedObject private var tester = ShortcutTester.shared
    var onFinish: () -> Void

    @State private var step = 0
    @State private var permissionIndex = 0
    @State private var wakeMinutes = 7 * 60
    @State private var rehearsalOK = false
    @State private var showsManualShortcutHelp = false
    @State private var copiedTime = false

    private let theme = ModeTheme.menu(armed: false)
    private let stepCount = 6

    var body: some View {
        ZStack {
            theme.stageBackground
            VStack(spacing: 0) {
                topBar
                Group {
                    switch step {
                    case 0: welcome
                    case 1: linkLamp
                    case 2: shortcuts
                    case 3: permissions
                    case 4: firstNight
                    default: rehearsal
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: step)
            }
        }
        .tint(theme.ink)
        .onAppear {
            if let routine = routineStore.activeRoutine {
                wakeMinutes = routine.alarmHour * 60 + routine.alarmMinute
            }
            nfcManager.onRehearsalRecognized = {
                withAnimation(.easeInOut(duration: 0.4)) { rehearsalOK = true }
            }
        }
        .onOpenURL { url in _ = tester.handle(url) }
        .sheet(isPresented: $showsManualShortcutHelp) {
            HelpView()
        }
    }

    // MARK: - Barra de cima

    private var topBar: some View {
        HStack {
            if step > 0 {
                MenuRoundButton(systemName: "chevron.left", label: "Voltar", theme: theme) { go(step - 1) }
            } else {
                Color.clear.frame(width: 34, height: 34)
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? theme.accent : (i < step ? theme.inkMuted : theme.hairline))
                        .frame(width: i == step ? 20 : 7, height: 7)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Passo \(step + 1) de \(stepCount)")
            Spacer()
            if step > 0 && step < stepCount - 1 {
                Button("pular") { go(step + 1) }
                    .font(.luminaria(.subheadline))
                    .foregroundStyle(theme.inkMuted)
                    .frame(width: 44)
            } else {
                Color.clear.frame(width: 44, height: 34)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .frame(height: 52)
    }

    private func go(_ index: Int) {
        withAnimation { step = min(max(index, 0), stepCount - 1) }
    }

    // MARK: - Moldura de cada tela

    private func screen<Content: View, Footer: View>(@ViewBuilder _ content: () -> Content,
                                                     @ViewBuilder footer: () -> Footer) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) { content() }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
            VStack(spacing: 8) { footer() }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .padding(.top, 8)
        }
    }

    private func face(asleep: Bool, recognized: Bool = false) -> some View {
        Image(asleep ? "LogoSono" : "LogoAcordado")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(asleep ? (recognized ? SoveeColor.sage : SoveeColor.noiteAzul) : SoveeColor.carvao)
            .padding(36)
            .frame(width: 150, height: 150)
            .background(Circle().fill(Color.white))
            .overlay(Circle().stroke(SoveeColor.sage.opacity(recognized ? 0.4 : 0), lineWidth: 6))
            .shadow(color: SoveeColor.carvao.opacity(0.12), radius: 9, x: 0, y: 6)
            .accessibilityHidden(true)
    }

    private func checkLabel(_ text: String) -> some View {
        Label(text, systemImage: "checkmark")
            .font(.luminaria(.subheadline, weight: .medium))
            .foregroundStyle(SoveeColor.floresta)
    }

    // MARK: 1. Boas-vindas

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer()
            face(asleep: false)
            Text("hora de desligar.")
                .font(.soveeDisplay(size: 30, weight: .medium))
                .foregroundStyle(theme.ink)
            Text("Encostou o celular na luminária, o SOVEE entra em modo noite: liga o Não Perturbe, bloqueia os apps que você escolher e te acorda de manhã.")
                .font(.luminaria(.body))
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Spacer()
            FullPillButton(title: "começar", theme: theme) { go(1) }
            Text("leva uns 3 minutos")
                .font(.luminaria(.footnote))
                .foregroundStyle(theme.inkMuted)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    // MARK: 2. Luminária

    private var linkLamp: some View {
        screen {
            MenuHeader(title: "sua luminária", subtitle: "Encoste o topo do iPhone na luminária. É só uma vez: depois ela vira o botão de dormir.", theme: theme)
            ThemedCard(theme: theme) {
                ThemedRow(
                    theme: theme,
                    title: nfcManager.isLinked ? "Luminária vinculada" : "Ainda não vinculada",
                    subtitle: nfcManager.isLinked ? "Pronto. Daqui pra frente, encostar arma a noite." : "O iPhone mostra uma janela de leitura; encoste até vibrar.",
                    leading: { IconBadge(systemName: nfcManager.isLinked ? "checkmark" : "wave.3.right", theme: theme) },
                    accessory: { EmptyView() }
                )
            }
            if let error = nfcManager.errorMessage {
                Text(error)
                    .font(.luminaria(.footnote, weight: .medium))
                    .foregroundStyle(theme.danger)
                    .padding(.horizontal, 6)
            }
            Text("Qualquer adesivo NFC comum serve. Perdeu ou trocou? Depois do primeiro vínculo, qualquer tag reconhecida funciona.")
                .font(.luminaria(.footnote))
                .foregroundStyle(theme.inkMuted)
                .padding(.horizontal, 6)
        } footer: {
            if nfcManager.isLinked {
                FullPillButton(title: "continuar", theme: theme) { go(2) }
            } else {
                FullPillButton(title: "vincular luminária", theme: theme) { nfcManager.beginScanning() }
            }
        }
    }

    // MARK: 3. Atalhos

    private var shortcuts: some View {
        screen {
            MenuHeader(title: "dois atalhos", subtitle: "O iPhone não deixa apps ligarem o Não Perturbe. Estes dois atalhos fazem isso por nós. Instale e toque em \"Adicionar atalho\".", theme: theme)
            ThemedCard(theme: theme) {
                shortcutRow(name: ShortcutManager.shortcutName, detail: "Liga o Não Perturbe até você desligar.", icon: "moon", divider: false)
                shortcutRow(name: ShortcutManager.wakeShortcutName, detail: "Desliga o Não Perturbe de manhã.", icon: "sun.max", divider: true)
            }
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.circle")
                Text("Não renomeie os atalhos. O SOVEE chama cada um pelo nome.")
            }
            .font(.luminaria(.footnote, weight: .medium))
            .foregroundStyle(theme.ink)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SoveeColor.ambar.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button { tester.start() } label: {
                Text(tester.state == .running ? "testando…" : "testar atalhos")
                    .font(.luminaria(.body))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundStyle(theme.ink)
                    .overlay(Capsule().strokeBorder(theme.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(tester.state == .running)
            testResult

            if ShortcutManager.sleepShortcutInstallLink == nil || ShortcutManager.wakeShortcutInstallLink == nil {
                Button("criar os atalhos à mão") { showsManualShortcutHelp = true }
                    .font(.luminaria(.footnote, weight: .medium))
                    .foregroundStyle(theme.ink)
                    .padding(.horizontal, 6)
            }

            safetyNet
        } footer: {
            FullPillButton(title: "continuar", theme: theme) { go(3) }
        }
    }

    private func shortcutRow(name: String, detail: String, icon: String, divider: Bool) -> some View {
        let url = ShortcutManager.installURL(forShortcutNamed: name)
        return ThemedRow(
            theme: theme,
            showsDivider: divider,
            title: name,
            subtitle: detail,
            leading: { IconBadge(systemName: icon, theme: theme) },
            accessory: {
                Button {
                    if let url { UIApplication.shared.open(url) }
                } label: {
                    Text(url == nil ? "link em breve" : "instalar")
                        .font(.luminaria(.footnote, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .foregroundStyle(url == nil ? theme.inkMuted : theme.accentForeground)
                        .background(url == nil ? (theme.chip ?? theme.card) : theme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(url == nil)
            }
        )
    }

    @ViewBuilder
    private var testResult: some View {
        switch tester.state {
        case .ok:
            checkLabel("Os dois atalhos responderam.")
        case .missing(let names):
            Text("Não achei: \(names.joined(separator: " e ")). Instale de novo, sem trocar o nome.")
                .font(.luminaria(.footnote, weight: .medium))
                .foregroundStyle(theme.danger)
        case .noAnswer:
            Text("O Atalhos não respondeu. Se ele mostrou um aviso de atalho não encontrado, instale de novo, sem trocar o nome.")
                .font(.luminaria(.footnote))
                .foregroundStyle(theme.inkMuted)
        case .running:
            Text("O Atalhos vai abrir rapidinho duas vezes: liga e desliga o Não Perturbe.")
                .font(.luminaria(.footnote))
                .foregroundStyle(theme.inkMuted)
        case .idle:
            EmptyView()
        }
    }

    /// Automação pessoal da manhã (o iPhone não deixa instalar por link): o app mostra o
    /// horário da rotina pra pessoa copiar.
    private var safetyNet: some View {
        let time = String(format: "%02d:%02d", wakeMinutes / 60, wakeMinutes % 60)
        return ThemedCard(title: "recomendado · rede de segurança da manhã", theme: theme) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Se você parar o despertador sem abrir o SOVEE, o Não Perturbe pode continuar ligado. Uma automação pessoal resolve; o iPhone não deixa instalar por link, então são 4 toques:")
                    .font(.luminaria(.footnote))
                    .foregroundStyle(theme.inkMuted)
                HStack {
                    Text("Horário do seu despertador: \(time)")
                        .font(.luminaria(.subheadline, weight: .medium))
                        .foregroundStyle(theme.ink)
                    Spacer()
                    Button(copiedTime ? "copiado" : "copiar") {
                        UIPasteboard.general.string = time
                        copiedTime = true
                    }
                    .font(.luminaria(.footnote, weight: .medium))
                    .foregroundStyle(theme.ink)
                }
                .padding(10)
                .background(theme.chip ?? theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Atalhos → Automação → Nova automação")
                    Text("2. Hora do dia → \(time) → Diariamente → Executar imediatamente")
                    Text("3. Ação \"Definir Foco\" → Não Perturbe → Desativar")
                    Text("4. OK")
                }
                .font(.luminaria(.footnote))
                .foregroundStyle(theme.ink)
            }
            .padding(10)
        }
    }

    // MARK: 4. Permissões

    private struct Permission {
        let icon: String
        let title: String
        let why: String
        let required: Bool
    }

    private var permissionList: [Permission] {
        var list = [Permission(icon: "bell", title: "Notificações", why: "Pro despertador em iPhones sem alarme do sistema e pros avisos do SOVEE.", required: true)]
        if SystemAlarm.authorization != .unavailable {
            list.append(Permission(icon: "alarm", title: "Alarmes", why: "O despertador toca como o do iPhone: no silencioso, com o Foco ligado e o app fechado.", required: true))
        }
        list.append(Permission(icon: "shield.lefthalf.filled", title: "Tempo de Uso", why: "Pra bloquear os apps que você escolher durante a noite. O SOVEE nunca vê quais apps são.", required: true))
        list.append(Permission(icon: "calendar", title: "Calendário · opcional", why: "Pra trocar de rotina sozinho em dias com um evento, como \"Viagem\".", required: false))
        return list
    }

    private var permissions: some View {
        let list = permissionList
        return screen {
            MenuHeader(title: "permissões", subtitle: "Uma de cada vez, com o porquê. Você pode mudar depois em Ajustes.", theme: theme)
            ThemedCard(theme: theme) {
                ForEach(Array(list.enumerated()), id: \.offset) { index, permission in
                    ThemedRow(
                        theme: theme,
                        showsDivider: index > 0,
                        title: permission.title,
                        subtitle: index == permissionIndex ? permission.why : nil,
                        leading: { IconBadge(systemName: permission.icon, theme: theme) },
                        accessory: {
                            if index < permissionIndex {
                                Image(systemName: "checkmark").foregroundStyle(SoveeColor.floresta)
                            }
                        }
                    )
                    .opacity(index > permissionIndex ? 0.45 : 1)
                }
            }
        } footer: {
            if permissionIndex < list.count {
                let current = list[permissionIndex]
                FullPillButton(title: "permitir " + current.title.components(separatedBy: " ·").first!.lowercased(), theme: theme) {
                    request(current)
                    permissionIndex += 1
                }
                if !current.required {
                    Button("agora não") { permissionIndex += 1 }
                        .font(.luminaria(.body))
                        .foregroundStyle(theme.inkMuted)
                        .padding(.vertical, 8)
                }
            } else {
                FullPillButton(title: "continuar", theme: theme) { go(4) }
            }
        }
    }

    private func request(_ permission: Permission) {
        switch permission.icon {
        case "bell": alarmManager.requestNotificationPermission()
        case "alarm": alarmManager.requestSystemAlarmPermission()
        case "shield.lefthalf.filled": screenTimeManager.requestAuthorization()
        case "calendar": routineStore.requestCalendarAccess()
        default: break
        }
    }

    // MARK: 5. Primeira noite

    private var firstNight: some View {
        screen {
            MenuHeader(title: "sua primeira noite", subtitle: "Dá pra mudar tudo depois em Rotinas.", theme: theme)
            ThemedCard(title: "que horas você acorda?", theme: theme) {
                HStack(spacing: 18) {
                    stepperButton("minus", label: "15 minutos antes") { wakeMinutes = (wakeMinutes - 15 + 1440) % 1440 }
                    Text(String(format: "%02d:%02d", wakeMinutes / 60, wakeMinutes % 60))
                        .font(.soveeDisplay(size: 44, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(theme.ink)
                    stepperButton("plus", label: "15 minutos depois") { wakeMinutes = (wakeMinutes + 15) % 1440 }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            Text("O despertador só toca nas noites em que você encostar na luminária. Os apps a bloquear você escolhe em Rotinas.")
                .font(.luminaria(.footnote))
                .foregroundStyle(theme.inkMuted)
                .padding(.horizontal, 6)
        } footer: {
            FullPillButton(title: "criar rotina", theme: theme) {
                saveFirstRoutine()
                go(5)
            }
        }
    }

    private func stepperButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.ink)
                .frame(width: 42, height: 42)
                .background(theme.chip ?? theme.card, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func saveFirstRoutine() {
        var routine = routineStore.activeRoutine ?? SleepRoutine(name: "Minha rotina")
        // Horário por dia da semana só é trocado se a pessoa mudou o horário aqui.
        if routine.weekdayAlarms != nil, wakeMinutes != routine.alarmHour * 60 + routine.alarmMinute {
            routine.weekdayAlarms = nil
        }
        routine.alarmHour = wakeMinutes / 60
        routine.alarmMinute = wakeMinutes % 60
        routineStore.upsert(routine)
        if routineStore.activeRoutineID == nil {
            routineStore.setActive(id: routine.id)
        }
    }

    // MARK: 6. Ensaio

    private var rehearsal: some View {
        VStack(spacing: 16) {
            Spacer()
            face(asleep: true, recognized: rehearsalOK)
            Text(rehearsalOK ? "funcionou." : "encoste agora")
                .font(.soveeDisplay(size: 30, weight: .medium))
                .foregroundStyle(theme.ink)
            Text(rehearsalOK ? "Hoje à noite: toque no botão, encoste na luminária e boa noite." : "Um ensaio do ritual de toda noite. Nada é armado: só confere se a leitura funciona.")
                .font(.luminaria(.body))
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            if rehearsalOK {
                ThemedCard(theme: theme) {
                    ThemedRow(theme: theme, title: String(format: "Despertador às %02d:%02d", wakeMinutes / 60, wakeMinutes % 60),
                              subtitle: "Só nas noites em que você encostar.",
                              leading: { IconBadge(systemName: "alarm", theme: theme) }, accessory: { EmptyView() })
                    ThemedRow(theme: theme, showsDivider: true, title: "Não Perturbe pelo atalho",
                              subtitle: "Liga ao encostar, desliga ao acordar.",
                              leading: { IconBadge(systemName: "moon", theme: theme) }, accessory: { EmptyView() })
                }
            }
            if let error = nfcManager.errorMessage, !rehearsalOK {
                Text(error)
                    .font(.luminaria(.footnote, weight: .medium))
                    .foregroundStyle(theme.danger)
            }
            Spacer()
            if rehearsalOK {
                FullPillButton(title: "concluir", theme: theme) { finish() }
            } else {
                FullPillButton(title: "encostar", theme: theme) { nfcManager.beginRehearsal() }
                Button("pular o ensaio") { finish() }
                    .font(.luminaria(.subheadline))
                    .foregroundStyle(theme.inkMuted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private func finish() {
        nfcManager.onRehearsalRecognized = nil
        OnboardingGate.markDone()
        onFinish()
    }
}
