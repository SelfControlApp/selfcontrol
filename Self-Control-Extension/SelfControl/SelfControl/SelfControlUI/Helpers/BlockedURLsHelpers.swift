//
//  BlockedURLsHelpers.swift
//  SelfControlUI
//
//  Created on 2025-10-31.
//

import Foundation

// MARK: - Blocked URLs Helpers
struct BlockedURLsHelpers {
    /// Get enabled URLs from the blocked URLs list
    private static func enabledURLs(_ blockedURLs: [BlockedURL]) -> [BlockedURL] {
        blockedURLs.filter { $0.isEnabled }
    }
    
    /// Count active blocked domains (sites)
    static func activeBlockedCount(_ blockedURLs: [BlockedURL]) -> Int {
        enabledURLs(blockedURLs).count
    }
    
    /// Count active paths across all enabled domains
    static func activePathCount(_ blockedURLs: [BlockedURL]) -> Int {
        enabledURLs(blockedURLs).reduce(0) { $0 + $1.paths.count }
    }
    
    /// Format blocking count message with separate domain and path counts
    static func blockingCountMessage(_ blockedURLs: [BlockedURL]) -> String {
        let domainCount = activeBlockedCount(blockedURLs)
        let pathCount = activePathCount(blockedURLs)
        
        if domainCount == 0 && pathCount == 0 {
            return "0 \(Strings.BlocklistEditor.sites.lowercased())"
        }
        
        var parts: [String] = []
        if domainCount > 0 {
            parts.append(Strings.BlockedURLs.domainsText(domainCount))
        }
        if pathCount > 0 {
            parts.append(Strings.BlocklistEditor.pathCount(pathCount))
        }
        
        return parts.joined(separator: ", ")
    }
    
    /// Generate unique identifier for blockedURLs state to force view updates
    static func blockedURLsStateId(_ blockedURLs: [BlockedURL]) -> String {
        let domainCount = activeBlockedCount(blockedURLs)
        let pathCount = activePathCount(blockedURLs)
        return "\(domainCount)_\(pathCount)_\(blockedURLs.count)"
    }
    
    /// Format blocked sites text for display
    static func blockedSitesText(_ blockedURLs: [BlockedURL]) -> String {
        if blockedURLs.isEmpty {
            return Strings.BlockedURLs.noSites
        }
        
        let enabled = enabledURLs(blockedURLs)
        
        if enabled.isEmpty {
            return Strings.BlockedURLs.allSitesDisabled
        }
        
        // Count domains and paths separately
        let domainCount = enabled.count
        let totalPathCount = enabled.reduce(0) { $0 + $1.paths.count }
        
        // Only show path name if there's exactly 1 domain and exactly 1 path
        if totalPathCount == 1 && domainCount == 1 {
            if let url = enabled.first, let firstPath = url.paths.first {
                // Remove leading slash if present for display
                let displayPath = firstPath.hasPrefix("/") ? String(firstPath.dropFirst()) : firstPath
                return "\(url.domain)/\(displayPath)"
            }
        }
        
        // Build domain count text
        let domainText: String
        if domainCount == 1 {
            domainText = enabled.first!.domain
        } else if domainCount != blockedURLs.count {
            domainText = Strings.BlockedURLs.domainCount(domainCount, total: blockedURLs.count)
        } else {
            domainText = Strings.BlockedURLs.domainsText(domainCount)
        }
        
        // Combine domain and path counts
        if totalPathCount > 0 {
            return "\(domainText), \(Strings.BlocklistEditor.pathCount(totalPathCount))"
        } else {
            return domainText
        }
    }
    
    /// Parse domain and path from input like "instagram.com/reels"
    static func parseDomainAndPath(from input: String) -> (domain: String, path: String?) {
        let cleaned = input.trimmingCharacters(in: .whitespaces).lowercased()
        
        // Check if input contains a path (has a / after the domain)
        if let slashIndex = cleaned.firstIndex(of: "/") {
            let domainPart = String(cleaned[..<slashIndex])
            var pathPart = String(cleaned[cleaned.index(after: slashIndex)...])
            
            // Ensure path starts with / for consistency
            if !pathPart.hasPrefix("/") {
                pathPart = "/" + pathPart
            }
            
            return (domain: domainPart, path: pathPart)
        }
        
        return (domain: cleaned, path: nil)
    }
}

