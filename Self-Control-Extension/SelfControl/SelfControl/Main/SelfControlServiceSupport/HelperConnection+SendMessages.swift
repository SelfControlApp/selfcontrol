//
//  HelperConnection+SendMessages.swift
//  SelfControl
//
//  Created by Satendra Singh on 31/05/26.
//

extension HelperConnection {
    func send_startNetwrokBlocking(minutes: Int) {
        bgProxyServiceConnection()?.startNetwrokBlocking(minutes: minutes)
    }
    
    func send_stopNetworkBlocking() {
        bgProxyServiceConnection()?.stopNetworkBlocking()
    }
    
    func send_getBlockedStates() {
        bgProxyServiceConnection()?.getBlockedStates { state, endDate in
            if state == true, let endDate = endDate {
                let minutes: Double = Double(endDate.timeIntervalSinceNow / 60)
                self.blockedStateHandler?(minutes)
            }
            print("REceived Blocked State: \(String(describing: state)), End Date: \(String(describing: endDate))")
        }
    }
    
    func send_extendBlocking(minutes: Int) {
        bgProxyServiceConnection()?.extendBlocking(minutes: minutes)
    }
    
    func send_setPreference(key: String, value: Bool) {
        bgProxyServiceConnection()?.setPreference(key: key, value: value)
    }
}
