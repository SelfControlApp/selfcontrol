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
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    var body: some Scene {
        WindowGroup {
            switch viewModel.viewState {
            case .filter:
                NewContentView()
                    .environmentObject(viewModel) // Inject the object into the environment
                    .background(WindowTitleBarHider())
            case .installNetworkExtension:
                OnBoardingInstallNetworkExt()
                    .environmentObject(viewModel) // Inject the object into the environment
                    .frame(width: 520, height: 420)
                
            case .installSafariExtension:
                OnBoardingInstallSafariExt()
                    .environmentObject(viewModel) // Inject the object into the environment
                    .frame(width: 520, height: 420)
                
            case .installChromeExtension:
                OnBoardingInstallChromeExt()
                    .environmentObject(viewModel) // Inject the object into the environment
                    .frame(width: 520, height: 420)
                
                
            default:
                EmptyView()
            }
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .appInfo) {
                Button(Strings.AppMenu.aboutSelfControl) {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowAboutScreen"), object: nil)
                }

                Divider()

                Button(Strings.AppMenu.editSiteList) {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowEditListScreen"), object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)

                  Button(Strings.AppMenu.editBlockSchedule) {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowBlockScheduleScreen"), object: nil)
                }
                .keyboardShortcut("b", modifiers: .command)

                Button(Strings.AppMenu.moreSettings) {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowAdvancedSettingsScreen"), object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)



                Divider()

                Button(Strings.AppMenu.donate) {
                    if let url = URL(string: Strings.AppMenu.URLs.donate) {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            CommandGroup(replacing: .help) {
                Button(Strings.AppMenu.gettingStartedTips) {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowTipsScreen"), object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)

                Divider()

                Button(Strings.AppMenu.selfControlHelp) {
                    if let url = URL(string: Strings.AppMenu.URLs.help) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .keyboardShortcut("?", modifiers: .command)

                Button(Strings.AppMenu.faq) {
                    if let url = URL(string: Strings.AppMenu.URLs.faq) {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        Window("Preferences View", id: "preferences") {
            PreferencesView() // Your view to be presented in the new window
                .environmentObject(viewModel) // Inject the object into the environment
        }
        .windowStyle(.automatic)
    }
    
    private var oldView: some View {
        ContentView()
            .environmentObject(viewModel) // Inject the object into the environment
            .onAppear(perform: {
                appDelegate.onAppClose = {
                    viewModel.stopFilter()
                }
            })
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

extension AppOnboardingViewState {
    init(state: SelfControlViewState) {
        switch state {
        case .installChromeExtension:
            self = .installChromeExtension
        case .installSafariExtension:
            self = .installSafariExtension
        default :
            self = .installNetworkExtension
        }
    }
}
