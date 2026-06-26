//
//  IntensityHelpers.swift
//  SelfControlUI
//
//  Created on 2025-10-31.
//

import Foundation

// MARK: - Intensity Helpers
struct IntensityHelpers {
    /// Get next intensity level in the cycle
    static func nextIntensity(current: IntensityLevel) -> IntensityLevel {
        let allLevels = IntensityLevel.allCases
        if let currentIndex = allLevels.firstIndex(of: current) {
            let nextIndex = (currentIndex + 1) % allLevels.count
            return allLevels[nextIndex]
        }
        return current
    }
    
    /// Get previous intensity level in the cycle
    static func previousIntensity(current: IntensityLevel) -> IntensityLevel {
        let allLevels = IntensityLevel.allCases
        if let currentIndex = allLevels.firstIndex(of: current) {
            let previousIndex = (currentIndex - 1 + allLevels.count) % allLevels.count
            return allLevels[previousIndex]
        }
        return current
    }
}

