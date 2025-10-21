//
//  SelfControlApp.swift
//  SelfControl
//
//  Created by Egzon Arifi on 02/04/2025.
//

import SwiftUI

@main
struct SelfControlApp: App {
    @StateObject var viewModel = FilterViewModel()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel) // Inject the object into the environment
            
            Button("Test", action: {
                let iPAddress = resolveIPToHostname(ipAddress: "8.8.8.8")
                print("IP: \(iPAddress ?? "Unknown")")
                // Example:
                if let host = reverseDNS(ipAddress: "8.8.8.8") {
                    print("Hostname: \(host)")
                } else {
                    print("Could not resolve.")
                }
                // Example
                if let domain = reverseDNSUsingGetNameInfo(ipAddress: "163.70.145.35") {
                    print("Domain: \(domain)")
                } else {
                    print("Reverse DNS lookup failed.")
                }

            })

        }
        Window("Preferences View", id: "preferences") {
            PreferencesView() // Your view to be presented in the new window
                .environmentObject(viewModel) // Inject the object into the environment
        }
        .windowStyle(.automatic)
    }

    func resolveIPToHostname(ipAddress: String) -> String? {
        let hostRef = CFHostCreateWithName(nil, ipAddress as CFString).takeRetainedValue()
        
        var resolved: DarwinBoolean = false
        if CFHostStartInfoResolution(hostRef, .names, nil) {
            if let names = CFHostGetNames(hostRef, &resolved)?.takeUnretainedValue() as NSArray?,
               let hostname = names.firstObject as? String {
                return hostname
            }
        }
        return nil
    }
    
    func reverseDNS(ipAddress: String) -> String? {
        let hostRef = CFHostCreateWithAddress(nil, ipAddressToData(ipAddress) as CFData).takeRetainedValue()
        var resolved: DarwinBoolean = false
        if CFHostStartInfoResolution(hostRef, .names, nil),
           let names = CFHostGetNames(hostRef, &resolved)?.takeUnretainedValue() as NSArray?,
           let hostname = names.firstObject as? String {
            return hostname
        }
        return nil
    }

    private func ipAddressToData(_ ipAddress: String) -> Data {
        var addr = in_addr()
        inet_pton(AF_INET, ipAddress, &addr)
        return Data(bytes: &addr, count: MemoryLayout<in_addr>.size)
    }
    
    func reverseDNSUsingGetNameInfo(ipAddress: String) -> String? {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        inet_pton(AF_INET, ipAddress, &addr.sin_addr)

        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))

        // Precompute length so we don't read from `addr` inside the closure.
        let addrLen = socklen_t(addr.sin_len)

        let result: Int32 = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                getnameinfo(saPtr,
                            addrLen,
                            &hostname, socklen_t(hostname.count),
                            nil, 0,
                            NI_NAMEREQD)
            }
        }

        guard result == 0 else { return nil }
        return String(cString: hostname)
    }

}
