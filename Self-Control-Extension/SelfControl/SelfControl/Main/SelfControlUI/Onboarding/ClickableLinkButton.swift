//
//  ClickableLinkButton.swift
//  SelfControl
//
//  Created by Satendra Singh on 04/02/26.
//

import SwiftUI

struct ClickableLinkButton: View {
    let message: String
    var onTap: () -> Void
    var body: some View {
        Text("[\(message)](https://localhost)")
            .environment(\.openURL, OpenURLAction { url in
             handleURL(url)
             return .handled
            })
    }
    func handleURL(_ url: URL) {
        print("Handled URL: \(url)")
        onTap()
     // Customize the action for the URL here
    }
}

#Preview {
    ClickableLinkButton(message: "Skip and accept subpar blocking", onTap: {
    
    })
}
