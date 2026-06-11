import AppKit
import AVFAudio
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

@MainActor
final class SpeechService {
    static let shared = SpeechService()
    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    nonisolated static func englishVoices() -> [SpeechVoiceOption] {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .filter(Self.isNaturalVoice)
            .sorted { lhs, rhs in
                let leftPriority = Self.voicePriority(lhs)
                let rightPriority = Self.voicePriority(rhs)
                if leftPriority != rightPriority {
                    return leftPriority < rightPriority
                }
                if lhs.language != rhs.language {
                    return lhs.language < rhs.language
                }
                return lhs.name < rhs.name
            }
            .map {
                SpeechVoiceOption(id: $0.identifier, name: $0.name, languageCode: $0.language)
            }

        if !voices.isEmpty {
            return Array(voices.prefix(2))
        }

        return [
            SpeechVoiceOption(
                id: "com.apple.voice.compact.en-US.Samantha",
                name: "Samantha",
                languageCode: "en-US"
            ),
            SpeechVoiceOption(
                id: "com.apple.voice.compact.en-GB.Daniel",
                name: "Daniel",
                languageCode: "en-GB"
            ),
        ]
    }

    nonisolated static func displayName(for voiceID: String, in options: [SpeechVoiceOption]) -> String {
        options.first(where: { $0.id == voiceID })?.displayName ?? voiceID
    }

    nonisolated static func resolvedVoiceOption(
        for settings: HotblockSettings,
        in options: [SpeechVoiceOption]
    ) -> SpeechVoiceOption? {
        if let voiceIdentifier = settings.voiceIdentifier,
           let option = options.first(where: { $0.id == voiceIdentifier }) {
            return option
        }

        if let option = options.first(where: { $0.name == settings.voiceName }) {
            return option
        }

        return options.first
    }

    nonisolated private static func isNaturalVoice(_ voice: AVSpeechSynthesisVoice) -> Bool {
        let noveltyNames: Set<String> = [
            "Albert", "Bad News", "Bahh", "Bells", "Boing", "Bubbles", "Cellos",
            "Fred", "Good News", "Jester", "Junior", "Kathy", "Organ", "Ralph",
            "Superstar", "Trinoids", "Whisper", "Wobble", "Zarvox",
        ]

        if voice.identifier.contains(".eloquence.") {
            return false
        }

        if noveltyNames.contains(voice.name) {
            return false
        }

        if #available(macOS 14.0, *),
           voice.voiceTraits.contains(.isNoveltyVoice) {
            return false
        }

        return true
    }

    nonisolated private static func voicePriority(_ voice: AVSpeechSynthesisVoice) -> Int {
        let preferredOrder = [
            "Nicky", "Aaron", "Martha", "Arthur", "Catherine", "Gordon",
            "Samantha", "Daniel", "Karen", "Moira", "Rishi", "Tessa",
        ]

        if let index = preferredOrder.firstIndex(of: voice.name) {
            return index
        }

        if voice.identifier.contains("siri_") {
            return preferredOrder.count + 20
        }

        return preferredOrder.count + 100
    }

    private enum SpeechStyle {
        case preview
        case warning(level: Int)
    }

    private struct SpeechSegment {
        let text: String
        let rate: Float
        let pitch: Float
        let preDelay: TimeInterval
        let postDelay: TimeInterval
    }

    private struct SpeechProfile {
        let baseRate: Float
        let basePitch: Float
        let initialDelay: TimeInterval
        let sentencePause: TimeInterval
    }

    private static func profile(for style: SpeechStyle) -> SpeechProfile {
        switch style {
        case .preview:
            return SpeechProfile(
                baseRate: 0.47,
                basePitch: 1.01,
                initialDelay: 0.02,
                sentencePause: 0.18
            )
        case .warning(let level):
            let clampedLevel = min(max(level, 0), 4)
            return SpeechProfile(
                baseRate: max(0.39, 0.45 - (Float(clampedLevel) * 0.015)),
                basePitch: max(0.88, 0.97 - (Float(clampedLevel) * 0.02)),
                initialDelay: 0,
                sentencePause: 0.24 + (Double(clampedLevel) * 0.03)
            )
        }
    }

    private static func makeSegments(from message: String, style: SpeechStyle) -> [SpeechSegment] {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let profile = profile(for: style)
        let sentences = sentenceSplit(for: trimmed)

        return sentences.enumerated().map { index, sentence in
            let punctuation = sentence.last
            let isShortCommand = sentence.split(whereSeparator: \.isWhitespace).count <= 3
            let isQuestion = punctuation == "?"
            let rateAdjustment = isShortCommand ? -0.03 : min(Float(sentence.count) * 0.0007, 0.03)
            let pitchAdjustment: Float = isQuestion ? 0.04 : (isShortCommand ? -0.04 : 0)
            let pauseAdjustment: TimeInterval

            switch punctuation {
            case ",":
                pauseAdjustment = 0.12
            case "!", "?":
                pauseAdjustment = 0.28
            default:
                pauseAdjustment = 0.2
            }

            return SpeechSegment(
                text: sentence,
                rate: min(max(profile.baseRate + rateAdjustment, 0.37), 0.52),
                pitch: min(max(profile.basePitch + pitchAdjustment, 0.84), 1.08),
                preDelay: index == 0 ? profile.initialDelay : 0,
                postDelay: profile.sentencePause + pauseAdjustment
            )
        }
    }

    private static func sentenceSplit(for message: String) -> [String] {
        let nsMessage = message as NSString
        var sentences: [String] = []

        nsMessage.enumerateSubstrings(
            in: NSRange(location: 0, length: nsMessage.length),
            options: [.bySentences, .localized]
        ) { _, range, _, _ in
            let sentence = nsMessage.substring(with: range)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
        }

        return sentences.isEmpty ? [message] : sentences
    }

    private static func voice(for settings: HotblockSettings) -> AVSpeechSynthesisVoice? {
        if let voiceIdentifier = settings.voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            return voice
        }

        if let matchedVoice = AVSpeechSynthesisVoice.speechVoices().first(where: {
            $0.name == settings.voiceName && $0.language.hasPrefix("en")
        }) {
            return matchedVoice
        }

        return AVSpeechSynthesisVoice(language: "en-US")
    }

    func preview(settings: HotblockSettings) {
        speak(
            "Right. You wanted focus. So let's get back to the thing that matters.",
            settings: settings,
            style: .preview
        )
    }

    func speakWarning(_ message: String, level: Int, settings: HotblockSettings) {
        speak(message, settings: settings, style: .warning(level: level))
    }

    private func speak(_ message: String, settings: HotblockSettings, style: SpeechStyle) {
        _ = synthesizer.stopSpeaking(at: .immediate)

        let voice = Self.voice(for: settings)
        let volume = Float(min(max(settings.volume, 0), 100)) / 100
        let segments = Self.makeSegments(from: message, style: style)

        for segment in segments {
            let utterance = AVSpeechUtterance(string: segment.text)
            utterance.voice = voice
            utterance.volume = volume
            utterance.rate = segment.rate
            utterance.pitchMultiplier = segment.pitch
            utterance.preUtteranceDelay = segment.preDelay
            utterance.postUtteranceDelay = segment.postDelay
            utterance.prefersAssistiveTechnologySettings = false
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        _ = synthesizer.stopSpeaking(at: .immediate)
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

struct BackgroundProtection: Sendable {
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
