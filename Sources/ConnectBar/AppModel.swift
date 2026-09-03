import AppKit
import Observation
import ServiceManagement
import UserNotifications

@MainActor
@Observable
final class AppModel {
    var apps: [StoreApp] = []
    var signals: [Signal] = []
    var connection: ConnectionState = .loading
    var isRefreshing = false
    var lastRefresh: Date?
    private(set) var seenSignalIDs: Set<String>

    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var needsAllAppsDefault: Bool

    var mockMode: Bool {
        didSet { defaults.set(mockMode, forKey: "mockMode"); restart() }
    }
    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    var selectedAppIDs: Set<String> {
        didSet { defaults.set(Array(selectedAppIDs), forKey: "selectedAppIDs"); refresh() }
    }

    init() {
        needsAllAppsDefault = defaults.integer(forKey: "appSelectionVersion") < 1
        mockMode = defaults.bool(forKey: "mockMode")
        notificationsEnabled = defaults.bool(forKey: "notificationsEnabled")
        selectedAppIDs = Set(defaults.stringArray(forKey: "selectedAppIDs") ?? [])
        seenSignalIDs = Set(defaults.stringArray(forKey: "seenSignalIDs") ?? [])
        if let data = defaults.data(forKey: "snapshot"),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            signals = snapshot.signals
            lastRefresh = snapshot.refreshedAt
        }
    }

    var attentionCount: Int { signals.filter { $0.isAttention && !seenSignalIDs.contains($0.id) }.count }
    var worstSeverity: Severity { signals.map(\.severity).max() ?? .info }
    var loginEnabled: Bool { SMAppService.mainApp.status == .enabled }

    func start() {
        refresh()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(600))
                self?.refresh()
            }
        }
    }

    func restart() {
        refreshTask?.cancel()
        apps = []
        signals = []
        connection = .loading
        refresh()
    }

    func refresh() {
        guard !isRefreshing else { return }
        refreshTask = Task { [weak self] in await self?.performRefresh() }
    }

    private func performRefresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let service: any ASCServing = mockMode ? MockASCClient() : try ASCClient()
            let fetchedApps = try await service.apps()
            apps = fetchedApps
            if needsAllAppsDefault {
                selectedAppIDs = Set(fetchedApps.map(\.id))
                defaults.set(1, forKey: "appSelectionVersion")
                needsAllAppsDefault = false
            }
            let selected = fetchedApps.filter { selectedAppIDs.contains($0.id) }
            var fetched: [Signal] = []
            try await withThrowingTaskGroup(of: [Signal].self) { group in
                for app in selected { group.addTask { try await service.signals(for: app) } }
                for try await appSignals in group { fetched += appSignals }
            }
            publish(fetched)
            connection = .ready
        } catch ASCError.missingCLI {
            connection = .missingCLI
        } catch {
            let message = error.localizedDescription
            connection = message.localizedCaseInsensitiveContains("auth") || message.contains("401")
                ? .unauthenticated : .failed(message)
        }
    }

    private func publish(_ fetched: [Signal]) {
        let oldIDs = Set(signals.map(\.id))
        signals = fetched
        lastRefresh = .now
        let snapshot = Snapshot(signals: fetched, refreshedAt: lastRefresh)
        if let data = try? JSONEncoder().encode(snapshot) { defaults.set(data, forKey: "snapshot") }
        guard notificationsEnabled, !oldIDs.isEmpty else { return }
        for signal in fetched where !oldIDs.contains(signal.id) && signal.isAttention {
            let content = UNMutableNotificationContent()
            content.title = signal.appName
            content.body = signal.detail.map { "\(signal.title): \($0)" } ?? signal.title
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: signal.id, content: content, trigger: nil))
        }
    }

    func markSeen(_ signal: Signal) {
        seenSignalIDs.insert(signal.id)
        defaults.set(Array(seenSignalIDs), forKey: "seenSignalIDs")
    }

    func markAllSeen() {
        seenSignalIDs.formUnion(signals.filter(\.isAttention).map(\.id))
        defaults.set(Array(seenSignalIDs), forKey: "seenSignalIDs")
    }

    func toggleAllApps() {
        selectedAppIDs = selectedAppIDs == Set(apps.map(\.id)) ? [] : Set(apps.map(\.id))
    }

    func requestNotifications() {
        Task {
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
            notificationsEnabled = granted
        }
    }

    func toggleLogin() {
        do {
            if loginEnabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch { connection = .failed(error.localizedDescription) }
    }

    func openASC() {
        NSWorkspace.shared.open(URL(string: "https://appstoreconnect.apple.com/apps")!)
    }
}
