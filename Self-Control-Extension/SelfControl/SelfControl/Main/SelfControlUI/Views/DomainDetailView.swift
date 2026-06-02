//
//  DomainDetailView.swift
//  SelfControlUI
//
//  Created on 2025-10-31.
//

import SwiftUI

// MARK: - Domain Detail View
struct DomainDetailView: View {
    @EnvironmentObject var viewModel: FilterViewModel

    @Binding var blockedURLs: [BlockedURL] {
        didSet {
            saveChanges()
        }
    }
    
    let domainId: UUID
    let isBlockingMode: Bool
    @Binding var currentScreen: AppScreen
    @Binding var blockingMode: BlockingMode
    @State private var newPath: String = ""
    @State private var blockEntireDomain: Bool = true
    @State private var isHoveringAdd: Bool = false
    
    var domain: BlockedURL? {
        blockedURLs.first(where: { $0.id == domainId })
    }
    
    // Get the storage key for this domain's blocking mode preference
    private var storageKey: String {
        "blockEntireDomain_\(domainId.uuidString)"
    }
    
    // Initialize blockEntireDomain from UserDefaults or based on domain state
    private func initializeBlockEntireDomain() {
        blockEntireDomain = UserDefaults.standard.bool(forKey: storageKey)
        if let domain = domain {
            // If domain has paths, always show paths tab (override stored preference)
            if !domain.paths.isEmpty {
                // Update stored preference to match
            } else {
                // No paths - check stored preference or default to true
                if UserDefaults.standard.object(forKey: storageKey) != nil {
                    blockEntireDomain = UserDefaults.standard.bool(forKey: storageKey)
                } else {
                    // No stored preference - default to true (block entire domain)
                    blockEntireDomain = true
                    saveBlockEntireDomainPreference()
                }
            }
        }
    }
    
    // Save the preference when it changes
    private func saveBlockEntireDomainPreference() {
        UserDefaults.standard.set(blockEntireDomain, forKey: storageKey)
        if let index = blockedURLs.firstIndex(where: { $0.id == domainId }) {
            blockedURLs[index].blockEntireDomain = blockEntireDomain
            saveChanges()
        }
    }
    
