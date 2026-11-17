import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private(set) var user: NokoUser?
    private(set) var projects: [NokoProject] = []
    private(set) var tags: [NokoTag] = []
    private(set) var timers: [Int: NokoTimer] = [:]   // by project id
    private(set) var now = Date()
    private(set) var timersFetchedAt = Date()
    private(set) var isLoggedIn = false
    private(set) var isLoading = false
    var errorMessage: String?

    private let client: NokoClient
    private let store: TokenStore
    private var projectsFetchedAt: Date?
    private var tickTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?

    init(client: NokoClient = NokoClient(), store: TokenStore = KeychainStore()) {
        self.client = client
        self.store = store
        startTicking()
        Task { await restoreSession() }
    }

    // MARK: Derived

    /// Timer shown in the menu bar: running first, otherwise first paused one.
    var displayedTimer: NokoTimer? {
        let active = timers.values.filter(\.isActive)
        return active.first(where: { $0.state == .running })
            ?? active.sorted(by: { $0.id < $1.id }).first
    }

    func elapsedSeconds(_ timer: NokoTimer) -> Int {
        guard timer.state == .running else { return timer.seconds }
        return timer.seconds + max(0, Int(now.timeIntervalSince(timersFetchedAt)))
    }

    func sortedProjects(matching search: String) -> [NokoProject] {
        let q = search.trimmingCharacters(in: .whitespaces)
        let filtered = q.isEmpty ? projects : projects.filter { $0.name.localizedCaseInsensitiveContains(q) }
        return filtered.sorted { a, b in
            let ta = timers[a.id]?.isActive == true, tb = timers[b.id]?.isActive == true
            if ta != tb { return ta }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    func project(id: Int) -> NokoProject? { projects.first { $0.id == id } }

    // MARK: Auth

    private func restoreSession() async {
        guard let token = store.load() else { return }
        await client.setToken(token)
        isLoggedIn = true
        await refreshAll()
        startPolling()
    }

    /// Validates the token, then persists it.
    func login(token: String) async throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        await client.setToken(trimmed)
        do {
            user = try await client.currentUser()
            try store.save(trimmed)
        } catch {
            await client.setToken(nil)
            user = nil
            throw error
        }
        isLoggedIn = true
        errorMessage = nil
        await refreshAll()
        startPolling()
    }

    func logout() {
        store.delete()
        pollTask?.cancel()
        Task { await client.setToken(nil) }
        isLoggedIn = false
        user = nil
        projects = []
        tags = []
        timers = [:]
        projectsFetchedAt = nil
    }

    // MARK: Refresh

    func refreshAll() async {
        guard isLoggedIn else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            if user == nil { user = try await client.currentUser() }
            async let p = client.projects()
            async let t = client.tags()
            projects = try await p
            tags = try await t
            projectsFetchedAt = Date()
            try await loadTimers()
            errorMessage = nil
        } catch { handle(error) }
    }

    func refreshTimers() async {
        guard isLoggedIn else { return }
        do { try await loadTimers(); errorMessage = nil } catch { handle(error) }
    }

    /// Called when the popover opens.
    func popoverOpened() async {
        if let at = projectsFetchedAt, Date().timeIntervalSince(at) < 300 {
            await refreshTimers()
        } else {
            await refreshAll()
        }
    }

    private func loadTimers() async throws {
        let list = try await client.timers()
        var dict: [Int: NokoTimer] = [:]
        for t in list where t.isActive { dict[t.project.id] = t }
        timers = dict
        timersFetchedAt = Date()
        now = Date()
    }

    // MARK: Actions

    func start(projectID: Int) async { await run { try await self.client.startTimer(projectID: projectID) } }
    func pause(projectID: Int) async { await run { try await self.client.pauseTimer(projectID: projectID) } }

    func updateNotes(projectID: Int, text: String) async {
        guard timers[projectID]?.description ?? "" != text else { return }
        await run(refresh: false) { try await self.client.updateNotes(projectID: projectID, description: text) }
        if let t = timers[projectID] {
            timers[projectID] = NokoTimer(id: t.id, state: t.state, seconds: t.seconds, date: t.date,
                                          description: text, project: t.project)
        }
    }

    /// Logs the timer as an entry. Throws so the confirmation window can show the error inline.
    func finish(projectID: Int, notes: String) async throws {
        do {
            try await client.logTimer(projectID: projectID, description: notes)
        } catch {
            if case NokoError.unauthorized = error { handle(error) }
            throw error
        }
        errorMessage = nil
        await refreshTimers()
    }

    /// The current user's entries in a project for a date range (yyyy-MM-dd).
    func entries(projectID: Int, from: String, to: String) async throws -> [NokoEntry] {
        do {
            if user == nil { user = try await client.currentUser() }
            guard let userID = user?.id else { throw NokoError.invalidResponse }
            return try await client.entries(projectID: projectID, userID: userID, from: from, to: to)
        } catch {
            if case NokoError.unauthorized = error { handle(error) }
            throw error
        }
    }

    /// Discards the timer without logging an entry. Throws so the window can show the error inline.
    func discard(projectID: Int) async throws {
        do {
            try await client.discardTimer(projectID: projectID)
        } catch {
            if case NokoError.unauthorized = error { handle(error) }
            throw error
        }
        errorMessage = nil
        await refreshTimers()
    }

    private func run(refresh: Bool = true, _ op: @escaping () async throws -> Void) async {
        do {
            try await op()
            errorMessage = nil
            if refresh { try await loadTimers() }
        } catch { handle(error) }
    }

    private func handle(_ error: Error) {
        if case NokoError.unauthorized = error {
            logout()
            errorMessage = String(localized: "error.unauthorized")
        } else {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Background work

    private func startTicking() {
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                if self.timers.values.contains(where: { $0.state == .running }) { self.now = Date() }
            }
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard let self, !Task.isCancelled else { return }
                await self.refreshTimers()
            }
        }
    }
}
