import AppKit
import Combine
import Foundation

@MainActor
final class HotblockModel: ObservableObject {
    static let shared = HotblockModel()

    @Published var draftWebsite = ""
    @Published private(set) var websites: [String]
    @Published private(set) var isBlocking: Bool
    @Published private(set) var unlockWords: [String]
    @Published var unlockAttempt = ""
    @Published private(set) var unlockError = ""
    @Published private(set) var history: [HistoryEntry]
    @Published private(set) var settings: HotblockSettings
    @Published private(set) var installedBrowsers: [SupportedBrowser] = []
    @Published private(set) var browserPermissions: [SupportedBrowser: BrowserPermission] = [:]
    @Published private(set) var englishVoices: [String] = ["Ava"]
    @Published private(set) var notificationsAuthorized = false
    @Published private(set) var setupCompleted: Bool
    @Published var setupPresented = false
    @Published private(set) var feedback = ""

    private var state: PersistedState
    private let persistence = PersistenceStore()
    private let backgroundProtection = BackgroundProtection()
    private var monitoringTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?
    private var lastHandledHost: String?
    private var lastNotificationAt: [String: Date] = [:]

    private init() {
        var loaded = persistence.load()
        loaded.websites = Array(Set(loaded.websites)).sorted()
        loaded.unlockWordCount = min(max(loaded.unlockWordCount, 1), 100)
        if loaded.isBlocking && loaded.unlockWords.isEmpty {
            loaded.unlockWords = Self.randomWords(count: loaded.unlockWordCount)
        }

        state = loaded
        websites = loaded.websites
        isBlocking = loaded.isBlocking
        unlockWords = loaded.unlockWords
        history = loaded.history.sorted { $0.timestamp > $1.timestamp }
        settings = loaded.settings
        setupCompleted = loaded.setupCompleted
        persist()
    }

    var canStartStrictSession: Bool {
        setupCompleted
            && !websites.isEmpty
            && installedBrowsers.allSatisfy { browserPermissions[$0] == .authorized }
    }

    var backgroundProtectionAvailable: Bool {
        backgroundProtection.isAvailable
    }

    var canCompleteSetup: Bool {
        installedBrowsers.allSatisfy { browserPermissions[$0] == .authorized }
            && notificationsAuthorized
            && backgroundProtectionAvailable
    }

    func bootstrap() async {
        installedBrowsers = BrowserAutomation.installedBrowsers()
        browserPermissions = Dictionary(uniqueKeysWithValues: installedBrowsers.map { ($0, .unknown) })
        setupPresented = !setupCompleted

        if isBlocking {
            _ = backgroundProtection.install()
            startMonitoring()
        } else {
            backgroundProtection.remove()
        }

        let detectedVoices = await Task.detached(priority: .utility) {
            SpeechService.englishVoices()
        }.value
        englishVoices = detectedVoices.isEmpty ? ["Ava"] : detectedVoices
        if !englishVoices.contains(settings.voiceName) {
            settings.voiceName = englishVoices.first ?? "Ava"
            syncAndPersist()
        }

        notificationsAuthorized = await NotificationService.requestAuthorization()
        await requestAllBrowserPermissions()
    }

    func addWebsite() {
        guard let domain = Self.normalizedDomain(from: draftWebsite) else {
            showFeedback("Enter a valid website such as instagram.com.")
            return
        }
        guard !websites.contains(domain) else {
            draftWebsite = ""
            showFeedback("\(domain) is already blocked.")
            return
        }

        websites.append(domain)
        websites.sort()
        draftWebsite = ""
        syncAndPersist()
        showFeedback("\(domain) added.")
    }

    func removeWebsite(_ website: String) {
        guard !isBlocking else { return }
        websites.removeAll { $0 == website }
        syncAndPersist()
    }

    func addWebsites(_ newWebsites: Set<String>) {
        websites = Array(Set(websites).union(newWebsites)).sorted()
        syncAndPersist()
    }

