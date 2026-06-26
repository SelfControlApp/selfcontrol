//
//  StopConfirmationOverlayView.swift
//  SelfControlUI
//
//  Created on 2025-10-31.
//

import SwiftUI

// MARK: - Stop Confirmation Overlay View
struct StopConfirmationOverlayView: View {
    let countdownTime: TimeInterval
    let onResume: () -> Void
    let onStopBlocking: () -> Void
    @State private var isHoveringStop = false
    @State private var isHoveringResume = false
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            DesignSystem.overlayBackground
                .ignoresSafeArea()
            
            // Confirmation card
            VStack(spacing: DesignSystem.spacingLarge) {
                VStack(spacing: 12) {
                    // Title
                    Text(Strings.StopConfirmation.title)
                        .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightSemibold))
                        .foregroundColor(DesignSystem.textPrimary)
                
                // Circular countdown loader
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(
                            DesignSystem.textPrimary.opacity(DesignSystem.opacityLow),
                            lineWidth: 8
                        )
                        .frame(width: 120, height: 120)
                    
                    // Progress circle (white)
                    Circle()
                        .trim(from: 0, to: CGFloat(countdownTime / 600.0))
                        .stroke(
                            Color.white.opacity(DesignSystem.opacityAlmost),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1.0), value: countdownTime)
                    
                    // Countdown text (mm:ss format)
                    VStack(spacing: 2) {
                        Text(TimeHelpers.formatCountdownTime(countdownTime))
                            .font(DesignSystem.font(size: DesignSystem.fontSizeDisplayXL, weight: DesignSystem.fontWeightBold, design: .monospaced))
                            .foregroundColor(DesignSystem.textPrimary)
                    }
                }
                
                    // Message - single line with dynamic text
                    Text(Strings.StopConfirmation.countdownMessage(countdownTime))
                        .font(DesignSystem.font(size: DesignSystem.fontSizeSmall))
                        .foregroundColor(DesignSystem.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Buttons
                HStack(spacing: DesignSystem.spacingSmall) {
                    // Resume button (more prominent)
                    Button(action: onResume) {
                        Text(Strings.StopConfirmation.resumeBlocking)
                            .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightMedium))
                            .foregroundColor(DesignSystem.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.spacingXSmall)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                    .fill(isHoveringResume ? DesignSystem.hoverBackground : DesignSystem.textPrimary.opacity(DesignSystem.opacityMedium))
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(DesignSystem.animationFast) {
                            isHoveringResume = hovering
                        }
                    }
                    
                    // Subtle Yes button
                    Button(action: onStopBlocking) {
                        Text(Strings.StopConfirmation.yesStopBlocking)
                            .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightMedium))
                            .foregroundColor(DesignSystem.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.spacingXSmall)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                    .fill(isHoveringStop ? DesignSystem.textPrimary.opacity(DesignSystem.opacityLow) : DesignSystem.backgroundTertiary)
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(DesignSystem.animationFast) {
                            isHoveringStop = hovering
                        }
                    }
                    .disabled(countdownTime > 0)
                    .opacity(countdownTime > 0 ? DesignSystem.disabledOpacity : DesignSystem.opacityFull)
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
            .offset(y: -20)
        }
    }
}

