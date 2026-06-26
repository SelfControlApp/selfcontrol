//
//  SimpleRegexConverter.swift
//  SelfControl
//
//  Created by Satendra Singh on 09/10/25.
//

import Foundation

final class SimpleRegexConverter {
    /// Converts a full URL string into a regex domain pattern suitable for Safari content blocker rules.
    /// Example: "https://www.facebook.com/friends" → "https?://(www\\.)?facebook\\.com/.*"
    static func regexPattern(from urlString: String) -> String? {
        guard let url = buildValidURL(from: urlString),
              let host = url.host else {
            return nil
        }
        
        // Escape regex special characters in domain
        let escapedHost = NSRegularExpression.escapedPattern(for: host)
        
        // Detect common "www" prefix and make it optional
        let pattern: String
        if host.hasPrefix("www.") {
            let domainWithoutWWW = String(host.dropFirst(4))
            let escapedDomain = NSRegularExpression.escapedPattern(for: domainWithoutWWW)
            pattern = "https?://(www\\.)?\(escapedDomain)/.*"
        } else {
            pattern = "https?://(www\\.)?\(escapedHost)/.*"
        }
        
        return pattern
    }
    
    static func buildValidURL(from path: String) -> URL? {
        var trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If it's already a valid URL with scheme
        if let url = URL(string: trimmedPath), url.scheme != nil {
            return url
        }
        
        // Add missing scheme (default to https)
        if !trimmedPath.lowercased().hasPrefix("http://") && !trimmedPath.lowercased().hasPrefix("https://") {
            trimmedPath = "https://" + trimmedPath
        }
        
        // Try building again
        guard var components = URLComponents(string: trimmedPath) else {
            return nil
        }
        
        // Fix missing host (e.g., if user entered "example.com/test")
        if components.host == nil {
            let parts = trimmedPath
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
                .split(separator: "/", maxSplits: 1)
            
            if let hostPart = parts.first {
                components.host = String(hostPart)
                components.path = parts.count > 1 ? "/" + parts[1] : ""
            }
        }
        
        // Return final URL
        return components.url
    }
    
    
    static func regexFromURL(_ input: String) -> String? {
        var urlString = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add a scheme if missing (needed for URL parsing)
        if !urlString.lowercased().hasPrefix("http://") &&
            !urlString.lowercased().hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        
        guard let url = URL(string: urlString), let host = url.host else {
            return nil
        }
        
        // Escape host and path for regex
        let escapedHost = NSRegularExpression.escapedPattern(for: host)
        let escapedPath = NSRegularExpression.escapedPattern(for: url.path)
        
        // Build regex:
        // ^[^:]+://+([^.]+\.)*facebook\.com(/friends|[/:]|$)
        // - Matches any scheme (http/https)
        // - Allows any subdomain levels
        // - Matches the path if given
        var regex = #"^[^:]+://+([^.]+\.)*\#(escapedHost)"#
        
        if !escapedPath.isEmpty && escapedPath != "/" {
            regex += escapedPath
        }
        
        regex += #"([/:]|$)"#
        
        return regex
    }
}
