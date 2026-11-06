import SwiftUI

// Telas da lâmpada SOVEE (Bluetooth), aprovadas em `design/lampada_prototipo.html`
// (controle com a luminária desenhada no meio, 5 bolinhas em cima e o painel da bolinha
// embaixo; pareamento; lâmpada ao dormir/ao acordar na rotina) e
// `design/integracao_prototipo.html` (opção C: bolinha no canto da tela inicial).

extension LampManager {
    /// Linha de status curta (embaixo do nome da lâmpada, no cartão das Configurações).
    var statusText: String {
        switch link {
        case .connected: return isSimulated ? "Conectada · simulada" : "Conectada"
        case .connecting: return "Procurando a lâmpada…"
        case .searching: return "Procurando lâmpada nova…"
        case .pairing: return "Pareando…"
        case .bluetoothOff: return "Bluetooth desligado"
        case .unauthorized: return "Sem permissão de Bluetooth"
        case .unsupportedVersion: return "Conectada, mas não reconhecida"
        case .staleBond: return "Pareamento antigo no iPhone"
        case .pairingRejected: return "Pareamento recusado"
        case .noLamp: return "Nenhuma lâmpada"
        }
    }
}

extension LampLink {
    /// Explicação de quando a lâmpada não pode ser usada agora (nil = nada a explicar).
    var notice: String? {
        switch self {
        case .connecting:
            return "Chegue perto da lâmpada e confira se ela está na tomada. O app conecta sozinho quando ela aparecer."
        case .bluetoothOff:
            return "O Bluetooth do iPhone está desligado. Ligue na Central de Controle pra falar com a lâmpada."
        case .unauthorized:
            return "O sovee não tem permissão de Bluetooth. Ative em Ajustes → sovee → Bluetooth."
        case .unsupportedVersion(let version):
            return "Esta lâmpada usa uma versão do protocolo que o app não conhece (v\(version)). Atualize o app sovee pra controlar ela."
        case .staleBond:
            return "O iPhone ainda guarda um pareamento antigo desta lâmpada. Vá em Ajustes → Bluetooth, toque no ⓘ da \(LampProtocol.settingsName) e em “Esquecer este dispositivo”. Depois pareie de novo."
        case .pairingRejected:
            return "A lâmpada recusou o pareamento. Segure o toque da lâmpada por 3 segundos até ela piscar âmbar e tente de novo."
        default:
            return nil
        }
    }
}

private func twoDigits(_ h: Int, _ m: Int) -> String { String(format: "%d:%02d", h, m) }

private struct LampNotice: View {
    enum Kind { case info, warning, danger }
    let kind: Kind
    let text: String
    let theme: ModeTheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: kind == .info ? "info.circle" : "exclamationmark.triangle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.luminaria(.caption))
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(wash)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var tint: Color {
        switch kind {
        case .info: return theme.accent
        case .warning: return Color(red: 0.79, green: 0.60, blue: 0.18)
        case .danger: return theme.danger
        }
    }

    private var wash: Color {
        switch kind {
        case .info: return theme.accentWash
        case .warning: return Color(red: 0.79, green: 0.60, blue: 0.18).opacity(0.14)
        case .danger: return theme.dangerWash
        }
    }
}

/// Botão em pílula clara (Identificar, Esquecer, Cancelar a luz de hoje).
private struct LampGhostButton: View {
    let title: String
    var isDanger = false
    let theme: ModeTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.luminaria(.subheadline, weight: theme.isSoveeMenu ? .medium : .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDanger ? theme.danger : (theme.chipInk ?? theme.accent))
        .background(isDanger ? theme.dangerWash : (theme.chip ?? theme.accentWash))
        .clipShape(Capsule())
    }
}

// MARK: - Tela da lâmpada

private enum LampTool: String, CaseIterable, Identifiable {
    case presets, mix, brightness, schedule, scenes, lamp

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .presets: return "circle.grid.2x2.fill"
        case .mix: return "circle.lefthalf.filled"
        case .brightness: return "sun.max"
        case .schedule: return "sunrise"
        case .scenes: return "flame.fill"
        case .lamp: return "slider.horizontal.3"
        }
    }

    var title: String {
        switch self {
        case .presets: return "Cores prontas"
        case .mix: return "Mistura"
        case .brightness: return "Brilho"
        case .schedule: return "Luz programada"
        case .scenes: return "Cenários · teste"
        case .lamp: return "Lâmpada"
        }
    }
}

