import AppKit
import SwiftUI

@MainActor
final class HotblockAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let showWindowNotification = Notification.Name("com.nortonvp.hotblock.showMainWindow")
    private let model = HotblockModel.shared
    private var mainWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var statusMenuItem: NSMenuItem?
    private var quitMenuItem: NSMenuItem?
    private var allowsImmediateTermination = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleShowWindowNotification),
            name: Self.showWindowNotification,
            object: nil
        )

        if handOffToExistingInstance() {
            allowsImmediateTermination = true
            DistributedNotificationCenter.default().post(name: Self.showWindowNotification, object: nil)
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        showMainWindow()

        Task {
            await model.bootstrap()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if allowsImmediateTermination {
            return .terminateNow
        }
        return model.canQuitApp() ? .terminateNow : .terminateCancel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func menuWillOpen(_ menu: NSMenu) {
        statusMenuItem?.title = model.isBlocking ? "Blocking active" : "Blocking inactive"
        quitMenuItem?.isEnabled = !model.isBlocking
    }

    @objc
    private func showMainWindow() {
        let window = mainWindow ?? makeMainWindow()
        mainWindow = window

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    @objc
    private func handleShowWindowNotification(_ notification: Notification) {
        showMainWindow()
    }

    @objc
    private func quitHotblock() {
        guard model.canQuitApp() else { return }
        NSApp.terminate(nil)
    }

    private func makeMainWindow() -> NSWindow {
        let controller = NSHostingController(rootView: ContentView(model: model))
        let window = NSWindow(contentViewController: controller)
        window.title = "Hotblock"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 520, height: 430))
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item

        let image = NSImage(systemSymbolName: "shield", accessibilityDescription: "Hotblock")
        image?.isTemplate = true
        item.button?.image = image
        item.button?.toolTip = "Hotblock"

        let menu = NSMenu()
        menu.delegate = self
        let open = NSMenuItem(title: "Open Hotblock", action: #selector(showMainWindow), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        let status = NSMenuItem(title: "Blocking inactive", action: nil, keyEquivalent: "")
        status.isEnabled = false
        statusMenuItem = status
        menu.addItem(status)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Hotblock", action: #selector(quitHotblock), keyEquivalent: "q")
        quit.target = self
        quitMenuItem = quit
        menu.addItem(quit)
        item.menu = menu
    }

    private func handOffToExistingInstance() -> Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return false
        }
        let currentPID = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .contains { $0.processIdentifier != currentPID }
    }
}

@main
struct HotblockApp: App {
    @NSApplicationDelegateAdaptor(HotblockAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