    func startBlocking(unlockWordCount: Int) {
        guard canStartStrictSession else {
            setupPresented = true
            showFeedback("Complete setup and browser permissions before starting.")
            return
        }

        state.unlockWordCount = min(max(unlockWordCount, 1), 100)
        unlockWords = Self.randomWords(count: state.unlockWordCount)
        unlockAttempt = ""
        unlockError = ""
        isBlocking = true
        syncAndPersist()

        if !backgroundProtection.install() {
            NotificationService.send(
                title: "Hotblock protection needs attention",
                body: "Background relaunch protection could not be installed."
            )
        }
        startMonitoring()
    }

    func submitUnlockAttempt() -> Bool {
        let attempt = Self.normalizeWords(unlockAttempt)
        let expected = unlockWords.joined(separator: " ")
        guard attempt == expected else {
            unlockError = "The words do not match. Try again."
            return false
        }
        endSession()
        return true
    }

    func requestAdministratorRecovery() async -> Bool {
        let authorized = await Task.detached(priority: .userInitiated) {
            AdministratorRecovery.request()
        }.value
        guard authorized else { return false }
        history.insert(HistoryEntry(timestamp: Date(), website: "Administrator Recovery"), at: 0)
        endSession()
        return true
    }

    func clearHistory() {
        history.removeAll()
        syncAndPersist()
    }

    func setVoice(_ voice: String) {
        guard !isBlocking else { return }
        settings.voiceName = voice
        syncAndPersist()
    }

    func setVolume(_ volume: Int) {
        guard !isBlocking else { return }
        settings.volume = min(max(volume, 0), 100)
        syncAndPersist()
    }

    func testVoice() {
        let currentSettings = settings
        Task.detached {
            SpeechService.speak("This is your Hotblock focus voice.", settings: currentSettings)
        }
    }

    func requestAllBrowserPermissions() async {
        for browser in installedBrowsers {
            browserPermissions[browser] = .unknown
            let result = await Task.detached(priority: .utility) {
                BrowserAutomation.readActiveTab(in: browser)
            }.value
            browserPermissions[browser] = result.permission
        }
    }

    func requestNotificationPermission() async {
        notificationsAuthorized = await NotificationService.requestAuthorization()
    }

