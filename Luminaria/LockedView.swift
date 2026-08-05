import SwiftUI

/// Mostrada por `ContentView` no lugar do botão redondo enquanto não houver uma
/// luminária vinculada — pedido explícito do usuário: o app não deve fazer nada de
/// útil (armar modo noite, bloquear apps) sem uma luminária física de verdade.
/// Não mexe no `NavigationStack`/toolbar de `ContentView`, só no conteúdo central —
/// o menu ☰ continua abrindo `SettingsView` normalmente, que é onde o vínculo
/// também pode ser feito/desfeito.
struct LockedView: View {
    let onLinkTapped: () -> Void

    private let theme = ModeTheme.living

    var body: some View {
        ZStack {
            theme.stage.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "wave.3.right.circle")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(theme.accent)

                Text("Vincule sua luminária")
                    .font(.luminaria(.title2, weight: .bold))
                    .foregroundStyle(theme.ink)

                Text("O Luminária só funciona com uma luminária física vinculada por NFC. Encoste o iPhone nela pra começar.")
                    .font(.luminaria(.subheadline))
                    .foregroundStyle(theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                FullPillButton(title: "Vincular luminária", theme: theme, action: onLinkTapped)
                    .padding(.horizontal, 40)
                    .padding(.top, 12)
            }
            .padding()
        }
    }
}
