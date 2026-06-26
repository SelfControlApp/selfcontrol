//
//  OnBoardingInstallChromeExt.swift
//  SelfControl
//
//  Created by Satendra Singh on 08/02/26.
//


import SwiftUI

struct OnBoardingInstallChromeExt: View {
    @EnvironmentObject var viewModel: FilterViewModel
    
    var body: some View {
        VStack {
            Text("Welcome to SelfControl!")
                .font(.largeTitle)
            
            Spacer()
            
            Text("SelfControl helps you focus by blocking your own access to distracting websites.")
                .font(.title2)
            
            Spacer()
            
            Text("To get started, we'll need to prepare your computer so our blocks work properly.")
                .font(.title2)
            
            Spacer()
            OnboardingStepView(step: 2)

            Text("Install the SelfControl Chrome Extension so we can provide better blocking in Chrome. We never store, share, or analyze your data - this is used or blocking.")
                .font(.title2)

            Spacer()
            
            Button("Install Chrome Extension") {
                //
//                if let url = URL(string: "chrome://extensions") {
//                    NSWorkspace.shared.open(url)
//                }
                let task = Process()
                task.launchPath = "/usr/bin/open"
                task.arguments = ["-a", "Google Chrome", "https://chromewebstore.google.com/detail/selfcontrol-blocker/lmpnckgcpefbmipnbfcickkaakpgbdhj"]
                task.launch()
            }
            
            Spacer()
            ClickableLinkButton(message: "Skip and accept subpar blocking", onTap: {
                print("Handle callback")
                AppPreferences.setChromeExtensionInstalled()
                viewModel.updateChromeExtensionViewStatus()
            })
            Spacer()
//                .tint(.blue)
        }
        .padding(20)
    }
}

#Preview {
    OnBoardingInstallChromeExt()
}
