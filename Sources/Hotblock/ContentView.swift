import SwiftUI

struct ContentView: View {
    @StateObject private var store = FocusBlockerStore.shared
    @State private var isShowingStartSheet = false
    @State private var isShowingUnlockSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Hotblock")
                .font(.largeTitle)

            Text("Add websites to a list. Press Start to watch the frontmost browser tab and play a voice warning when a blocked site is opened.")
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Button(store.isBlocking ? "Stop" : "Start") {
                        if store.isBlocking {
                            if store.requiresUnlockChallenge() {
                                store.prepareToStopBlocking()
                                isShowingUnlockSheet = true
                            } else {
                                store.stopBlocking()
                            }
                        } else {
                            isShowingStartSheet = true
                        }
                    }

                    Text(store.isBlocking ? "Blocking active" : "Blocking off")
                        .foregroundStyle(.secondary)
                }

                Text("Detected browsers: \(detectedBrowsersText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Supports Safari, Chrome, Brave, and Arc when the browser is frontmost.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Add Website")
                    .font(.headline)

                HStack(spacing: 12) {
                    TextField("instagram.com", text: $store.draftWebsite)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            store.addWebsite()
                        }

                    Button("Add") {
                        store.addWebsite()
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Blocked Websites")
                    .font(.headline)

                if store.websites.isEmpty {
                    Text("No websites added.")
                        .foregroundStyle(.secondary)
                } else {
                    List {
                        ForEach(store.websites, id: \.self) { website in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(website)

                                    if store.lastInterceptedWebsite == website {
                                        Text("Last warned site")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Button("Test Voice") {
                                    store.simulateVisit(website)
                                }
                                .disabled(!store.isBlocking)

                                Button("Remove") {
                                    store.removeWebsite(website)
                                }
                            }
                        }
                    }
                    .frame(minHeight: 240)
                }
            }

            Divider()
        }
        .padding(20)
        .frame(width: 560, height: 420)
        .task {
            store.configureLaunchAtLogin()
            await store.requestAutomationPermissionOnLaunch()
        }
        .sheet(isPresented: $isShowingStartSheet) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Start Blocking")
                    .font(.headline)

                Text("Choose how many random words must be typed to unblock. Set it to 0 to disable the typing challenge.")
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Required words: \(store.pendingUnlockWordCount)")

                    Slider(
                        value: Binding(
                            get: { Double(store.pendingUnlockWordCount) },
                            set: { store.pendingUnlockWordCount = Int($0.rounded()) }
                        ),
                        in: 0...100,
                        step: 1
                    )
                }

                HStack {
                    Spacer()

                    Button("Cancel") {
                        isShowingStartSheet = false
                    }

                    Button("Start") {
                        store.startBlocking()
                        isShowingStartSheet = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 360)
        }
        .sheet(isPresented: $isShowingUnlockSheet) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Unblock")
                    .font(.headline)

                if store.unlockWords.isEmpty {
                    Text("No word challenge is required.")
                } else {
                    Text("Type these words to stop blocking:")
                        .fixedSize(horizontal: false, vertical: true)

                    Text(store.unlockWords.joined(separator: " "))

                    TextField("Type the words here", text: $store.unlockAttempt)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            if store.submitUnlockAttempt() {
                                isShowingUnlockSheet = false
                            }
                        }
                }

                if !store.unlockErrorMessage.isEmpty {
                    Text(store.unlockErrorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }

                HStack {
                    Spacer()

                    Button("Cancel") {
                        isShowingUnlockSheet = false
                    }

                    Button("Unblock") {
                        if store.submitUnlockAttempt() {
                            isShowingUnlockSheet = false
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 420)
        }
    }

    private var detectedBrowsersText: String {
        if store.availableBrowsers.isEmpty {
            return "None"
        }

        return store.availableBrowsers.joined(separator: ", ")
    }
}
