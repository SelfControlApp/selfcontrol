//
//  HelperConnection+ReceivedMessages.swift
//  SelfControl
//
//  Created by Satendra Singh on 19/05/26.
//

extension HelperConnection {
    func didEnableWebExtension(_ extensionTypeRawValue: String, state: Bool) {
//        Task { @MainActor in
            if let ext = WEBExtension(rawValue: extensionTypeRawValue) {
                onExtensionStateChange?(ext, state)
//                switch ext {
//                case .chrome:
//                    NetworkExtensionState.shared.isChromeExtensionEnabled = state
//                case .safari:
//                    NetworkExtensionState.shared.isSafariExtensionEnabled = state
//                }
            }
//        }
    }
    
    func didStartedBlocking(_ state: Bool, _ endDate: Date) -> Void {
        if state == true {
            let minutes: Double = Double(endDate.timeIntervalSinceNow / 60)
            self.blockedStateHandler?(minutes)
        }
        print("REceived Blocked State: \(String(describing: state)), End Date: \(String(describing: endDate))")
    }
}
