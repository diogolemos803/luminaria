import Foundation

// MARK: - Amigos

/// Modelo de dados pra lista de amigos — item 2a do terreno social/gamificação.
///
/// **Não existe backend nem autenticação no app hoje** (toda a persistência é
/// `UserDefaults` local + `NSUbiquitousKeyValueStore`, que é privado por conta iCloud,
/// não compartilhável entre pessoas). Uma feature de amigos de verdade precisa de:
/// 1. Uma identidade real de usuário (Sign in with Apple é o caminho de menor fricção).
/// 2. Um backend pro grafo social — CloudKit (banco público/compartilhado via
///    `CKShare`, grátis dentro de limites generosos, sem servidor próprio) ou um
///    backend dedicado (Firebase/Supabase/API própria). CloudKit é a recomendação,
///    dado que o projeto já não tem nenhuma infra paga até agora.
///
/// Este arquivo só define a FORMA dos dados — nenhuma implementação de rede.
struct Friend: Identifiable, Codable, Equatable {
    /// ID estável vindo de uma identidade real (registro CloudKit, Sign in with
    /// Apple, etc.) — só um placeholder de tipo por enquanto, o formato final
    /// depende de qual backend for escolhido.
    var id: String
    var displayName: String
    var connectedAt: Date
}

enum FriendInviteStatus: String, Codable {
    case pending, accepted, declined
}

struct FriendInvite: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var fromDisplayName: String
    /// E-mail, número ou identificador de convite — formato final depende do backend.
    var toIdentifier: String
    var status: FriendInviteStatus
    var createdAt: Date
}

/// Qualquer fonte de dados de amigos (local/mock hoje, CloudKit ou backend próprio
/// depois) implementa isso — a UI programa contra o protocolo, não contra a
/// implementação, então trocar de local pra CloudKit não deveria exigir tocar nas
/// telas que já existirem quando isso for construído de verdade.
protocol FriendsRepository {
    func fetchFriends() async throws -> [Friend]
    func sendInvite(to identifier: String) async throws -> FriendInvite
    func respondToInvite(_ invite: FriendInvite, accept: Bool) async throws
}

// MARK: - Ranking de detox de tela

/// Funções puras sobre o histórico já existente (`SleepReportEntry`) — sem estado
/// próprio, fáceis de testar e reaproveitar tanto pra um ranking local quanto,
/// depois, social (bastaria comparar os números calculados aqui entre `Friend`s).
enum DetoxStats {
    /// Maior sequência de dias consecutivos com pelo menos uma sessão "limpa" — o
    /// despertador tocou até o fim, sem desarmar manualmente nem usar passe de
    /// emergência (ver `DetoxSessionEndReason` em `SleepReportStore.swift`). Olha só
    /// pro dia civil (`Calendar.startOfDay`) de cada entrada, ignorando duplicatas no
    /// mesmo dia.
    static func longestCleanDayStreak(in entries: [SleepReportEntry], calendar: Calendar = .current) -> Int {
        let cleanDays = Set(
            entries
                .filter { $0.endReason == .alarmFired }
                .map { calendar.startOfDay(for: $0.date) }
        )
        guard !cleanDays.isEmpty else { return 0 }

        var longest = 0
        var current = 0
        var previousDay: Date?
        for day in cleanDays.sorted() {
            if let previousDay,
               let expected = calendar.date(byAdding: .day, value: 1, to: previousDay),
               calendar.isDate(expected, inSameDayAs: day) {
                current += 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            previousDay = day
        }
        return longest
    }

    /// Maior sequência de horas sem "tocar o celular" numa sessão só, olhando pra
    /// `longestUninterruptedSeconds` de cada entrada — ver `NightSessionActivityTracker`
    /// em `GrowthEngine.swift` pra como esse número é calculado durante a sessão
    /// (reabrir o app ou usar um passe de emergência conta como "tocou").
    static func longestUninterruptedStreak(in entries: [SleepReportEntry]) -> TimeInterval {
        entries.map(\.longestUninterruptedSeconds).max() ?? 0
    }
}
