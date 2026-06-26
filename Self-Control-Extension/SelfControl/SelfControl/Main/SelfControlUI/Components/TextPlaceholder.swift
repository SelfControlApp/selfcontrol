//
//  Untitled.swift
//  SelfControl
//
//  Created by Satendra Singh on 31/03/26.
//

import SwiftUI

// MARK: - Generic placeholder overlay (pure SwiftUI)

public extension View {
    /// Overlays a placeholder view on top of `self` when the provided condition is true.
    /// This keeps taps going to the underlying field by disabling hit testing for the placeholder.
    ///
    /// Example:
    /// TextField("", text: $text)
    ///     .placeholder(when: text.isEmpty, alignment: .leading) {
    ///         Text("Email")
    ///             .foregroundColor(.secondary)
    ///             .font(.body)
    ///     }
    ///
    /// - Parameters:
    ///   - shouldShow: When true, the placeholder is visible.
    ///   - alignment: Alignment for the placeholder inside the overlay.
    ///   - placeholder: The placeholder view builder.
    /// - Returns: A view with the placeholder overlay applied.
    func placeholder<Placeholder: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Placeholder
    ) -> some View {
        ZStack(alignment: alignment) {
            if shouldShow {
                placeholder()
                    .allowsHitTesting(false) // so taps focus the TextField
            }
            self
        }
    }

    /// Convenience for showing a simple `Text` placeholder with color and optional font,
    /// using the same ZStack logic while keeping call sites concise.
    ///
    /// Example:
    /// TextField("", text: $text)
    ///     .textPlaceholder("Email",
    ///                      when: text.isEmpty,
    ///                      color: .secondary,
    ///                      font: .body,
    ///                      verticalPadding: 8)
    ///
    /// - Parameters:
    ///   - title: The placeholder string to display.
    ///   - shouldShow: When true, the placeholder is visible.
    ///   - alignment: Alignment for the placeholder inside the overlay.
    ///   - color: Placeholder text color.
    ///   - font: Optional placeholder font. If nil, inherits from environment.
    ///   - verticalPadding: Optional vertical padding to match your field’s insets.
    /// - Returns: A view with the placeholder overlay applied.
    func textPlaceholder(
        _ title: String,
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        color: Color = .secondary,
        font: Font? = nil,
        verticalPadding: CGFloat? = nil
    ) -> some View {
        placeholder(when: shouldShow, alignment: alignment) {
            var text = Text(title).foregroundColor(color)
            if let font {
                text.font(font)
            }
            if let verticalPadding {
                text.padding(.vertical, verticalPadding)
            }
            text
        }
    }
}
