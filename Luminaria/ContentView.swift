import SwiftUI

struct ContentView: View {
    @StateObject private var nfcManager = NFCManager()
    @State private var showSetupInstructions = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: nfcManager.isLinked ? "lamp.desk.fill" : "lamp.desk")
                    .font(.system(size: 64))
                    .foregroundStyle(nfcManager.isLinked ? .yellow : .secondary)
                    .padding(.top, 40)

                Text(nfcManager.isLinked ? "Luminária vinculada" : "Nenhuma luminária vinculada")
                    .font(.title2)
                    .fontWeight(.semibold)

                if let tagID = nfcManager.linkedTagID {
                    Text("Tag: \(tagID)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !nfcManager.statusMessage.isEmpty {
                    Text(nfcManager.statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }

                if let error = nfcManager.errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                VStack(spacing: 12) {
                    if !nfcManager.isLinked {
                        Button {
                            nfcManager.beginScanning()
                        } label: {
                            Label("Vincular luminária", systemImage: "wave.3.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else {
                        Button {
                            nfcManager.beginScanning()
                        } label: {
                            Label("Encostar na luminária", systemImage: "wave.3.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button {
                            showSetupInstructions = true
                        } label: {
                            Label("Configurar Atalho de Foco", systemImage: "moon.zzz")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button(role: .destructive) {
                            nfcManager.unlink()
                        } label: {
                            Label("Desvincular luminária", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Luminária")
            .onAppear {
                nfcManager.onRecognizedTap = {
                    ShortcutManager.shared.runSleepShortcut()
                }
            }
            .sheet(isPresented: $showSetupInstructions) {
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

                Text("Crie um Atalho chamado \"\(ShortcutManager.shortcutName)\" no app Atalhos com a ação \"Definir Foco\" (ligado). Depois disso, toda vez que você encostar o iPhone na luminária, este atalho será executado automaticamente.")
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
