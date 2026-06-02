//
//  EventSchedulerRunnerContainer.swift
//  SelfControl
//
//  Created by Satendra Singh on 28/05/26.
//

final class EventSchedulerRunnerController {
    private var eventRunner: EventSchedulerRunner? = nil
    var eventRunnerHandler: EventSchedulerRunner.EventHandler?
    
    init(eventRunnerHandler: EventSchedulerRunner.EventHandler? = nil) {
        self.eventRunnerHandler = eventRunnerHandler
        startEventScheduler()
    }
    
    func startEventScheduler() {
        Task {
            await self.eventRunner?.stop()
            let scheduler = EventScheduler()
            let events = HelperAppPreferences.loadSchedules()
            var eventObjs: [Event] = []
            for event in events {
                eventObjs.append(contentsOf: event.scheduledEvents)
            }
            for item in eventObjs {
                _ = try? await scheduler.schedule(newEvent: item)
            }
            eventRunner = EventSchedulerRunner(scheduler: scheduler)
            
            await eventRunner?.addGlobalHandler { event in
                await self.eventRunnerHandler?(event)
            }
            await eventRunner?.start()
        }
    }
    
    func stopEventScheduler() {
        Task {
            await self.eventRunner?.stop()
        }
        startEventScheduler()
    }
}

extension Schedule {
    var scheduledEvents: [Event] {
        var items: [Event] = []
        for slot in self.timeSlots {
            if let event = try? Event(days: enabledDays, startTime: TimeOfDay(hour: slot.startHour, minute: slot.startMinute), endTime: TimeOfDay(hour: slot.endHour, minute: slot.endMinute)) {
                items.append(event)
            }
        }
        return items
    }
}
