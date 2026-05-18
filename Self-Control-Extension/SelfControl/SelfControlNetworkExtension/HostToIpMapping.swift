//
//  HostToIpMapping.swift
//  SelfControl
//
//  Created by Satendra Singh on 20/10/25.
//

import Foundation

class HostToIpMapping {
    static func string(for addressData: Data) throws -> String {
        var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        
        let result = addressData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Int32 in
            guard let addrPtr = ptr.baseAddress else {
                return EINVAL
            }
            return getnameinfo(
                addrPtr.assumingMemoryBound(to: sockaddr.self),
                socklen_t(addressData.count),
                &hostBuffer,
                socklen_t(hostBuffer.count),
                nil,
                0,
                NI_NUMERICHOST
            )
        }
        
        if result != 0 {
            let message = String(cString: gai_strerror(result))
            throw NSError(domain: "HostToIpMappingError", code: Int(result), userInfo: [
                NSLocalizedDescriptionKey: message
            ])
        }
        
        return String(cString: hostBuffer)
    }
    
    static func ipAddresses(for domainName: String) -> [String] {
        let startTime = Date()
        
        // ✅ Correct initialization
        let cfHostOpt: CFHost? = CFHostCreateWithName(kCFAllocatorDefault, domainName as CFString).takeRetainedValue()
        guard let cfHost = cfHostOpt else {
            print("HostToIpMapping: Failed to create CFHost for \(domainName)")
            return []
        }
        
        var streamError = CFStreamError()
        let success = CFHostStartInfoResolution(cfHost, .addresses, &streamError)
        
        if !success || streamError.error != 0 {
            print("HostToIpMapping: Warning: failed to resolve addresses for \(domainName) with stream error \(streamError.error)")
            return []
        }
        
        // ✅ Use takeUnretainedValue safely
        guard let addressArray = CFHostGetAddressing(cfHost, nil)?
                .takeUnretainedValue() as? [Data] else {
            print("HostToIpMapping: Warning: failed to resolve addresses for \(domainName)")
            return []
        }
        
        var stringAddresses: [String] = []
        
        for addrData in addressArray {
            do {
                let ip = try string(for: addrData)
                stringAddresses.append(ip)
            } catch {
                print("HostToIpMapping: Warning: Failed to parse IP struct for \(domainName) with error: \(error.localizedDescription)")
            }
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed > 2.5 {
            print("HostToIpMapping: Warning: took \(elapsed) seconds to resolve \(domainName)")
        }
        
        return stringAddresses
    }
}
