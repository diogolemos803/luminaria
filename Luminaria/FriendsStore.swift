import CloudKit
import Combine
import Foundation

/// Amigos e ranking de detox (pedido do usuário, 2026-09-26), sobre o **banco público do
/// CloudKit** — sem servidor próprio, sem login extra: a identidade é a conta iCloud do
/// iPhone.
///
/// Modelo escolhido pelo usuário: **amizade por código, sem aceite**. Cada pessoa tem um
/// perfil público (registro `Profile`) com apelido, um código de 6 caracteres e as
/// estatísticas de detox; adicionar alguém é digitar o código dele — a lista de amigos é
/// só local (quem EU acompanho), sem fila de convites. **Ranking pela sequência atual de
/// noites limpas** (a mesma que libera os planetas — `DetoxStats.currentCleanDayStreak`),
/// com o recorde de cada um como desempate/informação extra.
///
/// Privacidade: o perfil público só tem apelido, código e números de detox. Só dá pra
/// achar um perfil sabendo o código (o único campo consultável) ou o ID dele — não existe
/// consulta que liste todo mundo.
///
/// **Configuração fora do código (obrigatória antes de funcionar num build assinado)**:
/// container `iCloud.com.luminaria.app` com CloudKit no App ID, e o tipo de registro
/// `Profile` criado e publicado em produção no CloudKit Console (campos em
/// `ProfileField`, índice "Queryable" em `friendCode`) — builds do TestFlight usam o
/// ambiente de produção, que não cria tipos de registro sozinho. Ver CLAUDE.md.
@MainActor
final class FriendsStore: ObservableObject {
    static let shared = FriendsStore()

