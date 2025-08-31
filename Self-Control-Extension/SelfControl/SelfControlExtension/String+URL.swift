//
//  String+URL.swift
//  SelfControlExtension
//
//  Created by Satendra Singh on 05/08/25.
//

import Foundation

extension String {
    var domainString: String? {
        Self.extractDomain(from: self)
    }
    
    static func extractDomain(from urlString: String) -> String? {
        var formattedURLString = urlString
        if !formattedURLString.lowercased().hasPrefix("http://") &&
           !formattedURLString.lowercased().hasPrefix("https://") {
            formattedURLString = "https://" + formattedURLString
        }

        guard let url = URL(string: formattedURLString),
              let host = url.host else {
            return nil
        }

        // Optional: extract root domain (e.g., "facebook.com" from "sub.facebook.com")
        let components = host.components(separatedBy: ".")
        if components.count >= 2 {
            return components.suffix(2).joined(separator: ".")
        } else {
            return host
        }
    }
}
