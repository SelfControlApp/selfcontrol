//
//  DesignSystem.swift
//  SelfControlUI
//
//  Created on 2025-10-31.
//

import SwiftUI

struct DesignSystem {
    // MARK: - Corner Radii
    static let radiusXSmall: CGFloat = 4
    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 12
    static let radiusLarge: CGFloat = 16
    static let radiusXLarge: CGFloat = 20
    static let radiusXXLarge: CGFloat = 24
    
    // MARK: - Spacing
    static let spacingTiny: CGFloat = 1.5
    static let spacingXXSmall: CGFloat = 2
    static let spacingXXSmallPlus: CGFloat = 3
    static let spacingXSmall: CGFloat = 6
    static let spacingSmall: CGFloat = 10
    static let spacingSmallMedium: CGFloat = 11
    static let spacingMediumSmall: CGFloat = 12
    static let spacingMedium: CGFloat = 14
    static let spacingMediumLarge: CGFloat = 16
    static let spacingLarge: CGFloat = 18
    static let spacingLargeMinus: CGFloat = 16
    static let spacingXLarge: CGFloat = 24
    static let spacingXLargePlusMedium: CGFloat = 28
    static let spacingXXLarge: CGFloat = 32
    
    // MARK: - Colors
    // Base backgrounds
    static let backgroundPrimary = Color(white: 0.15)
    static let backgroundSecondary = Color(white: 0.12)
    static let backgroundTertiary = Color(white: 0.2)
    
    // Border colors
    static let borderPrimary = Color.white.opacity(0.1)
    static let borderSecondary = Color.white.opacity(0.05)
    
    // Text colors
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.7)
    static let textTertiary = Color(white: 0.5)
    static let textQuaternary = Color(white: 0.4)
    
    // Interactive states
    static let hoverBackground = Color.white.opacity(0.2)
    static let hoverBorder = Color.white.opacity(0.4)
    
    // Modal/Overlay backgrounds
    static let overlayBackground = Color.black.opacity(0.6)
    
    // Disabled state colors
    static let disabledBackground = Color(white: 0.4)
    static let disabledText = Color(white: 0.4)
    
    // Accent colors
    static let accentOrange = Color.orange
    static let accentOrangeMuted = Color.orange.opacity(0.8)
    static let accentPurple = Color.purple
    static let accentPurpleMuted = Color.purple.opacity(0.8)
    static let toggleTint = Color(red: 0.85, green: 0.95, blue: 1.0)
    
    // MARK: - Typography
    static let fontSizeXSmall: CGFloat = 10
    static let fontSizeSmall: CGFloat = 11
    static let fontSizeBase: CGFloat = 12
    static let fontSizeMedium: CGFloat = 13
    static let fontSizeLarge: CGFloat = 14
    static let fontSizeXLarge: CGFloat = 15
    static let fontSizeXXLarge: CGFloat = 16
    static let fontSizeTitle: CGFloat = 18
    static let fontSizeHeading: CGFloat = 20
    static let fontSizeDisplay: CGFloat = 24
    static let fontSizeDisplayLarge: CGFloat = 28
    static let fontSizeDisplayXL: CGFloat = 32
    static let fontSizeDisplayXXL: CGFloat = 36
    static let fontSizeDisplayXXXL: CGFloat = 52
    static let fontSizeDisplayHuge: CGFloat = 64
    
    // Font weights
    static let fontWeightRegular = Font.Weight.regular
    static let fontWeightMedium = Font.Weight.medium
    static let fontWeightSemibold = Font.Weight.semibold
    static let fontWeightBold = Font.Weight.bold
    
    // MARK: - Opacities
    static let opacitySubtle: Double = 0.05
    static let opacityLow: Double = 0.1
    static let opacityMedium: Double = 0.2
    static let opacityHigh: Double = 0.4
    static let opacityHigher: Double = 0.6
    static let opacityAlmost: Double = 0.8
    static let opacityFull: Double = 1.0
    
    // Semantic opacity aliases for common use cases
    static let disabledOpacity: Double = 0.5
    
    // MARK: - Animations
    static let animationFast = Animation.easeInOut(duration: 0.2)
    static let animationNormal = Animation.easeInOut(duration: 0.3)
    
    // MARK: - Gradients
    static let backgroundGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.10, green: 0.10, blue: 0.12),
            Color(red: 0.14, green: 0.14, blue: 0.17),
            Color(red: 0.11, green: 0.11, blue: 0.14)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Mode Colors
    static func modeColor(for mode: BlockingMode) -> Color {
        mode == .blocklist ? Color(red: 0.25, green: 0.48, blue: 0.95) : Color(red: 0.9, green: 0.3, blue: 0.3)
    }
    
    // Muted destructive color
    static let destructiveColor = Color(red: 0.8, green: 0.3, blue: 0.3)
    
    // MARK: - Card Style Modifier
    static func cardStyle() -> some ViewModifier {
        CardStyleModifier()
    }
    
    // MARK: - Button Style Modifier
    static func buttonStyle(color: Color? = nil, isDestructive: Bool = false) -> some ViewModifier {
        ButtonStyleModifier(color: color, isDestructive: isDestructive)
    }
    
    // MARK: - Typography Helpers
    static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    
    static func font(size: CGFloat, weight: Font.Weight, design: Font.Design = .default) -> Font {
        .system(size: size, weight: weight, design: design)
    }
}

// MARK: - Style Modifiers
struct CardStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.radiusLarge)
                    .fill(DesignSystem.backgroundPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.radiusLarge)
                            .stroke(DesignSystem.borderPrimary, lineWidth: 1)
                    )
            )
    }
}

struct ButtonStyleModifier: ViewModifier {
    let color: Color?
    let isDestructive: Bool
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                    .fill(isDestructive ? DesignSystem.destructiveColor.opacity(DesignSystem.opacityLow) : (color?.opacity(DesignSystem.opacityMedium) ?? DesignSystem.backgroundTertiary))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                            .stroke(isDestructive ? DesignSystem.destructiveColor.opacity(DesignSystem.opacityMedium) : (color?.opacity(DesignSystem.opacityMedium) ?? DesignSystem.borderPrimary), lineWidth: 1)
                    )
            )
    }
}