/// Tela da lâmpada — "irmã" da tela do botão redondo (as duas trocam no lugar pela
/// bolinha do canto, ver `ContentView`). A luminária fica parada no meio; as 5 bolinhas de
/// cima escolhem o que aparece no painel de baixo. Sem lâmpada pareada, mostra o pareamento.
struct LampControlView: View {
    @ObservedObject var lamp: LampManager
    let theme: ModeTheme
    let isNight: Bool
    @State private var tool: LampTool = .presets
    @State private var confirmForget = false
    /// Modo teste dos cenários (fogueira etc.) — ligado em Lâmpada → "Cenários (teste)".
    @AppStorage(LampScenesFlag.key) private var scenesEnabled = false

    private var tools: [LampTool] {
        LampTool.allCases.filter { $0 != .scenes || scenesEnabled }
    }

    var body: some View {
        ZStack {
            theme.stage.ignoresSafeArea()
            if lamp.hasLamp {
                control
            } else {
                ScrollView {
                    LampPairingContent(lamp: lamp, theme: theme)
                        .padding(16)
                }
            }
        }
    }

    /// O que a cúpula mostra: a cor que a própria lâmpada informa.
    private var shown: (on: Bool, mix: Double, brightness: Double) {
        // Mexendo agora (ou há menos de 1,5 s): mostra o valor do controle, sem esperar a
        // lâmpada responder — a resposta chega aos pedaços e a cor andaria aos saltos.
        if lamp.isConnected, isEditing {
            return (true, lamp.manualMix, max(lamp.manualBrightness, 0.01))
        }
        if lamp.isConnected, let color = lamp.state?.color, !color.isOff {
            return (true, color.mix, color.brightness)
        }
        return (false, lamp.manualMix, lamp.manualBrightness)
    }

    private var usable: Bool { lamp.isConnected }

    private var isEditing: Bool { Date().timeIntervalSince(lamp.lastManualEdit) < 1.5 }

