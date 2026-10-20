import SwiftUI
import UIKit

/// Paleta oficial da marca SOVEE — hex convertidos pra RGB 0...1 direto do brief
/// (peach #FF9F66, sage #80A68E, terracota #DB8149, floresta #417C5A, creme #FDF8C7,
/// carvão #444444). Ponto único de conversão — o resto do app referencia esses nomes,
/// não hex/RGB espalhados.
enum SoveeColor {
    static let peach = Color(red: 1.0, green: 0.624, blue: 0.4)
    static let sage = Color(red: 0.502, green: 0.651, blue: 0.557)
    static let terracota = Color(red: 0.859, green: 0.506, blue: 0.286)
    static let floresta = Color(red: 0.255, green: 0.486, blue: 0.353)
    static let creme = Color(red: 0.992, green: 0.973, blue: 0.780)
    static let carvao = Color(red: 0.267, green: 0.267, blue: 0.267)

    /// **Não faz parte da paleta oficial do brief** — adicionado a pedido do usuário
    /// depois de ver o protótipo ("a sombra do modo noite ficou exemplar, só mude o
    /// verde [sage] pra um azul"). Um azul de luar suave, acento único do modo noite.
    static let noiteAzul = Color(red: 0.518, green: 0.631, blue: 0.784)

    /// Cores do site sovee.com.br usadas nos menus (2026-10-20): âmbar dos botões
    /// (#F2B05E) e o texto escuro sobre ele (#2A2A2A), grafite-azulado do menu ☰
    /// (#23252C) e o cinza quente claro do modo dia (#E9E7E2).
    static let ambar = Color(red: 0.949, green: 0.690, blue: 0.369)
    static let ambarInk = Color(red: 0.165, green: 0.165, blue: 0.165)
    static let grafite = Color(red: 0.137, green: 0.145, blue: 0.173)
    static let pedra = Color(red: 0.914, green: 0.906, blue: 0.886)
}

