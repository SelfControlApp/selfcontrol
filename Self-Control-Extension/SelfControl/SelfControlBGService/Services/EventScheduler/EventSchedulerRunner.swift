//
//  EventSchedulerRunner.swift
//  SelfControl
//
//  Created by Satendra Singh on 23/02/26.
//

import Foundation
import os.log

//  A firing engine that uses EventScheduler as storage and fires events at their scheduled times.
//  This actor observes the scheduler and invokes registered handlers when events start.
//
public actor EventSchedulerRunner {
    public typealias EventHandler = @Sendable (Event) async -> Void

    public init(scheduler: EventScheduler, fireTolerance: TimeInterval = 1.0) {
        self.scheduler = scheduler
        self.fireTolerance = fireTolerance
    }

    private let scheduler: EventScheduler
    private let fireTolerance: TimeInterval

//    private var timer: Timer?
    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.yourcompany.EventSchedulerRunner.timer")

    private var perEventHandlers: [UUID: EventHandler] = [:]
    private var globalHandlers: [UUID: EventHandler] = [:] // keyed by token
    private var scheduledEvent: Event?
    
    deinit {
        if let t = timer {
            t.setEventHandler {}   // break potential retain cycles
            t.cancel()
            timer = nil
        }
        scheduledEvent = nil
    }

    // MARK: - Control

    public func start() async {
//        os_log("[SC] 🔍] BG Event Scheduler is starting")
        BGFileLogger.info("\(#function) Event Scheduler is starting")
        guard timer == nil else { return }
        await scheduleNextTimer()
    }

    public func stop() {
        // Your existing stop logic (e.g., cancel reschedule task, clear state) stays the same

        if let t = timer {
            t.setEventHandler {}   // break potential retain cycles
            t.cancel()
            timer = nil
        }
        scheduledEvent = nil
    }

    /// Restart timer to quickly reflect changes (handlers or events).
    private func rescheduleLoop() async {
        await scheduleNextTimer()
    }

    // MARK: - Handlers

    public func setHandler(for eventID: UUID, handler: EventHandler?) async {
        if let handler {
            perEventHandlers[eventID] = handler
        } else {
            perEventHandlers.removeValue(forKey: eventID)
        }
        await rescheduleLoop()
    }

    @discardableResult
    public func addGlobalHandler(_ handler: @escaping EventHandler) async -> UUID {
        let token = UUID()
        globalHandlers[token] = handler
        
    //        await rescheduleLoop()
        return token
    }

    public func removeGlobalHandler(token: UUID) async {
        globalHandlers.removeValue(forKey: token)
        await rescheduleLoop()
    }

    // MARK: - Timer scheduling
    private func scheduleNextTimer() async {
        // Cancel any existing timer first
        if let t = timer {
            t.setEventHandler { }
            t.cancel()
            timer = nil
        }

        // Your existing logic to compute the next fire date and select the event:
        // (Keep this unchanged if you already have it)
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent
            let events = await scheduler.allEvents()

        // If you already obtain events differently, keep your existing code here.
        // Example (keep your own):
        let (maybeNextDate, maybeEvent) = earliestNextStart(after: now, events: events, calendar: calendar)
//        os_log("[SC] 🔍] BG scheduleNextTimer: %{public}@ ",maybeNextDate?.debugDescription ?? "nil")
        BGFileLogger.info("\(#function) scheduleNextTimer:\(maybeNextDate?.debugDescription ?? "nil")")
        guard let fireDate = maybeNextDate, let event = maybeEvent else {
            scheduledEvent = nil
            return
        }
        scheduledEvent = event
        
        // New: Create a one-shot DispatchSourceTimer
        let t = DispatchSource.makeTimerSource(queue: timerQueue)

        // Convert your tolerance (seconds) into Dispatch leeway
        let leeway = DispatchTimeInterval.nanoseconds(Int(fireTolerance * 1_000_000_000))

        // Compute the deadline relative to now
        let delta = fireDate.timeIntervalSinceNow
        let deadline: DispatchTime = delta > 0 ? .now() + delta : .now()

        // One-shot timer: schedule once with leeway
        t.schedule(deadline: deadline, leeway: leeway)

        // Hop back into the actor when it fires
        t.setEventHandler { [weak self] in
            guard let self else { return }
            Task { await self.timerDidFire() }
        }
        timer = t
        t.resume()
    }
    
    private func timerDidFire() async {
//        os_log("[SC] 🔍] BG timerDidFire: %{public}%@ ",scheduledEvent.debugDescription)
        BGFileLogger.info("\(#function) timerDidFire:\(scheduledEvent.debugDescription)")
        // Clear scheduled event if you do that today


        // Cancel and clear the GCD timer (one-shot)
        if let t = timer {
            t.setEventHandler {}
            t.cancel()
            timer = nil
        }

        let fireDate = Date()
        let calendar = scheduler.calendar
        let events = await scheduler.allEvents()
        await fireEventsStarting(around: fireDate, events: events, calendar: calendar, tolerance: fireTolerance)
        scheduledEvent = nil
        // Schedule the next timer based on the latest data
        await scheduleNextTimer()
    }
    
    // MARK: - Event computations
    private func earliestNextStart(after date: Date, events: [Event], calendar: Calendar) -> (Date?, Event?) {
        var best: Date?
        var bestEvent: Event?
        for event in events {
            if let start = nextStart(of: event, after: date, calendar: calendar) {
                if let b = best {
                    if start < b {
                        best = start
                        bestEvent = event
                    }
                } else {
                    best = start
                    bestEvent = event
                }
            }
        }
        return (best, bestEvent)
    }

    private func nextStart(of event: Event, after date: Date, calendar: Calendar) -> Date? {
        // Search up to 8 weeks ahead
        for dayOffset in 0..<(7 * 8) {
            guard let candidateDay = calendar.date(byAdding: .day, value: dayOffset, to: date) else { continue }
            let weekday = SCWeekday.from(date: candidateDay, calendar: calendar)
            guard event.occurs(on: weekday) else { continue }

            var comps = calendar.dateComponents([.year, .month, .day], from: candidateDay)
            comps.hour = event.startTime.hour
            comps.minute = event.startTime.minute
            comps.second = 0
            if let start = calendar.date(from: comps), start > date {
                return start
            }
        }
        return nil
    }

    private func fireEventsStarting(around date: Date, events: [Event], calendar: Calendar, tolerance: TimeInterval) async {
        guard let firedEvent = scheduledEvent else { return }

        // Capture handlers to call outside the actor's critical path
        let global = globalHandlers.values
//        for event in starting {
            var handlers: [EventHandler] = []
            if let h = perEventHandlers[firedEvent.id] {
                handlers.append(h)
            }
            handlers.append(contentsOf: global)
//            if handlers.isEmpty { continue }

            for handler in handlers {
                Task.detached(priority: .userInitiated) {
                    await handler(firedEvent)
                }
            }
//        }
    }
}
