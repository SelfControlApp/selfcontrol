//
//  AboutView.swift
//  SelfControlUI
//
//  Created on 2025-10-31.
//

import SwiftUI
import AppKit

// MARK: - About View
struct AboutView: View {
    @Binding var currentScreen: AppScreen
    
    var body: some View {
        ZStack {
            // Dark gradient background
            DesignSystem.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with back button
                HStack(alignment: .center) {
                    Button(action: {
                        currentScreen = .main
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightSemibold))
                            Text(Strings.Common.back)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightMedium))
                        }
                        .foregroundColor(DesignSystem.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    
                    Spacer()
                    
                    Text(Strings.About.title)
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
                    VStack(spacing: DesignSystem.spacingSmall) {
                        // Icon and Title
                        VStack(spacing: 1) {
                            if let nsImage = NSImage(named: "AppIcon") {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                            }
                            Text(Strings.About.appName)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeDisplayLarge, weight: DesignSystem.fontWeightBold))
                                .foregroundColor(DesignSystem.textPrimary)
                            
                            Text(Strings.About.version)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeLarge))
                                .foregroundColor(DesignSystem.textSecondary)
                            
                            AboutItemView(item: Strings.About.mainWebsite)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeMedium))
                        }
                        .padding(.top, DesignSystem.spacingLarge)
                        
                        // Credits section
                        VStack(spacing: DesignSystem.spacingSmall) {
                            // Developers
                            AboutItemsRow(items: Strings.About.developers)
                            
                            // Icon and contributors
                            AboutItemsRow(items: Strings.About.iconAndContributorsLine1)
                            AboutItemsRow(items: Strings.About.iconAndContributorsLine2)
                            
                            // Error reporting
                            AboutItemsRow(items: Strings.About.errorReporting)
                            
                            // License info
                            AboutItemsRow(items: Strings.About.license)
                            
                            // Source code
                            AboutItemsRow(items: Strings.About.sourceCode)
                            
                            // Footer
                            Text(Strings.About.freeAndOpenSource)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeMedium))
                                .foregroundColor(DesignSystem.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, DesignSystem.spacingLarge)
                    .padding(.bottom, DesignSystem.spacingLarge)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - About Item View
struct AboutItemView: View {
    let item: AboutItem
    
    var body: some View {
        switch item.type {
        case .text:
            Text(item.text)
                .foregroundColor(DesignSystem.textPrimary)
        case .link:
            if let urlString = item.url, let url = URL(string: urlString) {
                Link(item.text, destination: url)
            } else {
                Text(item.text)
                    .foregroundColor(DesignSystem.textPrimary)
            }
        }
    }
}

// MARK: - About Items Row
struct AboutItemsRow: View {
    let items: [AboutItem]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                AboutItemView(item: item)
            }
        }
        .font(DesignSystem.font(size: DesignSystem.fontSizeMedium))
        .multilineTextAlignment(.center)
    }
}