    var body: some View {
        ZStack {
            DesignSystem.backgroundGradient
                .ignoresSafeArea()
            
            if let domain = domain {
                VStack(spacing: 0) {
                    // Header
                    HStack(alignment: .center) {
                        Button(action: {
                            currentScreen = .editList
                        }) {
                            HStack(spacing: DesignSystem.spacingXXSmall) {
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
                        
                        Text(Strings.DomainDetail.siteSettings)
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
                        .background(DesignSystem.textPrimary.opacity(DesignSystem.opacityLow))
                    
                    ScrollView {
                        VStack(spacing: DesignSystem.spacingMedium) {
                            // Domain info
                            HStack(spacing: 8) {
                                Image(systemName: "globe")
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeXLarge))
                                    .foregroundColor(DesignSystem.textPrimary)
                                
                                Text(domain.domain)
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeXLarge, weight: DesignSystem.fontWeightSemibold))
                                    .foregroundColor(DesignSystem.textPrimary)
                                
                                Spacer()
                            }
                            .padding(DesignSystem.spacingSmall)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                    .fill(DesignSystem.backgroundPrimary.opacity(DesignSystem.opacityHigher))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                            .stroke(DesignSystem.hoverBorder.opacity(DesignSystem.opacityHigher), lineWidth: 1)
                                    )
                            )
                            
                            // Blocking mode selector
                            VStack(alignment: .leading, spacing: 10) {
                                Text(Strings.DomainDetail.blockingMode)
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeSmall, weight: DesignSystem.fontWeightSemibold))
                                    .foregroundColor(DesignSystem.textTertiary)
                                
                                HStack(spacing: 0) {
                                    Button(action: {
                                        if !isBlockingMode {
                                            withAnimation(DesignSystem.animationFast) {
                                                blockEntireDomain = true
                                                saveBlockEntireDomainPreference()
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "globe")
                                                .font(DesignSystem.font(size: DesignSystem.fontSizeMedium))
                                            Text(Strings.DomainDetail.blockEntireDomain)
                                                .font(DesignSystem.font(size: DesignSystem.fontSizeMedium, weight: DesignSystem.fontWeightMedium))
                                        }
                                        .foregroundColor(blockEntireDomain ? DesignSystem.backgroundPrimary : DesignSystem.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, DesignSystem.spacingSmall)
                                        .background(blockEntireDomain ? Color.white : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusSmall))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isBlockingMode)
                                    .opacity(isBlockingMode ? DesignSystem.disabledOpacity : DesignSystem.opacityFull)
                                    .help(isBlockingMode ? Strings.Help.cannotChangeModeDuringBlock : "")
                                    
                                    Button(action: {
                                        if !isBlockingMode {
                                            withAnimation(DesignSystem.animationFast) {
                                                blockEntireDomain = false
                                                saveBlockEntireDomainPreference()
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "list.bullet")
                                                .font(DesignSystem.font(size: DesignSystem.fontSizeMedium))
                                            Text(Strings.DomainDetail.specificPathsOnly)
                                                .font(DesignSystem.font(size: DesignSystem.fontSizeMedium, weight: DesignSystem.fontWeightMedium))
                                        }
                                        .foregroundColor(!blockEntireDomain ? DesignSystem.backgroundPrimary : DesignSystem.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, DesignSystem.spacingSmall)
                                        .contentShape(Rectangle())
                                        .background(!blockEntireDomain ? Color.white : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusSmall))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isBlockingMode)
                                    .opacity(isBlockingMode ? DesignSystem.disabledOpacity : DesignSystem.opacityFull)
                                    .help(isBlockingMode ? Strings.Help.cannotChangeModeDuringBlock : "")
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                        .fill(DesignSystem.backgroundTertiary)
                                )
                                
                                Text(blockEntireDomain ? Strings.DomainDetail.blockEntireDomainDescription : Strings.DomainDetail.specificPathsDescription)
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeBase))
                                    .foregroundColor(DesignSystem.textTertiary)
                            }
                            .padding(DesignSystem.spacingMedium)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                    .fill(DesignSystem.backgroundPrimary.opacity(DesignSystem.opacityHigher))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                            .stroke(DesignSystem.borderPrimary, lineWidth: 1)
                                    )
                            )
                            
                            // Paths section (only shown when not blocking entire domain)
                            if !blockEntireDomain {
                                VStack(alignment: .leading, spacing: DesignSystem.spacingMedium) {
                                    Text(Strings.DomainDetail.pathsAndSubdomains)
                                        .font(DesignSystem.font(size: DesignSystem.fontSizeSmall, weight: DesignSystem.fontWeightSemibold))
                                        .foregroundColor(DesignSystem.textTertiary)
                                    
                                    // Add path
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(DesignSystem.font(size: DesignSystem.fontSizeLarge))
                                            .foregroundColor(DesignSystem.textPrimary)
                                        
                                        ZStack(alignment: .leading) {
                                            TextField("", text: $newPath, onCommit: {
                                                addPath()
                                            })
                                            .textFieldStyle(.plain)
                                            .font(DesignSystem.font(size: DesignSystem.fontSizeMedium))
                                            .foregroundColor(DesignSystem.textPrimary)
                                            .placeholder(when: newPath.isEmpty, alignment: .leading) {
                                                Text(Strings.DomainDetail.addPathPlaceholder)
                                                    .foregroundColor(DesignSystem.disabledText)
                                                    .font(DesignSystem.font(size: DesignSystem.fontSizeMedium))
                                                    .padding(.vertical, 8) // match your field’s vertical insets
                                            }
                                        }
                                        Spacer()
                                            .frame(minWidth: 8)
                                        
                                        Button(action: {
                                            addPath()
                                        }) {
                                            Text(Strings.Common.add)
                                                .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightMedium))
                                                .foregroundColor(DesignSystem.textTertiary)
                                                .padding(.horizontal, DesignSystem.spacingSmall)
                                                .padding(.vertical, DesignSystem.spacingXSmall)
                                                .background(
                                                    RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                                        .fill(isHoveringAdd ? DesignSystem.hoverBackground : Color.clear)
                                                )
                                                .modifier(DesignSystem.buttonStyle())
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(newPath.trimmingCharacters(in: .whitespaces).isEmpty)
                                        .opacity(newPath.trimmingCharacters(in: .whitespaces).isEmpty ? DesignSystem.opacityHigh : DesignSystem.opacityFull)
                                        .focusable(false)
                                        .onHover { hovering in
                                            withAnimation(DesignSystem.animationFast) {
                                                isHoveringAdd = hovering
                                            }
                                        }
                                    }
                                    .padding(.horizontal, DesignSystem.spacingSmall)
                                    .padding(.vertical, DesignSystem.spacingSmallMedium)
                                    .frame(height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                            .fill(DesignSystem.backgroundPrimary)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                                    .stroke(DesignSystem.borderPrimary, lineWidth: 1)
                                            )
                                    )
                                    
                                    // Paths list
                                    if !domain.paths.isEmpty {
                                        VStack(spacing: 6) {
                                            ForEach(domain.paths, id: \.self) { path in
                                                HStack(spacing: 10) {
                                                    Image(systemName: "doc.text")
                                                        .font(DesignSystem.font(size: DesignSystem.fontSizeMedium))
                                                        .foregroundColor(DesignSystem.textPrimary.opacity(DesignSystem.opacityAlmost))
                                                    
                                                    Text(path)
                                                        .font(DesignSystem.font(size: DesignSystem.fontSizeMedium))
                                                        .foregroundColor(DesignSystem.textPrimary)
                                                    
                                                    Spacer()
                                                    
                                                    if !isBlockingMode {
                                                        Button(action: {
                                                            withAnimation {
                                                                if let index = blockedURLs.firstIndex(where: { $0.id == domainId }) {
                                                                    blockedURLs[index].paths.removeAll { $0 == path }
                                                                    saveChanges()
                                                                }
                                                            }
                                                        }) {
                                                            Image(systemName: "xmark.circle.fill")
                                                                .font(DesignSystem.font(size: DesignSystem.fontSizeXXLarge))
                                                                .foregroundColor(DesignSystem.textQuaternary)
                                                        }
                                                        .buttonStyle(.plain)
                                                    }
                                                }
                                                .padding(.horizontal, DesignSystem.spacingMediumSmall)
                                                .padding(.vertical, DesignSystem.spacingSmall)
                                                .background(
                                                    RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                                        .fill(DesignSystem.backgroundSecondary.opacity(DesignSystem.opacityHigher))
                                                )
                                            }
                                        }
                                    } else {
                                        Text(Strings.DomainDetail.noPathsAdded)
                                                        .font(DesignSystem.font(size: DesignSystem.fontSizeMedium))
                                            .foregroundColor(DesignSystem.textTertiary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, DesignSystem.spacingMediumLarge)
                                    }
                                }
                                .padding(DesignSystem.spacingMedium)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                        .fill(DesignSystem.backgroundPrimary.opacity(DesignSystem.opacityHigher))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                                .stroke(DesignSystem.borderPrimary, lineWidth: 1)
                                        )
                                )
                            }
                            
                            Spacer()
                                .frame(height: 20)
                            
                            // Delete button at bottom
                            if !isBlockingMode {
                                Button(action: {
                                    withAnimation {
                                        blockedURLs.removeAll { $0.id == domainId }
                                        currentScreen = .editList
                                        saveChanges()
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 14))
                                        Text(Strings.DomainDetail.deleteSite)
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(DesignSystem.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, DesignSystem.spacingMediumSmall)
                                    .modifier(DesignSystem.buttonStyle(isDestructive: true))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(DesignSystem.spacingLarge)
                    }
                }
            }
        }
        .onAppear {
            initializeBlockEntireDomain()
        }
        .onChange(of: domain?.paths.count ?? 0) { pathCount in
            // If paths are added while viewing, switch to paths tab
            if pathCount > 0 && blockEntireDomain {
                blockEntireDomain = false
                saveBlockEntireDomainPreference()
            }
        }
    }
    
    private func addPath() {
        let cleanPath = newPath.trimmingCharacters(in: .whitespaces)
        let formattedPath = cleanPath.hasPrefix("/") ? cleanPath : "/" + cleanPath
        
        guard !formattedPath.isEmpty else { return }
        guard formattedPath.count > 1 else { return }
        
        if let index = blockedURLs.firstIndex(where: { $0.id == domainId }) {
            if !blockedURLs[index].paths.contains(formattedPath) {
                withAnimation {
                    blockedURLs[index].paths.append(formattedPath)
                    newPath = ""
                    saveChanges()
                }
            }
        }
    }
    
    private func saveChanges() {
        viewModel.saveAndupdateBlockList(blockedURLs)
    }
}

