//
//  AdvancedSettingsView.swift
//  SelfControlUI
//
//  Created on 2025-10-31.
//

import SwiftUI

// MARK: - Advanced Settings View
struct AdvancedSettingsView: View {
    @Binding var currentScreen: AppScreen
    @Binding var blockingMode: BlockingMode
    let isBlockingMode: Bool
    
    // Network Settings
    @AppStorage("verifyConnection") private var verifyConnection = true
    @AppStorage("clearCache") private var clearCache = true
    @AppStorage("allowLocalNetworks") private var allowLocalNetworks = true
    
    // Blocking Settings
    @AppStorage("blockCommonSubdomains") private var blockCommonSubdomains = true
    @AppStorage("highlightInvalidHosts") private var highlightInvalidHosts = true
    @AppStorage("allowlistLinkedSites") private var allowlistLinkedSites = true
    
    // General Settings
    @AppStorage("autoCheckUpdates") private var autoCheckUpdates = true
    @AppStorage("sendErrorReports") private var sendErrorReports = false
    @AppStorage("playSoundOnCompletion") private var playSoundOnCompletion = true
    @AppStorage("timerFloatsOnTop") private var timerFloatsOnTop = false
    @AppStorage("showCountdownInDock") private var showCountdownInDock = true
    
    // Display Settings
    @AppStorage("hideSeconds") private var hideSeconds = false
    
    @State private var showingAllowlistWarning = false
    
    var body: some View {
        ZStack {
            // Dark gradient background
            DesignSystem.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Compact header
                HStack(alignment: .center) {
                    Button(action: {
                        currentScreen = .editList
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightSemibold))
                            Text(Strings.Common.back)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightMedium))
                        }
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    
                    Spacer()
                    
                    Text(Strings.AdvancedSettings.title)
                        .font(DesignSystem.font(size: DesignSystem.fontSizeXXLarge, weight: DesignSystem.fontWeightSemibold))
                        .foregroundColor(DesignSystem.textPrimary)
                    
                    Spacer()
                    
