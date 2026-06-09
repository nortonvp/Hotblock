# Hotblock Architecture

The current Swift Package is a functional prototype organized around small,
replaceable components:

- `HotblockModel` owns UI state and strict-session rules.
- `PersistenceStore` migrates legacy defaults and persists the complete state.
- `BrowserAutomation` detects, reads, and closes supported browser tabs.
- `MonitoringService` polls the frontmost browser and reports blocked attempts.
- `SpeechService` plays English spoken warnings.
- `NotificationService` reports permission and enforcement failures.
- `BackgroundProtection` installs the temporary user LaunchAgent watchdog.
- `HotblockAppDelegate` owns exactly one AppKit window and one status item.

The production architecture and its signing requirements are defined in
`PRODUCT_SPEC.md`. The LaunchAgent and AppleScript adapters are intentionally
isolated so they can be replaced by a privileged helper and browser extensions
without rewriting the domain model or interface.
