import SwiftUI

struct TimerView: View {
    @ObservedObject var appController: AppController

    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Timer?

    private var endDate: Date? {
        SCSettings.shared.value(for: "BlockEndDate") as? Date
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 4) {
                Text(timeString)
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                    .monospacedDigit()

                Text("remaining")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
            }

            Spacer().frame(height: 16)

            if let end = endDate {
                Text("Block ends at \(end, style: .time)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    private var timeString: String {
        if timeRemaining <= 0 { return "00:00:00" }
        let h = Int(timeRemaining) / 3600
        let m = (Int(timeRemaining) % 3600) / 60
        let s = Int(timeRemaining) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    private func startTimer() {
        updateTimeRemaining()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateTimeRemaining()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateTimeRemaining() {
        guard let end = endDate else {
            timeRemaining = 0
            return
        }
        timeRemaining = max(end.timeIntervalSinceNow, 0)

        if timeRemaining <= 0 {
            // Block expired
            stopTimer()
            SCSettings.shared.setValue(false, for: "BlockIsRunning")
            SCSettings.shared.synchronize()
            appController.blockIsOn = false
        }
    }
}
