//
//  TipsOverlayView.swift
//  SelfControlUI
//
//  Created on 2025-10-31.
//

import SwiftUI

// MARK: - Tips Overlay View
struct TipsOverlayView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            DesignSystem.overlayBackground
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Tips card
            VStack(alignment: .leading, spacing: DesignSystem.spacingLarge) {
                VStack(spacing: 12) {
                    // Header
                    Text(Strings.Tips.title)
                        .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightSemibold))
                        .foregroundColor(DesignSystem.textPrimary)

                    
                    // Tips content
                    VStack(alignment: .leading, spacing: DesignSystem.spacingMedium) {
                        ForEach(Strings.Tips.items) { tip in
                            TipItem(
                                title: tip.title,
                                description: tip.description
                            )
                        }
                    }
                }
                
                // Dismiss button
                HStack(spacing: DesignSystem.spacingSmall) {
                    Spacer()
                    Button(action: onDismiss) {
                        Text(Strings.Tips.gotIt)
                            .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightMedium))
                            .foregroundColor(.white)
                            .frame(width: 80)
                            .padding(.vertical, DesignSystem.spacingXSmall)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                    .fill(DesignSystem.backgroundTertiary)
                            )
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            .padding(DesignSystem.spacingLarge)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                    .fill(DesignSystem.backgroundPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                            .stroke(DesignSystem.borderPrimary, lineWidth: 1)
                    )
            )
            .shadow(color: DesignSystem.overlayBackground.opacity(DesignSystem.opacityHigh), radius: 15, x: 0, y: 5)
        }
    }
}

// MARK: - Tip Item
struct TipItem: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(DesignSystem.font(size: DesignSystem.fontSizeSmall, weight: DesignSystem.fontWeightSemibold))
                .foregroundColor(DesignSystem.textPrimary)
            
            Text(description)
                .font(DesignSystem.font(size: DesignSystem.fontSizeSmall))
                .foregroundColor(DesignSystem.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

