import SwiftUI

struct ContentView: View {
    @StateObject private var timer = FocusTimerModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.93, blue: 0.86),
                    Color(red: 0.92, green: 0.78, blue: 0.63),
                    Color(red: 0.79, green: 0.39, blue: 0.27),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hotblock")
                        .font(.system(size: 36, weight: .bold, design: .rounded))

                    Text("A simple focus timer for deep work on your Mac.")
                        .font(.title3)
                        .foregroundStyle(.black.opacity(0.7))
                }

                HStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.28), lineWidth: 18)
                            .frame(width: 220, height: 220)

                        Circle()
                            .trim(from: 0, to: timer.progress)
                            .stroke(
                                Color.white,
                                style: StrokeStyle(lineWidth: 18, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 220, height: 220)
                            .shadow(color: .white.opacity(0.35), radius: 10)

                        VStack(spacing: 8) {
                            Text(timer.formattedTime)
                                .font(.system(size: 44, weight: .semibold, design: .rounded))
                                .monospacedDigit()

                            Text(timer.isRunning ? "In focus" : "Ready")
                                .font(.headline)
                                .foregroundStyle(.black.opacity(0.7))
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        statCard(title: "Session length", value: "\(timer.selectedMinutes) min")
                        statCard(title: "Completed today", value: "\(timer.completedSessions)")

                        Text(timer.statusMessage)
                            .font(.body)
                            .foregroundStyle(.black.opacity(0.72))
                            .padding(.top, 4)
                    }
                }

                HStack(spacing: 12) {
                    Button(timer.isRunning ? "Pause" : "Start") {
                        timer.toggleRunning()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Reset") {
                        timer.reset()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Spacer()

                    Button("-5 min") {
                        timer.adjustDuration(by: -5)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button("+5 min") {
                        timer.adjustDuration(by: 5)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(30)
        }
        .frame(minWidth: 700, minHeight: 460)
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundStyle(.black.opacity(0.55))

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.85))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
