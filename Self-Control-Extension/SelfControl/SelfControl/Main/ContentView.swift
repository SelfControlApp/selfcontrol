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
    @State private var newDomain = ""

  var body: some View {
    VStack(spacing: 20) {
      // Status indicator with image and text.
        HStack {
            statusView
            Button {
                viewModel.activateExtension()
            } label: {
                Text("Install and Start Network Extension")
            }
            // Start/Stop buttons.
            HStack {
              if viewModel.status == .stopped {
                  Button("Start") {
        //            viewModel.startFilter()
                      viewModel.installLegacyLaunched(futureDuration: Date.now.addingTimeInterval(viewModel.delay*60))
                  }
              }
              if viewModel.status == .running {
                Button("Stop") {
                  viewModel.stopFilter()
                }
              }
            }
        }
        HStack {
            Spacer()
            Slider(value: $viewModel.delay, in: 1...30) {
                Text("Time: \(viewModel.delay, specifier: "%.1f") Minutes")
            }
            Spacer()
        }
      
        Button {
            if viewModel.isActiveBlocking == true {
                viewModel.deactivateNetworkBlocking()
                viewModel.cancelTimer()
            } else {
                if viewModel.status == .stopped {
                    viewModel.installLegacyLaunched(futureDuration: Date.now.addingTimeInterval(viewModel.delay*60))
                } else {
                    if viewModel.startTimerWithSelectedDelay() == false {
                        return
                    }
                    viewModel.activateNetworkBlocking()
                }
            }
        } label: {
            Text(viewModel.isActiveBlocking ? "Deactivate Block" : "Activate Block")
        }

      // Show a progress indicator when in the indeterminate state.
      if viewModel.status == .indeterminate {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle())
      }
//        Button {
//            viewModel.setBlockedUrls(urls: ProxyPreferences.getBlockedDomains())
//        } label: {
//            Text("Enable Url Blocking")
//        }
        HStack {
            Button("Edit Blocklist") {
                openWindow(id: "preferences")
            }
            Spacer()
        }
        SafariExtensionWebView()
            .frame(minHeight: 100)
        
          HStack {
              TextField("Enter Url to test block", text: $newDomain)
              Button("Test Url Blocking") {
                  viewModel.checkUrlRequest(url: newDomain)
              }
          }
        Spacer()
    }
    .padding()
    .frame(minWidth: 150, minHeight: 150)
    .onDisappear {
//        let urls = ProxyPreferences.getBlockedDomains()
        
    }
    .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            AppMover.moveIfNeeded()
        }
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
    }
  }
}

#Preview {
  ContentView()
}

