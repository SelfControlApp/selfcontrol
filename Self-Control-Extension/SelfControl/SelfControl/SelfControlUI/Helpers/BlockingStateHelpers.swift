//
//  BlockingStateHelpers.swift
//  SelfControlUI
//
//  Created on 2025-10-31.
//

import Foundation

// MARK: - Blocking State Helpers
/// Helper functions for managing blocking state and timers
/// Note: These are utility functions. Actual timer management should be handled by the view model/state manager
struct BlockingStateHelpers {
    /// Check if blocking can be stopped based on intensity level
    static func canStopBlocking(intensityLevel: IntensityLevel) -> Bool {
        intensityLevel == .low || intensityLevel == .medium
    }
    
    /// Check if stop confirmation is required based on intensity level
    static func requiresStopConfirmation(intensityLevel: IntensityLevel) -> Bool {
        intensityLevel == .medium
    }
}

