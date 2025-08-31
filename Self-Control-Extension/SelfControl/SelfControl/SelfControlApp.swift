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
  var body: some Scene {
    WindowGroup {
      ContentView()
            .environmentObject(viewModel) // Inject the object into the environment

    }
      Window("Preferences View", id: "preferences") {
          PreferencesView() // Your view to be presented in the new window
              .environmentObject(viewModel) // Inject the object into the environment
      }
      .windowStyle(.automatic)
  }
}
