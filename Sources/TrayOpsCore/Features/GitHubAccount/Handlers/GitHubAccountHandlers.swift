import Foundation

/// One handler per Request (SRP). Apply and Reconcile go through the **same**
/// ``AccountApplier`` so their behavior cannot diverge (RN-GH-10).

struct ResolveGitHubStateHandler: RequestHandler {
    let store: AccountStore
    let resolver: AccountStateResolver

    func handle(_ request: ResolveGitHubState) async throws -> GitHubAccountState {
        try await resolver.resolve(accounts: try store.all())
    }
}

struct ListAccountsHandler: RequestHandler {
    let store: AccountStore

    func handle(_ request: ListAccounts) async throws -> [AccountDTO] {
        try store.all().map(\.dto)
    }
}

struct ApplyAccountHandler: RequestHandler {
    let store: AccountStore
    let applier: AccountApplier
    let resolver: AccountStateResolver
    let target: AccountTarget

    func handle(_ request: ApplyAccount) async throws -> ApplyResultDTO {
        let accounts = try store.all()
        guard let account = accounts.first(where: { $0.id == request.id }) else {
            throw GitHubAccountError.accountNotFound
        }
        return await applyAndResolve(account, accounts: accounts, applier: applier, resolver: resolver, target: target)
    }
}

struct ReconcileAccountHandler: RequestHandler {
    let store: AccountStore
    let applier: AccountApplier
    let resolver: AccountStateResolver
    let target: AccountTarget

    func handle(_ request: ReconcileAccount) async throws -> ApplyResultDTO {
        let accounts = try store.all()
        let resolvedID = request.id ?? target.id
        guard let id = resolvedID, let account = accounts.first(where: { $0.id == id }) else {
            throw GitHubAccountError.noTargetAccount
        }
        return await applyAndResolve(account, accounts: accounts, applier: applier, resolver: resolver, target: target)
    }
}

struct AddAccountHandler: RequestHandler {
    let store: AccountStore

    func handle(_ request: AddAccount) async throws -> AccountDTO {
        let sortIndex = (try? store.all().count) ?? 0
        let account = Account(
            label: request.label,
            gitName: request.gitName,
            gitEmail: request.gitEmail,
            identityFile: request.identityFile,
            sortIndex: sortIndex
        )
        try store.add(account)
        return account.dto
    }
}

struct UpdateAccountHandler: RequestHandler {
    let store: AccountStore

    func handle(_ request: UpdateAccount) async throws -> AccountDTO {
        guard var account = try store.all().first(where: { $0.id == request.id }) else {
            throw GitHubAccountError.accountNotFound
        }
        account.label = request.label
        account.gitName = request.gitName
        account.gitEmail = request.gitEmail
        account.identityFile = request.identityFile
        try store.update(account)
        return account.dto
    }
}

struct RemoveAccountHandler: RequestHandler {
    let store: AccountStore

    func handle(_ request: RemoveAccount) async throws {
        guard let account = try store.all().first(where: { $0.id == request.id }) else {
            throw GitHubAccountError.accountNotFound
        }
        try store.remove(account)
    }
}

/// Shared Set/Reconcile sequence: apply then report success/failure with the
/// freshly resolved state (RN-GH-09/10).
private func applyAndResolve(
    _ account: Account,
    accounts: [Account],
    applier: AccountApplier,
    resolver: AccountStateResolver,
    target: AccountTarget
) async -> ApplyResultDTO {
    do {
        try await applier.apply(account)
        target.id = account.id
        let state = (try? await resolver.resolve(accounts: accounts)) ?? .unknown
        return ApplyResultDTO(success: true, message: nil, state: state)
    } catch {
        let state = (try? await resolver.resolve(accounts: accounts)) ?? .unknown
        return ApplyResultDTO(success: false, message: "\(error)", state: state)
    }
}