    private var control: some View {
        VStack(spacing: 12) {
            header
            toolRow
            notices
            illustration
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            readout
            panel
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .confirmationDialog("Esquecer a lâmpada?", isPresented: $confirmForget, titleVisibility: .visible) {
            Button("Esquecer", role: .destructive) { lamp.forget() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Pra parear de novo depois, apague também em Ajustes → Bluetooth → \(LampProtocol.settingsName) → “Esquecer este dispositivo”.")
        }
    }

    /// Com um cenário rodando, a cúpula anima com a mesma fórmula da lâmpada.
    @ViewBuilder
    private var illustration: some View {
        if let scene = lamp.activeScene, usable {
            TimelineView(.animation) { context in
                let s = scene.sample(at: context.date.timeIntervalSince(lamp.sceneStart))
                LampIllustration(isOn: true, mix: s.mix, brightness: max(s.brightness * lamp.sceneBrightness, 0.01),
                                 line: theme.ink, stage: theme.stage, isNight: isNight)
            }
        } else {
            LampIllustration(isOn: shown.on, mix: shown.mix, brightness: shown.brightness,
                             line: theme.ink, stage: theme.stage, isNight: isNight)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(LampProtocol.displayName)
                    .font(.luminaria(.headline, weight: .bold))
                    .foregroundStyle(theme.ink)
                HStack(spacing: 6) {
                    Circle()
                        .fill(usable ? Color(red: 0.44, green: 0.65, blue: 0.5) : theme.inkMuted)
                        .frame(width: 7, height: 7)
                    Text(lamp.statusText)
                        .font(.luminaria(.caption))
                        .foregroundStyle(theme.inkMuted)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { lamp.isLit },
                set: { $0 ? lamp.turnOn() : lamp.turnOff() }
            ))
            .labelsHidden()
            .tint(theme.accent)
            .disabled(!usable)
            .accessibilityLabel("Ligar ou desligar a lâmpada")
        }
    }

    private var toolRow: some View {
        HStack(spacing: 0) {
            ForEach(tools) { item in
                let isOn = tool == item
                let enabled = usable || item == .lamp
                Button {
                    tool = item
                } label: {
                    Image(systemName: item.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 48, height: 48)
                        .foregroundStyle(isOn ? theme.accentForeground : theme.ink)
                        .background(isOn ? theme.accent : theme.card)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.35)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(isOn ? .isSelected : [])
                if item != tools.last { Spacer(minLength: 0) }
            }
        }
    }

    @ViewBuilder
    private var notices: some View {
        if let notice = lamp.link.notice {
            LampNotice(kind: lamp.link == .connecting ? .info : .danger, text: notice, theme: theme)
        } else if let state = lamp.state, usable, !state.clockValid {
            LampNotice(kind: .warning, text: "A lâmpada perdeu a hora (pilha fraca ou primeira vez ligada). Acertando pela hora do iPhone…", theme: theme)
        } else if let state = lamp.state, usable, state.limiterActive {
            LampNotice(kind: .warning, text: "Brilho limitado pra proteger a fonte. A lâmpada reduziu as duas cores na mesma proporção.", theme: theme)
        } else if let error = lamp.errorMessage {
            LampNotice(kind: .danger, text: error, theme: theme)
        }
    }

    private var readout: some View {
        let color = usable && isEditing
            ? LampColor(mix: lamp.manualMix, brightness: max(lamp.manualBrightness, 0.01))
            : (usable ? lamp.state?.color : nil) ?? .off
        return VStack(spacing: 2) {
            Text(shown.on ? LampPreset.name(forMix: shown.mix) : "Desligada")
                .font(.luminaria(.footnote, weight: .bold))
                .foregroundStyle(theme.ink)
            Text("âmbar \(color.amber) · vermelho \(color.red)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(theme.inkMuted)
        }
        .accessibilityElement(children: .combine)
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tool.title.uppercased())
                    .font(.luminaria(.caption2, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(theme.inkMuted)
                Spacer()
                Text(panelValue)
                    .font(.luminaria(.caption, weight: .bold))
                    .foregroundStyle(theme.ink)
            }
            paneContent
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(height: 196)
        .background(theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .disabled(!usable && tool != .lamp)
        .opacity(!usable && tool != .lamp ? 0.45 : 1)
    }

    private var panelValue: String {
        switch tool {
        case .mix: return LampPreset.name(forMix: lamp.manualMix)
        case .brightness: return "\(Int((lamp.manualBrightness * 100).rounded()))%"
        case .scenes: return lamp.activeScene?.name ?? ""
        default: return ""
        }
    }

    @ViewBuilder
    private var paneContent: some View {
        switch tool {
        case .presets: presetsPane
        case .mix: mixPane
        case .brightness: brightnessPane
        case .schedule: schedulePane
        case .scenes: scenesPane
        case .lamp: lampPane
        }
    }

    private static func shortName(_ preset: LampPreset) -> String {
        switch preset.id {
        case "ambar": return "Âmbar"
        case "laranjaVermelho": return "Laranja-\nverm."
        default: return preset.name
        }
    }

    private var presetsPane: some View {
        HStack(alignment: .top, spacing: 4) {
            ForEach(LampPreset.all) { preset in
                let selected = shown.on && abs(preset.color.mix - shown.mix) < 0.01
                    && abs(preset.color.brightness - shown.brightness) < 0.03
                Button {
                    lamp.setManual(mix: preset.color.mix, brightness: preset.color.brightness)
                } label: {
                    VStack(spacing: 6) {
                        Circle()
                            .fill(LampDisplayColor.color(mix: preset.color.mix))
                            .frame(width: 40, height: 40)
                            .padding(3)
                            .overlay(Circle().stroke(selected ? theme.accent : .clear, lineWidth: 2))
                        Text(Self.shortName(preset))
                            .font(.luminaria(.caption2, weight: selected ? .bold : .medium))
                            .foregroundStyle(selected ? theme.ink : theme.inkMuted)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(preset.name)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var mixBinding: Binding<Double> {
        Binding(get: { lamp.manualMix }, set: { lamp.setManual(mix: $0, brightness: lamp.manualBrightness) })
    }

    private var brightnessBinding: Binding<Double> {
        Binding(get: { lamp.manualBrightness }, set: { lamp.setManual(mix: lamp.manualMix, brightness: $0) })
    }

    private var mixPane: some View {
        VStack(spacing: 8) {
            GradientSlider(value: mixBinding, colors: LampDisplayColor.mixGradient, accessibilityLabel: "Mistura")
            HStack {
                Text("Amarelo")
                Spacer()
                Text("Laranja")
                Spacer()
                Text("Vermelho")
            }
            .font(.luminaria(.caption2))
            .foregroundStyle(theme.inkMuted)
        }
    }

    private var brightnessPane: some View {
        let power = LampColor(mix: lamp.manualMix, brightness: lamp.manualBrightness).powerPercent
        return VStack(alignment: .leading, spacing: 12) {
            GradientSlider(
                value: brightnessBinding,
                lowerBound: 0.01,
                colors: [theme.ink.opacity(0.15), LampDisplayColor.color(mix: lamp.manualMix)],
                accessibilityLabel: "Brilho"
            )
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.ink.opacity(0.1))
                    Capsule().fill(theme.accent)
                        .frame(width: geo.size.width * CGFloat(min(Double(power) / 160, 1)))
                }
            }
            .frame(height: 6)
            Text("Potência \(power)% de 160%")
                .font(.luminaria(.caption2))
                .foregroundStyle(theme.inkMuted)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var schedulePane: some View {
        if let routine = lamp.savedRoutine, routine.enabled {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lamp.isTodayCancelled
                         ? "Luz da manhã cancelada"
                         : "Luz da manhã às \(twoDigits(routine.startTime.hour, routine.startTime.minute))")
                        .font(.luminaria(.subheadline, weight: .bold))
                        .foregroundStyle(theme.ink)
                    Text(lamp.isTodayCancelled
                         ? "Volta na próxima noite em que você armar o modo noite"
                         : "Até \(twoDigits(routine.endTime.hour, routine.endTime.minute)) · gravada na lâmpada")
                        .font(.luminaria(.caption))
                        .foregroundStyle(theme.inkMuted)
                }
                if !lamp.isTodayCancelled {
                    LampGhostButton(title: "Cancelar a luz de hoje", isDanger: true, theme: theme) {
                        lamp.cancelToday()
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Nenhuma luz programada")
                    .font(.luminaria(.subheadline, weight: .bold))
                    .foregroundStyle(theme.ink)
                Text("A luz da manhã é gravada na lâmpada quando você encosta na luminária com o modo noite armado. Cores e horários ficam em cada rotina de sono (Menu → Rotina de sono).")
                    .font(.luminaria(.caption))
                    .foregroundStyle(theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var scenesPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(LampScene.allCases) { scene in
                    let selected = lamp.activeScene == scene
                    Button {
                        if selected { lamp.stopScene() } else { lamp.startScene(scene) }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: scene.symbol)
                                .font(.system(size: 17, weight: .semibold))
                                .frame(width: 42, height: 42)
                                .foregroundStyle(selected ? theme.accentForeground : theme.ink)
                                .background(selected ? theme.accent : (theme.chip ?? theme.accentWash), in: Circle())
                            Text(scene.name)
                                .font(.luminaria(.caption2, weight: selected ? .bold : .medium))
                                .foregroundStyle(theme.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(scene.name)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "sun.min")
                Slider(value: Binding(
                    get: { lamp.sceneBrightness },
                    set: { lamp.setSceneBrightness($0, send: false) }
                ), in: 0.05...1) { editing in
                    if !editing { lamp.setSceneBrightness(lamp.sceneBrightness) }
                }
                .tint(theme.accent)
                .accessibilityLabel("Brilho do cenário")
                Image(systemName: "sun.max")
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(theme.inkMuted)
            Text(lamp.activeScene?.subtitle ?? (lamp.lacks(.scene)
                ? "O firmware desta lâmpada ainda não tem os cenários. Tocar tenta de novo."
                : "A lâmpada anima sozinha, mesmo com o celular bloqueado. Toque de novo pra parar."))
                .font(.luminaria(.caption))
                .foregroundStyle(theme.inkMuted)
                .lineLimit(2)
        }
    }

    private var lampPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                LampGhostButton(title: "Identificar", theme: theme) { lamp.identify() }
                    .accessibilityHint("Faz a lâmpada piscar 3 vezes")
                    .disabled(!usable)
                    .opacity(usable ? 1 : 0.45)
                LampGhostButton(title: "Esquecer", isDanger: true, theme: theme) { confirmForget = true }
            }
            // Uma linha só: o painel tem altura fixa e ganhou a chave dos cenários.
            Text("Relógio da lâmpada: \(clockText)")
                .font(.luminaria(.caption))
                .foregroundStyle(theme.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack {
                Text("Lâmpada simulada")
                    .font(.luminaria(.subheadline, weight: .medium))
                    .foregroundStyle(theme.ink)
                Spacer()
                Toggle("", isOn: Binding(get: { lamp.isSimulated }, set: { lamp.setSimulated($0) }))
                    .labelsHidden()
                    .tint(theme.accent)
            }
            HStack {
                Text("Cenários (teste)")
                    .font(.luminaria(.subheadline, weight: .medium))
                    .foregroundStyle(theme.ink)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { scenesEnabled },
                    set: { on in
                        scenesEnabled = on
                        if !on, lamp.activeScene != nil { lamp.stopScene() }
                    }
                ))
                .labelsHidden()
                .tint(theme.accent)
            }
        }
    }

    private var clockText: String {
        guard usable, let state = lamp.state else { return "—" }
        guard state.clockValid else { return "acertando…" }
        return "\(twoDigits(state.clock.hour ?? 0, state.clock.minute ?? 0)) · acertado pelo iPhone"
    }
}

// MARK: - Pareamento

/// Passo a passo + estado do pareamento. Usado na tela da lâmpada (sem lâmpada pareada) e
/// em Configurações → Adicionar lâmpada.
struct LampPairingContent: View {
    @ObservedObject var lamp: LampManager
    let theme: ModeTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ThemedCard(title: "Adicionar lâmpada", theme: theme) {
                VStack(alignment: .leading, spacing: 12) {
                    step(1, "Ligue a lâmpada na tomada e deixe o iPhone perto dela.")
                    step(2, "Se for a primeira vez, ela já está pronta pra parear. Senão, segure o toque da lâmpada por 3 segundos até ela piscar âmbar duas vezes.")
                    step(3, "Toque em “Procurar lâmpada” e aceite o pedido de pareamento do iPhone.")
                }
                .padding(10)
            }

            statusCard

            Text("Segurar o toque por 10 segundos apaga todos os celulares pareados (a lâmpada pisca vermelho). Depois disso, vá em Ajustes → Bluetooth no iPhone, toque no ⓘ da \(LampProtocol.settingsName) e em “Esquecer este dispositivo” antes de parear de novo.")
                .font(.luminaria(.caption))
                .foregroundStyle(theme.inkMuted)
                .padding(.horizontal, 6)

            ThemedCard(title: "Sem a placa ainda", theme: theme) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Usar lâmpada simulada")
                            .font(.luminaria(.subheadline, weight: .semibold))
                            .foregroundStyle(theme.ink)
                        Text("Imita a lâmpada pra testar as telas")
                            .font(.luminaria(.caption))
                            .foregroundStyle(theme.inkMuted)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { lamp.isSimulated }, set: { lamp.setSimulated($0) }))
                        .labelsHidden()
                        .tint(theme.accent)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
            }
        }
        .onDisappear {
            if lamp.link == .searching || lamp.link == .pairing { lamp.cancelPairing() }
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.luminaria(.caption, weight: theme.isSoveeMenu ? .medium : .bold))
                .foregroundStyle(theme.chipInk ?? theme.accent)
                .frame(width: 24, height: 24)
                .background(theme.chip ?? theme.accentWash)
                .clipShape(Circle())
            Text(text)
                .font(.luminaria(.subheadline))
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var statusCard: some View {
        switch lamp.link {
        case .searching:
            progressRow(title: "Procurando sua luminária sovee…", subtitle: "Deixe o iPhone a menos de 2 metros da lâmpada.")
        case .pairing:
            progressRow(title: "Luminária sovee encontrada", subtitle: "Toque em “Parear” no aviso do iPhone.")
        case .connected where lamp.hasLamp:
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    IconBadge(systemName: "checkmark", theme: theme)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lâmpada pronta")
                            .font(.luminaria(.subheadline, weight: .bold))
                            .foregroundStyle(theme.ink)
                        Text("Hora acertada. A luz da manhã é gravada nela quando você encosta na luminária.")
                            .font(.luminaria(.caption))
                            .foregroundStyle(theme.inkMuted)
                    }
                    Spacer(minLength: 0)
                }
                LampGhostButton(title: "Piscar pra confirmar", theme: theme) { lamp.identify() }
            }
        default:
            VStack(spacing: 12) {
                if let notice = lamp.link.notice {
                    LampNotice(kind: .danger, text: notice, theme: theme)
                }
                FullPillButton(title: lamp.link == .noLamp ? "Procurar lâmpada" : "Tentar de novo", theme: theme) {
                    lamp.startPairing()
                }
            }
        }
    }

    private func progressRow(title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.luminaria(.subheadline, weight: .bold))
                    .foregroundStyle(theme.ink)
                Text(subtitle)
                    .font(.luminaria(.caption))
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .themedCardSurface(theme, cornerRadius: 22)
    }
}