    enum Status: Equatable {
        case idle
        case loading
        case ready
        /// iPhone sem conta iCloud (ou iCloud restrito).
        case noAccount
        case failed(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var me: FriendProfile?
    @Published private(set) var friends: [FriendProfile] = []
    @Published private(set) var displayName: String

    static let containerIdentifier = "iCloud.com.luminaria.app"
    private static let recordType = "Profile"
    private static let friendIDsKey = "com.luminaria.friends.ids"
    private static let displayNameKey = "com.luminaria.friends.displayName"
    private static let myCodeKey = "com.luminaria.friends.myCode"
    /// Sem ambiguidade visual (sem 0/O, 1/I/L) — o código é digitado à mão.
    private static let codeAlphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")

    private enum ProfileField {
        static let displayName = "displayName"
        static let friendCode = "friendCode"
        static let currentStreak = "currentStreak"
        static let longestStreak = "longestStreak"
        static let totalCleanNights = "totalCleanNights"
        static let lastCleanNight = "lastCleanNight"
        static let updatedAt = "updatedAt"
    }

    private lazy var container = CKContainer(identifier: Self.containerIdentifier)
    private var database: CKDatabase { container.publicCloudDatabase }
    private var myRecordID: CKRecord.ID?
    private var friendIDs: [String]

    private init() {
        let defaults = UserDefaults.standard
        friendIDs = defaults.stringArray(forKey: Self.friendIDsKey) ?? []
        displayName = defaults.string(forKey: Self.displayNameKey) ?? ""
    }

    /// Ranking: eu + amigos, pela sequência atual (a que vale hoje), recorde desempata.
    var ranking: [FriendProfile] {
        let everyone = (me.map { [$0] } ?? []) + friends
        return everyone.sorted {
            let a = $0.effectiveStreak(), b = $1.effectiveStreak()
            if a != b { return a > b }
            if $0.longestStreak != $1.longestStreak { return $0.longestStreak > $1.longestStreak }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    var inviteMessage: String {
        guard let code = me?.friendCode else { return "" }
        return "Bora ver quem fica mais noites longe do celular? Me adiciona no Luminária (Amigos → Adicionar amigo) com o código \(code)."
    }

    // MARK: - Carregar / atualizar

    /// Garante a conta iCloud, publica o meu perfil com as estatísticas atuais e busca os
    /// perfis dos amigos. Chamado ao abrir a tela de amigos (e no "puxar pra atualizar").
    func refresh() async {
        if status != .ready { status = .loading }
        do {
            guard try await container.accountStatus() == .available else {
                status = .noAccount
                return
            }
            try await publishMyProfile()
            try await fetchFriends()
            status = .ready
        } catch {
            status = .failed(Self.describe(error))
        }
    }

    /// Chamado quando uma noite termina (`SleepReportStore.recordSession`) — mantém os
    /// números do meu perfil em dia pros amigos. Silencioso: falha aqui não incomoda
    /// ninguém, a próxima abertura da tela de amigos tenta de novo.
    func publishMyStatsQuietly() async {
        guard (try? await container.accountStatus()) == .available else { return }
        try? await publishMyProfile()
    }

    func setDisplayName(_ name: String) async {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
        guard trimmed != displayName else { return }
        displayName = trimmed
        UserDefaults.standard.set(trimmed, forKey: Self.displayNameKey)
        await refresh()
    }

    // MARK: - Amigos

    enum AddFriendError: LocalizedError {
        case invalidCode, notFound, isMe, alreadyFriend

        var errorDescription: String? {
            switch self {
            case .invalidCode: return "O código tem 6 letras e números."
            case .notFound: return "Nenhum perfil com esse código. Confira com seu amigo."
            case .isMe: return "Esse é o seu próprio código."
            case .alreadyFriend: return "Essa pessoa já está na sua lista."
            }
        }
    }

    func addFriend(code rawCode: String) async throws -> FriendProfile {
        let code = rawCode.uppercased().filter { !$0.isWhitespace }
        guard code.count == 6 else { throw AddFriendError.invalidCode }
        if code == me?.friendCode { throw AddFriendError.isMe }

        let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(format: "%K == %@", ProfileField.friendCode, code))
        let (results, _) = try await database.records(matching: query, resultsLimit: 1)
        guard let record = try results.first?.1.get() else { throw AddFriendError.notFound }
        let profile = Self.profile(from: record)
        guard !friendIDs.contains(profile.id) else { throw AddFriendError.alreadyFriend }

        friendIDs.append(profile.id)
        persistFriendIDs()
        friends.append(profile)
        return profile
    }

    func removeFriend(id: String) {
        friendIDs.removeAll { $0 == id }
        friends.removeAll { $0.id == id }
        persistFriendIDs()
    }

    // MARK: - CloudKit

    private func publishMyProfile() async throws {
        let recordID = try await ensureMyRecordID()
        let code = try await ensureMyCode()
        let stats = Self.currentStats()

        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        record[ProfileField.displayName] = displayName.isEmpty ? "Sem apelido" : displayName
        record[ProfileField.friendCode] = code
        record[ProfileField.currentStreak] = stats.currentStreak
        record[ProfileField.longestStreak] = stats.longestStreak
        record[ProfileField.totalCleanNights] = stats.totalCleanNights
        record[ProfileField.lastCleanNight] = stats.lastCleanNight
        record[ProfileField.updatedAt] = Date()
        // `.changedKeys` grava por cima sem precisar buscar o registro antes (é sempre
        // o meu próprio perfil, só eu escrevo nele).
        _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .changedKeys)
        me = Self.profile(from: record)
    }

    private func fetchFriends() async throws {
        guard !friendIDs.isEmpty else {
            friends = []
            return
        }
        let ids = friendIDs.map { CKRecord.ID(recordName: $0) }
        let results = try await database.records(for: ids)
        // perfis apagados/inexistentes simplesmente não aparecem (sem derrubar a lista)
        friends = ids.compactMap { id in
            guard let record = try? results[id]?.get() else { return nil }
            return Self.profile(from: record)
        }
    }

    /// ID do meu perfil derivado da conta iCloud (estável entre reinstalações e aparelhos
    /// da mesma conta) — não precisa guardar nada localmente pra me reencontrar.
    private func ensureMyRecordID() async throws -> CKRecord.ID {
        if let myRecordID { return myRecordID }
        let userID = try await container.userRecordID()
        let id = CKRecord.ID(recordName: "profile_" + userID.recordName)
        myRecordID = id
        return id
    }

    /// Reaproveita o código já publicado (inclusive depois de reinstalar o app); só gera
    /// um novo, conferindo que ninguém usa, na primeira vez.
    private func ensureMyCode() async throws -> String {
        if let saved = UserDefaults.standard.string(forKey: Self.myCodeKey) { return saved }
        let recordID = try await ensureMyRecordID()
        if let existing = try? await database.record(for: recordID),
           let code = existing[ProfileField.friendCode] as? String {
            UserDefaults.standard.set(code, forKey: Self.myCodeKey)
            return code
        }
        for _ in 0..<5 {
            let candidate = String((0..<6).map { _ in Self.codeAlphabet.randomElement()! })
            let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(format: "%K == %@", ProfileField.friendCode, candidate))
            let (taken, _) = try await database.records(matching: query, resultsLimit: 1)
            if taken.isEmpty {
                UserDefaults.standard.set(candidate, forKey: Self.myCodeKey)
                return candidate
            }
        }
        throw CKError(.internalError)
    }

