//
//  SCUtility.swift
//  SelfControl
//
//  Created by Satendra Singh on 26/04/26.
//

import SystemConfiguration

final class SCUtility {

    static func networkConnectionIsAvailable() -> Bool {
        var flags = SCNetworkReachabilityFlags()
        
        guard let target = SCNetworkReachabilityCreateWithName(nil, "google.com"),
              SCNetworkReachabilityGetFlags(target, &flags) else {
            return false
        }        
        return flags.contains(.reachable) && !flags.contains(.connectionRequired)
    }    
}
