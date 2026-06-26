//
//  NetworkExtensionState.swift
//  SelfControl
//
//  Created by Satendra Singh on 26/11/25.
//

import Foundation
import Combine

@MainActor
final class NetworkExtensionState: ObservableObject {
    // MARK: - Published mutable properties
    @Published var isEnabled: Bool
    @Published var isSafariExtensionEnabled: Bool
    @Published var isChromeExtensionEnabled: Bool
//    @Published var isActive: Bool = false

    // Singleton instance, isolated to the MainActor
    static let shared: NetworkExtensionState = NetworkExtensionState(isEnabled: false)
    
    // MARK: - Initializers
    init(isEnabled: Bool, isSafariExtensionEnabled: Bool = false, isChromeExtensionEnabled: Bool = false) {
        self.isEnabled = isEnabled
        self.isSafariExtensionEnabled = isSafariExtensionEnabled
        self.isChromeExtensionEnabled = isChromeExtensionEnabled
    }

    // MARK: - Equatable
    // Equatable conformance compares current values, not identity.
    static func == (lhs: NetworkExtensionState, rhs: NetworkExtensionState) -> Bool {
        lhs.isEnabled == rhs.isEnabled &&
        lhs.isSafariExtensionEnabled == rhs.isSafariExtensionEnabled &&
        lhs.isChromeExtensionEnabled == rhs.isChromeExtensionEnabled
    }

    // MARK: - Focused setters (optional convenience)
    func setIsEnabled(_ newValue: Bool) {
        isEnabled = newValue
    }

    func setSafariExtensionEnabled(_ newValue: Bool) {
        isSafariExtensionEnabled = newValue
    }

    func setChromeExtensionEnabled(_ newValue: Bool) {
        isChromeExtensionEnabled = newValue
    }
    
    func printAll() {
        print("isEnabled: \(isEnabled)")
        print("isSafariExtensionEnabled: \(isSafariExtensionEnabled)")
        print("isChromeExtensionEnabled: \(isChromeExtensionEnabled)")
    }
}
