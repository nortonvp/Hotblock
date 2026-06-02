import SwiftUI

struct ContentView: View {
    @State private var blockCount = 0
    @State private var statusMessage = "Your starter app is running."

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Hotblock")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("A tiny macOS starter app you can grow in Xcode and keep on GitHub.")
                .font(.title3)
                .foregroundStyle(.secondary)

            Divider()

            Text("Focus blocks started: \(blockCount)")
                .font(.headline)

            Text(statusMessage)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Start Focus Block") {
                    blockCount += 1
                    statusMessage = "Nice. You started block \(blockCount)."
                }

                Button("Reset") {
                    blockCount = 0
                    statusMessage = "Counter reset. Ready for the next block."
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 320)
    }
}
