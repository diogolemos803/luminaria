import SwiftUI

struct ContentView: View {
    @StateObject private var nfcManager = NFCManager()
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
                nfcManager.onRecognizedTap = {
                    guard isNightModeArmed else { return }
                    ShortcutManager.shared.runSleepShortcut()
                }
            }
            .onOpenURL { _ in
                // Callback do x-callback-url do Atalhos (luminaria://shortcut-done|shortcut-error).
                // Nada a fazer além de aceitar a volta ao app; existe só pra não abrir o app
                // Atalhos por completo ao disparar o Atalho.
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(nfcManager: nfcManager)
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
        }
    }
}

struct SettingsView: View {
    @ObservedObject var nfcManager: NFCManager
    @Environment(\.dismiss) private var dismiss
    @State private var showShortcutSetup = false

    @AppStorage("alarmHour") private var alarmHour: Int = 7
    @AppStorage("alarmMinute") private var alarmMinute: Int = 0
    @AppStorage("nightShiftOffHour") private var nightShiftOffHour: Int = 7
    @AppStorage("nightShiftOffMinute") private var nightShiftOffMinute: Int = 30

    private var alarmTime: Binding<Date> {
        Binding(
            get: { Self.date(hour: alarmHour, minute: alarmMinute) },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                alarmHour = comps.hour ?? 7
                alarmMinute = comps.minute ?? 0
            }
        )
    }

    private var nightShiftOffTime: Binding<Date> {
        Binding(
            get: { Self.date(hour: nightShiftOffHour, minute: nightShiftOffMinute) },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                nightShiftOffHour = comps.hour ?? 7
                nightShiftOffMinute = comps.minute ?? 30
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

                Section("Atalho de Foco") {
                    Button {
                        showShortcutSetup = true
                    } label: {
                        Label("Configurar Atalho de Foco", systemImage: "moon.zzz")
                    }
                }

                Section {
                    DatePicker("Horário do despertador", selection: alarmTime, displayedComponents: .hourAndMinute)
                    DatePicker("Desligar Modo Noturno às", selection: nightShiftOffTime, displayedComponents: .hourAndMinute)
                } header: {
                    Text("Rotina de sono")
                } footer: {
                    Text("O despertador é enviado ao Atalho automaticamente. Já o horário de desligar o Modo Noturno precisa ser configurado manualmente numa automação por horário no app Atalhos — a Apple não permite que o Luminária crie isso sozinho.")
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
            .sheet(isPresented: $showShortcutSetup) {
                ShortcutSetupView()
            }
        }
    }
}

/// Passo único e manual: a Apple não permite que apps terceiros criem
/// automaticamente um Atalho com a ação "Definir Foco", "Adicionar Alarme" ou
/// "Definir Modo Noturno".
struct ShortcutSetupView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Configuração única")
                        .font(.title2.bold())

                    Text("Crie um Atalho chamado \"\(ShortcutManager.shortcutName)\" no app Atalhos com as ações abaixo, nessa ordem. Depois disso, toque no botão pra armar o modo noite e, em seguida, encoste o iPhone na luminária — este atalho será executado automaticamente.")
                        .font(.body)

                    VStack(alignment: .leading, spacing: 8) {
                        stepRow(number: 1, text: "Abra o app Atalhos")
                        stepRow(number: 2, text: "Toque em + para criar um novo atalho")
                        stepRow(number: 3, text: "Nomeie como \"\(ShortcutManager.shortcutName)\"")
                        stepRow(number: 4, text: "Adicione \"Obter Datas da Entrada\" (usa o texto que o Luminária envia como entrada)")
                        stepRow(number: 5, text: "Adicione \"Adicionar Alarme\", usando a data do passo anterior como horário")
                        stepRow(number: 6, text: "Adicione \"Definir Foco\" e escolha o modo desejado, ligado")
                        stepRow(number: 7, text: "Adicione \"Definir Modo Noturno\" como ligado")
                        stepRow(number: 8, text: "Salve o atalho")
                    }
                    .padding(.top, 8)

                    Divider()
                        .padding(.vertical, 4)

                    Text("Desligar o Modo Noturno de manhã")
                        .font(.headline)

                    Text("Isso precisa de uma segunda automação, separada, porque o Atalho acima roda uma única vez à noite e não pode \"esperar\" até de manhã. Crie na aba Automação do app Atalhos:")
                        .font(.body)

                    VStack(alignment: .leading, spacing: 8) {
                        stepRow(number: 1, text: "Na aba Automação, toque em + e escolha \"Horário do Dia\"")
                        stepRow(number: 2, text: "Defina o mesmo horário configurado em \"Desligar Modo Noturno às\" no Luminária")
                        stepRow(number: 3, text: "Adicione a ação \"Definir Modo Noturno\" como desligado")
                        stepRow(number: 4, text: "Desative \"Perguntar Antes de Executar\"")
                    }
                    .padding(.top, 4)

                    Button {
                        ShortcutManager.shared.openShortcutsAppToCreate()
                    } label: {
                        Label("Abrir app Atalhos", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("Atalho de Foco")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .fontWeight(.semibold)
            Text(text)
        }
        .font(.subheadline)
    }
}

#Preview {
    ContentView()
}
