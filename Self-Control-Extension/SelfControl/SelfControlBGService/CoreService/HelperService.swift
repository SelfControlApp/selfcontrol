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
    let chromeService = ChromeExtensionRequestListner()
    var blockedUrls: [String] = []
    private var timer: DelayTimerHandler?
    private var eventSchedulerController: EventSchedulerRunnerController?
    
    override init() {
        super.init()
        
        eventSchedulerController = EventSchedulerRunnerController(eventRunnerHandler: { [weak self] event in
            os_log("New Event schedule started: \(event.startTime.formatted()) - \(event.endTime.formatted())")

            let minutes = Double(event.endTime.minutes(from: event.startTime, wrapAroundMidnight: true))
            self?.startNetwrokBlocking(minutes: Int(minutes))
        })
    }
    
    func registerClient() {
        os_log("[SC] 🔍] BG registerClient")
        queue.async {
//            self.clients.add(client)
//            client.didUpdateStatus(self.isMonitoring ? "running" : "stopped")
            print("Register Client received")
            self.blockedUrls = HelperAppPreferences.loadlockedUrls() ?? []
        }
        self.sendPing()

        self.chromeService.startListening()
        self.chromeService.blockeddomainFetcher = { [weak self] in
            return self?.blockedUrls ?? []
        }
    }
    
    func proxyConnectionService() -> HelperClientProtocol? {
        var proxy: AnyObject?
        guard let conn = clientConnection else {
            os_log("[SC] 🔍] BG No client connection")
            BGFileLogger.error("BG No client connection")
            return nil
        }
        proxy = conn.remoteObjectProxyWithErrorHandler { err in
            os_log("[SC] 🔍] BG Client proxy error:\(err)")
            BGFileLogger.error("HelperService: proxyConnectionService: Error: \(err)")
           } as AnyObject?
        return proxy as? HelperClientProtocol
    }
    
    func sendPing() {
        os_log("[SC] 🔍] BG HELPER sendPing")
        let schedules = HelperAppPreferences.loadSchedules()
        var details :String = ""
        for schedule in schedules {
            os_log("[SC] 🔍] BG Schedule: \(schedule.summaryString)")
            details.append(schedule.summaryString + "\n")
        }
        proxyConnectionService()?.didEmitEvent("Hello from helper: \(schedules.count), details: \(details)")
    }

    func currentStatus(reply: @escaping (String) -> Void) {
        queue.async {
            reply(self.isMonitoring ? "running" : "stopped")
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
        queue.async { [weak self] in
            HelperAppPreferences.saveSchedulesData(schedules: schedules)
            self?.broadcastEvent("Schedules saved")
            self?.sendPing()
            self?.eventSchedulerController?.startEventScheduler()
            reply(true)
        }
    }
    
    func loadSchedules(reply: @escaping (Data) -> Void) {
        queue.async {
            self.broadcastEvent("Schedules loaded")
            reply(Data())
        }
    }
    
    func saveBlockedUrls(blockedURLS: [String]) {
        queue.async(flags: .barrier) {
            self.blockedUrls = blockedURLS
        }
    }
    
    func startNetwrokBlocking(minutes: Int) {
        os_log("[SC] 🔍] BG startNetwrokBlocking:\(minutes)")
        self.register({ status in
            os_log("[SC] 🔍] BG register NE status: \(status)")
        })
        queue.async { [weak self] in
            self?.startNetworkBlocking()
            self?.timer = DelayTimerHandler(delay: Double(minutes), completionHandler: { [weak self] in
                self?.stopNetworkBlocking()
            }, cancelHandler: { [weak self] in
                self?.stopNetworkBlocking()
            })
            if let queue = self?.queue {
                self?.timer?.timerQueue = queue
            }
            self?.timer?.startTimerWithSelectedDelay()
            if let fireDate = self?.timer?.timerFireDate {
                os_log("[SC] 🔍] BG register NE timer active, firing at: \(fireDate)")
                HelperService.send_didStartedBlocking(true, fireDate)
            }
        }
    }
    
    func stopNetworkBlocking() {
        os_log("[SC] 🔍] BG stopNetworkBlocking")
        timer?.cancelTimer()
        queue.async {
            Task {
                _ = IPCConnection.shared.sendMessageToEnableNetworkExtension(false)
                await AppStateManager.shared.deactivateContentBlocking()
                Sound.checkAndPlay()
            }
        }
    }
    
    func extendBlocking(minutes: Int) {
        os_log("[SC] 🔍] BG extendBlocking: %{public}d", minutes)
        timer?.extendBlocking(minutes: minutes)
    }
    
    func setPreference(key: String, value: Bool) {
        os_log("[SC] 🔍] BG extendBlocking: %{public}@:, %{public}d", key, value)
        HelperAppPreferences.savePreference(key: key, value: value)
    }

    func getBlockedStates(reply: @escaping (_ state: Bool, _ endDate: Date?) -> Void) {
        queue.async { [weak self] in
            Task { [weak self] in
                let state = await AppStateManager.shared.isBlockingEnabled
                if state {
                    if let endDate = self?.timer?.timerFireDate {
                        os_log("[SC] 🔍] BG getBlockedStates Timer active, firing at: \(endDate)")
                        reply(true, endDate)
                    } else {
                        os_log("[SC] 🔍] BG getBlockedStates Timer active, firing NIL")
                        reply(false, nil)
                    }
                    
                } else {
                    os_log("[SC] 🔍] BG getBlockedStates Timer not running")
                    reply(false, nil)
                }
            }
        }
    }

    private func startNetworkBlocking() {
        queue.async {
            Task {
                _ = IPCConnection.shared.sendMessageToEnableNetworkExtension(true)
                await AppStateManager.shared.activateContentBlocking()
                FilterController.restartFilter { result in
                    os_log("[SC] 🔍] BG FilterController.restartFilter: \(result)")
                }

            }
        }
    }
}
