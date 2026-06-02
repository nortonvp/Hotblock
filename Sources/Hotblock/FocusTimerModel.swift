import Combine
import Foundation

@MainActor
final class FocusTimerModel: ObservableObject {
    @Published private(set) var selectedMinutes: Int
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var completedSessions = 0
    @Published private(set) var isRunning = false
    @Published private(set) var statusMessage = "Ready to start your next block."

    private var timerCancellable: AnyCancellable?

    init(defaultMinutes: Int = 25) {
        selectedMinutes = defaultMinutes
        remainingSeconds = defaultMinutes * 60
    }

    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var progress: Double {
        let totalSeconds = max(selectedMinutes * 60, 1)
        return 1 - (Double(remainingSeconds) / Double(totalSeconds))
    }

    func toggleRunning() {
        isRunning ? pause() : start()
    }

    func adjustDuration(by minutes: Int) {
        guard !isRunning else { return }

        selectedMinutes = min(max(selectedMinutes + minutes, 5), 90)
        remainingSeconds = selectedMinutes * 60
        statusMessage = "Session length set to \(selectedMinutes) minutes."
    }

    func reset() {
        stopTimer()
        remainingSeconds = selectedMinutes * 60
        statusMessage = "Timer reset. Ready when you are."
    }

    private func start() {
        guard !isRunning else { return }

        if remainingSeconds == 0 {
            remainingSeconds = selectedMinutes * 60
        }

        isRunning = true
        statusMessage = "Focus mode is on. Stay with this block."

        timerCancellable = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func pause() {
        stopTimer()
        statusMessage = "Paused with \(formattedTime) left."
    }

    private func tick() {
        guard isRunning else { return }

        if remainingSeconds > 0 {
            remainingSeconds -= 1
        }

        if remainingSeconds == 0 {
            completedSessions += 1
            stopTimer()
            statusMessage = "Block complete. Take a breath, then go again."
        }
    }

    private func stopTimer() {
        isRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
    }
}
