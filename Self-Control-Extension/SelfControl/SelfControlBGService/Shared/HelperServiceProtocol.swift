// Shared/HelperServiceProtocol.swift
import Foundation

// The client protocol allows the helper to send events to the UI app.
@objc public protocol HelperClientProtocol {
    func didUpdateStatus(_ status: String)
    func didEmitEvent(_ message: String)
    func didEnableWebExtension(_ extensionTypeRawValue: String, state: Bool)
    func didStartedBlocking(_ state: Bool, _ endDate: Date)
}

// The service protocol defines the operations the UI app can call on the helper.
@objc public protocol HelperServiceProtocol {
    // One-time registration so the helper can call back into the UI app.
    func registerClient()
    
    func currentStatus(reply: @escaping (String) -> Void)
    // Example command that produces an async result pushed back to the client
    
    //Schedule Save/load
    func saveSchedules(schedules: Data, reply: @escaping (Bool) -> Void)
    func loadSchedules(reply: @escaping (_ schedules: Data) -> Void)
    
    //Start blocking network
    func startNetwrokBlocking(minutes: Int)
    func stopNetworkBlocking()
    func extendBlocking(minutes: Int)
    func setPreference(key: String, value: Bool)
    func setBlockedURLs(_ urls: [String])
    func getBlockedStates(reply: @escaping (_ state: Bool, _ endDate: Date?) -> Void)
    //Save block url list
}

enum WEBExtension: String {
    case chrome
    case safari
}
