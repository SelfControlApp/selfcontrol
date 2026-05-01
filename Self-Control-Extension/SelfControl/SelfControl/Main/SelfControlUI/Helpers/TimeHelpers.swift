//
//  TimeHelpers.swift
//  SelfControlUI
//
//  Created on 2025-10-31.
//

import Foundation

// MARK: - Time Formatting Helpers
struct TimeHelpers {
    /// Format time display string from minutes, supporting easter egg mode with days
    static func timeDisplay(minutes: Double, isEasterEggUnlocked: Bool, days: Int) -> String {
        if isEasterEggUnlocked {
            // Extract days, hours, and minutes
            let daysInMinutes = days * 24 * 60
            let totalMins = Int(minutes)
            let hoursAndMins = totalMins - daysInMinutes
            let hours = max(0, hoursAndMins) / 60
            let mins = max(0, hoursAndMins) % 60
            
            var parts: [String] = []
            if days > 0 {
                parts.append("\(days)d")
            }
            if hours > 0 {
                parts.append("\(hours)h")
            }
            if mins > 0 {
                parts.append("\(mins)m")
            }
            return parts.isEmpty ? "0m" : parts.joined(separator: " ")
        }
        
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(Int(minutes))m"
    }
    
    /// Format countdown display string from remaining time
    static func countdownDisplay(remainingTime: TimeInterval, hideSeconds: Bool) -> String {
        let hours = Int(remainingTime) / 3600
        let mins = (Int(remainingTime) % 3600) / 60
        let secs = Int(remainingTime) % 60
        
        if hideSeconds {
            return String(format: "%02d:%02d", hours, mins)
        } else {
            return String(format: "%02d:%02d:%02d", hours, mins, secs)
        }
    }
    
    /// Format countdown time as mm:ss (for medium intensity stop confirmation)
    static func formatCountdownTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Extract time components from minutes for editing
    static func extractTimeComponents(minutes: Double, isEasterEggUnlocked: Bool, days: Int) -> (days: Int, hours: Int, minutes: Int) {
        if isEasterEggUnlocked {
            let daysInMinutes = days * 24 * 60
            let totalMins = Int(minutes)
            let hoursAndMins = totalMins - daysInMinutes
            let hours = max(0, hoursAndMins) / 60
            let mins = max(0, hoursAndMins) % 60
            return (days: days, hours: hours, minutes: mins)
        }
        
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        return (days: 0, hours: hours, minutes: mins)
    }
    
    // MARK: - Time Input Calculation Helpers
    
    /// Result structure for time calculations
    struct TimeCalculationResult {
        let days: Int
        let daysInput: String
        let hours: Int
        let hoursInput: String
        let minutes: Int
        let minutesInput: String
        let totalMinutes: Double
    }
    
    /// Calculate minutes from hours and minutes inputs (non-easter egg mode)
    static func calculateMinutesFromInputs(hoursInput: String, minutesInput: String, isEasterEggUnlocked: Bool) -> (hours: Int, hoursInput: String, minutes: Int, minutesInput: String, totalMinutes: Double) {
        var hours = Int(hoursInput) ?? 0
        var mins = Int(minutesInput) ?? 0
        
        if !isEasterEggUnlocked {
            // For non-easter egg version, handle minutes overflow first
            if mins >= 60 {
                let additionalHours = mins / 60
                hours += additionalHours
                mins = mins % 60
            }
            
            // Then clamp hours to 24 max
            hours = min(24, max(0, hours))
        }
        
        let finalHoursInput = hours == 0 ? "0" : String(hours)
        let finalMinutesInput = mins == 0 ? "0" : String(mins)
        
        let totalMinutes = Double(hours * 60 + mins)
        let maxMinutes = isEasterEggUnlocked ? Double.greatestFiniteMagnitude : 1440
        let clampedMinutes = max(0, min(maxMinutes, totalMinutes))
        
        return (hours: hours, hoursInput: finalHoursInput, minutes: mins, minutesInput: finalMinutesInput, totalMinutes: clampedMinutes)
    }
    
