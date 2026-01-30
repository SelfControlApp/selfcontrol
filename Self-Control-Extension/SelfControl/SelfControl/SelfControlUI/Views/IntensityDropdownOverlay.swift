//
//  IntensityDropdownOverlay.swift
//  SelfControlUI
//
//  Created on 2025-10-31.
//

import SwiftUI

// MARK: - Intensity Dropdown Overlay
struct IntensityDropdownOverlay: View {
    @Binding var selectedLevel: IntensityLevel
    let onDismiss: () -> Void
    @State private var hoveredLevel: IntensityLevel?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Transparent background to catch taps
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onDismiss()
                    }
                
                // Dropdown menu positioned below button
                VStack(spacing: 6) {
                    ForEach(IntensityLevel.allCases, id: \.self) { level in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedLevel = level
                                onDismiss()
                            }
                        }) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(level.displayName)
                                        .font(DesignSystem.font(size: DesignSystem.fontSizeSmall, weight: DesignSystem.fontWeightSemibold))
                                        .foregroundColor(DesignSystem.textPrimary)
                                    
                                    Text(level.description)
                                        .font(DesignSystem.font(size: DesignSystem.fontSizeSmall))
                                        .foregroundColor(DesignSystem.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                                
                                if selectedLevel == level {
                                    Image(systemName: "checkmark")
                                        .font(DesignSystem.font(size: DesignSystem.fontSizeSmall, weight: DesignSystem.fontWeightSemibold))
                                        .foregroundColor(DesignSystem.textPrimary)
                                        .padding(.top, DesignSystem.spacingXXSmall)
                                }
                            }
                            .padding(.horizontal, DesignSystem.spacingMedium)
                            .padding(.vertical, DesignSystem.spacingMediumSmall)
                            .contentShape(Rectangle())
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                    .fill(hoveredLevel == level ? DesignSystem.textPrimary.opacity(DesignSystem.opacityLow) : DesignSystem.textPrimary.opacity(DesignSystem.opacitySubtle))
                            )
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            withAnimation(DesignSystem.animationFast) {
                                hoveredLevel = hovering ? level : nil
                            }
                        }
                    }
                }
                .padding(DesignSystem.spacingXSmall)
                .frame(width: 300)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                        .fill(DesignSystem.backgroundPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                .stroke(DesignSystem.borderPrimary, lineWidth: 1)
                        )
                )
                .shadow(color: DesignSystem.overlayBackground.opacity(DesignSystem.opacityHigh), radius: 16, x: 0, y: 8)
                .position(x: geometry.size.width / 2, y: 180)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
                ))
            }
        }
    }
}

