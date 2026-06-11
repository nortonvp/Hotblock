import Foundation

enum SupportedBrowser: String, CaseIterable, Codable, Identifiable, Sendable {
    case safari
    case chrome
    case brave
    case arc

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .safari: "Safari"
        case .chrome: "Google Chrome"
        case .brave: "Brave Browser"
        case .arc: "Arc"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .safari: "com.apple.Safari"
        case .chrome: "com.google.Chrome"
        case .brave: "com.brave.Browser"
        case .arc: "company.thebrowser.Browser"
        }
    }
}

enum BrowserPermission: String, Codable, Sendable {
    case unknown
    case authorized
    case denied
    case unavailable
}

struct HotblockSettings: Codable, Equatable {
    var voiceName = "Samantha"
    var volume = 80
}

struct HistoryEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    let timestamp: Date
    let website: String
}

struct PersistedState: Codable {
    var websites: [String] = []
    var isBlocking = false
    var unlockWordCount = 3
    var unlockWords: [String] = []
    var history: [HistoryEntry] = []
    var settings = HotblockSettings()
    var setupCompleted = false
    var warningLevel = 0
    var lastBlockedAttempt: Date?
}

struct BrowserReadResult: Sendable {
    let urlString: String?
    let permission: BrowserPermission
}
