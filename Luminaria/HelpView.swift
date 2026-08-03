import SwiftUI

/// Passo único e manual: a Apple não permite que apps terceiros criem automaticamente um
/// Atalho com a ação "Definir Foco" ou "Definir Modo Noturno". O despertador NÃO passa por
/// aqui — é nativo do Luminária (ver `AlarmManager`). Concentra as instruções longas que
/// antes ficavam misturadas na tela de Configurações.
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isNightModeArmed) private var isNightModeArmed
    @ObservedObject private var alarmManager = AlarmManager.shared

    private var theme: ModeTheme { .current(armed: isNightModeArmed) }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.stage.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Configuração única")
                            .font(.luminaria(.title2, weight: .bold))
                            .foregroundStyle(theme.ink)

                        Text("Crie um Atalho chamado \"\(ShortcutManager.shortcutName)\" no app Atalhos com as ações abaixo, nessa ordem. Depois disso, toque no botão pra armar o modo noite e, em seguida, encoste o iPhone na luminária — este atalho será executado automaticamente.")
                            .font(.luminaria(.subheadline))
                            .foregroundStyle(theme.inkMuted)

                        ThemedCard(theme: theme) {
                            stepRow(1, "Abra o app Atalhos")
                            stepRow(2, "Toque em + para criar um novo atalho")
                            stepRow(3, "Nomeie como \"\(ShortcutManager.shortcutName)\"")
                            stepRow(4, "Adicione \"Definir Foco\" e escolha o modo desejado, ligado")
                            stepRow(5, "Adicione \"Definir Modo Noturno\" como ligado")
                            stepRow(6, "Salve o atalho")
                        }

                        FullPillButton(title: "Abrir app Atalhos", theme: theme) {
                            ShortcutManager.shared.openShortcutsAppToCreate()
                        }

                        sectionHeading("Desligar o Modo Noturno de manhã")

                        Text("O despertador é do próprio Luminária e não depende do Atalho — só arma quando a luminária é reconhecida via NFC com o modo noite ativo. Já o Modo Noturno precisa de uma automação separada, porque o Atalho acima roda uma única vez à noite e não pode \"esperar\" até de manhã. Crie na aba Automação do app Atalhos, usando o mesmo horário configurado na rotina de sono:")
                            .font(.luminaria(.subheadline))
                            .foregroundStyle(theme.inkMuted)

                        ThemedCard(theme: theme) {
                            stepRow(1, "Na aba Automação, toque em + e escolha \"Horário do Dia\"")
                            stepRow(2, "Defina o mesmo horário configurado em \"Desligar Modo Noturno às\" na rotina ativa")
                            stepRow(3, "Adicione a ação \"Definir Modo Noturno\" como desligado")
                            stepRow(4, "Desative \"Perguntar Antes de Executar\"")
                        }

                        sectionHeading("Com a tela bloqueada")

                        Text("Nenhum app de terceiros consegue desenhar tela nenhuma por cima da tela de bloqueio — nem este, nem qualquer outro despertador da App Store. Quem funciona de verdade nessa hora é a notificação: ela toca o som escolhido e tem um botão \"Parar\" (toque longo ou deslize a notificação) pra desarmar sem precisar desbloquear o iPhone. A tela de \"Parar\" dentro do app só aparece quando você desbloqueia e abre o Luminária.")
                            .font(.luminaria(.subheadline))
                            .foregroundStyle(theme.inkMuted)

                        Text("Se nem o som tocar, o Atalho pode estar ativando um Foco que está escondendo a notificação. Confira:")
                            .font(.luminaria(.subheadline))
                            .foregroundStyle(theme.inkMuted)

                        ThemedCard(theme: theme) {
                            stepRow(1, "Ajustes → Notificações → Luminária: ative Banners, Sons e \"Mostrar na Tela Bloqueada\"")
                            stepRow(2, "Ajustes → Foco → (o modo que o Atalho ativa): adicione o Luminária aos apps sempre permitidos, ou ative \"Notificações Sensíveis ao Tempo\"")
                        }

                        statusChip

                        Text("Uma sirene de verdade, tipo a do app Relógio, que ignora até o modo silencioso, exige uma permissão especial da Apple (\"alertas críticos\") inviável sem conta de desenvolvedor paga — por isso o despertador aqui depende de notificações normais do sistema.")
                            .font(.luminaria(.caption))
                            .foregroundStyle(theme.inkMuted)
                    }
                    .padding(16)
                    .padding(.top, 4)
                }
            }
            .navigationTitle("Ajuda")
            .toolbarBackground(theme.stage, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(isNightModeArmed ? .dark : .light, for: .navigationBar)
            .tint(theme.accent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }

    private var notificationStatusText: String {
        if alarmManager.notificationsAuthorized == true {
            return "Notificações autorizadas"
        } else if alarmManager.notificationsAuthorized == false {
            return "Notificações negadas — abra Ajustes do iPhone"
        } else {
            return "Notificações ainda não solicitadas"
        }
    }

    private var statusChip: some View {
        let isGood = alarmManager.notificationsAuthorized == true
        let color = alarmManager.notificationsAuthorized == false ? theme.danger : (isGood ? Color(uiColor: .systemGreen) : theme.inkMuted)
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(notificationStatusText)
                .font(.luminaria(.caption, weight: .bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text)
            .font(.luminaria(.headline, weight: .bold))
            .foregroundStyle(theme.ink)
            .padding(.top, 4)
    }

    private func stepRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.luminaria(.caption, weight: .heavy))
                .foregroundStyle(theme.accent)
                .frame(width: 20, height: 20)
                .background(theme.accentWash)
                .clipShape(Circle())
                .padding(.top, 1)
            Text(text)
                .font(.luminaria(.subheadline))
                .foregroundStyle(theme.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}