    func openAutomationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
        if let url {
            NSWorkspace.shared.open(url)
        }
    }

    func completeSetup() {
        guard canCompleteSetup else {
            showFeedback("Finish every setup step before continuing.")
            return
        }
        setupCompleted = true
        setupPresented = false
        syncAndPersist()
    }

    func showSetup() {
        setupPresented = true
    }

    func canQuitApp() -> Bool {
        !isBlocking
    }

    private func endSession() {
        isBlocking = false
        unlockAttempt = ""
        unlockError = ""
        unlockWords = []
        state.warningLevel = 0
        state.lastBlockedAttempt = nil
        monitoringTask?.cancel()
        monitoringTask = nil
        backgroundProtection.remove()
        syncAndPersist()
    }

    private func startMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = Task { [weak self] in
            while let self, !Task.isCancelled, self.isBlocking {
                await self.checkFrontmostBrowser()
                try? await Task.sleep(for: .milliseconds(700))
            }
        }
    }

    private func checkFrontmostBrowser() async {
        guard isBlocking, let browser = BrowserAutomation.frontmostBrowser() else {
            lastHandledHost = nil
            return
        }

        let read = await Task.detached(priority: .utility) {
            BrowserAutomation.readActiveTab(in: browser)
        }.value
        browserPermissions[browser] = read.permission

        guard read.permission == .authorized else {
            lastHandledHost = nil
            notifyRepeatedly(
                key: "permission-\(browser.rawValue)",
                title: "Hotblock needs browser permission",
                body: "Restore Automation permission for \(browser.displayName)."
            )
            return
        }

        guard let urlString = read.urlString,
              let host = BrowserAutomation.normalizedHost(from: urlString),
              let website = websites.first(where: { host == $0 || host.hasSuffix(".\($0)") })
        else {
            lastHandledHost = nil
            return
        }

        let closed = await Task.detached(priority: .userInitiated) {
            BrowserAutomation.closeActiveTab(in: browser)
        }.value

        guard closed else {
            notifyRepeatedly(
                key: "close-\(browser.rawValue)-\(website)",
                title: "Hotblock could not close a blocked tab",
                body: "Hotblock will keep trying to close \(website) in \(browser.displayName)."
            )
            return
        }

        guard lastHandledHost != host else { return }
        lastHandledHost = host
        recordBlockedAttempt(website)
    }

    private func recordBlockedAttempt(_ website: String) {
        let now = Date()
        if let lastAttempt = state.lastBlockedAttempt,
           now.timeIntervalSince(lastAttempt) >= 30 * 60 {
            state.warningLevel = 0
        }

        let message = Self.warningMessage(level: state.warningLevel, website: website)
        state.warningLevel = min(state.warningLevel + 1, 4)
        state.lastBlockedAttempt = now
        history.insert(HistoryEntry(timestamp: now, website: website), at: 0)
        syncAndPersist()

        let currentSettings = settings
        Task.detached {
            SpeechService.speak(message, settings: currentSettings)
        }
    }

    private func notifyRepeatedly(key: String, title: String, body: String) {
        let now = Date()
        if let previous = lastNotificationAt[key], now.timeIntervalSince(previous) < 8 {
            return
        }
        lastNotificationAt[key] = now
        NotificationService.send(title: title, body: body)
    }

    private func syncAndPersist() {
        state.websites = websites
        state.isBlocking = isBlocking
        state.unlockWords = unlockWords
        state.history = history
        state.settings = settings
        state.setupCompleted = setupCompleted
        persist()
    }

    private func persist() {
        persistence.save(state)
    }

    private func showFeedback(_ message: String) {
        feedbackTask?.cancel()
        feedback = message
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.feedback = ""
        }
    }

    nonisolated private static func normalizedDomain(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let components = URLComponents(string: candidate),
              var host = components.host?.lowercased()
        else {
            return nil
        }

        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }
        while host.hasSuffix(".") {
            host.removeLast()
        }

        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, labels.allSatisfy({ label in
            guard !label.isEmpty, label.count <= 63,
                  label.first != "-", label.last != "-"
            else {
                return false
            }
            return label.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
        }) else {
            return nil
        }
        return host
    }

    nonisolated private static func normalizeWords(_ text: String) -> String {
        text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    nonisolated private static func randomWords(count: Int) -> [String] {
        let pool = [
            "anchor", "planet", "copper", "forest", "window", "signal", "paper", "rocket",
            "harbor", "pencil", "velvet", "marble", "ticket", "button", "thunder", "orange",
            "ladder", "cactus", "stream", "mirror", "pepper", "castle", "candle", "galaxy",
            "ribbon", "island", "blanket", "meadow", "lantern", "silver", "pocket", "bridge",
            "summit", "garden", "compass", "coffee", "winter", "violet", "magnet", "parrot",
        ]
        return (0..<count).map { _ in pool.randomElement() ?? "focus" }
    }

    nonisolated private static func warningMessage(level: Int, website: String) -> String {
        let spokenWebsite = website
            .replacingOccurrences(of: ".", with: " dot ")
            .replacingOccurrences(of: "-", with: " ")
        switch level {
        case 0:
            return "Stop. You chose to focus, not visit \(spokenWebsite)."
        case 1:
            return "You are distracting yourself again. Get back to work."
        case 2:
            return "Close this nonsense. You know exactly what you should be doing."
        case 3:
            return "This is pathetic. Stop wasting your own time and focus."
        default:
            return "You are acting like a mindless doomscrolling robot. Get back to work now."
        }
    }
}
