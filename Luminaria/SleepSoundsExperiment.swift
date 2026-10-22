import AVFoundation
import Combine
import SwiftUI

// EXPERIMENTO "sons pra dormir" (item 6 do plano Hatch, 2026-10-22).
// Teste mínimo: só ruído branco + timer, atrás de uma chave DESLIGADA por padrão
// (Ajuda → Experimentos). Pra remover: apagar este arquivo e SleepSoundsTimer.swift,
// e as 2 linhas que citam `SleepSoundsSettingsCard`/`SleepSoundsExperimentToggle`
// (SettingsView em ContentView.swift e HelpView.swift).

enum SleepSoundsFlag {
    static let key = "com.luminaria.experiment.sleepSounds"
    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: key) }
}

/// Toca ruído branco gerado na hora (sem arquivo de áudio) com `AVAudioEngine`.
///
/// Convivência com o despertador: usa a MESMA categoria `.playback` do `AlarmManager`
/// (o loop silencioso do esquema antigo continua junto) e nunca desativa a sessão ao
/// parar — desativar derrubaria o loop silencioso. Para sozinho quando o despertador toca
/// (`AlarmManager.isAlarmRinging`); o alarme do sistema (AlarmKit) interrompe o áudio do
/// app e, nesse caso, o ruído não volta.
final class SleepSoundPlayer: ObservableObject {
    static let shared = SleepSoundPlayer()

    @Published private(set) var isPlaying = false
    @Published private(set) var endDate: Date?

    /// Nível do ruído (o volume do iPhone continua valendo por cima).
    private let level: Float = 0.12
    private var engine: AVAudioEngine?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] note in self?.handleInterruption(note) }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .AVAudioEngineConfigurationChange)
            .sink { [weak self] _ in self?.restartIfNeeded() }
            .store(in: &cancellables)
        AlarmManager.shared.$isAlarmRinging
            .filter { $0 }
            .sink { [weak self] _ in self?.stop() }
            .store(in: &cancellables)
    }

    func play(choice: SleepSoundTimerChoice) {
        guard let end = SleepSoundTimer.endDate(for: choice, now: Date(), alarmDate: AlarmManager.shared.nextFireDate) else { return }
        endDate = end
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
        if engine == nil { engine = makeEngine() }
        startEngine()
        isPlaying = engine?.isRunning == true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        engine?.stop()
        engine = nil
        endDate = nil
        isPlaying = false
    }

    private func tick() {
        guard let endDate else { stop(); return }
        let volume = SleepSoundTimer.volume(now: Date(), end: endDate)
        if volume <= 0 { stop(); return }
        engine?.mainMixerNode.outputVolume = volume
    }

    private func makeEngine() -> AVAudioEngine {
        let engine = AVAudioEngine()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        var state: UInt32 = 0x9E37_79B9
        let level = self.level
        let source = AVAudioSourceNode(format: format) { _, _, frameCount, bufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            for frame in 0..<Int(frameCount) {
                // xorshift32: barato e sem alocação, dá pra rodar no thread de áudio.
                state ^= state << 13
                state ^= state >> 17
                state ^= state << 5
                let sample = (Float(state) / Float(UInt32.max) * 2 - 1) * level
                for buffer in buffers {
                    buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = sample
                }
            }
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        return engine
    }

    private func startEngine() {
        guard let engine, !engine.isRunning else { return }
        engine.prepare()
        try? engine.start()
    }

    private func restartIfNeeded() {
        guard isPlaying, !AlarmManager.shared.isAlarmRinging else { return }
        startEngine()
    }

    private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .ended {
            try? AVAudioSession.sharedInstance().setActive(true)
            restartIfNeeded()
        }
    }
}

// MARK: - Telas

/// Chave do experimento, no fim da Ajuda.
struct SleepSoundsExperimentToggle: View {
    let theme: ModeTheme
    @AppStorage(SleepSoundsFlag.key) private var isEnabled = false