/// Configurações → Adicionar lâmpada.
struct LampPairingScreen: View {
    @ObservedObject var lamp: LampManager
    @Environment(\.isNightModeArmed) private var isNightModeArmed

    var body: some View {
        let theme = ModeTheme.menu(armed: isNightModeArmed)
        ZStack {
            theme.stageBackground
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    MenuHeader(title: "Lâmpada", subtitle: "Sua luminária sovee, por Bluetooth.", theme: theme)
                    LampPairingContent(lamp: lamp, theme: theme)
                }
                .padding(16)
            }
        }
        .menuChrome(title: "Lâmpada", theme: theme, isNight: isNightModeArmed)
    }
}

/// Cartão "Lâmpada" do menu de Configurações.
struct LampSettingsCard: View {
    @ObservedObject var lamp: LampManager
    let theme: ModeTheme
    var onOpenLamp: () -> Void

    var body: some View {
        ThemedCard(title: "Lâmpada", theme: theme) {
            if lamp.hasLamp {
                Button(action: onOpenLamp) {
                    ThemedRow(
                        theme: theme,
                        title: LampProtocol.displayName,
                        subtitle: "\(lamp.statusText) · bolinha no canto da tela inicial",
                        leading: { IconBadge(systemName: "lamp.table.fill", theme: theme) },
                        accessory: { chevron }
                    )
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink {
                    LampPairingScreen(lamp: lamp)
                } label: {
                    ThemedRow(
                        theme: theme,
                        title: "Adicionar lâmpada",
                        subtitle: "Sua luminária sovee, por Bluetooth",
                        leading: { IconBadge(systemName: "plus", theme: theme) },
                        accessory: { chevron }
                    )
                }
            }
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.inkMuted.opacity(0.7))
    }
}

// MARK: - Lâmpada na rotina de sono

/// "Lâmpada ao dormir" e "Lâmpada ao acordar" no editor de cada rotina (só aparece com uma
/// lâmpada pareada). Com as duas chaves desligadas, a rotina não mexe na lâmpada.
struct LampRoutineSections: View {
    @Binding var routine: SleepRoutine
    let theme: ModeTheme
    @ObservedObject private var lamp = LampManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.accent)
                Text("A lâmpada segue o despertador: só acontece nas noites em que você arma o modo noite e encosta na luminária. Não repete sozinha nos outros dias.")
                    .font(.luminaria(.caption))
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(theme.accentWash)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // Mesmo nível de ajuste da luz da manhã (2026-11-06, pedido do dono).
            ThemedCard(title: "Lâmpada ao dormir", theme: theme) {
                toggleRow("Apagar devagar", subtitle: sleepSubtitle, isOn: $routine.lampSleep.enabled)
                if routine.lampSleep.enabled {
                    divider
                    minutesRow("Começa depois de encostar", value: $routine.lampSleep.startDelayMinutes, range: LampSunset.delayRange)
                    divider
                    toggleRow("Começar da luz acesa",
                              subtitle: routine.lampSleep.fromCurrentLight
                                ? "Se a lâmpada estiver apagada, ela continua apagada"
                                : "A lâmpada acende na cor abaixo e parte dali",
                              isOn: $routine.lampSleep.fromCurrentLight)
                    if !routine.lampSleep.fromCurrentLight {
                        colorRow("Começa em", mix: $routine.lampSleep.mix)
                        sliderRow("Brilho no começo", value: $routine.lampSleep.brightness, range: 0.05...1, mix: routine.lampSleep.mix)
                    }
                    divider
                    toggleRow("Mudar de cor no caminho",
                              subtitle: routine.lampSleep.toMix == nil ? "Fica na mesma cor do começo" : "Vai da cor do começo até esta",
                              isOn: Binding(
                                get: { routine.lampSleep.toMix != nil },
                                set: { routine.lampSleep.toMix = $0 ? LampPreset.all[4].color.mix : nil }
                              ))
                    if routine.lampSleep.toMix != nil {
                        colorRow("Termina em", mix: Binding(
                            get: { routine.lampSleep.toMix ?? 1 },
                            set: { routine.lampSleep.toMix = $0 }
                        ))
                    }
                    sliderRow("Brilho no fim (0% = apagada)", value: $routine.lampSleep.toBrightness, range: 0...1, mix: sleepEndMix)
                    divider
                    minutesRow("Leva", value: $routine.lampSleep.minutes, range: LampSunset.rampRange)
                    if routine.lampSleep.toBrightness > 0.001 {
                        minutesRow("Fica acesa no fim", value: $routine.lampSleep.holdMinutes, range: LampSunset.holdRange)
                    }
                    sleepPreview.padding(10)
                    if lamp.lacks(.sunset), usesProgrammedFade {
                        Text("O firmware desta lâmpada ainda não entende esses ajustes. Até atualizar, ela apaga devagar da mesma luz e no mesmo tempo, sem espera e sem mudar de cor.")
                            .font(.luminaria(.caption))
                            .foregroundStyle(theme.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 10)
                    }
                }
            }

