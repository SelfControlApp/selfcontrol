//
//  SafariExtensionWebView.swift
//  SelfControl
//
//  Created by Satendra Singh on 16/11/25.
//

import SwiftUI
import WebKit
import SafariServices

// A minimal NSViewRepresentable wrapper to show WKWebView in SwiftUI on macOS.
private struct WKWebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No-op for now. You can update navigation or content here if needed.
    }
}

struct SafariExtensionWebView: View {
    // Create a real WKWebView using WKWebViewConfiguration.
    let vm = WebPageViewModel()
    
    var body: some View {
        WKWebViewRepresentable(webView: vm.webView)
            .frame(minHeight: 150)
            .onAppear {
                // Load something if desired, or leave it empty for now.
                // Example:
//                 if let url = URL(string: "https://apple.com") {
//                     vm.webView.load(URLRequest(url: url))
//                 }
//                self.webView.navigationDelegate = self

//                self.webView.configuration.userContentController.add(self, name: "controller")

                self.vm.webView.loadFileURL(Bundle.main.url(forResource: "Main", withExtension: "html")!, allowingReadAccessTo: Bundle.main.resourceURL!)
            }
    }
}

final class WebPageViewModel: NSObject, WKNavigationDelegate, WKScriptMessageHandler  {
    private let extensionManager = SafariExtensionManager.shared
    
    let webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        // Configure as needed (userContentController, preferences, etc.)
        return WKWebView(frame: .zero, configuration: configuration)
    }()
    
    override init() {
        super.init()
        self.webView.navigationDelegate = self
        self.webView.configuration.userContentController.add(self, name: "controller")
    }
    
    private let extensionIdentifier = SafariExtensionConstants.identifier

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {

        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: extensionIdentifier) { (state, error) in
            if let error = error as NSError? {
                print("⚠️ Safari State check error for \(self.extensionIdentifier): \(error.domain) code \(error.code) – \(error.localizedDescription)")
            } else {
                print("🔍 Safari Current state of \(self.extensionIdentifier):", state?.description ?? "Unknown")
                print(state?.isEnabled ?? "Not sure")
                if state?.isEnabled == false {
                    print("⚠️ Safari Extension not enabled in Safari. Please enable it in Settings → Safari → Extensions.")
                }
            }

            DispatchQueue.main.async {
                if #available(macOS 13, *) {
                    webView.evaluateJavaScript("show(\(state?.isEnabled), true)")
                } else {
                    webView.evaluateJavaScript("show(\(state?.isEnabled), false)")
                }
                self.updateSafariExtensionState(state: state?.isEnabled ?? false)
            }
        }
    }
    
    
    private func updateSafariExtensionState(state: Bool) {
        ProxyPreferences.setSafariExtensionState(state)
        IPCConnection.shared.sendMessageToSetActiveBrowserExtension(ActiveBrowserExtensios.safari.rawValue, state: state)
        if state == true {
            updateBlocker()
        }
    }
    
    func updateBlocker() {
        let urls = ProxyPreferences.getBlockedDomains()
        print("URLS: \(urls)")
        BlockListManager.updateSafariBlockList(blockedPaths: urls, appGroup: extensionIdentifier, extensionIdentifier: extensionIdentifier)
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if (message.body as! String != "open-preferences") {
            return;
        }

        SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionIdentifier) { error in
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

#Preview {
    SafariExtensionWebView()
}
