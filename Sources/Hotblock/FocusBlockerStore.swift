import AppKit
import Foundation
import ServiceManagement

@MainActor
final class FocusBlockerStore: ObservableObject {
    static let shared = FocusBlockerStore()

    private struct BrowserFetchResult {
        let urlString: String?
        let permissionDenied: Bool
    }

    private enum StorageKey {
        static let websites = "hotblock.websites"
        static let isBlocking = "hotblock.isBlocking"
        static let unlockWordCount = "hotblock.unlockWordCount"
        static let unlockWords = "hotblock.unlockWords"
        static let didPromptLoginItemApproval = "hotblock.didPromptLoginItemApproval"
    }

    private enum LaunchAgent {
        static let label = "com.nortonvp.hotblock.keepalive"
        static let fileName = "com.nortonvp.hotblock.keepalive.plist"
        static let backgroundArgument = "--background"
    }

    @Published var draftWebsite = ""
    @Published private(set) var websites: [String] = []
    @Published private(set) var isBlocking = false
    @Published private(set) var statusMessage = "Add a website, then press Start."
    @Published private(set) var lastInterceptedWebsite: String?
    @Published private(set) var availableBrowsers: [String] = []
    @Published var pendingUnlockWordCount = 3
    @Published var unlockAttempt = ""
    @Published private(set) var unlockWords: [String] = []
    @Published private(set) var unlockErrorMessage = ""

    private var pollTask: Task<Void, Never>?
    private var currentlyWarnedWebsite: String?
    private var didRequestLaunchPermission = false
    private var didConfigureLaunchAtLogin = false
    private let defaults = UserDefaults.standard

    private init() {
        availableBrowsers = Self.detectInstalledBrowsers()
        websites = defaults.stringArray(forKey: StorageKey.websites) ?? []
        isBlocking = defaults.bool(forKey: StorageKey.isBlocking)
        if defaults.object(forKey: StorageKey.unlockWordCount) == nil {
            pendingUnlockWordCount = 3
        } else {
            pendingUnlockWordCount = min(max(defaults.integer(forKey: StorageKey.unlockWordCount), 0), 100)
        }
        unlockWords = defaults.stringArray(forKey: StorageKey.unlockWords) ?? []

        if isBlocking && unlockWords.isEmpty {
            unlockWords = Self.randomWords(count: pendingUnlockWordCount)
            persistUnlockSettings()
        }
    }

    func requestAutomationPermissionOnLaunch() async {
        guard !didRequestLaunchPermission else { return }
        didRequestLaunchPermission = true

        if isBlocking, !websites.isEmpty {
            installKeepAliveLaunchAgent()
        }

        guard let browserName = Self.preferredBrowserForPermissionRequest() else {
            statusMessage = "No supported browser found for Automation permission."
            return
        }

        statusMessage = "Requesting macOS Automation permission for \(browserName)..."

        let fetchResult = await Task.detached(priority: .utility) {
            Self.fetchActiveTabURL(for: browserName)
        }.value

        if fetchResult.permissionDenied {
            statusMessage = "Automation permission was denied for \(browserName)."
            return
        }

        if isBlocking, !websites.isEmpty {
            statusMessage = "Blocking is active. Watching Safari and Chrome tabs."
            startMonitoring()
            return
        }

        statusMessage = "Automation check completed for \(browserName). Add a website, then press Start."
    }

