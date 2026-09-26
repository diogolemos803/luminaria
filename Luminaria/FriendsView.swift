import SwiftUI

/// Amigos e ranking de detox (ver `FriendsStore`). Aberta pelo menu (`SettingsView`).
/// Três blocos: o seu perfil (apelido + código pra convidar), adicionar amigo pelo
/// código, e o ranking pela sequência atual de noites limpas.
struct FriendsView: View {
    @ObservedObject var store: FriendsStore = .shared
    @Environment(\.isNightModeArmed) private var isNightModeArmed

    @State private var nameDraft = ""
    @State private var codeDraft = ""
    @State private var addMessage: String?
    @State private var addFailed = false
    @State private var isAdding = false
    @FocusState private var focusedField: Field?

    private enum Field { case name, code }

    private var theme: ModeTheme { .current(armed: isNightModeArmed) }

    var body: some View {
        ZStack {
            theme.stage.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch store.status {
                    case .idle, .loading:
                        if store.me == nil {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                        } else {
                            content
                        }
                    case .noAccount:
                        messageBlock(
                            icon: "icloud.slash",
                            text: "Amigos usa a sua conta iCloud. Entre no iCloud em Ajustes do iPhone e volte aqui."
                        )
                    case .failed(let message):
                        messageBlock(icon: "exclamationmark.icloud", text: message)
                        FullPillButton(title: "Tentar de novo", theme: theme) {
                            Task { await store.refresh() }
                        }
                    case .ready:
                        content
                    }
                }
                .padding(16)
                .padding(.top, 4)
            }
            .refreshable { await store.refresh() }
        }
        .navigationTitle("Amigos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.stage, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(isNightModeArmed ? .dark : .light, for: .navigationBar)
        .tint(theme.accent)
        .task {
            nameDraft = store.displayName
            await store.refresh()
        }
        // salva o apelido também ao sair do campo, não só no "OK" do teclado
        .onChange(of: focusedField) { field in
            if field != .name {
                Task { await store.setDisplayName(nameDraft) }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        profileCard
        addFriendCard
        rankingCard
        Text("O ranking compara a sequência atual de noites limpas — noites em que o despertador tocou sem você desligar o modo noite antes nem usar o passe de emergência. Seus amigos só veem seu apelido e esses números.")
            .font(.luminaria(.caption))
            .foregroundStyle(theme.inkMuted)
    }

    // MARK: Seu perfil

    private var profileCard: some View {
        ThemedCard(title: "Seu perfil", theme: theme) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Seu apelido", text: $nameDraft)
                    .font(.luminaria(.body, weight: .semibold))
                    .foregroundStyle(theme.ink)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .name)
                    .onSubmit { Task { await store.setDisplayName(nameDraft) } }
                    .padding(12)
                    .background(theme.ink.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if let code = store.me?.friendCode {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Seu código")
                                .font(.luminaria(.caption))
                                .foregroundStyle(theme.inkMuted)
                            Text(code)
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .tracking(3)
                                .foregroundStyle(theme.ink)
                                .textSelection(.enabled)
                        }
                        Spacer()
                        ShareLink(item: store.inviteMessage) {
                            Label("Convidar", systemImage: "square.and.arrow.up")
                                .font(.luminaria(.subheadline, weight: .bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .foregroundStyle(theme.accentForeground)
                                .background(theme.accent)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(10)
        }
    }

    // MARK: Adicionar amigo

    private var addFriendCard: some View {
        ThemedCard(title: "Adicionar amigo", theme: theme) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    TextField("Código de 6 letras", text: $codeDraft)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.ink)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .focused($focusedField, equals: .code)
                        .onSubmit(addFriend)
                        .onChange(of: codeDraft) { newValue in
                            let cleaned = String(newValue.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
                            if cleaned != newValue { codeDraft = cleaned }
                        }
                        .padding(12)
                        .background(theme.ink.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button(action: addFriend) {
                        Group {
                            if isAdding {
                                ProgressView().tint(theme.accentForeground)
                            } else {
                                Text("Adicionar")
                            }
                        }
                        .font(.luminaria(.subheadline, weight: .bold))
                        .frame(minWidth: 92, minHeight: 44)
                        .foregroundStyle(theme.accentForeground)
                        .background(theme.accent.opacity(codeDraft.count == 6 ? 1 : 0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(codeDraft.count != 6 || isAdding)
                }

                if let addMessage {
                    Text(addMessage)
                        .font(.luminaria(.caption, weight: .medium))
                        .foregroundStyle(addFailed ? theme.danger : Color(uiColor: .systemGreen))
                }
            }
            .padding(10)
        }
    }

    private func addFriend() {
        guard codeDraft.count == 6, !isAdding else { return }
        isAdding = true
        addMessage = nil
        Task {
            do {
                let friend = try await store.addFriend(code: codeDraft)
                addFailed = false
                addMessage = "\(friend.displayName) entrou no seu ranking."
                codeDraft = ""
                focusedField = nil
            } catch {
                addFailed = true
                addMessage = (error as? LocalizedError)?.errorDescription ?? "Não deu pra adicionar agora. Tente de novo."
            }
            isAdding = false
        }
    }

    // MARK: Ranking

    private var rankingCard: some View {
        ThemedCard(title: "Ranking", theme: theme) {
            if store.friends.isEmpty {
                ThemedRow(
                    theme: theme,
                    title: "Ainda só você por aqui",
                    subtitle: "Mande seu código pra alguém e veja quem aguenta mais noites longe do celular.",
                    leading: { IconBadge(systemName: "person.2", theme: theme) },
                    accessory: { EmptyView() }
                )
            }
            ForEach(Array(store.ranking.enumerated()), id: \.element.id) { index, profile in
                rankingRow(position: index + 1, profile: profile, showsDivider: index > 0 || store.friends.isEmpty)
            }
        }
    }

    private func rankingRow(position: Int, profile: FriendProfile, showsDivider: Bool) -> some View {
        let isMe = profile.id == store.me?.id
        let streak = profile.effectiveStreak()
        let row = ThemedRow(
            theme: theme,
            showsDivider: showsDivider,
            title: isMe ? "\(profile.displayName) (você)" : profile.displayName,
            subtitle: "Recorde: \(nightsText(profile.longestStreak)) · \(profile.totalCleanNights) no total",
            leading: { positionBadge(position) },
            accessory: {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(streak)")
                        .font(.luminaria(.title3, weight: .bold))
                        .foregroundStyle(theme.ink)
                    Text(streak == 1 ? "noite" : "noites")
                        .font(.luminaria(.caption2))
                        .foregroundStyle(theme.inkMuted)
                }
            }
        )
        return Group {
            if isMe {
                row
            } else {
                row.contextMenu {
                    Button(role: .destructive) {
                        store.removeFriend(id: profile.id)
                    } label: {
                        Label("Remover do ranking", systemImage: "person.badge.minus")
                    }
                }
            }
        }
    }

    /// 1º/2º/3º com cor de medalha; do 4º em diante, número simples.
    private func positionBadge(_ position: Int) -> some View {
        let medal: Color? = {
            switch position {
            case 1: return Color(sceneHex: 0xE0B24A)
            case 2: return Color(sceneHex: 0xB8BEC6)
            case 3: return Color(sceneHex: 0xC98A5B)
            default: return nil
            }
        }()
        return Text("\(position)")
            .font(.luminaria(.subheadline, weight: .bold))
            .frame(width: 32, height: 32)
            .foregroundStyle(medal == nil ? theme.inkMuted : Color.white)
            .background(medal ?? theme.ink.opacity(0.06))
            .clipShape(Circle())
    }

    private func nightsText(_ count: Int) -> String {
        count == 1 ? "1 noite" : "\(count) noites"
    }

    private func messageBlock(icon: String, text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(theme.inkMuted)
            Text(text)
                .font(.luminaria(.subheadline, weight: .medium))
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}
