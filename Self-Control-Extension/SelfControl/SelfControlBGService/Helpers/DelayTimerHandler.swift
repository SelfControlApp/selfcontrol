//
//  DelayTimerHandler.swift
//  SelfControl
//
//  Created by Satendra Singh on 20/05/26.
//


import Foundation
import os.log

//final class DelayTimerHandler {
//    
//    private var blockTimer: Timer?
//    private(set) var timerFireDate: Date?
//    private(set) var isActiveBlocking: Bool = false
//    
//    var delay: Double // delay in minutes
//    
//    // Handlers
//    var completionHandler: (() -> Void)?
//    var cancelHandler: (() -> Void)?
//    
//    init(delay: Double,
//         completionHandler: (() -> Void)? = nil,
//         cancelHandler: (() -> Void)? = nil) {
//        self.delay = delay
//        self.completionHandler = completionHandler
//        self.cancelHandler = cancelHandler
//    }
//    
//    @discardableResult
//    func startTimerWithSelectedDelay() -> Bool {
//        cancelTimer()
//        
//        let seconds = delay * 60.0
//        guard seconds > 30 else {
//            os_log("[SC] 🔍 startTimerWithSelectedDelay called with non-positive delay: %f", seconds)
//            return false
//        }
//        
//        timerFireDate = Date().addingTimeInterval(seconds)
//        os_log("[SC] 🔍 Scheduling timer to fire in %.0f seconds (%.2f minutes)", seconds, delay)
//        
//        blockTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
//            guard let self = self else {
//                os_log("[SC] 🔍 Timer fired,self is nil.")
//                return
//            }
//            os_log("[SC] 🔍 Timer fired.")
//            self.completionHandler?()
//            self.cancelTimer()
//        }
//        
//        isActiveBlocking = true
//        return true
//    }
//    
//    func cancelTimer() {
//        if blockTimer != nil {
//            os_log("[SC] 🔍 Cancelling timer.")
//            cancelHandler?()
//        }
//        blockTimer?.invalidate()
//        blockTimer = nil
//        isActiveBlocking = false
//        timerFireDate = nil
//    }
//    
//    var blockingEndTime: Date? {
//        timerFireDate
//    }
//    
//    var blockingStartTime: Date? {
//        timerFireDate?.addingTimeInterval(delay * 60.0)
//    }
//}


final class DelayTimerHandler {
    
    private var blockTimer: DispatchSourceTimer?
    var timerQueue = DispatchQueue(label: "com.example.delaytimerhandler.timer", qos: .utility)
    private(set) var timerFireDate: Date?
    private(set) var isActiveBlocking: Bool = false
    
    var delay: Double // delay in minutes
    
    // Handlers
    var completionHandler: (() -> Void)?
    var cancelHandler: (() -> Void)?
    
    init(delay: Double,
         completionHandler: (() -> Void)? = nil,
         cancelHandler: (() -> Void)? = nil) {
        self.delay = delay
        self.completionHandler = completionHandler
        self.cancelHandler = cancelHandler
    }
    
    deinit {
        cancelTimer()
    }
    
    @discardableResult
    func startTimerWithSelectedDelay() -> Bool {
        cancelTimer()
        
        let seconds = delay * 60.0
        guard seconds > 30 else {
            os_log("[SC] 🔍 startTimerWithSelectedDelay called with non-positive delay: %f", seconds)
            return false
        }
        
        timerFireDate = Date().addingTimeInterval(seconds)
        os_log("[SC] 🔍 Scheduling dispatch timer to fire in %.0f seconds (%.2f minutes)", seconds, delay)
        
        let t = DispatchSource.makeTimerSource(queue: timerQueue)
        // One-shot: schedule once and cancel in handler
        t.schedule(deadline: .now() + seconds, repeating: .never, leeway: .seconds(1))
        t.setEventHandler { [weak self] in
            guard let self = self else {
                os_log("[SC] 🔍 Dispatch timer fired, self is nil.")
                return
            }
            os_log("[SC] 🔍 Dispatch timer fired.")
            self.completionHandler?()
            self.completionHandler = nil
            self.cancelHandler = nil
        }
        t.resume()
        blockTimer = t
        
        isActiveBlocking = true
        return true
    }
    
    func cancelTimer() {
        if let blockTimer {
            os_log("[SC] 🔍 Cancelling dispatch timer.")
            cancelHandler?()
            blockTimer.setEventHandler {} // Break potential retain cycles
            blockTimer.cancel()
        }
        blockTimer = nil
        isActiveBlocking = false
        timerFireDate = nil
        self.completionHandler = nil
        self.cancelHandler = nil
    }
    
    var blockingEndTime: Date? {
        timerFireDate
    }
    
    var blockingStartTime: Date? {
        timerFireDate?.addingTimeInterval(-delay * 60.0)
    }
}