    func configureLaunchAtLogin() {
        guard !didConfigureLaunchAtLogin else { return }
        didConfigureLaunchAtLogin = true

        do {
            try SMAppService.mainApp.register()

            if SMAppService.mainApp.status == .requiresApproval,
               !defaults.bool(forKey: StorageKey.didPromptLoginItemApproval) {
                defaults.set(true, forKey: StorageKey.didPromptLoginItemApproval)
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch {
            return
        }
    }

    func canQuitApp() -> Bool {
        !isBlocking
    }

    func addWebsite() {
        let normalized = normalizeWebsite(draftWebsite)

        guard !normalized.isEmpty else {
            statusMessage = "Enter a website like instagram.com."
            return
        }

        guard !websites.contains(normalized) else {
            statusMessage = "\(normalized) is already on your list."
            draftWebsite = ""
            return
        }

        websites.append(normalized)
        persistWebsites()
        draftWebsite = ""
        statusMessage = "\(normalized) added to your focus list."
    }

    func removeWebsite(_ website: String) {
        websites.removeAll { $0 == website }
        persistWebsites()
        if lastInterceptedWebsite == website {
            lastInterceptedWebsite = nil
        }
        statusMessage = "\(website) removed."

        if websites.isEmpty {
            isBlocking = false
            persistBlockingState()
            statusMessage = "Your list is empty. Add a website to start blocking."
        }
    }

    func startBlocking() {
        guard !websites.isEmpty else {
            statusMessage = "Add at least one website before you start."
            return
        }

        unlockWords = pendingUnlockWordCount == 0 ? [] : Self.randomWords(count: pendingUnlockWordCount)
        unlockAttempt = ""
        unlockErrorMessage = ""
        isBlocking = true
        persistBlockingState()
        persistUnlockSettings()
        installKeepAliveLaunchAgent()
        statusMessage = "Blocking is active. Watching Safari and Chrome tabs."
        startMonitoring()
    }

    func stopBlocking() {
        isBlocking = false
        persistBlockingState()
        removeKeepAliveLaunchAgent()
        unlockAttempt = ""
        unlockErrorMessage = ""
        currentlyWarnedWebsite = nil
        pollTask?.cancel()
        pollTask = nil
        statusMessage = "Blocking is off."
    }

    func prepareToStopBlocking() {
        if pendingUnlockWordCount == 0 {
            stopBlocking()
            return
        }

        unlockAttempt = ""
        unlockErrorMessage = ""
    }

    func requiresUnlockChallenge() -> Bool {
        !unlockWords.isEmpty
    }

    func submitUnlockAttempt() -> Bool {
        let normalizedAttempt = Self.normalizeWords(unlockAttempt)
        let expected = unlockWords.joined(separator: " ")

        guard normalizedAttempt == expected else {
            unlockErrorMessage = "The words do not match."
            return false
        }

        stopBlocking()
        return true
    }

    func simulateVisit(_ website: String) {
        guard isBlocking else {
            statusMessage = "Press Start before testing a blocked website."
            return
        }

        lastInterceptedWebsite = website
        statusMessage = "Blocked visit intercepted: \(website)"

        let spokenWebsite = website
            .replacingOccurrences(of: ".", with: " dot ")
            .replacingOccurrences(of: "-", with: " ")

        speak("You should be focusing, not getting distracted by \(spokenWebsite).")
    }

    private func speak(_ message: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = ["-v", preferredVoiceName(), message]

        do {
            try process.run()
        } catch {
            statusMessage = "Voice warning failed to play."
        }
    }

    private func preferredVoiceName() -> String {
        let installedVoices = Self.installedVoiceNames()
        let preferredVoices = ["Daniel", "Karen", "Samantha", "Alex"]

        for voice in preferredVoices where installedVoices.contains(voice) {
            return voice
        }

        return "Daniel"
    }

    private func persistWebsites() {
        defaults.set(websites, forKey: StorageKey.websites)
    }

    private func persistBlockingState() {
        defaults.set(isBlocking, forKey: StorageKey.isBlocking)
    }

    private func persistUnlockSettings() {
        defaults.set(pendingUnlockWordCount, forKey: StorageKey.unlockWordCount)
        defaults.set(unlockWords, forKey: StorageKey.unlockWords)
    }

    private func installKeepAliveLaunchAgent() {
        guard let executablePath = Bundle.main.executableURL?.path else {
            return
        }
        guard let bundlePath = Bundle.main.bundleURL.path.removingPercentEncoding else {
            return
        }
        let scriptPath = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("scripts/hotblock-watchdog.sh")
            .path

        let launchAgentsDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        let plistURL = launchAgentsDirectory.appendingPathComponent(LaunchAgent.fileName)

        let plist: [String: Any] = [
            "Label": LaunchAgent.label,
            "ProgramArguments": ["/bin/zsh", scriptPath, bundlePath, executablePath, "com.nortonvp.hotblock"],
            "RunAtLoad": true,
            "KeepAlive": true,
            "LimitLoadToSessionType": "Aqua",
        ]

        do {
            try FileManager.default.createDirectory(at: launchAgentsDirectory, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)
            Self.runLaunchctl(arguments: ["bootout", "gui/\(getuid())", LaunchAgent.label])
            Self.runLaunchctl(arguments: ["bootstrap", "gui/\(getuid())", plistURL.path])
            Self.runLaunchctl(arguments: ["kickstart", "-k", "gui/\(getuid())/\(LaunchAgent.label)"])
        } catch {
            statusMessage = "Could not install background relaunch protection."
        }
    }

    private func removeKeepAliveLaunchAgent() {
        let launchAgentsDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        let plistURL = launchAgentsDirectory.appendingPathComponent(LaunchAgent.fileName)

        Self.runLaunchctl(arguments: ["bootout", "gui/\(getuid())", LaunchAgent.label])
        try? FileManager.default.removeItem(at: plistURL)
    }

    private func startMonitoring() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.checkCurrentWebsite()
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    private func checkCurrentWebsite() async {
        guard isBlocking else { return }

        guard let browserName = Self.frontmostSupportedBrowserName() else {
            currentlyWarnedWebsite = nil
            return
        }

        let fetchResult = await Task.detached(priority: .utility) {
            Self.fetchActiveTabURL(for: browserName)
        }.value

        if fetchResult.permissionDenied {
            statusMessage = "Hotblock needs macOS Automation permission to read the \(browserName) tab."
            currentlyWarnedWebsite = nil
            return
        }

        guard
            let urlString = fetchResult.urlString,
            let host = Self.normalizedHost(from: urlString)
        else {
            currentlyWarnedWebsite = nil
            return
        }

        guard let matchedWebsite = websites.first(where: { host == $0 || host.hasSuffix(".\($0)") }) else {
            currentlyWarnedWebsite = nil
            return
        }

        guard currentlyWarnedWebsite != matchedWebsite else {
            return
        }

        currentlyWarnedWebsite = matchedWebsite
        lastInterceptedWebsite = matchedWebsite
        statusMessage = "Blocked visit intercepted automatically: \(matchedWebsite)"

        let spokenWebsite = matchedWebsite
            .replacingOccurrences(of: ".", with: " dot ")
            .replacingOccurrences(of: "-", with: " ")

        speak("You should be focusing, not getting distracted by \(spokenWebsite).")
        await Task.detached(priority: .utility) {
            Self.closeActiveTab(for: browserName)
        }.value
    }

    private func normalizeWebsite(_ website: String) -> String {
        var normalized = website
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        normalized = normalized.replacingOccurrences(of: "https://", with: "")
        normalized = normalized.replacingOccurrences(of: "http://", with: "")
        normalized = normalized.replacingOccurrences(of: "www.", with: "")

        if let slashIndex = normalized.firstIndex(of: "/") {
            normalized = String(normalized[..<slashIndex])
        }

        return normalized
    }

    nonisolated private static func frontmostSupportedBrowserName() -> String? {
        let name = NSWorkspace.shared.frontmostApplication?.localizedName

        switch name {
        case "Safari", "Google Chrome", "Brave Browser", "Arc":
            return name
        default:
            return nil
        }
    }

    nonisolated private static func preferredBrowserForPermissionRequest() -> String? {
        if let frontmost = frontmostSupportedBrowserName() {
            return frontmost
        }

        return detectInstalledBrowsers().first
    }

    nonisolated private static func isBrowserInstalled(named browserName: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier(for: browserName)) != nil
    }

    nonisolated private static func detectInstalledBrowsers() -> [String] {
        ["Safari", "Google Chrome", "Brave Browser", "Arc"]
            .filter(isBrowserInstalled(named:))
    }

    nonisolated private static func bundleIdentifier(for browserName: String) -> String {
        switch browserName {
        case "Safari":
            return "com.apple.Safari"
        case "Google Chrome":
            return "com.google.Chrome"
        case "Brave Browser":
            return "com.brave.Browser"
        case "Arc":
            return "company.thebrowser.Browser"
        default:
            return ""
        }
    }

    nonisolated private static func fetchActiveTabURL(for browserName: String) -> BrowserFetchResult {
        let script: String

        switch browserName {
        case "Safari":
            script = """
            tell application "Safari"
                if (count of windows) is 0 then return ""
                return URL of current tab of front window
            end tell
            """
        case "Google Chrome", "Brave Browser", "Arc":
            script = """
            tell application "\(browserName)"
                if (count of windows) is 0 then return ""
                return URL of active tab of front window
            end tell
            """
        default:
            return BrowserFetchResult(urlString: nil, permissionDenied: false)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return BrowserFetchResult(urlString: nil, permissionDenied: false)
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = String(data: errorData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            let permissionDenied =
                errorOutput.contains("Not authorized to send Apple events") ||
                errorOutput.contains("1743")
            return BrowserFetchResult(urlString: nil, permissionDenied: permissionDenied)
        }

        return BrowserFetchResult(
            urlString: output?.isEmpty == false ? output : nil,
            permissionDenied: false
        )
    }

    nonisolated private static func normalizedHost(from urlString: String) -> String? {
        guard let url = URL(string: urlString), let host = url.host?.lowercased() else {
            return nil
        }

        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }

        return host
    }

    nonisolated private static func closeActiveTab(for browserName: String) {
        let script: String

        switch browserName {
        case "Safari":
            script = """
            tell application "Safari"
                if (count of windows) is 0 then return
                close current tab of front window
            end tell
            """
        case "Google Chrome", "Brave Browser", "Arc":
            script = """
            tell application "\(browserName)"
                if (count of windows) is 0 then return
                close active tab of front window
            end tell
            """
        default:
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try? process.run()
        process.waitUntilExit()
    }

    nonisolated private static func installedVoiceNames() -> Set<String> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = ["-v", "?"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return []
        }

        let voices = output
            .split(separator: "\n")
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard let firstPart = trimmed.split(separator: " ").first else {
                    return nil
                }
                return String(firstPart)
            }

        return Set(voices)
    }

    nonisolated private static func runLaunchctl(arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try? process.run()
        process.waitUntilExit()
    }

    nonisolated private static func randomWords(count: Int) -> [String] {
        let pool = [
            "anchor", "planet", "copper", "forest", "window", "signal", "paper", "rocket",
            "harbor", "pencil", "velvet", "marble", "ticket", "button", "thunder", "orange",
            "ladder", "cactus", "stream", "mirror", "pepper", "castle", "candle", "galaxy",
            "ribbon", "island", "blanket", "meadow", "lantern", "silver", "pocket", "bridge"
        ]

        return Array(pool.shuffled().prefix(max(count, 1)))
    }

    nonisolated private static func normalizeWords(_ text: String) -> String {
        text
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
