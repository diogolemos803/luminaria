import Foundation
import SwiftUI

// MARK: - Protocolo trocável

/// Qualquer visual futuro pro "sistema de crescimento" implementa isso. A lógica de
/// progresso (`NightSessionActivityTracker` abaixo) nunca precisa saber qual metáfora
/// visual está sendo usada — só expõe a fase atual (`NightSessionActivityTracker.
/// Phase`) e o destino corrente, e quem implementa esse protocolo decide como
/// desenhar isso. Trocar a metáfora depois é só trocar QUEM conforma esse protocolo
/// (hoje: `RocketGrowthVisual`), sem tocar em `NightSessionActivityTracker`.
protocol GrowthVisualizing {
    associatedtype Content: View
    @ViewBuilder func render(
        phase: NightSessionActivityTracker.Phase,
        destination: CelestialDestination,
        theme: ModeTheme
    ) -> Content
}

// MARK: - Destinos (planetas desbloqueados por sequência de dias)

/// Um destino que o foguete pode visitar — desbloqueado por sequência de dias
/// consecutivos com sessão "limpa" (`DetoxStats.currentCleanDayStreak`), não por
/// compra (decisão do usuário: só sequência por enquanto, sem StoreKit — isso exigiria
/// configurar produtos no App Store Connect e não dá pra testar sem device real com
/// conta sandbox, nenhum dos dois disponível neste ambiente). Hoje aparece como o
/// selo no céu da decolagem (`LaunchScene`); o pouso (`MoonLandingScene`) ainda é
/// sempre na Lua.
struct CelestialDestination: Identifiable, Equatable {
    let id: String
    let name: String
    let requiredStreakDays: Int
    let color: Color
}

enum GrowthDestinations {
    /// 0/7/15/30 dias — os números exatos pedidos pelo usuário ("7 dias seguidos, 15
    /// dias, 1 mês etc"). A Lua está sempre disponível (0 dias), o resto desbloqueia
    /// progressivamente. Nomes e marcos vêm de `PlanetMilestones` (`WidgetShared.swift`,
    /// compartilhado com os widgets da tela bloqueada) — aqui só entram as cores.
    static let all: [CelestialDestination] = PlanetMilestones.all.map {
        CelestialDestination(id: $0.id, name: $0.name, requiredStreakDays: $0.requiredStreakDays, color: color(for: $0.id))
    }

    private static func color(for id: String) -> Color {
        switch id {
        case "mars": return Color(red: 0.80, green: 0.42, blue: 0.30)
        case "saturn": return Color(red: 0.86, green: 0.72, blue: 0.48)
        case "neptune": return SoveeColor.noiteAzul
        default: return Color(red: 0.82, green: 0.82, blue: 0.80)
        }
    }

    static func unlocked(currentStreak: Int) -> [CelestialDestination] {
        all.filter { $0.requiredStreakDays <= currentStreak }
    }

    /// O destino da viagem de hoje — sempre o mais distante já desbloqueado. Não tem
    /// UI ainda pra escolher manualmente qual visitar (a pessoa só vê o pouso de
    /// manhã acontecer no destino mais longe que já alcançou); dá pra adicionar um
    /// seletor depois sem mudar essa lógica.
    static func furthestUnlocked(currentStreak: Int) -> CelestialDestination {
        unlocked(currentStreak: currentStreak).max { $0.requiredStreakDays < $1.requiredStreakDays } ?? all[0]
    }
}

// MARK: - Rastreador de atividade / progresso

