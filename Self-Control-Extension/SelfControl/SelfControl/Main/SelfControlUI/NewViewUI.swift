//
//  NewViewUI.swift
//  SelfControl
//
//  Created by Satendra Singh on 16/01/26.
//

import SwiftUI

struct NewViewUI {
    static var body: some Scene {
        let windowGroup = WindowGroup {
            NewContentView()
                .background(WindowTitleBarHider())
        }
//        .commands {
//            CommandGroup(replacing: .newItem) { }
//            CommandGroup(replacing: .appInfo) {
//                Button(Strings.AppMenu.aboutSelfControl) {
//                    NotificationCenter.default.post(name: NSNotification.Name("ShowAboutScreen"), object: nil)
//                }
//
//                Divider()
//
//                Button(Strings.AppMenu.editSiteList) {
//                    NotificationCenter.default.post(name: NSNotification.Name("ShowEditListScreen"), object: nil)
//                }
//                .keyboardShortcut("e", modifiers: .command)
//
//                  Button(Strings.AppMenu.editBlockSchedule) {
//                    NotificationCenter.default.post(name: NSNotification.Name("ShowBlockScheduleScreen"), object: nil)
//                }
//                .keyboardShortcut("b", modifiers: .command)
//
//                Button(Strings.AppMenu.moreSettings) {
//                    NotificationCenter.default.post(name: NSNotification.Name("ShowAdvancedSettingsScreen"), object: nil)
//                }
//                .keyboardShortcut(",", modifiers: .command)
//
//
//
//                Divider()
//
//                Button(Strings.AppMenu.donate) {
//                    if let url = URL(string: Strings.AppMenu.URLs.donate) {
//                        NSWorkspace.shared.open(url)
//                    }
//                }
//            }
//            CommandGroup(replacing: .help) {
//                Button(Strings.AppMenu.gettingStartedTips) {
//                    NotificationCenter.default.post(name: NSNotification.Name("ShowTipsScreen"), object: nil)
//                }
//                .keyboardShortcut("t", modifiers: .command)
//
//                Divider()
//
//                Button(Strings.AppMenu.selfControlHelp) {
//                    if let url = URL(string: Strings.AppMenu.URLs.help) {
//                        NSWorkspace.shared.open(url)
//                    }
//                }
//                .keyboardShortcut("?", modifiers: .command)
//
//                Button(Strings.AppMenu.faq) {
//                    if let url = URL(string: Strings.AppMenu.URLs.faq) {
//                        NSWorkspace.shared.open(url)
//                    }
//                }
//            }
//        }

        return windowGroup
    }
}

//// MARK: - Window Configuration Helper (macOS 11 compatible)
struct WindowTitleBarHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                configure(window: window)
            } else if let window = NSApplication.shared.windows.first {
                configure(window: window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            configure(window: window)
        }
    }

    private func configure(window: NSWindow) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.styleMask.insert(.fullSizeContentView)
        // Set a slightly smaller default content size
        if window.contentView?.frame.size.width ?? 0 > 0 {
            window.setContentSize(NSSize(width: 600, height: 450))
        }
    }
}
