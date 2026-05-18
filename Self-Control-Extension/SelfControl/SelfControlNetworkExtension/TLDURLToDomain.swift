//
//  TLDURLToDomain.swift
//  SelfControlExtension
//
//  Created by Satendra Singh on 15/10/25.
//

import Foundation

final class TLDURLToDomain {
    func domain(for tldURL: URL) -> String? {
        return tldURL.host
    }
    
    private func extractDomain(from url: URL) -> String? {
        return url.host
    }
    
    
    func getDomain(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else {
            print("Invalid URL string.")
            return nil
        }

        // Using URL.host
        if let host = url.host {
            return host
        }
        return nil
    }
    
    static func getURLDomain(from input: String) -> String? {
        // Normalize input to ensure it has a scheme
        let formatted = input.contains("://") ? input : "https://\(input)"
        guard let host = URL(string: formatted)?.host else { return nil }

        let parts = host.split(separator: ".")
        guard parts.count >= 2 else { return host }

        // Return last two parts (e.g., facebook.com, google.co.uk)
        if parts.count >= 3 && parts[parts.count - 2] == "co" {
            return parts.suffix(3).joined(separator: ".") // handles e.g. google.co.uk
        } else {
            return parts.suffix(2).joined(separator: ".")
        }
    }

}
