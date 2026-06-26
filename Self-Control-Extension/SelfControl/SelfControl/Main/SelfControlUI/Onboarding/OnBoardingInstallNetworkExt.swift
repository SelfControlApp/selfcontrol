//
//  OnBoardingView1.swift
//  SelfControl
//
//  Created by Satendra Singh on 01/02/26.
//

import SwiftUI

struct OnBoardingInstallNetworkExt: View {
    @EnvironmentObject var viewModel: FilterViewModel

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
            OnboardingStepView(step: 1)

            Text("Install the SelfControl Network Extension so we can block network traffic in any application in your computer. We never store, share, or analyze your data - this is used or blocking only.")
                .font(.title2)

            Spacer()
            
            Button("Install Network Extension") {
                viewModel.activateExtension()
            }
            
            Spacer()
            ClickableLinkButton(message: "Skip and accept subpar blocking", onTap: {
                print("Handle callback")
                viewModel.isNetworkExtensionSkipped.toggle()
            })
        }
        .padding(20)
    }
}

#Preview {
    OnBoardingInstallNetworkExt()
}
