//
//  HelperService.swift
//  SelfControl
//
//  Created by Satendra Singh on 17/05/26.
//
import OSLog
import Foundation

final class HelperService: NSObject, HelperServiceProtocol {
    private var isMonitoring = false
    private var clients = NSHashTable<AnyObject>.weakObjects()
    let queue = DispatchQueue(label: "com.application.SelfControl.corebits.bgservice.queue")
    var clientConnection: NSXPCConnection?

    func registerClient() {
        os_log("[SC] 🔍] BG registerClient")
        queue.async {
//            self.clients.add(client)
//            client.didUpdateStatus(self.isMonitoring ? "running" : "stopped")
            print("Register Client received")
            
        }
        self.sendPing()

    }
    
    private func proxyConnectionService() -> HelperClientProtocol? {
        var proxy: AnyObject?
        guard let conn = clientConnection else {
            os_log("[SC] 🔍] BG No client connection")
            return nil
        }
        proxy = conn.remoteObjectProxyWithErrorHandler { err in
            os_log("[SC] 🔍] BG Client proxy error:\(err)")
           } as AnyObject?
        return proxy as? HelperClientProtocol
    }
    
    func sendPing() {
        os_log("[SC] 🔍] BG HELPER sendPing")
        let schedules = EventSchedulerStore.loadSchedules()
        var details :String = ""
        for schedule in schedules {
            os_log("[SC] 🔍] BG Schedule: \(schedule.summaryString)")
            details.append(schedule.summaryString + "\n")
        }
        proxyConnectionService()?.didEmitEvent("Hello from helper: \(schedules.count), details: \(details)")
    }


    func startMonitoring(reply: @escaping (Bool) -> Void) {
        os_log("[SC] 🔍] BG startMonitoring")
        queue.async {
            guard !self.isMonitoring else { reply(true); return }
            self.isMonitoring = true
            self.broadcastStatus()
            // Start your actual background work here (timers, file watchers, etc.)
            reply(true)
        }
    }

    func stopMonitoring(reply: @escaping (Bool) -> Void) {
        os_log("[SC] 🔍] BG stopMonitoring")

        queue.async {
            guard self.isMonitoring else { reply(true); return }
            self.isMonitoring = false
            // Stop your background work
            self.broadcastStatus()
            reply(true)
        }
    }

    func currentStatus(reply: @escaping (String) -> Void) {
        queue.async {
            reply(self.isMonitoring ? "running" : "stopped")
        }
    }

    func performWork(_ input: String, reply: @escaping (Bool) -> Void) {
        queue.async {
            // Do some work…
            self.broadcastEvent("Processed: \(input)")
            reply(true)
        }
    }

    private func broadcastStatus() {
        let status = self.isMonitoring ? "running" : "stopped"
        for client in self.clients.allObjects {
            (client as? HelperClientProtocol)?.didUpdateStatus(status)
        }
    }

    private func broadcastEvent(_ message: String) {
        for client in self.clients.allObjects {
            (client as? HelperClientProtocol)?.didEmitEvent(message)
        }
    }
    
    func saveSchedules(schedules: Data, reply: @escaping (Bool) -> Void) {
        queue.async {
            EventSchedulerStore.saveSchedulesData(schedules: schedules)
            self.broadcastEvent("Schedules saved")
            self.sendPing()
            reply(true)
        }
    }
    
    func loadSchedules(reply: @escaping (Data) -> Void) {
        queue.async {
            self.broadcastEvent("Schedules loaded")
            reply(Data())
        }
    }
}
