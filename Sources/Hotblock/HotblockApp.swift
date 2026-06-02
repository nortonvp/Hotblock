import SwiftUI

final class HotblockAppDelegate: NSObject, NSApplicationDelegate {
    private static let showWindowNotification = Notification.Name("com.nortonvp.hotblock.showMainWindow")
    private var launchedInBackground = CommandLine.arguments.contains("--background")
    private var allowsImmediateTermination = false
    private var statusItem: NSStatusItem?

    @MainActor
    static func showMainWindow() {
        ensureSingleMainWindow()
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)

        guard let window = NSApp.windows.first else { return }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.orderFrontRegardless()
        window.makeKey()
    }

    @MainActor
    static func ensureSingleMainWindow() {
        let windows = NSApp.windows
        guard windows.count > 1 else { return }

        for window in windows.dropFirst() {
            window.close()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleShowWindowNotification),
            name: Self.showWindowNotification,
            object: nil
        )

        if shouldHandOffToExistingInstance() {
            allowsImmediateTermination = true
            DistributedNotificationCenter.default().post(name: Self.showWindowNotification, object: nil)
            NSApp.terminate(nil)
            return
        }
        DispatchQueue.main.async {
            HotblockAppDelegate.ensureSingleMainWindow()

            if self.launchedInBackground {
                NSApp.windows.forEach { $0.orderOut(nil) }
            } else {
                HotblockAppDelegate.showMainWindow()
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if allowsImmediateTermination {
            return .terminateNow
        }

        guard FocusBlockerStore.shared.canQuitApp() else {
            NSApp.activate(ignoringOtherApps: true)
            return .terminateCancel
        }

        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        HotblockAppDelegate.showMainWindow()
        return true
    }

    @MainActor
    @objc
    private func handleShowWindowNotification() {
        HotblockAppDelegate.showMainWindow()
    }

    private func shouldHandOffToExistingInstance() -> Bool {
        if launchedInBackground {
            return false
        }

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return false
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != currentPID }

        guard !runningApps.isEmpty else {
            return false
        }

        return runningApps.contains { _ in true }
    }

    @MainActor
    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "shield", accessibilityDescription: "Hotblock")
            button.imagePosition = .imageOnly
        }

        let menu = NSMenu()
        menu.addItem(
            withTitle: "Open Hotblock",
            action: #selector(openHotblockFromMenuBar),
            keyEquivalent: ""
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Hotblock",
            action: #selector(quitHotblockFromMenuBar),
            keyEquivalent: ""
        )

        menu.items.forEach { $0.target = self }
        item.menu = menu
    }

    @MainActor
    @objc
    private func openHotblockFromMenuBar() {
        DispatchQueue.main.async {
            HotblockAppDelegate.showMainWindow()
        }
    }

    @MainActor
    @objc
    private func quitHotblockFromMenuBar() {
        NSApp.terminate(nil)
    }
}

@main
struct HotblockApp: App {
    @NSApplicationDelegateAdaptor(HotblockAppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Hotblock", id: "main") {
            ContentView()
        }
        .defaultSize(width: 560, height: 420)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
