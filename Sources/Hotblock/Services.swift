import AppKit
import Foundation
import UserNotifications

enum BrowserAutomation {
    private struct ScriptResult: Sendable {
        let output: String
        let error: String
        let status: Int32
    }

    @MainActor
    static func installedBrowsers() -> [SupportedBrowser] {
        SupportedBrowser.allCases.filter {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleIdentifier) != nil
        }
    }

    @MainActor
    static func frontmostBrowser() -> SupportedBrowser? {
        guard let identifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return nil
        }
        return SupportedBrowser.allCases.first { $0.bundleIdentifier == identifier }
    }

    nonisolated static func readActiveTab(in browser: SupportedBrowser) -> BrowserReadResult {
        let script: String
        switch browser {
        case .safari:
            script = """
            tell application "Safari"
                if (count of windows) is 0 then return ""
                return URL of current tab of front window
            end tell
            """
        case .chrome, .brave, .arc:
            script = """
            tell application "\(browser.displayName)"
                if (count of windows) is 0 then return ""
                return URL of active tab of front window
            end tell
            """
        }

        let result = runAppleScript(script)
        if result.status == 0 {
            return BrowserReadResult(
                urlString: result.output.isEmpty ? nil : result.output,
                permission: .authorized
            )
        }

        let denied = result.error.contains("Not authorized to send Apple events")
            || result.error.contains("-1743")
            || result.error.contains("1002")
        return BrowserReadResult(urlString: nil, permission: denied ? .denied : .unavailable)
    }

    nonisolated static func checkPermission(for browser: SupportedBrowser) -> BrowserPermission {
        let script = """
        tell application "\(browser.displayName)"
            return name
        end tell
        """
        let result = runAppleScript(script)
        if result.status == 0 {
            return .authorized
        }
        return isPermissionDenied(result.error) ? .denied : .unavailable
    }

    nonisolated static func closeActiveTab(in browser: SupportedBrowser) -> Bool {
        let script: String
        switch browser {
        case .safari:
            script = """
            tell application "Safari"
                if (count of windows) is 0 then return "missing"
                close current tab of front window
                return "closed"
            end tell
            """
        case .chrome, .brave, .arc:
            script = """
            tell application "\(browser.displayName)"
                if (count of windows) is 0 then return "missing"
                close active tab of front window
                return "closed"
            end tell
            """
        }
        let result = runAppleScript(script)
        return result.status == 0 && result.output == "closed"
    }

    nonisolated static func normalizedHost(from urlString: String) -> String? {
        guard let url = URL(string: urlString), var host = url.host?.lowercased() else {
            return nil
        }
        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }
        return host
    }

    nonisolated private static func isPermissionDenied(_ error: String) -> Bool {
        error.contains("Not authorized to send Apple events")
            || error.contains("-1743")
            || error.contains("1002")
    }

    nonisolated private static func runAppleScript(_ script: String) -> ScriptResult {
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
            return ScriptResult(output: "", error: error.localizedDescription, status: -1)
        }

        let output = String(
            data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let error = String(
            data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ScriptResult(output: output, error: error, status: process.terminationStatus)
    }
}

enum SpeechService {
    nonisolated static func englishVoices() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = ["-v", "?"]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        guard (try? process.run()) != nil else {
            return ["Samantha"]
        }
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let voices = output.split(separator: "\n").compactMap { line -> String? in
            guard line.contains("en_") || line.contains("en-") else { return nil }
            return line.split(whereSeparator: \.isWhitespace).first.map(String.init)
        }
        return Array(Set(voices)).sorted()
    }

    nonisolated static func speak(_ message: String, settings: HotblockSettings) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        let volume = Double(min(max(settings.volume, 0), 100)) / 100
        process.arguments = ["-v", settings.voiceName, "[[volm \(volume)]] \(message)"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
    }
}

enum NotificationService {
    static func requestAuthorization() async -> Bool {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        return await isAuthorized()
    }

    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    nonisolated static func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

enum AdministratorRecovery {
    nonisolated static func request() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "do shell script \"true\" with administrator privileges"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}

struct BackgroundProtection {
    private let label = "com.nortonvp.hotblock.keepalive"
    private let fileName = "com.nortonvp.hotblock.keepalive.plist"

    var isAvailable: Bool {
        Bundle.main.url(forResource: "hotblock-watchdog", withExtension: "sh") != nil
    }

    func install() -> Bool {
        guard let executablePath = Bundle.main.executableURL?.path,
              let scriptPath = Bundle.main.url(forResource: "hotblock-watchdog", withExtension: "sh")?.path
        else {
            return false
        }

        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        let plistURL = directory.appendingPathComponent(fileName)
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/bin/zsh", scriptPath, executablePath, "com.nortonvp.hotblock"],
            "RunAtLoad": true,
            "KeepAlive": true,
            "LimitLoadToSessionType": "Aqua",
        ]

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)
            runLaunchctl(["bootout", "gui/\(getuid())/\(label)"])
            let bootstrapped = runLaunchctl(["bootstrap", "gui/\(getuid())", plistURL.path])
            let started = runLaunchctl(["kickstart", "-k", "gui/\(getuid())/\(label)"])
            return bootstrapped && started
        } catch {
            return false
        }
    }

    func remove() {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent(fileName)
        runLaunchctl(["bootout", "gui/\(getuid())/\(label)"])
        try? FileManager.default.removeItem(at: url)
    }

    @discardableResult
    private func runLaunchctl(_ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
