//
//  OnBoardingView2.swift
//  SelfControl
//
//  Created by Satendra Singh on 04/02/26.
//

import SwiftUI
import SafariServices

struct OnBoardingInstallSafariExt: View {
    var body: some View {
        VStack {
            Text("Welcome to SelfControl!")
                .font(.largeTitle)
            
            Spacer()
            
            Text("SelfControl helps you focus by blocking your own access to distracting websites.")
                .font(.title2)
            
            Spacer()
            
            Text("To get started, we'll need t o prepare your computer so our blocks work properly.")
                .font(.title2)
            
            Spacer()
            OnboardingStepView(step: 3)

            Text("Install the SelfControl Saari Extension so we can provide better blocking in Safari. We never store, share,o r analyze your data - this i s used o r blocking only.")
                .font(.title2)

            Spacer()
            
            Button("Install Safari Extension") {
                //
                enableExtension()
            }
            
            Spacer()
            ClickableLinkButton(message: "Skip and accept subpar blocking", onTap: {
                print("Handle callback")
            })
            Spacer()
//                .tint(.blue)
        }
        .padding(20)
    }

    func enableExtension() {
        SFSafariApplication.showPreferencesForExtension(withIdentifier: SafariExtensionConstants.identifier) { error in
            if let error = error {
//                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Safari-Settings.extension")!)
                NSLog("Error opening Safari preferences: \(error.localizedDescription)")
                NSWorkspace.shared.openApplication(
                    at: URL(fileURLWithPath: "/Applications/Safari.app"),
                    configuration: NSWorkspace.OpenConfiguration(),
                    completionHandler: nil
                )
            }
        }

//        SFSafariApplication.showPreferencesForExtension(withIdentifier: "com.application.SelfControl.corebits.SelfControl-Safari-Extension") { (error) in
//            if let error = error {
//                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Safari-Settings.extension")!)
//                NSLog("Error opening Safari preferences: \(error.localizedDescription)")
//            }
//        }
    }
}

#Preview {
    OnBoardingInstallSafariExt()
}