                    Text("")
                        .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightMedium))
                        .foregroundColor(DesignSystem.textSecondary)
                        .frame(width: 60, alignment: .trailing)
                }
                .padding(.horizontal, DesignSystem.spacingLarge)
                .padding(.vertical, DesignSystem.spacingSmall)
                
                Divider()
                    .background(DesignSystem.borderPrimary)
                
                ScrollView {
                    VStack(spacing: 10) {
                        // Blocking Settings
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Strings.AdvancedSettings.blocking)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeSmall, weight: DesignSystem.fontWeightSemibold))
                                .foregroundColor(DesignSystem.textTertiary)
                                .tracking(1.2)
                            
                            VStack(spacing: 0) {
                                settingRow(title: Strings.AdvancedSettings.blockCommonSubdomains, isOn: $blockCommonSubdomains, showDivider: true)
                                settingRow(title: Strings.AdvancedSettings.highlightInvalidHosts, isOn: $highlightInvalidHosts, showDivider: true)
                                settingRow(title: Strings.AdvancedSettings.allowlistLinkedSites, isOn: $allowlistLinkedSites, showDivider: false)
                            }
                        }
                        .padding(DesignSystem.spacingMedium)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                .fill(DesignSystem.backgroundPrimary.opacity(DesignSystem.opacityHigher))
                        )
                        
                        // General Settings
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Strings.AdvancedSettings.general)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeSmall, weight: DesignSystem.fontWeightSemibold))
                                .foregroundColor(DesignSystem.textTertiary)
                                .tracking(1.2)
                            
                            VStack(spacing: 0) {
                                settingRow(title: Strings.AdvancedSettings.autoCheckUpdates, isOn: $autoCheckUpdates, showDivider: true)
                                settingRow(title: Strings.AdvancedSettings.autoSendErrorReports, isOn: $sendErrorReports, showDivider: true)
                                settingRow(title: Strings.AdvancedSettings.playSoundOnCompletion, isOn: $playSoundOnCompletion, showDivider: false)
                            }
                        }
                        .padding(DesignSystem.spacingMedium)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                .fill(DesignSystem.backgroundPrimary.opacity(DesignSystem.opacityHigher))
                        )
                        
                        // Network & Cache
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Strings.AdvancedSettings.networkAndCache)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeSmall, weight: DesignSystem.fontWeightSemibold))
                                .foregroundColor(DesignSystem.textTertiary)
                                .tracking(1.2)
                            
                            VStack(spacing: 0) {
                                settingRow(title: Strings.AdvancedSettings.verifyInternetConnection, isOn: $verifyConnection, showDivider: true)
                                settingRow(title: Strings.AdvancedSettings.clearBrowserCache, isOn: $clearCache, showDivider: true)
                                settingRow(title: Strings.AdvancedSettings.allowLocalNetworks, isOn: $allowLocalNetworks, showDivider: false)
                            }
                        }
                        .padding(DesignSystem.spacingMedium)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                .fill(DesignSystem.backgroundPrimary.opacity(DesignSystem.opacityHigher))
                        )
                        
                        // Display & Timer
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Strings.AdvancedSettings.displayAndTimer)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeSmall, weight: DesignSystem.fontWeightSemibold))
                                .foregroundColor(DesignSystem.textTertiary)
                                .tracking(1.2)
                            
                            VStack(spacing: 0) {
                                settingRow(title: Strings.AdvancedSettings.timerFloatsOnTop, isOn: $timerFloatsOnTop, showDivider: true)
                                settingRow(title: Strings.AdvancedSettings.showCountdownInDock, isOn: $showCountdownInDock, showDivider: true)
                                settingRow(title: Strings.AdvancedSettings.hideSecondsInCountdown, isOn: $hideSeconds, showDivider: false)
                            }
                        }
                        .padding(DesignSystem.spacingMedium)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                .fill(DesignSystem.backgroundPrimary.opacity(DesignSystem.opacityHigher))
                        )
                        
                        // Mode Settings
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Strings.AdvancedSettings.mode)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeSmall, weight: DesignSystem.fontWeightSemibold))
                                .foregroundColor(DesignSystem.textTertiary)
                                .tracking(1.2)
                            
                            // Allowlist mode checkbox with warning
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle(isOn: Binding(
                                    get: { blockingMode == .allowlist },
                                    set: { newValue in
                                        if !isBlockingMode {
                                            if newValue {
                                                showingAllowlistWarning = true
                                            } else {
                                                withAnimation(DesignSystem.animationFast) {
                                                    blockingMode = .blocklist
                                                }
                                            }
                                        }
                                    }
                                )) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.shield.fill")
                                            .font(DesignSystem.font(size: DesignSystem.fontSizeLarge))
                                            .foregroundColor(blockingMode == .allowlist ? Color.white : DesignSystem.textSecondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(Strings.AdvancedSettings.allowlistMode)
                                                .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightMedium))
                                                .foregroundColor(DesignSystem.textPrimary)
                                            Text(Strings.AdvancedSettings.allowlistModeDescription)
                                                .font(DesignSystem.font(size: DesignSystem.fontSizeSmall))
                                                .foregroundColor(DesignSystem.textSecondary)
                                        }
                                    }
                                }
                                .toggleStyle(SwitchToggleStyle(tint: DesignSystem.toggleTint))
                                .disabled(isBlockingMode)
                                .opacity(isBlockingMode ? DesignSystem.disabledOpacity : DesignSystem.opacityFull)
                                .padding(DesignSystem.spacingMedium)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                        .fill(blockingMode == .allowlist ? DesignSystem.textPrimary.opacity(DesignSystem.opacityMedium) : DesignSystem.backgroundTertiary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                                .stroke(blockingMode == .allowlist ? DesignSystem.hoverBorder.opacity(DesignSystem.opacityHigher) : DesignSystem.borderPrimary, lineWidth: 1)
                                        )
                                )
                            }
                        }
                        .padding(DesignSystem.spacingMedium)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                .fill(DesignSystem.backgroundPrimary.opacity(DesignSystem.opacityHigher))
                        )
                    }
                    .padding(DesignSystem.spacingLarge)
                }
            }
        }
        .alert(isPresented: $showingAllowlistWarning) {
            Alert(
                title: Text(Strings.AdvancedSettings.enableAllowlistTitle),
                message: Text(Strings.AdvancedSettings.enableAllowlistMessage),
                primaryButton: .default(Text(Strings.AdvancedSettings.enableAllowlist), action: {
                    withAnimation(DesignSystem.animationFast) {
                        blockingMode = .allowlist
                    }
                }),
                secondaryButton: .cancel(Text(Strings.Common.cancel))
            )
        }
    }
    
    private func settingRow(title: String, isOn: Binding<Bool>, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Toggle(isOn: isOn) {
                    Text(title)
                        .font(DesignSystem.font(size: DesignSystem.fontSizeMedium))
                        .foregroundColor(DesignSystem.textPrimary)
                        .multilineTextAlignment(.leading)
                }
                .toggleStyle(CheckboxToggleStyle())
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignSystem.spacingMediumSmall)
            .padding(.vertical, DesignSystem.spacingSmall)
            
            if showDivider {
                Divider()
                    .background(DesignSystem.borderPrimary)
                    .padding(.leading, 12)
            }
        }
    }
}