            ThemedCard(title: "Lâmpada ao acordar", theme: theme) {
                toggleRow("Amanhecer", subtitle: wakeSubtitle, isOn: $routine.lampWake.enabled)
                if routine.lampWake.enabled {
                    divider
                    minutesRow("Começa antes do despertador", value: $routine.lampWake.minutesBefore, range: 1...120)
                    divider
                    colorRow("Começa em", mix: $routine.lampWake.fromMix)
                    sliderRow("Brilho no começo", value: $routine.lampWake.fromBrightness, range: 0...1, mix: routine.lampWake.fromMix)
                    divider
                    colorRow("Termina em", mix: $routine.lampWake.toMix)
                    sliderRow("Brilho no fim", value: $routine.lampWake.toBrightness, range: 0.05...1, mix: routine.lampWake.toMix)
                    divider
                    minutesRow("Fica acesa depois", value: $routine.lampWake.holdMinutes, range: 0...240)
                    wakePreview.padding(10)
                }
            }

            Text("Com as duas chaves desligadas, esta rotina não mexe na lâmpada.")
                .font(.luminaria(.caption))
                .foregroundStyle(theme.inkMuted)
        }
    }

    /// Horário da PRÓXIMA manhã (a rotina pode ter horário por dia da semana).
    private var alarmMinutes: Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: routine.nextAlarmDate())
        return (comps.hour ?? routine.alarmHour) * 60 + (comps.minute ?? routine.alarmMinute)
    }

    private func clock(_ totalMinutes: Int) -> String {
        let m = ((totalMinutes % 1440) + 1440) % 1440
        return twoDigits(m / 60, m % 60)
    }

    private var wakeSubtitle: String {
        guard routine.lampWake.enabled else { return "Desligado nesta rotina" }
        let start = clock(alarmMinutes - routine.lampWake.minutesBefore)
        let end = clock(alarmMinutes + routine.lampWake.holdMinutes)
        return "\(start) até \(end), com despertador às \(clock(alarmMinutes))"
    }

    /// Cor de fim do "ao dormir" pra prévia (sem cor de fim = a do começo).
    /// Os ajustes pedem o apagar programado (0x08), não o simples (0x07).
    private var usesProgrammedFade: Bool {
        let probe = LampColor(mix: sleepStartMix, brightness: 0.8)
        if case .sunset = routine.lampSleep.nightCommand(current: probe) { return true }
        return false
    }

    private var sleepEndMix: Double {
        routine.lampSleep.toMix ?? sleepStartMix
    }

    /// Começando "da luz acesa" a cor real só se sabe na hora; a prévia usa a última cor
    /// escolhida à mão na tela da lâmpada.
    private var sleepStartMix: Double {
        routine.lampSleep.fromCurrentLight ? LampManager.shared.manualMix : routine.lampSleep.mix
    }

    private var sleepStartBrightness: Double {
        routine.lampSleep.fromCurrentLight ? LampManager.shared.manualBrightness : routine.lampSleep.brightness
    }

    private var sleepSubtitle: String {
        let s = routine.lampSleep
        guard s.enabled else { return "Desligado nesta rotina" }
        let start = s.clampedDelay == 0 ? "Ao encostar" : "\(s.clampedDelay) min depois de encostar"
        let end = s.toBrightness > 0.001
            ? (s.clampedHold > 0 ? ", fica \(s.clampedHold) min e apaga" : " e apaga")
            : " até apagar"
        return "\(start) · \(s.fadeMinutes) min\(end)"
    }

    private var sleepPreview: some View {
        let s = routine.lampSleep
        let delay = Double(s.clampedDelay), ramp = Double(s.fadeMinutes)
        let hold = s.toBrightness > 0.001 ? Double(s.clampedHold) : 0
        let total = max(delay + ramp + hold, 1)
        let fromMix = sleepStartMix, fromB = sleepStartBrightness
        let toMix = sleepEndMix, toB = s.toBrightness
        return VStack(spacing: 4) {
            LampTimelinePreview { t in
                let m = t * total
                if m < delay { return (fromMix, fromB) }
                if m < delay + ramp {
                    let k = (m - delay) / ramp
                    return (fromMix + (toMix - fromMix) * k, fromB + (toB - fromB) * k)
                }
                return (toMix, toB)
            }
            HStack {
                Text("ao encostar")
                Spacer()
                Text("+\(s.clampedDelay + s.fadeMinutes + Int(hold)) min · apagada")
            }
            .font(.luminaria(.caption2))
            .foregroundStyle(theme.inkMuted)
            .monospacedDigit()
            if s.fromCurrentLight {
                Text("A prévia usa a última cor escolhida na tela da lâmpada; na hora vale a luz que estiver acesa.")
                    .font(.luminaria(.caption2))
                    .foregroundStyle(theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var wakePreview: some View {
        let wake = routine.lampWake
        let total = Double(wake.minutesBefore + wake.holdMinutes)
        let split = total > 0 ? Double(wake.minutesBefore) / total : 1
        return VStack(spacing: 4) {
            LampTimelinePreview { t in
                guard t < split, split > 0 else { return (wake.toMix, wake.toBrightness) }
                let k = t / split
                return (wake.fromMix + (wake.toMix - wake.fromMix) * k,
                        wake.fromBrightness + (wake.toBrightness - wake.fromBrightness) * k)
            }
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Text(clock(alarmMinutes - wake.minutesBefore))
                    Text("\(clock(alarmMinutes)) ⏰")
                        .fixedSize()
                        .position(x: min(max(geo.size.width * split, 30), geo.size.width - 30), y: 7)
                    if wake.holdMinutes > 0 {
                        Text(clock(alarmMinutes + wake.holdMinutes))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .frame(height: 14)
            .font(.luminaria(.caption2))
            .foregroundStyle(theme.inkMuted)
            .monospacedDigit()
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.hairline)
            .frame(height: 1)
            .padding(.leading, 10)
    }

    private func toggleRow(_ title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.luminaria(.subheadline, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text(subtitle)
                    .font(.luminaria(.caption))
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(theme.accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }

    private func colorRow(_ title: String, mix: Binding<Double>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.luminaria(.subheadline, weight: .medium))
                    .foregroundStyle(theme.ink)
                Text(LampPreset.name(forMix: mix.wrappedValue))
                    .font(.luminaria(.caption))
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                ForEach(LampPreset.all) { preset in
                    let selected = abs(preset.color.mix - mix.wrappedValue) < 0.01
                    Button {
                        mix.wrappedValue = preset.color.mix
                    } label: {
                        Circle()
                            .fill(LampDisplayColor.color(mix: preset.color.mix))
                            .frame(width: 26, height: 26)
                            .padding(2)
                            .overlay(Circle().stroke(selected ? theme.accent : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(preset.name)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, mix: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.luminaria(.subheadline, weight: .medium))
                    .foregroundStyle(theme.ink)
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded()))%")
                    .font(.luminaria(.subheadline, weight: .bold))
                    .foregroundStyle(theme.ink)
                    .monospacedDigit()
            }
            Slider(value: value, in: range)
                .tint(LampDisplayColor.color(mix: mix))
                .accessibilityLabel(title)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    /// Passo de 5 minutos, partindo de 1 (1 → 5 → 10…).
    private func minutesRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(title)
                .font(.luminaria(.subheadline, weight: .medium))
                .foregroundStyle(theme.ink)
            Spacer(minLength: 8)
            Text("\(value.wrappedValue) min")
                .font(.luminaria(.subheadline, weight: .bold))
                .foregroundStyle(theme.ink)
                .monospacedDigit()
            Stepper(title) {
                let v = value.wrappedValue
                value.wrappedValue = min(v < 5 ? 5 : v + 5, range.upperBound)
            } onDecrement: {
                let v = value.wrappedValue
                value.wrappedValue = max(v - 5, range.lowerBound)
            }
            .labelsHidden()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}
