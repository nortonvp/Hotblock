import Sliders
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: HotblockModel
    @State private var showingStart = false
    @State private var showingUnlock = false
    @State private var showingHistory = false
    @State private var showingSettings = false
    @State private var selectedPreset: WebsitePreset?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Hotblock")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    showingHistory = true
                } label: {
                    Image(systemName: "clock")
                }
                .help("History")

                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
            }

            HStack {
                TextField("instagram.com", text: $model.draftWebsite)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        model.addWebsite()
                    }

                Button("Add") {
                    model.addWebsite()
                }
                .keyboardShortcut(.defaultAction)

                Menu {
                    ForEach(WebsitePreset.allCases) { preset in
                        Button {
                            selectedPreset = preset
                        } label: {
                            Label(
                                "\(preset.rawValue) (\(preset.websites.count))",
                                systemImage: preset.systemImage
                            )
                        }
                    }
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .frame(width: 16, height: 16)
                        .padding(.horizontal, 8)
                }
                .menuIndicator(.hidden)
                .controlSize(.regular)
                .help("Presets: add a built-in group of websites")
            }

            if !model.feedback.isEmpty {
                Text(model.feedback)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GroupBox("Blocked Websites") {
                if model.websites.isEmpty {
                    Text("No websites added.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(model.websites, id: \.self) { website in
                        HStack {
                            Text(website)
                            Spacer()
                            Button {
                                model.removeWebsite(website)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .disabled(model.isBlocking)
                            .help(model.isBlocking ? "Websites cannot be removed during a strict session" : "Remove")
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)

            HStack {
                Spacer()
                Button(model.isBlocking ? "Stop" : "Start") {
                    if model.isBlocking {
                        showingUnlock = true
                    } else if model.canStartStrictSession {
                        showingStart = true
                    } else {
                        model.showSetup()
                    }
                }
            }
        }
        .padding(18)
        .frame(width: 520, height: 430)
        .sheet(isPresented: $showingStart) {
            StartSessionView(model: model, isPresented: $showingStart)
        }
        .sheet(isPresented: $showingUnlock) {
            UnlockView(model: model, isPresented: $showingUnlock)
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView(model: model)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(model: model)
        }
        .sheet(isPresented: $model.setupPresented) {
            SetupAssistantView(model: model)
        }
        .sheet(item: $selectedPreset) { preset in
            PresetConfirmationView(model: model, preset: preset)
        }
    }
}

private struct PresetConfirmationView: View {
    @ObservedObject var model: HotblockModel
    let preset: WebsitePreset
    @Environment(\.dismiss) private var dismiss
    @State private var selectedWebsites: Set<String>

    init(model: HotblockModel, preset: WebsitePreset) {
        self.model = model
        self.preset = preset
        _selectedWebsites = State(initialValue: Set(preset.websites))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("\(preset.rawValue) Preset", systemImage: preset.systemImage)
                .font(.headline)

            Text("Choose from \(preset.websites.count) websites to add to your blocked list.")
                .foregroundStyle(.secondary)

            HStack {
                Button("Select All") {
                    selectedWebsites = Set(preset.websites)
                }
                Button("Deselect All") {
                    selectedWebsites.removeAll()
                }
                Spacer()
                Text("\(selectedWebsites.count) selected")
                    .foregroundStyle(.secondary)
            }

            List(preset.websites, id: \.self) { website in
                Toggle(
                    website,
                    isOn: Binding(
                        get: { selectedWebsites.contains(website) },
                        set: { isSelected in
                            if isSelected {
                                selectedWebsites.insert(website)
                            } else {
                                selectedWebsites.remove(website)
                            }
                        }
                    )
                )
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Add Selected") {
                    model.addWebsites(selectedWebsites)
                    dismiss()
                }
                .disabled(selectedWebsites.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460, height: 520)
    }
}

private struct StartSessionView: View {
    @ObservedObject var model: HotblockModel
    @Binding var isPresented: Bool
    @State private var wordCount: Int

    init(model: HotblockModel, isPresented: Binding<Bool>) {
        self.model = model
        _isPresented = isPresented
        _wordCount = State(initialValue: model.unlockWordCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Start Strict Session")
                .font(.headline)

            Text("Choose how many random words you must type to stop blocking.")
                .foregroundStyle(.secondary)

            HotblockSliderCard(
                title: "Unlock challenge",
                icon: "text.badge.plus",
                accent: .red,
                minimumLabel: "1",
                maximumLabel: "300",
                accessibilityLabel: "Unlock challenge word count",
                valueText: "\(wordCount) words",
                value: $wordCount,
                range: 1...300,
                step: 1
            )

            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                Button("Start") {
                    model.startBlocking(unlockWordCount: wordCount)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

private struct HotblockSliderCard: View {
    let title: String
    let icon: String
    let accent: Color
    let minimumLabel: String
    let maximumLabel: String
    let accessibilityLabel: String
    let valueText: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    var isEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(accent)
                Text(title)
                    .fontWeight(.medium)
                Spacer()
                Text(valueText)
                    .font(.caption.monospacedDigit())
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accent.opacity(0.14), in: Capsule())
            }

            ValueSlider(
                value: $value,
                in: range,
                step: step
            )
            .valueSliderStyle(
                HorizontalValueSliderStyle(
                    track:
                        LinearGradient(
                            colors: [accent.opacity(0.35), accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(height: 8)
                        .background(
                            Capsule()
                                .fill(accent.opacity(0.12))
                        )
                        .clipShape(Capsule()),
                    thumb:
                        Circle()
                        .fill(.background)
                        .overlay(
                            Circle()
                                .stroke(accent, lineWidth: 2)
                        )
                        .shadow(color: accent.opacity(0.24), radius: 6, y: 1),
                    thumbSize: CGSize(width: 18, height: 18),
                    thumbInteractiveSize: CGSize(width: 28, height: 28),
                    options: .interactiveTrack
                )
            )
            .frame(height: 28)
            .disabled(!isEnabled)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(valueText)

            HStack {
                Text(minimumLabel)
                Spacer()
                Text(maximumLabel)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct UnlockView: View {
    @ObservedObject var model: HotblockModel
    @Binding var isPresented: Bool
    @State private var recoveryFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Stop Strict Session")
                .font(.headline)

            Text("Type these words exactly:")

            Text(model.unlockWords.joined(separator: " "))
                .fixedSize(horizontal: false, vertical: true)

            TextField("Type the words here", text: $model.unlockAttempt)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)

            if !model.unlockError.isEmpty {
                Text(model.unlockError)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            if recoveryFailed {
                Text("Administrator Recovery was cancelled or failed.")
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            HStack {
                Button("Administrator Recovery") {
                    Task {
                        recoveryFailed = !(await model.requestAdministratorRecovery())
                        if !model.isBlocking {
                            isPresented = false
                        }
                    }
                }

                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                Button("Unblock", action: submit)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 470)
    }

    private func submit() {
        if model.submitUnlockAttempt() {
            isPresented = false
        }
    }
}

private struct HistoryView: View {
    @ObservedObject var model: HotblockModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("History")
                .font(.headline)

            if model.history.isEmpty {
                Text("No blocked attempts yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.history) { entry in
                    HStack {
                        Text(entry.website)
                        Spacer()
                        Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Button("Delete History") {
                    model.clearHistory()
                }
                    .disabled(model.history.isEmpty)
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 500, height: 360)
    }
}

private struct SettingsView: View {
    @ObservedObject var model: HotblockModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Focus Voice")
                    .fontWeight(.medium)
                Text("Choose between two more natural English voices.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker(
                    "Focus Voice",
                    selection: Binding(
                        get: {
                            model.settings.voiceIdentifier
                                ?? model.englishVoices.first(where: { $0.name == model.settings.voiceName })?.id
                                ?? model.englishVoices.first?.id
                                ?? ""
                        },
                        set: { model.setVoice($0) }
                    )
                ) {
                    ForEach(model.englishVoices) { voice in
                        Text(model.voiceDisplayName(voice)).tag(voice.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.radioGroup)
                .disabled(model.isBlocking)
            }

            HotblockSliderCard(
                title: "Volume",
                icon: "speaker.wave.2.fill",
                accent: .orange,
                minimumLabel: "0",
                maximumLabel: "100",
                accessibilityLabel: "Voice volume",
                valueText: "\(model.settings.volume)%",
                value: Binding(
                    get: { model.settings.volume },
                    set: { model.setVolume($0) }
                ),
                range: 0...100,
                step: 1,
                isEnabled: !model.isBlocking
            )

            if model.isBlocking {
                Text("Voice settings are locked during a strict session.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Preview Voice") {
                    model.testVoice()
                }
                Button("Setup Assistant") {
                    model.showSetup()
                }
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

private struct SetupAssistantView: View {
    @ObservedObject var model: HotblockModel
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hotblock Setup")
                .font(.headline)
            Text("Step \(step + 1) of 5")
                .foregroundStyle(.secondary)

            GroupBox {
                stepContent
                    .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            }

            HStack {
                Button("Back") {
                    step = max(step - 1, 0)
                }
                .disabled(step == 0)

                Spacer()

                if model.setupCompleted {
                    Button("Close") {
                        dismiss()
                    }
                } else if step < 4 {
                    Button("Next") {
                        step += 1
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Finish") {
                        Task {
                            await model.refreshSetupVerification()
                            model.completeSetup()
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 500, height: 310)
        .interactiveDismissDisabled(!model.setupCompleted)
        .task(id: step) {
            if step == 4 {
                await model.refreshSetupVerification()
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            VStack(alignment: .leading, spacing: 10) {
                Text("Background Protection")
                    .font(.headline)
                Text("Hotblock uses background protection to relaunch an active strict session after Force Quit.")
                Label(
                    model.backgroundProtectionAvailable ? "Protection component is available" : "Protection component is missing",
                    systemImage: model.backgroundProtectionAvailable ? "checkmark.circle" : "exclamationmark.triangle"
                )
                Text("This prototype uses a user LaunchAgent. The production release will use a signed privileged helper.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case 1:
            VStack(alignment: .leading, spacing: 10) {
                Text("Browser Permissions")
                    .font(.headline)
                ForEach(model.installedBrowsers) { browser in
                    HStack {
                        Text(browser.displayName)
                        Spacer()
                        Text(permissionText(model.browserPermissions[browser] ?? .unknown))
                    }
                }
                HStack {
                    Button("Request Permissions") {
                        Task { await model.requestAllBrowserPermissions() }
                    }
                    Button("Open Automation Settings") {
                        model.openAutomationSettings()
                    }
                }
            }
        case 2:
            VStack(alignment: .leading, spacing: 10) {
                Text("Notifications")
                    .font(.headline)
                Text("Hotblock uses notifications when browser permission is lost or a tab cannot be closed.")
                Label(
                    model.notificationsAuthorized ? "Notifications allowed" : "Notifications not allowed (optional)",
                    systemImage: model.notificationsAuthorized ? "checkmark.circle" : "info.circle"
                )
                Button("Request Notification Permission") {
                    Task { await model.requestNotificationPermission() }
                }
            }
        case 3:
            VStack(alignment: .leading, spacing: 10) {
                Text("Voice")
                    .font(.headline)
                Text("Choose the voice and volume later in Settings, then test it here.")
                Button("Test Voice") {
                    model.testVoice()
                }
            }
        default:
            VStack(alignment: .leading, spacing: 10) {
                Text("Final Verification")
                    .font(.headline)
                Label(
                    model.canCompleteSetup ? "Hotblock is ready" : "Some required setup steps are incomplete",
                    systemImage: model.canCompleteSetup ? "checkmark.circle" : "exclamationmark.triangle"
                )
                Text("Strict sessions cannot start until every installed supported browser has permission.")
                ForEach(model.requiredSetupIssues, id: \.self) { issue in
                    Text("• \(issue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Check Again") {
                    Task { await model.refreshSetupVerification() }
                }
            }
        }
    }

    private func permissionText(_ permission: BrowserPermission) -> String {
        switch permission {
        case .authorized: "Allowed"
        case .denied: "Denied"
        case .unavailable: "Unavailable"
        case .unknown: "Not checked"
        }
    }
}
