//
//  ExtendTimerOverlayView.swift
//  SelfControlUI
//
//  Created on 2026-01-08.
//

import SwiftUI

struct ExtendTimerOverlayView: View {
    @Binding var extensionMinutes: Double
    let onConfirm: (Double) -> Void
    let onDismiss: () -> Void
    @State private var isHoveringCancel = false
    @State private var isHoveringConfirm = false
    @State private var hoursInput: String = "0"
    @State private var minutesInput: String = "0"
    @State private var isAdjustingTime = false
    
    var timeDisplay: String {
        let totalMinutes = Int(extensionMinutes)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours == 0 {
            return "\(minutes)m"
        } else if minutes == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h \(minutes)m"
        }
    }
    
    private func updateMinutesFromInputs() {
        let hours = Int(hoursInput.filter { $0.isNumber }) ?? 0
        let mins = Int(minutesInput.filter { $0.isNumber }) ?? 0
        
        let clampedHours = max(0, min(24, hours))
        let clampedMinutes = max(0, min(59, mins))
        
        hoursInput = String(clampedHours)
        minutesInput = String(clampedMinutes)
        
        extensionMinutes = Double(clampedHours * 60 + clampedMinutes)
    }
    
    private func adjustHours(by amount: Int) {
        let currentHours = Int(hoursInput) ?? 0
        let newHours = max(0, min(24, currentHours + amount))
        hoursInput = String(newHours)
        updateMinutesFromInputs()
    }
    
    private func adjustMinutes(by amount: Int) {
        let currentHours = Int(hoursInput) ?? 0
        let currentMins = Int(minutesInput) ?? 0
        var totalMinutes = currentHours * 60 + currentMins + amount
        
        totalMinutes = max(0, min(1440, totalMinutes))
        
        let newHours = totalMinutes / 60
        let newMins = totalMinutes % 60
        
        hoursInput = String(newHours)
        minutesInput = String(newMins)
        
        extensionMinutes = Double(totalMinutes)
    }
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            DesignSystem.overlayBackground
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Modal content
            VStack(spacing: DesignSystem.spacingMedium) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.plus")
                        .font(DesignSystem.font(size: DesignSystem.fontSizeDisplay))
                        .foregroundColor(DesignSystem.textPrimary)
                    
                    Text("Extend Timer")
                        .font(DesignSystem.font(size: DesignSystem.fontSizeHeading, weight: DesignSystem.fontWeightSemibold))
                        .foregroundColor(DesignSystem.textPrimary)
                    
                    Text("Add more time to your current session")
                        .font(DesignSystem.font(size: DesignSystem.fontSizeSmall))
                        .foregroundColor(DesignSystem.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                // Timer input with arrow buttons
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(DesignSystem.font(size: DesignSystem.fontSizeTitle))
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    DesignSystem.textPrimary.opacity(DesignSystem.opacityAlmost),
                                    DesignSystem.textPrimary.opacity(DesignSystem.opacityHigher)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .mask(
                                Image(systemName: "clock.fill")
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeTitle))
                            )
                        )
                        .shadow(color: DesignSystem.overlayBackground.opacity(DesignSystem.opacityHigh), radius: 2, x: 0, y: 2)
                        .padding(.top, DesignSystem.spacingSmallMedium)
                    
                    HStack(spacing: 6) {
                        // Hours
                        HStack(spacing: 2) {
                            ArrowKeyTextField(
                                text: $hoursInput,
                                onUpArrow: { 
                                    isAdjustingTime = true
                                    adjustHours(by: 1)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isAdjustingTime = false
                                    }
                                },
                                onDownArrow: { 
                                    isAdjustingTime = true
                                    adjustHours(by: -1)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isAdjustingTime = false
                                    }
                                },
                                onSubmit: { 
                                    updateMinutesFromInputs()
                                },
                                onFocusChange: { hasFocus in
                                    if !hasFocus {
                                        updateMinutesFromInputs()
                                    }
                                }
                            )
                            .frame(width: max(40, CGFloat(hoursInput.count) * 20 + 10))
                            
                            VStack(spacing: 2) {
                                Button(action: { 
                                    isAdjustingTime = true
                                    adjustHours(by: 1)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isAdjustingTime = false
                                    }
                                }) {
                                    Image(systemName: "chevron.up")
                                        .font(DesignSystem.font(size: DesignSystem.fontSizeXSmall, weight: DesignSystem.fontWeightBold))
                                        .foregroundColor(DesignSystem.textPrimary)
                                        .frame(width: 20, height: 16)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .focusable(false)
                                
                                Button(action: { 
                                    isAdjustingTime = true
                                    adjustHours(by: -1)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isAdjustingTime = false
                                    }
                                }) {
                                    Image(systemName: "chevron.down")
                                        .font(DesignSystem.font(size: DesignSystem.fontSizeXSmall, weight: DesignSystem.fontWeightBold))
                                        .foregroundColor(DesignSystem.textPrimary)
                                        .frame(width: 20, height: 16)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .focusable(false)
                            }
                            
                            Text(Strings.MainScreen.hours)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeHeading, weight: DesignSystem.fontWeightMedium))
                                .foregroundColor(DesignSystem.textSecondary)
                                .padding(.top, DesignSystem.spacingXSmall)
                        }
                        
                        // Minutes
                        HStack(spacing: 2) {
                            ArrowKeyTextField(
                                text: $minutesInput,
                                onUpArrow: { 
                                    isAdjustingTime = true
                                    adjustMinutes(by: 1)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isAdjustingTime = false
                                    }
                                },
                                onDownArrow: { 
                                    isAdjustingTime = true
                                    adjustMinutes(by: -1)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isAdjustingTime = false
                                    }
                                },
                                onSubmit: { 
                                    updateMinutesFromInputs()
                                },
                                onFocusChange: { hasFocus in
                                    if !hasFocus {
                                        updateMinutesFromInputs()
                                    }
                                }
                            )
                            .frame(width: max(40, CGFloat(minutesInput.count) * 20 + 10))
                            
                            VStack(spacing: 2) {
                                Button(action: { 
                                    isAdjustingTime = true
                                    adjustMinutes(by: 1)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isAdjustingTime = false
                                    }
                                }) {
                                    Image(systemName: "chevron.up")
                                        .font(DesignSystem.font(size: DesignSystem.fontSizeXSmall, weight: DesignSystem.fontWeightBold))
                                        .foregroundColor(DesignSystem.textPrimary)
                                        .frame(width: 20, height: 16)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .focusable(false)
                                
                                Button(action: { 
                                    isAdjustingTime = true
                                    adjustMinutes(by: -1)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isAdjustingTime = false
                                    }
                                }) {
                                    Image(systemName: "chevron.down")
                                        .font(DesignSystem.font(size: DesignSystem.fontSizeXSmall, weight: DesignSystem.fontWeightBold))
                                        .foregroundColor(DesignSystem.textPrimary)
                                        .frame(width: 20, height: 16)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .focusable(false)
                            }
                            
                            Text(Strings.MainScreen.minutes)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeHeading, weight: DesignSystem.fontWeightMedium))
                                .foregroundColor(DesignSystem.textSecondary)
                                .padding(.top, DesignSystem.spacingXSmall)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, DesignSystem.spacingSmall)
                .padding(.bottom, DesignSystem.spacingMedium)
                
                // Action buttons
                HStack(spacing: DesignSystem.spacingSmall) {
                    Button(action: {
                        onDismiss()
                    }) {
                        Text(Strings.Common.cancel)
                            .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightMedium))
                            .foregroundColor(DesignSystem.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.spacingSmall)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                    .fill(isHoveringCancel ? DesignSystem.hoverBackground : Color.clear)
                            )
                            .modifier(DesignSystem.buttonStyle())
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(DesignSystem.animationFast) {
                            isHoveringCancel = hovering
                        }
                    }
                    
                    Button(action: {
                        onConfirm(extensionMinutes)
                    }) {
                        Text("Extend")
                            .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightMedium))
                            .foregroundColor(DesignSystem.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.spacingSmall)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                    .fill(isHoveringConfirm ? DesignSystem.hoverBackground : Color.clear)
                            )
                            .modifier(DesignSystem.buttonStyle())
                    }
                    .buttonStyle(.plain)
                    .disabled(extensionMinutes == 0)
                    .opacity(extensionMinutes == 0 ? DesignSystem.disabledOpacity : DesignSystem.opacityFull)
                    .onHover { hovering in
                        withAnimation(DesignSystem.animationFast) {
                            isHoveringConfirm = hovering
                        }
                    }
                }
                .padding(.top, DesignSystem.spacingSmall)
            }
            .padding(DesignSystem.spacingXLarge)
            .frame(maxWidth: 400)
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
        .onAppear {
            // Initialize inputs from extensionMinutes
            let totalMinutes = Int(extensionMinutes)
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            hoursInput = String(hours)
            minutesInput = String(minutes)
        }
    }
}