    /// Calculate minutes from days, hours, and minutes inputs (easter egg mode)
    static func calculateMinutesFromAllInputs(daysInput: String, hoursInput: String, minutesInput: String, currentDays: Int, isEasterEggUnlocked: Bool) -> TimeCalculationResult {
        var inputDays = Int(daysInput) ?? currentDays
        var inputHours = Int(hoursInput) ?? 0
        var inputMins = Int(minutesInput) ?? 0
        
        if isEasterEggUnlocked {
            // First, handle minutes overflow -> convert to hours
            if inputMins >= 60 {
                let additionalHours = inputMins / 60
                inputHours += additionalHours
                inputMins = inputMins % 60
            }
            
            // Then, handle hours overflow -> convert to days
            if inputHours >= 24 {
                let additionalDays = inputHours / 24
                let newTotalDays = inputDays + additionalDays
                
                // If total would exceed 1000, cap at 1000 and keep excess in hours
                if newTotalDays > 1000 {
                    let daysToAdd = 1000 - inputDays
                    inputDays = 1000
                    inputHours = inputHours - (daysToAdd * 24)
                } else {
                    inputDays = newTotalDays
                    inputHours = inputHours % 24
                }
            }
            
            // Final clamp to ensure we never exceed 1000
            inputDays = min(1000, max(0, inputDays))
            inputHours = max(0, inputHours)
            inputMins = max(0, min(59, inputMins))
            
            let totalMinutes = Double(inputDays * 24 * 60 + inputHours * 60 + inputMins)
            
            return TimeCalculationResult(
                days: inputDays,
                daysInput: inputDays == 0 ? "0" : String(inputDays),
                hours: inputHours,
                hoursInput: inputHours == 0 ? "0" : String(inputHours),
                minutes: inputMins,
                minutesInput: inputMins == 0 ? "0" : String(inputMins),
                totalMinutes: max(0, totalMinutes)
            )
        } else {
            // Fall back to non-easter egg calculation
            let result = calculateMinutesFromInputs(hoursInput: hoursInput, minutesInput: minutesInput, isEasterEggUnlocked: false)
            return TimeCalculationResult(
                days: 0,
                daysInput: "0",
                hours: result.hours,
                hoursInput: result.hoursInput,
                minutes: result.minutes,
                minutesInput: result.minutesInput,
                totalMinutes: result.totalMinutes
            )
        }
    }
    
    /// Adjust days by amount (easter egg mode)
    static func adjustDays(currentDaysInput: String, currentDays: Int, amount: Int) -> (days: Int, daysInput: String) {
        let currentDays = Int(currentDaysInput) ?? currentDays
        let newDays = min(1000, max(0, currentDays + amount))
        return (days: newDays, daysInput: newDays == 0 ? "0" : String(newDays))
    }
    
    /// Adjust hours by amount
    static func adjustHours(daysInput: String, hoursInput: String, minutesInput: String, currentDays: Int, currentMinutes: Double, amount: Int, isEasterEggUnlocked: Bool) -> TimeCalculationResult {
        if isEasterEggUnlocked {
            var currentDays = Int(daysInput) ?? currentDays
            var currentHours = Int(hoursInput) ?? (Int(currentMinutes) / 60 % 24)
            
            currentHours += amount
            
            // Auto-calculate days from hours
            if currentHours >= 24 {
                let additionalDays = currentHours / 24
                currentDays += additionalDays
                currentHours = currentHours % 24
            } else if currentHours < 0 && currentDays > 0 {
                // Borrow from days if hours go negative
                let borrowDays = (-currentHours + 23) / 24
                currentDays = max(0, currentDays - borrowDays)
                currentHours = currentHours + (borrowDays * 24)
            }
            
            // Clamp days to max 1000
            currentDays = min(1000, max(0, currentDays))
            
            return calculateMinutesFromAllInputs(
                daysInput: currentDays == 0 ? "0" : String(currentDays),
                hoursInput: currentHours == 0 ? "0" : String(max(0, currentHours)),
                minutesInput: minutesInput,
                currentDays: currentDays,
                isEasterEggUnlocked: true
            )
        } else {
            // Original behavior for editing mode
            let currentHours = Int(hoursInput) ?? 0
            let newHours = max(0, min(24, currentHours + amount))
            let result = calculateMinutesFromInputs(
                hoursInput: String(newHours),
                minutesInput: minutesInput,
                isEasterEggUnlocked: false
            )
            return TimeCalculationResult(
                days: 0,
                daysInput: "0",
                hours: result.hours,
                hoursInput: result.hoursInput,
                minutes: result.minutes,
                minutesInput: result.minutesInput,
                totalMinutes: result.totalMinutes
            )
        }
    }
    