/// Paleta compartilhada das telas secundárias (Configurações, Rotinas, Ajuda) e, desde
/// o rebrand visual SOVEE, também da tela principal (`ContentView`). O acento muda de
/// temperatura com o modo — terracota quente de dia, azul de luar (`SoveeColor.
/// noiteAzul`, fora da paleta oficial, ajuste pedido pelo usuário) calmo à noite —
/// mesma lógica de antes (o produto é uma luminária, o destaque muda junto com o
/// modo), só que recalibrado pra paleta SOVEE.
///
/// `.legacyLiving`/`.legacyZleepy` preservam a paleta âmbar/periwinkle da identidade
/// anterior (Zleepy Lamp) — não usados por padrão em lugar nenhum, existem só como
/// caminho de volta rápido caso o visual SOVEE não seja aprovado (pedido explícito do
/// usuário: "crie uma nova, mas deixe no código uma opção de retorno").
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

    // Campos do visual dos menus no estilo do site sovee.com.br (2026-10-20). Têm valor
    // padrão pra `.living`/`.zleepy` (tela do botão, lâmpada, despertador) continuarem
    // exatamente como estavam — só `.menuDay`/`.menuNight` preenchem.
    /// Cartão de "vidro": gradiente diagonal no lugar da cor chapada de `card`.
    var cardGradient: [Color]? = nil
    var cardEdge: Color = .clear
    var cardShadow: Color = .clear
    /// Fundo do círculo dos ícones (nil = `accentWash`) e cor do ícone (nil = `accent`).
    var chip: Color? = nil
    var chipInk: Color? = nil
    /// Brilho âmbar suave na base da tela.
    var stageGlow: Color = .clear
    /// Títulos e rótulos em minúsculas, rótulos espaçados, botões em pílula.
    var isSoveeMenu: Bool = false

    /// Fundo branco (era creme — o usuário não gostou do menu "amarelo" no modo dia,
    /// 2026-09-25); com isso os cartões viram um cinza bem claro, senão sumiriam no
    /// branco. O botão redondo da tela principal continua branco puro (ver `ContentView`).
    static let living = ModeTheme(
        stage: .white,
        card: Color(red: 0.953, green: 0.953, blue: 0.957),
        ink: SoveeColor.carvao,
        inkMuted: Color(red: 0.55, green: 0.54, blue: 0.50),
        hairline: Color.black.opacity(0.07),
        accent: SoveeColor.terracota,
        accentWash: SoveeColor.terracota.opacity(0.14),
        accentForeground: .white,
        danger: Color(red: 0.72, green: 0.34, blue: 0.24),
        dangerWash: Color(red: 0.72, green: 0.34, blue: 0.24).opacity(0.10)
    )

    static let zleepy = ModeTheme(
        stage: SoveeColor.carvao,
        card: Color(red: 0.32, green: 0.32, blue: 0.32),
        ink: SoveeColor.creme,
        inkMuted: Color(red: 0.65, green: 0.64, blue: 0.60),
        hairline: Color.white.opacity(0.08),
        accent: SoveeColor.noiteAzul,
        accentWash: SoveeColor.noiteAzul.opacity(0.16),
        accentForeground: SoveeColor.carvao,
        danger: Color(red: 0.82, green: 0.50, blue: 0.42),
        dangerWash: Color(red: 0.82, green: 0.50, blue: 0.42).opacity(0.12)
    )

    /// Paleta Zleepy Lamp original — âmbar de luminária acesa / periwinkle de luar.
    /// Só existe como caminho de volta; nada usa isso por padrão.
    static let legacyLiving = ModeTheme(
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

    static let legacyZleepy = ModeTheme(
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

    /// Menus (Configurações, Rotinas, Ajuda, Relatório, Amigos, Bloqueio, Lâmpada) no
    /// estilo do site sovee.com.br — protótipo aprovado em `design/menus_sovee_prototipo.html`.
    /// Noite = vidro marrom-quente sobre grafite-azulado (o menu ☰ do site); dia = o
    /// inverso (pedido do usuário): texto grafite-azulado sobre cinza quente claro, vidro
    /// claro. Âmbar do site (#F2B05E) é a cor de ação nos dois modos.
    static let menuDay = ModeTheme(
        stage: SoveeColor.pedra,
        card: Color.white.opacity(0.75),
        ink: SoveeColor.grafite,
        inkMuted: SoveeColor.grafite.opacity(0.58),
        hairline: SoveeColor.grafite.opacity(0.10),
        accent: SoveeColor.ambar,
        accentWash: SoveeColor.ambar.opacity(0.22),
        accentForeground: SoveeColor.ambarInk,
        danger: Color(red: 0.706, green: 0.318, blue: 0.227),
        dangerWash: Color(red: 0.706, green: 0.318, blue: 0.227).opacity(0.10),
        cardGradient: [Color.white.opacity(0.82), Color(red: 0.980, green: 0.961, blue: 0.925).opacity(0.60)],
        cardEdge: SoveeColor.grafite.opacity(0.08),
        cardShadow: SoveeColor.grafite.opacity(0.10),
        chip: SoveeColor.grafite.opacity(0.07),
        chipInk: SoveeColor.grafite,
        stageGlow: SoveeColor.ambar.opacity(0.20),
        isSoveeMenu: true
    )

    static let menuNight = ModeTheme(
        stage: SoveeColor.grafite,
        card: Color(red: 0.310, green: 0.278, blue: 0.251),
        ink: SoveeColor.creme,
        inkMuted: SoveeColor.creme.opacity(0.60),
        hairline: SoveeColor.creme.opacity(0.16),
        accent: SoveeColor.ambar,
        accentWash: SoveeColor.ambar.opacity(0.20),
        accentForeground: SoveeColor.ambarInk,
        danger: Color(red: 0.898, green: 0.604, blue: 0.510),
        dangerWash: Color(red: 0.898, green: 0.604, blue: 0.510).opacity(0.12),
        cardGradient: [Color(red: 0.471, green: 0.384, blue: 0.298).opacity(0.42),
                       Color(red: 0.204, green: 0.173, blue: 0.149).opacity(0.50)],
        cardEdge: SoveeColor.creme.opacity(0.14),
        cardShadow: Color.black.opacity(0.35),
        chip: SoveeColor.creme.opacity(0.13),
        chipInk: SoveeColor.creme,
        stageGlow: SoveeColor.ambar.opacity(0.22),
        isSoveeMenu: true
    )

    static func current(armed: Bool) -> ModeTheme { armed ? .zleepy : .living }

    /// Tema das telas de menu. Pra voltar ao visual anterior dos menus, trocar por
    /// `current(armed:)`.
    static func menu(armed: Bool) -> ModeTheme { armed ? .menuNight : .menuDay }

    /// Fundo das telas de menu: cor de palco + brilho âmbar na base.
    var stageBackground: some View {
        ZStack {
            stage
            RadialGradient(colors: [stageGlow, stageGlow.opacity(0)],
                           center: .bottom, startRadius: 0, endRadius: 460)
                .scaleEffect(x: 1.4, y: 1, anchor: .bottom)
        }
        .ignoresSafeArea()
    }
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

/// Tipografia: **DM Sans em todo o app** (decisão do usuário, 2026-09-28). Os arquivos
/// estão em `Luminaria/Fonts/` (Regular, Medium e Bold do repositório oficial
/// googlefonts/dm-fonts, licença SIL OFL em `DMSans-OFL.txt` — uso comercial liberado),
/// registrados em `Info.plist` (`UIAppFonts`). A Neue Machina do brief SOVEE ficou de
/// fora: é grátis só pra uso pessoal (e dentro do Canva, que licencia pra uso na própria
/// plataforma); embutir num app exige licença comercial da Pangram Pangram.
///
/// Se a fonte não estiver disponível (ex.: dentro da extensão do widget, que compila
/// este arquivo mas não embute as fontes), cai pra fonte do sistema.
extension Font {
    /// Fonte de texto de todas as telas (antes: arredondada do sistema). Acompanha o
    /// Dynamic Type (`relativeTo:`).
    static func luminaria(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        guard hasDMSans else {
            return .system(style, design: .rounded).weight(weight)
        }
        return .custom(dmSansName(for: weight), size: baseSize(for: style), relativeTo: style)
    }

    /// Títulos e tagline ("hora de desligar."), em tamanho fixo — DM Sans no peso
    /// pedido (Bold por padrão).
    static func soveeDisplay(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        guard hasDMSans else {
            return .system(size: size, weight: weight)
        }
        return .custom(dmSansName(for: weight), size: size)
    }

    /// Texto da tela principal — mesma DM Sans de `luminaria`.
    static func soveeBody(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        guard hasDMSans else {
            return .system(style, design: .default).weight(weight)
        }
        return .custom(dmSansName(for: weight), size: baseSize(for: style), relativeTo: style)
    }

    private static let hasDMSans = UIFont(name: "DMSans-Regular", size: 12) != nil

    /// Só existem três pesos no projeto: semibold e acima viram Bold; light e abaixo,
    /// Regular.
    private static func dmSansName(for weight: Font.Weight) -> String {
        switch weight {
        case .medium:
            return "DMSans-Medium"
        case .semibold, .bold, .heavy, .black:
            return "DMSans-Bold"
        default:
            return "DMSans-Regular"
        }
    }

    private static func baseSize(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline, .body: return 17
        case .subheadline, .callout: return 15
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        default: return 17
        }
    }
}

/// Badge circular com ícone — substitui o SF Symbol "solto" ao lado do texto nas listas
/// padrão do iOS por um círculo colorido, ecoando o botão redondo da tela principal.
struct IconBadge: View {
    let systemName: String
    var isDanger: Bool = false
    let theme: ModeTheme

    var body: some View {
        let size: CGFloat = theme.isSoveeMenu ? 36 : 32
        Image(systemName: systemName)
            .font(.system(size: theme.isSoveeMenu ? 15 : 14, weight: theme.isSoveeMenu ? .medium : .semibold))
            .foregroundStyle(isDanger ? theme.danger : (theme.chipInk ?? theme.accent))
            .frame(width: size, height: size)
            .background(isDanger ? theme.dangerWash : (theme.chip ?? theme.accentWash))
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
            Text(theme.isSoveeMenu ? title.lowercased() : title)
                .font(.luminaria(.body, weight: theme.isSoveeMenu ? .medium : .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.isSoveeMenu ? 15 : 14)
        }
        .foregroundStyle(theme.accentForeground)
        .background(theme.accent)
        .clipShape(RoundedRectangle(cornerRadius: theme.isSoveeMenu ? 999 : 18, style: .continuous))
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
            Text(theme.isSoveeMenu ? title.lowercased() : title)
                .font(.luminaria(.body, weight: theme.isSoveeMenu ? .regular : .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
        }
        .foregroundStyle(theme.danger)
        .background(theme.isSoveeMenu ? Color.clear : theme.dangerWash)
        .clipShape(RoundedRectangle(cornerRadius: theme.isSoveeMenu ? 999 : 18, style: .continuous))
        .overlay {
            if theme.isSoveeMenu {
                Capsule().strokeBorder(theme.hairline, lineWidth: 1)
            }
        }
    }
}

/// Grupo de conteúdo num cartão de cantos bem redondos, com rótulo opcional em versalete
/// — substitui `Section` das listas padrão por algo com a mesma "forma" do botão principal.
struct ThemedCard<Content: View>: View {
    var title: String? = nil
    let theme: ModeTheme
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: theme.isSoveeMenu ? 8 : 6) {
            if let title {
                if theme.isSoveeMenu {
                    // Rótulo do site: minúsculas, pequeno e espaçado (letter-spacing .18em).
                    Text(title.lowercased())
                        .font(.luminaria(.caption, weight: .medium))
                        .tracking(2.1)
                        .foregroundStyle(theme.inkMuted)
                        .padding(.horizontal, 8)
                } else {
                    Text(title.uppercased())
                        .font(.luminaria(.caption2, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(theme.inkMuted)
                        .padding(.horizontal, 10)
                }
            }
            if theme.isSoveeMenu {
                let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
                VStack(spacing: 0) { content() }
                    .padding(6)
                    .background(
                        LinearGradient(colors: theme.cardGradient ?? [theme.card],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: shape
                    )
                    .overlay(shape.strokeBorder(theme.cardEdge, lineWidth: 1))
                    .shadow(color: theme.cardShadow, radius: 20, x: 0, y: 10)
            } else {
                VStack(spacing: 0) { content() }
                    .padding(4)
                    .background(theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
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
                    .padding(.leading, theme.isSoveeMenu ? 58 : 46)
            }
            HStack(spacing: 12) {
                leading()
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(theme.isSoveeMenu
                              ? .luminaria(.body, weight: .medium)
                              : .luminaria(.subheadline, weight: .semibold))
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

/// Título grande no topo das telas de menu, no lugar do título da barra do iOS — como
/// os títulos do site (minúsculas, peso médio, espaçamento -0.02em).
struct MenuHeader: View {
    let title: String
    var subtitle: String? = nil
    let theme: ModeTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.lowercased())
                .font(.soveeDisplay(size: 30, weight: .medium))
                .tracking(-0.6)
                .foregroundStyle(theme.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.luminaria(.subheadline))
                    .foregroundStyle(theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }
}

/// Botão redondo da barra (fechar), igual ao botão ☰ do site.
struct MenuRoundButton: View {
    let systemName: String
    let label: String
    let theme: ModeTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.ink)
                .frame(width: 34, height: 34)
                .background(theme.chip ?? theme.accentWash, in: Circle())
        }
        .accessibilityLabel(label)
    }
}

extension View {
    /// Fundo de cartão do tema: vidro com borda e sombra nos menus SOVEE, cor chapada nos
    /// outros temas. Pra linhas soltas que não estão dentro de um `ThemedCard`.
    @ViewBuilder
    func themedCardSurface(_ theme: ModeTheme, cornerRadius: CGFloat = 26) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if theme.isSoveeMenu {
            self
                .background(LinearGradient(colors: theme.cardGradient ?? [theme.card],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: shape)
                .overlay(shape.strokeBorder(theme.cardEdge, lineWidth: 1))
                .shadow(color: theme.cardShadow, radius: 20, x: 0, y: 10)
        } else {
            self.background(theme.card).clipShape(shape)
        }
    }

    /// Barra de navegação das telas de menu: título do sistema escondido (o título grande
    /// fica no conteúdo, ver `MenuHeader`), mas mantido pra servir de rótulo do "voltar"
    /// e pra acessibilidade; fundo na cor do palco; botões na cor do texto.
    func menuChrome(title: String, theme: ModeTheme, isNight: Bool) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) }
            }
            .toolbarBackground(theme.stage, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(isNight ? .dark : .light, for: .navigationBar)
            .tint(theme.ink)
    }
}