/// Rastreia atividade dentro de UMA sessão de modo noite ativa — alimenta duas coisas
/// ao mesmo tempo, porque as duas dependem exatamente da mesma pergunta técnica
/// (ver resumo da rodada do brief SOVEE, item 3b): "a pessoa tocou no celular durante
/// a sessão?"
///
/// 1. **Reset do progresso de crescimento** (item 2c): reabrir o app ou usar um passe
///    de emergência durante uma sessão ativa "explode o foguete", que depois volta a
///    orbitar normalmente.
/// 2. **Métrica de maior sequência sem tocar numa sessão** (item 2b, métrica 1):
///    guarda o maior intervalo entre dois "toques" (ou entre o início da sessão e o
///    primeiro toque, ou entre o último toque e o fim da sessão).
///
/// **Definição de "toque" usada aqui**: reabrir o app OU usar um passe de emergência —
/// não existe API pública no iOS pra detectar "qualquer toque na tela" ou "desbloqueou
/// o celular" com o app em segundo plano (ver investigação de viabilidade do item 3b).
/// Como os apps ficam de fato bloqueados durante o modo noite, essas são as duas
/// únicas ações reais e detectáveis que significam "a pessoa decidiu mexer no
/// celular" — não é uma aproximação frágil, é o que dá pra observar de verdade.
final class NightSessionActivityTracker: ObservableObject {
    static let shared = NightSessionActivityTracker()

    /// `.liftoff` é o momento da decolagem (transiente — vira `.orbiting` quando a
    /// própria cena visual chama `liftoffAnimationCompleted()`, ao terminar de
    /// desenhar a subida). `.orbiting` é o estado de repouso da sessão —
    /// dura a noite inteira, sem "progresso" nenhum pra calcular (a viagem não avança
    /// mais em direção a um destino durante a noite; o destino só entra em cena no
    /// pouso, de manhã — ver `MoonLandingScene` em `RocketScenes.swift`).
    /// `.exploded` é TRANSIENTE (meteoro atinge o foguete) — depois de
    /// `explosionDuration` volta pra `.liftoff`, porque a cena relança um foguete novo
    /// da Terra, e vira `.orbiting` quando esse relançamento assenta. A sessão de
    /// bloqueio em si não é afetada.
    enum Phase: Equatable {
        case liftoff
        case orbiting
        case exploded
    }

    @Published private(set) var phase: Phase = .liftoff
    /// Instante do último "toque" (explosão). A cena usa isso pra desenhar o meteoro, a
    /// explosão e o relançamento a partir desse momento (ver `LaunchScene`).
    @Published private(set) var lastExplosionDate: Date?

    private var sessionStartDate: Date?
    private var lastTouchDate: Date?
    private var longestGapThisSession: TimeInterval = 0
    private var isExploding = false

    /// Meteoro + explosão (ver `LaunchPainter.relaunchDelay`); depois disso a fase volta
    /// pra `.liftoff`, porque o foguete novo decola de novo — e é a própria cena que
    /// chama `liftoffAnimationCompleted()` quando esse relançamento assenta.
    private static let explosionDuration: TimeInterval = 2.1
    /// Janela logo após o início da sessão em que "voltar a ficar ativo" é ignorado
    /// (ver `registerTouchEvent`).
    private static let startGracePeriod: TimeInterval = 10

    private init() {}

    /// Chamado por `ScreenTimeManager.applyShield` — início de uma sessão de bloqueio
    /// nova. Repare que isso NÃO agenda sozinho a virada pra `.orbiting` — quem faz
    /// isso é `liftoffAnimationCompleted()`, chamado pela própria cena visual
    /// (`LaunchScene`) quando a animação de decolagem dela termina de verdade.
    /// Bug real corrigido: a primeira versão tinha um timer próprio aqui (contando a
    /// partir do INÍCIO da sessão, antes até do botão redondo sumir da tela), correndo
    /// em paralelo com a duração da animação visual da cena — como a cena só aparece
    /// depois do botão descer (~1s depois), os dois relógios ficavam fora de sincronia
    /// e a fase virava `.orbiting` ANTES da animação de subida visual terminar,
    /// cortando a decolagem pela metade (relatado pelo usuário como "não teve
    /// animação nenhuma"). Delegar o fim da decolagem pra quem está de fato desenhando
    /// a decolagem elimina essa corrida de vez.
    func sessionDidStart() {
        let now = Date()
        sessionStartDate = now
        lastTouchDate = now
        longestGapThisSession = 0
        isExploding = false
        lastExplosionDate = nil
        phase = .liftoff
    }

