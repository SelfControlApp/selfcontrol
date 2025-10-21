//
//  DNSResolver.swift
//  SelfControl
//
//  Created by Satendra Singh on 21/10/25.
//


import Foundation
import Network

actor DNSResolverActor {
    var resolvedIPs: Set<String> = []
    func resolve(hostURL: [String]) async -> Set<String> {
        var intendedHosts: Set<String> = []
        for url in hostURL {
            print("Resolving: \(url)")
            if let host = DNSResolver.getHost(from: url) {
                intendedHosts.insert(host)
            }
        }
        
            resolvedIPs = []
            for host in intendedHosts {
                let ips = await DNSResolver.resolve(hostname: host)
                print("host: \(host), ips: \(ips)")
                resolvedIPs.formUnion(ips)
            }
        return resolvedIPs
    }
}

/// A modern async DNS resolver using Network.framework
final class DNSResolver {
    static func getHost(from input: String) -> String? {
        var string = input
        if !string.contains("://") {
            string = "https://" + string
        }
        return URL(string: string)?.host
    }

    static func resolve(hostURL: String, timeout: TimeInterval = 5.0) async -> [String] {
        guard let host = getHost(from: hostURL) else { return [] }
        return await resolve(hostname: host, timeout: timeout)
    }
    /// Resolves IPv4/IPv6 addresses for a given domain asynchronously.
    /// - Parameters:
    ///   - hostname: The domain name (e.g. "facebook.com").
    ///   - timeout: Optional timeout in seconds (default 5s).
    /// - Returns: Array of resolved IP addresses as strings.
    static func resolve(hostname: String, timeout: TimeInterval = 5.0) async -> [String] {
        await withCheckedContinuation { continuation in
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true

            // We use the resolver service to resolve DNS asynchronously
            let endpoint = NWEndpoint.hostPort(host: .name(hostname, nil), port: 80)

            let resolver = NWConnection(to: endpoint, using: params)

            var didResume = false

            @Sendable func finish(_ ips: [String]) {
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: ips)
                resolver.cancel()
            }

            resolver.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    // Once ready, we can extract resolved IPs from the endpoint
                    if let remote = resolver.currentPath?.remoteEndpoint,
                       case let .hostPort(host, _) = remote {
                        switch host {
                        case .ipv4(let addr):
                            finish([ipv4ToString(addr)])
                        case .ipv6(let addr):
                            finish([ipv6ToString(addr)])
                        default:
                            finish([])
                        }
                    } else {
                        finish([])
                    }

                case .failed(_):
                    finish([])
                default:
                    break
                }
            }

            // Start resolution
            resolver.start(queue: .global(qos: .userInitiated))

            // Timeout handler
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak resolver] in
                // If still not finished, cancel and return empty
                resolver?.cancel()
                finish([])
            }
        }
    }

    /// Converts IPv4 address to string.
    nonisolated private static func ipv4ToString(_ addr: IPv4Address) -> String {
        let bytes = [UInt8](addr.rawValue)
        guard bytes.count == 4 else { return "" }
        return bytes.map(String.init).joined(separator: ".")
    }

    /// Converts IPv6 address to string.
    nonisolated private static func ipv6ToString(_ addr: IPv6Address) -> String {
        let bytes = [UInt8](addr.rawValue)
        guard bytes.count == 16 else { return "" }
        let segments = stride(from: 0, to: bytes.count, by: 2).map {
            (UInt16(bytes[$0]) << 8) | UInt16(bytes[$0 + 1])
        }
        // Basic hex formatting; does not perform zero-compression (::)
        return segments.map { String(format: "%x", $0) }.joined(separator: ":")
    }
}
