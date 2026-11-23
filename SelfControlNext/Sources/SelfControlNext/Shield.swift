import AppKit
import SwiftUI

/// Shows a panel above everything. macOS 14+ won't let a background app take focus from the app
/// the user is in, so the panel may appear unfocused. The user's first click on it activates
/// SelfControl, and from then on typing goes to the panel.
@MainActor
func bringToFront(_ panel: NSPanel) {
    NSApp.activate()
    panel.orderFrontRegardless()
    panel.makeKey()
}

private final class ShieldPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { close() }
}

/// The floating "this app/website is blocked" screen.
@MainActor
final class ShieldController {
    private var panel: ShieldPanel?
    private var shownFor: (bundleID: String, at: Date)?

    func present(target: BlockTarget, reason: BlockReason) {
        // Don't flicker if we're already showing this shield.
        if let panel, panel.isVisible, let shownFor, shownFor.bundleID == target.key,
           Date().timeIntervalSince(shownFor.at) < 5 {
            return
        }
        panel?.close()

        let p = ShieldPanel(contentRect: NSRect(x: 0, y: 0, width: 440, height: 400),
                            styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .floating
        p.isMovableByWindowBackground = true
        p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Panels hide when their app isn't active by default, and the app usually isn't: the user is
        // in the app being blocked. Without this the panel would be invisible.
        p.hidesOnDeactivate = false

        let view = ShieldView(target: target, reason: reason, dismiss: { [weak p] in p?.close() })
        let host = NSHostingView(rootView: view)
        host.frame.size = host.fittingSize
        p.contentView = host
        p.setContentSize(host.fittingSize)
        p.center()

        panel = p
        shownFor = (target.key, Date())
        bringToFront(p)
    }
}

private struct ShieldView: View {
    let target: BlockTarget
    let reason: BlockReason
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack(alignment: .bottomTrailing) {
                TargetIcon(target: target, size: 84)
                    .saturation(0.2)
                    .opacity(0.85)
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(tint.gradient))
                    .overlay(Circle().stroke(.background, lineWidth: 3))
                    .offset(x: 8, y: 6)
            }
            .padding(.top, 8)

            VStack(spacing: 6) {
                Text(title).font(.title2.weight(.semibold))
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                Button(action: dismiss) {
                    Text("OK").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(tint)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 380)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .padding(30)
    }

    private var title: String {
        switch reason {
        case .focus: "Focus Session"
        case .downtime: "Downtime"
        case .limit, .siteLimit: "Time Limit Reached"
        }
    }

    private var message: String {
        switch reason {
        case .focus(let until):
            "\(target.name) is blocked for your focus session. It will be available again at \(until.formatted(date: .omitted, time: .shortened))."
        case .downtime(let until):
            "\(target.name) isn't available during Downtime. Downtime ends at \(until.formatted(date: .omitted, time: .shortened))."
        case .limit(_, let limit):
            "You've reached your \(formatDuration(limit)) limit on \(target.name) today."
        case .siteLimit(_, let limit):
            "You've spent \(formatDuration(limit)) on \(target.name) today, so it's blocked in every browser until midnight."
        }
    }

    private var symbol: String {
        switch reason {
        case .focus: "lock.fill"
        case .downtime: "moon.fill"
        case .limit, .siteLimit: "hourglass"
        }
    }

    private var tint: Color {
        switch reason {
        case .focus: .red
        case .downtime: .indigo
        case .limit, .siteLimit: .orange
        }
    }
}

/// App icon, or a globe tile for a website.
struct TargetIcon: View {
    let target: BlockTarget
    let size: CGFloat

    var body: some View {
        switch target {
        case .app(let app):
            AppIconView(app: app, size: size)
        case .website:
            Image(systemName: "globe")
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).fill(Color.teal.gradient))
        }
    }
}
