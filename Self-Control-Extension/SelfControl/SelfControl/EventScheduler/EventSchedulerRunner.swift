//
//  EventSchedulerRunner.swift
//  SelfControl
//
//  Created by Satendra Singh on 23/02/26.
//

import Foundation

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

    private var timer: Timer?
    private var perEventHandlers: [UUID: EventHandler] = [:]
    private var globalHandlers: [UUID: EventHandler] = [:] // keyed by token
    private var scheduledEvent: Event?
    
    deinit {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Control

    public func start() async {
        guard timer == nil else { return }
        await scheduleNextTimer()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
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
        // Cancel existing timer, if any
        timer?.invalidate()
        timer = nil

        let now = Date()
        let calendar = await scheduler.calendar
        let events = await scheduler.allEvents()

        // Compute earliest next start among all events
        let next = earliestNextStart(after: now, events: events, calendar: calendar)

        // If there are no upcoming events, poll again in a short while
        let interval: TimeInterval
        if let nextDate = next.0 {
            interval = max(0.0, nextDate.timeIntervalSinceNow)
        } else {
            interval = 0.3
        }

        // Create a one-shot timer to fire at the next event (or retry interval)
        let newTimer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            guard let self else { return }
            // Hop back to the actor to handle firing and rescheduling
            Task {
                await self.timerDidFire()
            }
        }
        scheduledEvent = next.1
        // Ensure the timer fires during UI interactions as well
        newTimer.tolerance = min(fireTolerance, max(0.0, interval * 0.90))
        RunLoop.main.add(newTimer, forMode: .common)
        self.timer = newTimer
    }

    private func timerDidFire() async {
        let fireDate = Date()
        let calendar = await scheduler.calendar
        let events = await scheduler.allEvents()

        await fireEventsStarting(around: fireDate, events: events, calendar: calendar, tolerance: fireTolerance)

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
        // Determine which events start at this time within tolerance
//        let starting = events.compactMap { event -> Event? in
//            let weekday = SCWeekday.from(date: date, calendar: calendar)
//            guard event.occurs(on: weekday) else { return nil }
//            var comps = calendar.dateComponents([.year, .month, .day], from: date)
//            comps.hour = event.startTime.hour
//            comps.minute = event.startTime.minute
//            comps.second = 0
//            guard let start = calendar.date(from: comps) else { return nil }
//            return abs(start.timeIntervalSince(date)) <= tolerance ? event : nil
//        }

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
