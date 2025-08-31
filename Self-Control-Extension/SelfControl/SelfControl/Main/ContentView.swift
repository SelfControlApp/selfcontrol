//
//  ContentView.swift
//  SelfControl
//
//  Created by Egzon Arifi on 02/04/2025.
//

import SwiftUI
import NetworkExtension
import SystemExtensions
import os.log
import Cocoa

struct ContentView: View {
    @EnvironmentObject var viewModel: FilterViewModel
    @Environment(\.openWindow) private var openWindow

  var body: some View {
    VStack(spacing: 20) {
      // Status indicator with image and text.
        Button {
            viewModel.activateExtension()
        } label: {
            Text("Install and Start Block")
        }
        HStack {
            Spacer()
            Slider(value: $viewModel.delay, in: 1...60) {
                Text("Time: \(viewModel.delay, specifier: "%.1f") Minutes")
            }
            Spacer()
        }
      statusView
      // Show a progress indicator when in the indeterminate state.
      if viewModel.status == .indeterminate {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle())
      }
      
      // Start/Stop buttons.
      HStack {
        if viewModel.status == .stopped {
          Button("Start") {
            viewModel.startFilter()
              
          }
        }
        if viewModel.status == .running {
          Button("Stop") {
            viewModel.stopFilter()
          }
        }
      }
//        Button {
//            viewModel.setBlockedUrls(urls: ProxyPreferences.getBlockedDomains())
//        } label: {
//            Text("Enable Url Blocking")
//        }
    }
    .padding()
    .frame(minWidth: 150, minHeight: 150)
    .onDisappear {
//        let urls = ProxyPreferences.getBlockedDomains()
        
    }
  }
}

private extension ContentView {
  var statusView: some View {
    HStack {
      viewModel.status.color
        .clipShape(Circle())
        .frame(width: 20, height: 20)
      Text("Status: \(viewModel.status.text)")
        Button("Edit Blocklist") {
            openWindow(id: "preferences")

        }
    }
  }
}

#Preview {
  ContentView()
}
