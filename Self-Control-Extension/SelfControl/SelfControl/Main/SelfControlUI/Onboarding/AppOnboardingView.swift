//
//  AppOnboardingView.swift
//  SelfControl
//
//  Created by Satendra Singh on 01/02/26.
//

import SwiftUI
enum AppOnboardingViewState {
    case installNetworkExtension
    case installSafariExtension
    case installChromeExtension
}

struct AppOnboardingView: View {
    @State var state: AppOnboardingViewState = .installNetworkExtension
    var body: some View {
        switch state {
        case .installNetworkExtension:
            OnBoardingInstallNetworkExt()
        case .installSafariExtension:
            OnBoardingInstallSafariExt()
        case .installChromeExtension:
            OnBoardingInstallChromeExt()
        }
    }
}

#Preview {
    AppOnboardingView()
}
