import SwiftUI

/// Passo único e manual: a Apple não permite que apps terceiros criem automaticamente um
/// Atalho com a ação "Definir Foco" ou "Definir Modo Noturno". O despertador NÃO passa por
/// aqui — é nativo do Luminária (ver `AlarmManager`). Concentra as instruções longas que
/// antes ficavam misturadas na tela de Configurações.
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var alarmManager = AlarmManager.shared

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
                        stepRow(number: 4, text: "Adicione \"Definir Foco\" e escolha o modo desejado, ligado")
                        stepRow(number: 5, text: "Adicione \"Definir Modo Noturno\" como ligado")
                        stepRow(number: 6, text: "Salve o atalho")
                    }
                    .padding(.top, 8)

                    Divider()
                        .padding(.vertical, 4)

                    Text("Desligar o Modo Noturno de manhã")
                        .font(.headline)

                    Text("O despertador é do próprio Luminária e não depende do Atalho — só arma quando a luminária é reconhecida via NFC com o modo noite ativo. Já o Modo Noturno precisa de uma automação separada, porque o Atalho acima roda uma única vez à noite e não pode \"esperar\" até de manhã. Crie na aba Automação do app Atalhos, usando o mesmo horário configurado na rotina de sono:")
                        .font(.body)

                    VStack(alignment: .leading, spacing: 8) {
                        stepRow(number: 1, text: "Na aba Automação, toque em + e escolha \"Horário do Dia\"")
                        stepRow(number: 2, text: "Defina o mesmo horário configurado em \"Desligar Modo Noturno às\" na rotina ativa")
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

                    Divider()
                        .padding(.vertical, 4)

                    Text("Se o despertador não aparecer na tela bloqueada")
                        .font(.headline)

                    Text("O Atalho ativa um Foco pra dormir sem celular — o próprio iOS pode estar escondendo a notificação do despertador por causa disso. Confira:")
                        .font(.body)

                    VStack(alignment: .leading, spacing: 8) {
                        stepRow(number: 1, text: "Ajustes → Notificações → Luminária: ative Banners, Sons e \"Mostrar na Tela Bloqueada\"")
                        stepRow(number: 2, text: "Ajustes → Foco → (o modo que o Atalho ativa): adicione o Luminária aos apps sempre permitidos, ou ative \"Notificações Sensíveis ao Tempo\"")
                    }
                    .padding(.top, 4)

                    HStack(spacing: 4) {
                        Text("Notificações:")
                        Text(notificationStatusText)
                            .fontWeight(.semibold)
                            .foregroundStyle(notificationStatusColor)
                    }
                    .font(.subheadline)
                    .padding(.top, 4)

                    Text("Uma sirene de verdade, tipo a do app Relógio, que ignora até o modo silencioso, exige uma permissão especial da Apple (\"alertas críticos\") inviável sem conta de desenvolvedor paga — por isso o despertador aqui depende de notificações normais do sistema.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding()
            }
            .navigationTitle("Ajuda")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }

    private var notificationStatusText: String {
        if alarmManager.notificationsAuthorized == true {
            return "autorizadas"
        } else if alarmManager.notificationsAuthorized == false {
            return "negadas — abra Ajustes do iPhone pra permitir"
        } else {
            return "ainda não solicitadas"
        }
    }

    private var notificationStatusColor: Color {
        if alarmManager.notificationsAuthorized == true {
            return .green
        } else if alarmManager.notificationsAuthorized == false {
            return .red
        } else {
            return .secondary
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
