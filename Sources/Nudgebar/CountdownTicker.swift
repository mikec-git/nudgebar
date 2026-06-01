import Combine
import Foundation

/// Drives a periodic tick whose cadence depends on the next event's proximity.
/// Within 60 min of the next event the ticker fires every 1 second; otherwise every 60 seconds.
@MainActor
final class CountdownTicker: ObservableObject {
    @Published private(set) var tickCount: Int = 0

    private var timer: Timer?
    private var nextEventStart: Date?

    deinit {
        timer?.invalidate()
    }

    func update(nextEventStart: Date?, now: Date = .now) {
        let seconds = nextEventStart?.timeIntervalSince(now)
        let interval = StatusItemTitleFormatter.tickInterval(secondsUntilStart: seconds)

        if self.nextEventStart == nextEventStart, let timer, timer.timeInterval == interval, timer.isValid {
            return
        }

        self.nextEventStart = nextEventStart
        scheduleTimer(interval: interval)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        nextEventStart = nil
    }

    private func scheduleTimer(interval: TimeInterval) {
        timer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.tickCount &+= 1
                if let start = self.nextEventStart {
                    let nextInterval = StatusItemTitleFormatter.tickInterval(
                        secondsUntilStart: start.timeIntervalSince(.now)
                    )
                    if nextInterval != interval {
                        self.scheduleTimer(interval: nextInterval)
                    }
                }
            }
        }
        timer.tolerance = interval * 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