    /// Chamado por `LaunchScene` no exato instante em que a animação visual de
    /// decolagem terminou de subir — só então a fase vira `.orbiting`. Guardas:
    /// ignora se a sessão já terminou (`sessionStartDate == nil`) ou se um toque
    /// aconteceu nesse meio-tempo (já explodiu, `phase != .liftoff`).
    func liftoffAnimationCompleted() {
        guard sessionStartDate != nil, phase == .liftoff else { return }
        phase = .orbiting
    }

    /// Chamado por `ScreenTimeManager.removeShield` — fim da sessão (por qualquer
    /// motivo: despertador tocou, desarme manual, ou passe de emergência). Retorna o
    /// maior intervalo sem toque observado durante essa sessão, pra
    /// `SleepReportEntry.longestUninterruptedSeconds`.
    @discardableResult
    func sessionDidEnd() -> TimeInterval {
        if let lastTouchDate {
            longestGapThisSession = max(longestGapThisSession, Date().timeIntervalSince(lastTouchDate))
        }
        let result = longestGapThisSession
        sessionStartDate = nil
        lastTouchDate = nil
        longestGapThisSession = 0
        isExploding = false
        lastExplosionDate = nil
        phase = .liftoff
        return result
    }

    /// Chamado quando o app volta a ficar ativo (`scenePhase == .active`) DURANTE uma
    /// sessão armada, ou quando um passe de emergência é usado — os dois únicos
    /// eventos reais e detectáveis de "a pessoa mexeu no celular" (ver documentação
    /// da classe). "Explode o foguete" (fase transiente) e registra o intervalo
    /// terminado como candidato a "maior sequência sem tocar".
    func registerTouchEvent() {
        guard let sessionStartDate else { return }
        let now = Date()
        // A folha de sistema do NFC deixa o app `.inactive`; ao fechar (logo depois
        // de reconhecer a luminária, que é quando a sessão começa) o `scenePhase`
        // volta pra `.active` — sem essa carência isso contaria como "reabriu o app"
        // e explodiria o foguete na própria decolagem.
        guard now.timeIntervalSince(sessionStartDate) > Self.startGracePeriod else { return }
        if let lastTouchDate {
            longestGapThisSession = max(longestGapThisSession, now.timeIntervalSince(lastTouchDate))
        }
        lastTouchDate = now
        isExploding = true
        phase = .exploded
        lastExplosionDate = now
        WidgetBridge.markImpact(at: now)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.explosionDuration) { [weak self] in
            guard let self, self.sessionStartDate != nil, self.lastExplosionDate == now else { return }
            self.isExploding = false
            self.phase = .liftoff
        }
    }
}

// MARK: - Visual: entrada + decolagem noturna

/// Implementação concreta de `GrowthVisualizing` — a cena de decolagem aprovada no
/// protótipo `design/decolagem_prototipo.html` (ilustração flat seguindo a
/// referência `design/referencia_decolagem.webp`), desenhada em `LaunchScene`
/// (`RocketScenes.swift`). Se um visual diferente for escolhido depois, basta criar
/// outro tipo conformando `GrowthVisualizing` e trocar qual é instanciado em
/// `ContentView` — a lógica em `NightSessionActivityTracker` não muda nada.
///
/// `sceneStart` é o instante em que a cena começa a entrar (o botão redondo sai pela
/// esquerda nesse mesmo momento); `nil` = app reaberto no meio da sessão, mostra
/// direto o foguete já em voo.
struct RocketGrowthVisual: GrowthVisualizing {
    var sceneStart: Date?
    /// Último "toque" da sessão (`NightSessionActivityTracker.lastExplosionDate`).
    var explosionDate: Date?

    func render(phase: NightSessionActivityTracker.Phase, destination: CelestialDestination, theme: ModeTheme) -> some View {
        LaunchScene(badgeColor: destination.color, sceneStart: sceneStart, explosionDate: explosionDate)
    }
}
