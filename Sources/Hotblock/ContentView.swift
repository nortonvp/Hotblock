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
                    Label("Presets", systemImage: "square.grid.2x2")
                }
                .help("Add a built-in group of websites")
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
    @State private var wordCount = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Start Strict Session")
                .font(.headline)

            Text("Choose how many random words you must type to stop blocking.")

            Text("Unlock words: \(wordCount)")
            Slider(
                value: Binding(
                    get: { Double(wordCount) },
                    set: { wordCount = Int($0.rounded()) }
                ),
                in: 1...100,
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
        .frame(width: 380)
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

            Picker(
                "English Voice",
                selection: Binding(
                    get: { model.settings.voiceName },
                    set: { model.setVoice($0) }
                )
            ) {
                ForEach(model.englishVoices, id: \.self) { voice in
                    Text(voice).tag(voice)
                }
            }
            .disabled(model.isBlocking)

            Text("Volume: \(model.settings.volume)%")
            Slider(
                value: Binding(
                    get: { Double(model.settings.volume) },
                    set: { model.setVolume(Int($0.rounded())) }
                ),
                in: 0...100,
                step: 1
            )
            .disabled(model.isBlocking)

            if model.isBlocking {
                Text("Voice settings are locked during a strict session.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Test Voice") {
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
                        model.completeSetup()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 500, height: 310)
        .interactiveDismissDisabled(!model.setupCompleted)
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
                    model.notificationsAuthorized ? "Notifications allowed" : "Notifications not allowed",
                    systemImage: model.notificationsAuthorized ? "checkmark.circle" : "exclamationmark.triangle"
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