    var body: some View {
        ThemedCard(title: "Experimentos", theme: theme) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sons pra dormir (teste)")
                        .font(.luminaria(.subheadline, weight: .medium))
                        .foregroundStyle(theme.ink)
                    Text("Ruído branco com timer. Aparece no menu quando ligado.")
                        .font(.luminaria(.caption))
                        .foregroundStyle(theme.inkMuted)
                }
                Spacer()
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .tint(theme.accent)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
        }
        .onChange(of: isEnabled) { on in
            if !on { SleepSoundPlayer.shared.stop() }
        }
    }
}

/// Entrada no menu — só aparece com o experimento ligado.
struct SleepSoundsSettingsCard: View {
    let theme: ModeTheme
    @AppStorage(SleepSoundsFlag.key) private var isEnabled = false
    @ObservedObject private var player = SleepSoundPlayer.shared

    var body: some View {
        if isEnabled {
            ThemedCard(theme: theme) {
                NavigationLink {
                    SleepSoundsView()
                } label: {
                    ThemedRow(
                        theme: theme,
                        title: "Sons pra dormir",
                        subtitle: player.isPlaying ? "Tocando ruído branco" : "Teste · ruído branco com timer",
                        leading: { IconBadge(systemName: "waveform", theme: theme) },
                        accessory: {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.inkMuted.opacity(0.7))
                        }
                    )
                }
            }
        }
    }
}

struct SleepSoundsView: View {
    @Environment(\.isNightModeArmed) private var isNightModeArmed
    @ObservedObject private var player = SleepSoundPlayer.shared
    @ObservedObject private var alarm = AlarmManager.shared
    @State private var choice: SleepSoundTimerChoice = .minutes(30)

    private var theme: ModeTheme { .menu(armed: isNightModeArmed) }

    var body: some View {
        ZStack {
            theme.stageBackground
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    MenuHeader(title: "sons pra dormir", subtitle: "Teste: ruído branco com timer.", theme: theme)

                    ThemedCard(title: "timer", theme: theme) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                            ForEach(SleepSoundTimerChoice.all, id: \.self) { option in
                                chip(option)
                            }
                        }
                        .padding(8)
                        if choice == .untilAlarm, alarm.nextFireDate == nil {
                            Text("Sem despertador armado agora. Arme a noite encostando na luminária, ou escolha um tempo.")
                                .font(.luminaria(.caption))
                                .foregroundStyle(theme.inkMuted)
                                .padding(.horizontal, 10)
                                .padding(.bottom, 8)
                        }
                    }

                    if player.isPlaying, let end = player.endDate {
                        HStack {
                            Image(systemName: "waveform")
                            Text("Ruído branco · para às \(end.formatted(date: .omitted, time: .shortened))")
                        }
                        .font(.luminaria(.subheadline, weight: .medium))
                        .foregroundStyle(theme.ink)
                        .padding(.horizontal, 6)
                    }

                    FullPillButton(title: player.isPlaying ? "parar" : "tocar ruído branco", theme: theme) {
                        if player.isPlaying {
                            player.stop()
                        } else {
                            player.play(choice: choice)
                        }
                    }
                    .disabled(!player.isPlaying && choice == .untilAlarm && alarm.nextFireDate == nil)

                    Text("Toca com a tela bloqueada e com o Não Perturbe. No fim do timer, diminui em 1 minuto e para. Se o despertador tocar antes, o som para.")
                        .font(.luminaria(.caption))
                        .foregroundStyle(theme.inkMuted)
                        .padding(.horizontal, 6)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .menuChrome(title: "Sons pra dormir", theme: theme, isNight: isNightModeArmed)
    }

    private func chip(_ option: SleepSoundTimerChoice) -> some View {
        let selected = option == choice
        return Button {
            choice = option
            // Trocar o timer com o som tocando vale na hora.
            if player.isPlaying { player.play(choice: option) }
        } label: {
            Text(option.label)
                .font(.luminaria(.subheadline, weight: selected ? .bold : .medium))
                .foregroundStyle(selected ? theme.accentForeground : theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? theme.accent : (theme.chip ?? theme.accentWash), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
