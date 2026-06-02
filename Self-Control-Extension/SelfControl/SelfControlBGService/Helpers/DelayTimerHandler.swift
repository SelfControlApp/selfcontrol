//
//  DelayTimerHandler.swift
//  SelfControl
//
//  Created by Satendra Singh on 20/05/26.
//


import Foundation
import os.log

final class DelayTimerHandler {

    private var blockTimer: DispatchSourceTimer?
    var timerQueue = DispatchQueue(
        label: "com.example.delaytimerhandler.timer",
        qos: .utility
    )

    private(set) var timerFireDate: Date?
    private(set) var isActiveBlocking: Bool = false

    var delay: Double // minutes

    var completionHandler: (() -> Void)?
    var cancelHandler: (() -> Void)?

    init(
        delay: Double,
        completionHandler: (() -> Void)? = nil,
        cancelHandler: (() -> Void)? = nil
    ) {
        self.delay = delay
        self.completionHandler = completionHandler
        self.cancelHandler = cancelHandler
    }

    deinit {
        cancelTimer()
    }

    @discardableResult
    func startTimerWithSelectedDelay() -> Bool {

        cancelEventHandler() // IMPORTANT

        let seconds = delay * 60.0

        guard seconds > 30 else {
            os_log("[SC] 🔍] BG Invalid delay: %f", seconds)
            return false
        }

        timerFireDate = Date().addingTimeInterval(seconds)
        isActiveBlocking = true

        let timer = DispatchSource.makeTimerSource(queue: timerQueue)

        timer.schedule(
            deadline: .now() + seconds,
            repeating: .never,
            leeway: .seconds(1)
        )

        timer.setEventHandler { [weak self] in
            guard let self else { return }

            os_log("[SC] 🔍] BG Timer fired")

            // Prevent future usage immediately
            let completion = self.completionHandler

            self.blockTimer?.setEventHandler {}
            self.blockTimer?.cancel()
            self.blockTimer = nil

            self.isActiveBlocking = false
            self.timerFireDate = nil

            self.completionHandler = nil
            self.cancelHandler = nil

            // Call once
            completion?()
        }

        blockTimer = timer
        timer.resume()

        return true
    }
    
    func extendBlocking(minutes: Int) {
        guard minutes > 0 else { return }
        timerQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.isActiveBlocking, let timer = self.blockTimer else {
                os_log("[SC] 🔍] BG extendBlocking ignored: no active timer")
                return
            }

            let additionalSeconds = Double(minutes) * 60.0
            let now = Date()
            let currentFire = self.timerFireDate ?? now
            let newFire = currentFire.addingTimeInterval(additionalSeconds)

            // Update model
            self.timerFireDate = newFire
            self.delay += Double(minutes) // keep start time consistent

            // Reschedule timer to the new deadline
            let remaining = max(0, newFire.timeIntervalSince(now))
            os_log("[SC] 🔍] BG Extending blocking by %{public}d minutes (%{public}.0f s). New remaining: %.0f s", minutes, additionalSeconds, remaining)
            timer.schedule(deadline: .now() + remaining, repeating: .never, leeway: .seconds(1))
        }
    }
    
    private func cancelEventHandler() {
        guard let timer = blockTimer else { return }

        os_log("[SC] 🔍] BG Cancelling timer")

        timer.setEventHandler {}
        timer.cancel()
    }
    
    func cancelTimer() {

        guard let timer = blockTimer else { return }

        os_log("[SC] 🔍] BG Cancelling timer")

        timer.setEventHandler {}
        timer.cancel()

        blockTimer = nil

        isActiveBlocking = false
        timerFireDate = nil

        cancelHandler?()

        completionHandler = nil
        cancelHandler = nil
    }

    var blockingEndTime: Date? {
        timerFireDate
    }

    var blockingStartTime: Date? {
        timerFireDate?.addingTimeInterval(-(delay * 60.0))
    }
}
