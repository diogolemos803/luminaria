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
            }
            .animation(.easeInOut(duration: 0.5), value: isNightModeArmed)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: isPressed)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(isNightModeArmed ? .white : .primary)
                    }
                }
            }
            .onAppear {
                nfcManager.onRecognizedTap = {
                    guard isNightModeArmed else { return }
                    ShortcutManager.shared.runSleepShortcut()
                }
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
            ShortcutManager.shared.runSleepShortcut()
        }
    }
}

struct SettingsView: View {
    @ObservedObject var nfcManager: NFCManager
    @Environment(\.dismiss) private var dismiss
    @State private var showShortcutSetup = false

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
/// automaticamente um Atalho com a ação "Definir Foco".
struct ShortcutSetupView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Configuração única")
                    .font(.title2.bold())

                Text("Crie um Atalho chamado \"\(ShortcutManager.shortcutName)\" no app Atalhos com a ação \"Definir Foco\" (ligado). Depois disso, sempre que o modo noite estiver ativado no app — seja pelo botão ou pela luminária via NFC — este atalho será executado automaticamente.")
                    .font(.body)

                VStack(alignment: .leading, spacing: 8) {
                    stepRow(number: 1, text: "Abra o app Atalhos")
                    stepRow(number: 2, text: "Toque em + para criar um novo atalho")
                    stepRow(number: 3, text: "Nomeie como \"\(ShortcutManager.shortcutName)\"")
                    stepRow(number: 4, text: "Adicione a ação \"Definir Foco\" e escolha o modo desejado, ligado")
                    stepRow(number: 5, text: "Salve o atalho")
                }
                .padding(.top, 8)

                Spacer()

                Button {
                    ShortcutManager.shared.openShortcutsAppToCreate()
                } label: {
                    Label("Abrir app Atalhos", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
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