    /// Adjust minutes by amount
    static func adjustMinutes(daysInput: String, hoursInput: String, minutesInput: String, currentDays: Int, currentMinutes: Double, amount: Int, isEasterEggUnlocked: Bool) -> TimeCalculationResult {
        if isEasterEggUnlocked {
            var currentDays = Int(daysInput) ?? currentDays
            var currentHours = Int(hoursInput) ?? (Int(currentMinutes) / 60 % 24)
            var currentMins = Int(minutesInput) ?? (Int(currentMinutes) % 60)
            
            currentMins += amount
            var carryHours = 0
            
            if currentMins >= 60 {
                carryHours = currentMins / 60
                currentMins = currentMins % 60
            } else if currentMins < 0 {
                carryHours = (currentMins - 59) / 60
                currentMins = ((currentMins % 60) + 60) % 60
            }
            
            currentHours += carryHours
            
            // Auto-calculate days from hours
            if currentHours >= 24 {
                let additionalDays = currentHours / 24
                currentDays += additionalDays
                currentHours = currentHours % 24
            } else if currentHours < 0 && currentDays > 0 {
                let borrowDays = (-currentHours + 23) / 24
                currentDays = max(0, currentDays - borrowDays)
                currentHours = currentHours + (borrowDays * 24)
            }
            
            // Clamp days to max 1000
            currentDays = min(1000, max(0, currentDays))
            
            return TimeCalculationResult(
                days: currentDays,
                daysInput: currentDays == 0 ? "0" : String(currentDays),
                hours: currentHours,
                hoursInput: currentHours == 0 ? "0" : String(max(0, currentHours)),
                minutes: currentMins,
                minutesInput: currentMins == 0 ? "0" : String(max(0, currentMins)),
                totalMinutes: Double(currentDays * 24 * 60 + currentHours * 60 + currentMins)
            )
        } else {
            // Original behavior for editing mode
            let currentMins = Int(minutesInput) ?? 0
            var newMins = currentMins + amount
            var carryHours = 0
            
            if newMins >= 60 {
                carryHours = 1
                newMins = 0
            } else if newMins < 0 {
                carryHours = -1
                newMins = 59
            }
            
            // If there's a carry, adjust hours directly
            var newHours = Int(hoursInput) ?? 0
            if carryHours != 0 {
                newHours += carryHours
                newHours = max(0, min(24, newHours))
            }
            
            // Calculate final result
            let result = calculateMinutesFromInputs(
                hoursInput: String(newHours),
                minutesInput: String(newMins),
                isEasterEggUnlocked: false
            )
            return TimeCalculationResult(
                days: 0,
                daysInput: "0",
                hours: result.hours,
                hoursInput: result.hoursInput,
                minutes: result.minutes,
                minutesInput: result.minutesInput,
                totalMinutes: result.totalMinutes
            )
        }
    }
    
    // MARK: - Date/Time Conversion Helpers
    
    /// Create a Date from hour and minute components
    static func dateFromTime(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
    
    /// Extract hour and minute from a Date
    static func timeFromDate(_ date: Date) -> (hour: Int, minute: Int) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0, components.minute ?? 0)
    }
    
}

