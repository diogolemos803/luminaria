import SwiftUI

/// Paleta compartilhada das telas secundárias (Configurações, Rotinas, Ajuda) — os mesmos
/// tons cream/chumbo do botão principal (ver `ContentView`), só que estendidos pra cartões
/// e badges circulares em vez da lista padrão do iOS. O acento muda de temperatura com o
/// modo: âmbar de luminária acesa no Living mode, periwinkle de luar no Zleepy mode — o
/// próprio produto é uma lâmpada, então o destaque muda de cor junto com o modo, em vez de
/// ser uma cor de marca arbitrária.
struct ModeTheme {
    let stage: Color
    let card: Color
    let ink: Color
    let inkMuted: Color
    let hairline: Color
    let accent: Color
    let accentWash: Color
    let accentForeground: Color
    let danger: Color
    let dangerWash: Color

    static let living = ModeTheme(
        stage: Color(red: 0.957, green: 0.953, blue: 0.941),
        card: .white,
        ink: Color(red: 0.290, green: 0.282, blue: 0.267),
        inkMuted: Color(red: 0.588, green: 0.576, blue: 0.541),
        hairline: Color.black.opacity(0.07),
        accent: Color(red: 0.776, green: 0.573, blue: 0.310),
        accentWash: Color(red: 0.776, green: 0.573, blue: 0.310).opacity(0.14),
        accentForeground: .white,
        danger: Color(red: 0.694, green: 0.361, blue: 0.275),
        dangerWash: Color(red: 0.694, green: 0.361, blue: 0.275).opacity(0.10)
    )

    static let zleepy = ModeTheme(
        stage: Color(red: 0.129, green: 0.141, blue: 0.165),
        card: Color(red: 0.169, green: 0.184, blue: 0.216),
        ink: Color(red: 0.847, green: 0.855, blue: 0.878),
        inkMuted: Color(red: 0.533, green: 0.553, blue: 0.588),
        hairline: Color.white.opacity(0.08),
        accent: Color(red: 0.576, green: 0.639, blue: 0.839),
        accentWash: Color(red: 0.576, green: 0.639, blue: 0.839).opacity(0.16),
        accentForeground: Color(red: 0.106, green: 0.118, blue: 0.141),
        danger: Color(red: 0.820, green: 0.541, blue: 0.463),
        dangerWash: Color(red: 0.820, green: 0.541, blue: 0.463).opacity(0.12)
    )

    static func current(armed: Bool) -> ModeTheme { armed ? .zleepy : .living }
}

private struct NightModeArmedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Propaga se o modo noite está armado pras telas secundárias (Configurações, Rotinas,
    /// Ajuda), sem precisar passar o bool por parâmetro em cada `init`. Definido uma vez
    /// onde a sheet/NavigationLink é apresentada; todo o resto lê de volta com
    /// `@Environment(\.isNightModeArmed)`.
    var isNightModeArmed: Bool {
        get { self[NightModeArmedKey.self] }
        set { self[NightModeArmedKey.self] = newValue }
    }
}

extension Font {
    static func luminaria(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded).weight(weight)
    }
}

/// Badge circular com ícone — substitui o SF Symbol "solto" ao lado do texto nas listas
/// padrão do iOS por um círculo colorido, ecoando o botão redondo da tela principal.
struct IconBadge: View {
    let systemName: String
    var isDanger: Bool = false
    let theme: ModeTheme

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isDanger ? theme.danger : theme.accent)
            .frame(width: 32, height: 32)
            .background(isDanger ? theme.dangerWash : theme.accentWash)
            .clipShape(Circle())
    }
}

/// Ponto sólido usado como indicador de "rotina ativa", no lugar do checkmark padrão.
struct ActiveDot: View {
    let theme: ModeTheme
    var body: some View {
        Circle().fill(theme.accent).frame(width: 9, height: 9)
    }
}

/// Botão em pílula cheia — ação primária da tela (Salvar, Abrir app Atalhos, Ativar).
struct FullPillButton: View {
    let title: String
    let theme: ModeTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.luminaria(.body, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .foregroundStyle(theme.accentForeground)
        .background(theme.accent)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Ação destrutiva de baixo peso visual (Excluir rotina, Desvincular) — texto colorido
/// sobre um fundo suave, em vez de um botão vermelho chapado.
struct GhostDangerButton: View {
    let title: String
    let theme: ModeTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.luminaria(.body, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
        }
        .foregroundStyle(theme.danger)
        .background(theme.dangerWash)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Grupo de conteúdo num cartão de cantos bem redondos, com rótulo opcional em versalete
/// — substitui `Section` das listas padrão por algo com a mesma "forma" do botão principal.
struct ThemedCard<Content: View>: View {
    var title: String? = nil
    let theme: ModeTheme
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title.uppercased())
                    .font(.luminaria(.caption2, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(theme.inkMuted)
                    .padding(.horizontal, 10)
            }
            VStack(spacing: 0) { content() }
                .padding(4)
                .background(theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

/// Uma linha dentro de um `ThemedCard`, com um elemento à esquerda (badge/dot) e um
/// acessório opcional à direita (chevron) — a unidade básica que substitui as linhas de
/// `List`/`Form`.
struct ThemedRow<Leading: View, Accessory: View>: View {
    let theme: ModeTheme
    let showsDivider: Bool
    let title: String
    let subtitle: String?
    let leading: () -> Leading
    let accessory: () -> Accessory

    /// Init explícito (em vez do memberwise sintetizado) pra fixar a ordem dos argumentos
    /// usada em todas as telas — theme, showsDivider, title, subtitle, leading, accessory —
    /// já que o Swift exige a ordem de chamada bater com a ordem de declaração mesmo com
    /// argumentos nomeados.
    init(
        theme: ModeTheme,
        showsDivider: Bool = false,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.theme = theme
        self.showsDivider = showsDivider
        self.title = title
        self.subtitle = subtitle
        self.leading = leading
        self.accessory = accessory
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsDivider {
                Rectangle()
                    .fill(theme.hairline)
                    .frame(height: 1)
                    .padding(.leading, 46)
            }
            HStack(spacing: 12) {
                leading()
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.luminaria(.subheadline, weight: .semibold))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.luminaria(.caption))
                            .foregroundStyle(theme.inkMuted)
                    }
                }
                Spacer(minLength: 8)
                accessory()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 11)
        }
    }
}
