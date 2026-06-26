//
//  CustomComponents.swift
//  SelfControlUI
//
//  Created on 2025-10-31.
//

import SwiftUI
import AppKit

// MARK: - Arrow Key TextField
struct ArrowKeyTextField: NSViewRepresentable {
    @Binding var text: String
    var onUpArrow: () -> Void
    var onDownArrow: () -> Void
    var onSubmit: () -> Void
    var onFocusChange: ((Bool) -> Void)? = nil
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = ArrowKeyNSTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.drawsBackground = false
        textField.alignment = .right
        textField.font = .systemFont(ofSize: 32, weight: .bold)
        textField.textColor = NSColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
        textField.onUpArrow = onUpArrow
        textField.onDownArrow = onDownArrow
        textField.onSubmit = onSubmit
        textField.onFocusChange = onFocusChange
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ArrowKeyTextField
        
        init(_ parent: ArrowKeyTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}

class ArrowKeyNSTextField: NSTextField {
    var onUpArrow: (() -> Void)?
    var onDownArrow: (() -> Void)?
    var onSubmit: (() -> Void)?
    var onFocusChange: ((Bool) -> Void)?
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            onFocusChange?(true)
        }
        return result
    }
    
    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result {
            onFocusChange?(false)
        }
        return result
    }
    
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126: // Up arrow
            onUpArrow?()
        case 125: // Down arrow
            onDownArrow?()
        default:
            super.keyDown(with: event)
        }
    }
}

// MARK: - Checkbox Toggle Style
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .font(DesignSystem.font(size: DesignSystem.fontSizeHeading))
                .foregroundColor(configuration.isOn ? Color.white : Color(white: 0.5))
                .onTapGesture {
                    configuration.isOn.toggle()
                }
            
            configuration.label
        }
    }
}

// MARK: - Custom Switch Toggle Style
struct SwitchToggleStyle: ToggleStyle {
    let tint: Color
    @State private var isHovered = false
    
    init(tint: Color = Color(red: 0.25, green: 0.48, blue: 0.95)) {
        self.tint = tint
    }
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            // Switch pill
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                // Background pill
                Capsule()
                    .fill(configuration.isOn ? Color.white : Color(white: 0.25))
                    .frame(width: 44, height: 24)
                    .overlay(
                        Capsule()
                            .stroke(configuration.isOn ? DesignSystem.textPrimary.opacity(DesignSystem.opacityMedium) : DesignSystem.borderPrimary, lineWidth: 1)
                    )
                    .shadow(color: DesignSystem.overlayBackground.opacity(DesignSystem.opacityMedium), radius: 2, x: 0, y: 1)
                
                // Thumb/knob - warm white when off, dark gray when on
                Circle()
                    .fill(configuration.isOn ? Color(red: 0.2, green: 0.2, blue: 0.22) : Color(red: 0.96, green: 0.95, blue: 0.96))
                    .frame(width: 20, height: 20)
                    .shadow(color: DesignSystem.overlayBackground.opacity(DesignSystem.opacityMedium), radius: 2, x: 0, y: 1)
                    .padding(DesignSystem.spacingXXSmall)
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.75, blendDuration: 0), value: configuration.isOn)
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7, blendDuration: 0), value: isHovered)
            .onTapGesture {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    configuration.isOn.toggle()
                }
            }
            .onHover { hovering in
                isHovered = hovering
            }
            
            configuration.label
        }
    }
}

// MARK: - Hover Hand Cursor Modifier (macOS 11 compatible)
extension View {
    func handCursorOnHover() -> some View {
        self.onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