    private func persistFriendIDs() {
        UserDefaults.standard.set(friendIDs, forKey: Self.friendIDsKey)
    }

    private static func profile(from record: CKRecord) -> FriendProfile {
        FriendProfile(
            id: record.recordID.recordName,
            displayName: record[ProfileField.displayName] as? String ?? "Sem apelido",
            friendCode: record[ProfileField.friendCode] as? String ?? "",
            currentStreak: record[ProfileField.currentStreak] as? Int ?? 0,
            longestStreak: record[ProfileField.longestStreak] as? Int ?? 0,
            totalCleanNights: record[ProfileField.totalCleanNights] as? Int ?? 0,
            lastCleanNight: record[ProfileField.lastCleanNight] as? Date,
            updatedAt: record[ProfileField.updatedAt] as? Date ?? Date.distantPast
        )
    }

    private static func currentStats() -> (currentStreak: Int, longestStreak: Int, totalCleanNights: Int, lastCleanNight: Date?) {
        let entries = SleepReportStore.shared.entries
        let cleanDates = entries.filter { $0.endReason == .alarmFired }.map(\.date)
        let calendar = Calendar.current
        return (
            DetoxStats.currentCleanDayStreak(in: entries),
            DetoxStats.longestCleanDayStreak(in: entries),
            Set(cleanDates.map { calendar.startOfDay(for: $0) }).count,
            cleanDates.max()
        )
    }

    private static func describe(_ error: Error) -> String {
        if let ck = error as? CKError {
            switch ck.code {
            case .networkUnavailable, .networkFailure:
                return "Sem conexão com a internet."
            case .notAuthenticated:
                return "Entre na sua conta iCloud nos Ajustes do iPhone."
            case .unknownItem, .badContainer, .permissionFailure, .serverRejectedRequest:
                return "O iCloud do app ainda não está configurado (erro \(ck.code.rawValue))."
            default:
                return "Não deu pra falar com o iCloud (erro \(ck.code.rawValue))."
            }
        }
        return error.localizedDescription
    }
}

/// Perfil público de detox (o meu ou de um amigo).
struct FriendProfile: Identifiable, Equatable {
    let id: String
    var displayName: String
    var friendCode: String
    var currentStreak: Int
    var longestStreak: Int
    var totalCleanNights: Int
    var lastCleanNight: Date?
    var updatedAt: Date

    /// Sequência que vale HOJE: o número publicado só é atualizado quando a pessoa usa o
    /// app, então se a última noite limpa dela foi antes de ontem, a sequência já quebrou
    /// mesmo que o perfil ainda mostre o número antigo.
    func effectiveStreak(now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let lastCleanNight,
              let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) else { return 0 }
        return calendar.startOfDay(for: lastCleanNight) >= yesterday ? currentStreak : 0
    }
}
