//
//  SCDurationSlider.swift
//  SelfControl
//
//  Created by Satendra Singh on 31/08/25.
//

import Foundation


//import Foundation
//import AppKit

//class SCTimeIntervalFormatter {
//    
//    func string(for obj: Any?) -> String {
//        guard let number = obj as? NSNumber else {
//            return ""
//        }
//        return formatSeconds(number.doubleValue)
//    }
//    
//    func formatSeconds(_ seconds: TimeInterval) -> String {
//        let useModernBehavior = NSAppKitVersion.current >= NSAppKitVersion.macOS10_8
//        if useModernBehavior {
//            return formatSecondsUsingModernBehavior(seconds)
//        } else {
//            return formatSecondsUsingLegacyBehavior(seconds)
//        }
//    }
//        
//    private func formatSecondsUsingModernBehavior(_ seconds: TimeInterval) -> String {
//        struct FormatterHolder {
//            static let formatter: TTTTimeIntervalFormatter = {
//                let formatter = NSDateFormatter()
//                formatter.pastDeicticExpression = ""
//                formatter.presentDeicticExpression = ""
//                formatter.futureDeicticExpression = ""
//                formatter.significantUnits = [.year, .month, .day, .hour, .minute]
//                formatter.numberOfSignificantUnits = 0
//                formatter.leastSignificantUnit = .minute
//                return formatter
//            }()
//        }
//
//        var formatted = FormatterHolder.formatter.string(forTimeInterval: seconds) ?? ""
//        if formatted.isEmpty {
//            formatted = stringIndicatingZeroMinutes()
//        }
//        
//        return formatted
//    }
//    
//    private func formatSecondsUsingLegacyBehavior(_ seconds: TimeInterval) -> String {
//        let numMinutes = Int(seconds / 60)
//        let formatDays = numMinutes / 1440
//        let formatHours = (numMinutes % 1440) / 60
//        let formatMinutes = numMinutes % 60
//        
//        var timeString = ""
//        
//        if numMinutes > 0 {
//            if formatDays > 0 {
//                timeString = "\(formatDays) " + (formatDays == 1 ? NSLocalizedString("day", comment: "Single day time string") : NSLocalizedString("days", comment: "Plural days time string"))
//            }
//            if formatHours > 0 {
//                let hoursPart = "\(formatHours) " + (formatHours == 1 ? NSLocalizedString("hour", comment: "Single hour time string") : NSLocalizedString("hours", comment: "Plural hours time string"))
//                timeString += (formatDays > 0 ? ", " : "") + hoursPart
//            }
//            if formatMinutes > 0 {
//                let minutesPart = "\(formatMinutes) " + (formatMinutes == 1 ? NSLocalizedString("minute", comment: "Single minute time string") : NSLocalizedString("minutes", comment: "Plural minutes time string"))
//                timeString += ((formatHours > 0 || formatDays > 0) ? ", " : "") + minutesPart
//            }
//        } else {
//            timeString = stringIndicatingZeroMinutes()
//        }
//        
//        return timeString
//    }
//    
//    private func stringIndicatingZeroMinutes() -> String {
//        return String(
//            format: "0 %@ (%@)",
//            NSLocalizedString("minutes", comment: "Plural minutes time string"),
//            NSLocalizedString("disabled", comment: "Shows that SelfControl is disabled")
//        )
//    }
//}
