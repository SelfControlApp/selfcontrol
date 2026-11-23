import AppKit
import SwiftUI

enum DelayChoice {
    case blockNow
    case delay(minutes: Int)
}

private final class PromptPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) {}  // Esc doesn't dismiss: an answer is required
}

/// Asks "Is this a good time?" before an app or website is blocked, offering a delay of up to
/// `maxDelayMinutes`. Unanswered prompts block automatically after `timeout`.
@MainActor
final class DelayPromptController {
    static let maxDelayMinutes = 30
    static let timeout: TimeInterval = 60

    private var panel: PromptPanel?
    private(set) var promptingBundleID: String?
    private var token = UUID()

    var isShowing: Bool { promptingBundleID != nil }

    func present(target: BlockTarget, reason: BlockReason, delaysToday: Int, onChoice: @escaping (DelayChoice) -> Void) {
        guard !isShowing else { return }
        let myToken = UUID()
        token = myToken
        promptingBundleID = target.key
        let deadline = Date().addingTimeInterval(Self.timeout)

        let finish: (DelayChoice) -> Void = { [weak self] choice in
            guard let self, self.token == myToken, self.isShowing else { return }
            self.promptingBundleID = nil
            self.panel?.close()
            self.panel = nil
            onChoice(choice)
        }

        let p = PromptPanel(contentRect: NSRect(x: 0, y: 0, width: 440, height: 420),
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

        let host = NSHostingView(rootView: DelayPromptView(target: target, reason: reason, deadline: deadline,
                                                           delaysToday: delaysToday, choose: finish))
        host.frame.size = host.fittingSize
        p.contentView = host
        p.setContentSize(host.fittingSize)
        p.center()
        panel = p
        bringToFront(p)

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.timeout) { finish(.blockNow) }
    }
}

private struct DelayPromptView: View {
    let target: BlockTarget
    let reason: BlockReason
    let deadline: Date
    let delaysToday: Int
    let choose: (DelayChoice) -> Void

    @State private var minutes = 10
    @State private var text = "10"
    @FocusState private var fieldFocused: Bool

    private var parsed: Int? { Int(text.trimmingCharacters(in: .whitespaces)) }
    private var validationMessage: String? {
        guard let m = parsed else { return "Enter a number of minutes." }
        if m < 1 { return "Delay by at least 1 minute." }
        if m > DelayPromptController.maxDelayMinutes { return "Delays can be at most \(DelayPromptController.maxDelayMinutes) minutes." }
        return nil
    }

    var body: some View {
        VStack(spacing: 18) {
            ZStack(alignment: .bottomTrailing) {
                TargetIcon(target: target, size: 72)
                Image(systemName: reasonSymbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(tint.gradient))
                    .overlay(Circle().stroke(.background, lineWidth: 3))
                    .offset(x: 8, y: 6)
            }
            .padding(.top, 6)

            VStack(spacing: 6) {
                Text("Is this a good time?").font(.title2.weight(.semibold))
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                Button { choose(.blockNow) } label: {
                    Text("Yes, Block \(target.name) Now").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(tint)

                HStack(spacing: 8) {
                    Text("Not now. Delay for")
                    TextField("Minutes", text: $text)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 46)
                        .focused($fieldFocused)
                        .onSubmit(delay)
                    Stepper("Minutes", value: Binding(
                        get: { min(max(parsed ?? 10, 1), DelayPromptController.maxDelayMinutes) },
                        set: { text = String($0) }
                    ), in: 1...DelayPromptController.maxDelayMinutes)
                    .labelsHidden()
                    Text("min")
                    Button("Delay", action: delay)
                        .disabled(validationMessage != nil)
                }
                .font(.callout)

                if let validationMessage {
                    Text(validationMessage).font(.caption).foregroundStyle(.red)
                }
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let left = max(0, Int(deadline.timeIntervalSince(context.date).rounded(.up)))
                Text(footer(secondsLeft: left))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
            }
        }
        .padding(28)
        .frame(width: 400)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .padding(30)
        .onAppear { fieldFocused = true }
    }

    private func delay() {
        guard validationMessage == nil, let m = parsed else { return }
        choose(.delay(minutes: m))
    }

    private func footer(secondsLeft: Int) -> String {
        var s = "Blocking automatically in \(secondsLeft)s if you don't answer."
        if delaysToday > 0 { s += "\nYou've delayed \(target.name) \(delaysToday) time\(delaysToday == 1 ? "" : "s") today." }
        return s
    }

    private var message: String {
        switch reason {
        case .limit(_, let limit):
            "You've reached your \(formatDuration(limit)) daily limit on \(target.name). SelfControl is about to block it."
        case .siteLimit(_, let limit):
            "You've spent \(formatDuration(limit)) on \(target.name) today. SelfControl is about to block it until midnight."
        case .downtime(let until):
            "Downtime has started, so \(target.name) is about to be blocked until \(until.formatted(date: .omitted, time: .shortened))."
        case .focus:
            "\(target.name) is about to be blocked."
        }
    }

    private var reasonSymbol: String {
        if case .downtime = reason { return "moon.fill" }
        return "hourglass"
    }

    private var tint: Color {
        if case .downtime = reason { return .indigo }
        return .orange
    }
}
