//
//  BlocklistEditorView.swift
//  SelfControlUI
//
//  Created on 2025-10-31.
//

import SwiftUI
struct BlocklistEditorView: View {
    @EnvironmentObject var viewModel: FilterViewModel

    @Binding var blockedURLs: [BlockedURL] {
        didSet {
            saveChanges()
        }
    }
    let isBlockingMode: Bool
    @Binding var blockingMode: BlockingMode
    @Binding var currentScreen: AppScreen
    @Binding var showingTips: Bool
    @State private var newSite: String = ""
    @State private var newPath: String = ""
    @State private var searchText: String = ""
    @AppStorage("showSuggestedSites") private var showSuggested: Bool = false
    @State private var selectedDomain: UUID? = nil
    @State private var focusedField: EditorFocusField?
    @State private var showingAddSiteConfirmation = false
    @State private var pendingSiteToAdd: String? = nil
    @State private var isBulkEditMode: Bool = false
    @State private var selectedURLs: Set<UUID> = []
    @State private var lastSelectedIndex: Int? = nil
    @State private var showingDeleteConfirmation: Bool = false
    @State private var isSearchMode: Bool = false
    @State private var isHoveringSuggestedChip = false
    @State private var isHoveringBulkEdit = false
    @State private var isHoveringImport = false
    @State private var isHoveringExport = false
    @State private var isHoveringAdd = false
    
    enum EditorFocusField: Hashable {
        case addWebsite
        case search
        case addPath
        case doneButton
    }
    
    // Suggested sites for quick adding
    let suggestedSites = DomainConstants.suggestedSites
    
    var filteredURLs: [BlockedURL] {
        if searchText.isEmpty {
            return blockedURLs.sorted { $0.domain < $1.domain }
        }
        return blockedURLs.filter { url in
            url.domain.localizedCaseInsensitiveContains(searchText) ||
            url.paths.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }.sorted { $0.domain < $1.domain }
    }
    
    var totalCount: Int {
        blockedURLs.count + blockedURLs.reduce(0) { $0 + $1.paths.count }
    }
    
    func handleCheckboxClick(for urlId: UUID, at index: Int, isShiftPressed: Bool = false) {
        if isShiftPressed, let lastIndex = lastSelectedIndex {
            // Shift-select: select range from lastSelectedIndex to current index
            let startIndex = min(lastIndex, index)
            let endIndex = max(lastIndex, index)
            let range = startIndex...endIndex
            
            let isCurrentlySelected = selectedURLs.contains(urlId)
            
            // Toggle all items in range
            for i in range {
                let itemId = filteredURLs[i].id
                if isCurrentlySelected {
                    selectedURLs.remove(itemId)
                } else {
                    selectedURLs.insert(itemId)
                }
            }
        } else {
            // Normal click: toggle single item
            if selectedURLs.contains(urlId) {
                selectedURLs.remove(urlId)
            } else {
                selectedURLs.insert(urlId)
            }
            lastSelectedIndex = index
        }
    }
    
    func deleteSelectedURLs() {
        withAnimation(DesignSystem.animationFast) {
            // Create a new array without the selected items
            blockedURLs = blockedURLs.filter { !selectedURLs.contains($0.id) }
            selectedURLs.removeAll()
            
            // Clear bulk edit mode if no URLs left
            if blockedURLs.isEmpty {
                isBulkEditMode = false
            }
        }
    }
    
    var headerSubtitleText: String {
        let enabledCount = blockedURLs.filter { $0.isEnabled }.count
        let pathCount = blockedURLs.reduce(0) { $0 + $1.paths.count }
        
        if enabledCount != blockedURLs.count {
            return "\(enabledCount)/\(blockedURLs.count) enabled" + (pathCount > 0 ? ", \(pathCount) paths" : "")
        } else if pathCount > 0 {
            return "\(blockedURLs.count) domain\(blockedURLs.count == 1 ? "" : "s"), \(pathCount) path\(pathCount == 1 ? "" : "s")"
        } else {
            return "\(blockedURLs.count) website\(blockedURLs.count == 1 ? "" : "s")"
        }
    }
    
    var headerView: some View {
        HStack(alignment: .center) {
            // Back button
            Button(action: {
                selectedDomain = nil
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
            
            // Import button
            Button(action: {
                // TODO: Import functionality
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                        .font(DesignSystem.font(size: DesignSystem.fontSizeBase))
                    Text(Strings.Common.importText)
                        .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightMedium))
                }
                .foregroundColor(DesignSystem.textPrimary)
                .padding(.horizontal, DesignSystem.spacingSmall)
                .padding(.vertical, DesignSystem.spacingXSmall)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                        .fill(isHoveringImport ? DesignSystem.hoverBackground : Color.clear)
                )
                .modifier(DesignSystem.buttonStyle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .onHover { hovering in
                withAnimation(DesignSystem.animationFast) {
                    isHoveringImport = hovering
                }
            }
            
            // Export button
            Button(action: {
                // TODO: Export functionality
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(DesignSystem.font(size: DesignSystem.fontSizeBase))
                    Text(Strings.Common.export)
                        .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightMedium))
                }
                .foregroundColor(DesignSystem.textPrimary)
                .padding(.horizontal, DesignSystem.spacingSmall)
                .padding(.vertical, DesignSystem.spacingXSmall)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                        .fill(isHoveringExport ? DesignSystem.hoverBackground : Color.clear)
                )
                .modifier(DesignSystem.buttonStyle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .onHover { hovering in
                withAnimation(DesignSystem.animationFast) {
                    isHoveringExport = hovering
                }
            }
        }
        .overlay(
            Text(blockingMode == .blocklist ? Strings.BlocklistEditor.title : Strings.BlocklistEditor.allowlist)
                .font(DesignSystem.font(size: DesignSystem.fontSizeXXLarge, weight: DesignSystem.fontWeightSemibold))
                .foregroundColor(DesignSystem.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
        )
    }
    
    var body: some View {
        ZStack {
            // Dark gradient background
            DesignSystem.backgroundGradient
                .ignoresSafeArea(.all)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            VStack(spacing: 0) {
                // Compact header
                headerView
                    .padding(.horizontal, DesignSystem.spacingLarge)
                    .padding(.vertical, DesignSystem.spacingSmall)
                
                Divider()
                    .background(DesignSystem.borderPrimary)
                
                // Allowlist mode warning banner
                if blockingMode == .allowlist {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(DesignSystem.font(size: DesignSystem.fontSizeLarge))
                            .foregroundColor(DesignSystem.textPrimary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Strings.BlocklistEditor.allowlistModeActive)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeSmall, weight: DesignSystem.fontWeightBold))
                                .foregroundColor(DesignSystem.textPrimary)
                            Text(Strings.BlocklistEditor.allowlistModeDescription)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeSmall))
                                .foregroundColor(DesignSystem.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(DesignSystem.spacingMedium)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                            .fill(DesignSystem.textPrimary.opacity(DesignSystem.opacityMedium))
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                    .stroke(DesignSystem.hoverBorder.opacity(DesignSystem.opacityHigher), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, DesignSystem.spacingLarge)
                    .padding(.top, DesignSystem.spacingMedium)
                }
                
                // Combined add and search section
                HStack(spacing: DesignSystem.spacingSmall) {
                    // Add website / Search (toggles based on isSearchMode)
                        HStack(spacing: 8) {
                        // Icon - animated transition
                        Group {
                            if isSearchMode {
                            Image(systemName: "magnifyingglass")
                                .font(DesignSystem.font(size: DesignSystem.fontSizeLarge))
                                    .foregroundColor(DesignSystem.textPrimary)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeLarge))
                                    .foregroundColor(DesignSystem.textPrimary)
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        
                        // TextField - animated transition
                        Group {
                            if isSearchMode {
                            TextField(Strings.BlocklistEditor.searchPlaceholder, text: $searchText)
                                .textFieldStyle(.plain)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeMedium))
                                .foregroundColor(DesignSystem.textPrimary)
                            } else {
                                TextField(Strings.BlocklistEditor.addWebsitePlaceholder, text: $newSite, onCommit: {
                                    addWebsite()
                                })
                                    .textFieldStyle(.plain)
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeMedium))
                                    .foregroundColor(DesignSystem.textPrimary)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                        
                        // Spacer to push button to the right
                        if isSearchMode {
                            Spacer()
                                .frame(minWidth: 8)
                        }
                            
                        // Close/Add button area - maintains consistent width
                        Group {
                            if isSearchMode {
                            Button(action: {
                                    withAnimation(DesignSystem.animationNormal) {
                                isSearchMode = false
                                searchText = ""
                                focusedField = .addWebsite
                                    }
                            }) {
                                    Text(Strings.Common.cancel)
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
                            .help(Strings.Help.closeSearch)
                            .onHover { hovering in
                                withAnimation(DesignSystem.animationFast) {
                                    isHoveringAdd = hovering
                                }
                            }
                    } else {
                            Button(action: {
                                addWebsite()
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
                            .disabled(newSite.trimmingCharacters(in: .whitespaces).isEmpty)
                            .opacity(newSite.trimmingCharacters(in: .whitespaces).isEmpty ? DesignSystem.opacityHigh : DesignSystem.opacityFull)
                            .focusable(false)
                            .onHover { hovering in
                                withAnimation(DesignSystem.animationFast) {
                                    isHoveringAdd = hovering
                                }
                            }
                            .help(Strings.Help.addSite)
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                        .padding(.horizontal, DesignSystem.spacingSmall)
                        .padding(.vertical, DesignSystem.spacingSmallMedium)
                    .frame(height: 44) // Fixed height to prevent size changes
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                .fill(DesignSystem.backgroundPrimary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                    .stroke((isSearchMode && focusedField == .search) || (!isSearchMode && focusedField == .addWebsite) ? DesignSystem.textPrimary : DesignSystem.borderPrimary, lineWidth: 1)
                                )
                        )
                    .animation(DesignSystem.animationNormal, value: isSearchMode)
                    .animation(DesignSystem.animationNormal, value: searchText.isEmpty)
                    
                    // Search icon (replaces gear icon) - minimal spacing
                    Button(action: {
                        withAnimation(DesignSystem.animationNormal) {
                        isSearchMode.toggle()
                        if isSearchMode {
                            focusedField = .search
                        } else {
                            searchText = ""
                            focusedField = .addWebsite
                            }
                        }
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(DesignSystem.font(size: DesignSystem.fontSizeXXLarge))
                                    .foregroundColor(isSearchMode ? DesignSystem.textPrimary : DesignSystem.textTertiary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .help(isSearchMode ? Strings.Help.closeSearch : Strings.Help.search)
                    .padding(.leading, DesignSystem.spacingXXSmall)
                }
                .padding(.horizontal, DesignSystem.spacingLarge)
                .padding(.vertical, DesignSystem.spacingSmall)
                
                Divider()
                    .background(DesignSystem.borderPrimary)
                
                // Hierarchical tree list
                urlListView
                
                // Bottom action bar
                bottomActionBar
            }
            
            // Delete confirmation modal overlay - placed last to appear on top
            if showingDeleteConfirmation {
                DesignSystem.overlayBackground
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingDeleteConfirmation = false
                    }
                
                VStack(spacing: DesignSystem.spacingMedium) {
                    let count = selectedURLs.count
                    
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(DesignSystem.font(size: DesignSystem.fontSizeDisplay))
                            .foregroundColor(DesignSystem.destructiveColor)
                        
                        Text(Strings.BlocklistEditor.deleteSiteTitle(count))
                            .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightSemibold))
                            .foregroundColor(DesignSystem.textPrimary)
                        
                        Text(Strings.BlocklistEditor.deleteSiteMessage(count))
                            .font(DesignSystem.font(size: DesignSystem.fontSizeSmall))
                            .foregroundColor(DesignSystem.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    HStack(spacing: DesignSystem.spacingSmall) {
                        Button(action: {
                            showingDeleteConfirmation = false
                        }) {
                            Text(Strings.Common.cancel)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightMedium))
                                .foregroundColor(DesignSystem.textPrimary)
                                .frame(width: 80)
                                .padding(.vertical, DesignSystem.spacingXSmall)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                        .fill(DesignSystem.backgroundTertiary)
                                )
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            deleteSelectedURLs()
                            showingDeleteConfirmation = false
                        }) {
                            Text(Strings.Common.delete)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightMedium))
                                .foregroundColor(DesignSystem.textPrimary)
                                .frame(width: 80)
                                .padding(.vertical, DesignSystem.spacingXSmall)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                        .fill(DesignSystem.destructiveColor)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(DesignSystem.spacingMedium)
                .frame(maxWidth: 320)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                        .fill(DesignSystem.backgroundPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                .stroke(DesignSystem.borderPrimary, lineWidth: 1)
                        )
                )
                .shadow(color: DesignSystem.overlayBackground.opacity(DesignSystem.opacityHigh), radius: 15, x: 0, y: 5)
                .zIndex(999)
            }
        }
        .alert(isPresented: $showingAddSiteConfirmation) {
            let site = pendingSiteToAdd ?? "this site"
            return Alert(
                title: Text(Strings.BlocklistEditor.addToExistingBlockTitle),
                message: Text(Strings.BlocklistEditor.addToExistingBlockMessage(site, blockingMode: blockingMode)),
                primaryButton: .default(Text(Strings.BlocklistEditor.addSite), action: {
                    confirmAddWebsite()
                }),
                secondaryButton: .cancel(Text(Strings.Common.cancel), action: {
                    pendingSiteToAdd = nil
                })
            )
        }
        .onAppear {
            // Reset to list view and focus on add website field when editor opens
            selectedDomain = nil
            focusedField = .addWebsite
        }
    }
    
    var addWebsiteSection_UNUSED: some View {
        VStack(spacing: DesignSystem.spacingMedium) {
                    HStack(spacing: DesignSystem.spacingSmall) {
                        Image(systemName: "plus.circle.fill")
                            .font(DesignSystem.font(size: DesignSystem.fontSizeHeading))
                            .foregroundColor(DesignSystem.textPrimary)
                        
                    TextField(Strings.BlocklistEditor.addWebsiteExamplePlaceholder, text: $newSite, onCommit: { addWebsite() })
                        .textFieldStyle(.plain)
                        .font(DesignSystem.font(size: DesignSystem.fontSizeXLarge))
                        .foregroundColor(DesignSystem.textPrimary)
                        .padding(DesignSystem.spacingSmall)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                .fill(DesignSystem.backgroundPrimary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                        .stroke(focusedField == .addWebsite ? DesignSystem.textPrimary : DesignSystem.borderPrimary, lineWidth: focusedField == .addWebsite ? 2 : 1)
                                )
                        )
                        
                        
                        Button(action: addWebsite) {
                            Text(Strings.Common.add)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightMedium))
                                .foregroundColor(DesignSystem.textPrimary)
                                .padding(.horizontal, DesignSystem.spacingLarge)
                                .padding(.vertical, DesignSystem.spacingSmall)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                        .fill(DesignSystem.textPrimary)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(newSite.isEmpty)
                        .opacity(newSite.isEmpty ? DesignSystem.disabledOpacity : DesignSystem.opacityFull)
                    }
                    
                    // Suggested chip
                    if !suggestedSites.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.spacingSmall) {
                            Text(Strings.BlocklistEditor.quickAdd)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightMedium))
                                .foregroundColor(DesignSystem.textTertiary)
                                .textCase(.uppercase)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    Button(action: {
                                        showSuggested.toggle()
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "lightbulb")
                                                .font(DesignSystem.font(size: DesignSystem.fontSizeBase))
                                            Text(Strings.BlocklistEditor.suggested)
                                                .font(DesignSystem.font(size: DesignSystem.fontSizeMedium, weight: DesignSystem.fontWeightMedium))
                                        }
                                        .foregroundColor(showSuggested ? DesignSystem.textTertiary : DesignSystem.textSecondary)
                                        .padding(.horizontal, DesignSystem.spacingMedium)
                                        .padding(.vertical, DesignSystem.spacingXSmall)
                                        .background(
                                            RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                                .fill(showSuggested ? DesignSystem.backgroundPrimary : DesignSystem.backgroundTertiary)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            // Show all suggested sites
                            if showSuggested {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(suggestedSites, id: \.self) { site in
                                            let isAlreadyBlocked = blockedURLs.contains { $0.domain == site }
                                            Button(action: {
                                                if !isAlreadyBlocked {
                                                    // Add without animation to prevent blink
                                                    // showSuggested is @AppStorage so it persists automatically
                                                    var transaction = Transaction()
                                                    transaction.disablesAnimations = true
                                                    withTransaction(transaction) {
                                                        blockedURLs.append(BlockedURL(domain: site))
                                                    }
                                                }
                                            }) {
                                                HStack(spacing: 6) {
                                                    Text(site)
                                                        .font(DesignSystem.font(size: DesignSystem.fontSizeBase))
                                                    Image(systemName: isAlreadyBlocked ? "checkmark.circle.fill" : "plus.circle")
                                                        .font(DesignSystem.font(size: DesignSystem.fontSizeBase))
                                                }
                                                .foregroundColor(DesignSystem.textPrimary)
                                                .padding(.horizontal, DesignSystem.spacingSmall)
                                                .padding(.vertical, DesignSystem.spacingXSmall)
                                                .background(
                                                    RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                                        .fill(DesignSystem.backgroundPrimary)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                                                .stroke(isAlreadyBlocked ? DesignSystem.hoverBorder.opacity(DesignSystem.opacityHigher) : DesignSystem.borderPrimary, lineWidth: 1)
                                                        )
                                                )
                                            }
                                            .buttonStyle(.plain)
                                            .disabled(isAlreadyBlocked)
                                        }
                                    }
                                }
                            }
                        }
                    }
        }
    }
    
    var searchBarView_UNUSED: some View {
        HStack(spacing: DesignSystem.spacingSmall) {
                    Image(systemName: "magnifyingglass")
                        .font(DesignSystem.font(size: DesignSystem.fontSizeXXLarge))
                        .foregroundColor(DesignSystem.textTertiary)
                    
                    TextField(Strings.BlocklistEditor.searchBlockedSitesPlaceholder, text: $searchText)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.font(size: DesignSystem.fontSizeLarge))
                        .foregroundColor(DesignSystem.textPrimary)
                        
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(DesignSystem.font(size: DesignSystem.fontSizeXXLarge))
                                .foregroundColor(DesignSystem.textQuaternary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(DesignSystem.spacingSmall)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                        .fill(DesignSystem.backgroundPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                .stroke(focusedField == .search ? DesignSystem.textPrimary : Color.clear, lineWidth: 2)
                        )
                )
        .padding(.horizontal, DesignSystem.spacingXLarge)
        .padding(.vertical, DesignSystem.spacingMedium)
    }
    
    var urlListView: some View {
        domainListView
    }
    
    var domainListView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Count header with Suggested and Bulk Edit buttons
                if !filteredURLs.isEmpty || (!suggestedSites.isEmpty && searchText.isEmpty && !isSearchMode) {
                    ZStack {
                        // Centered text
                        if !filteredURLs.isEmpty {
                            Text(Strings.BlocklistEditor.siteCount(blockedURLs.count))
                                .font(DesignSystem.font(size: DesignSystem.fontSizeSmall, weight: DesignSystem.fontWeightSemibold))
                                .foregroundColor(DesignSystem.textTertiary)
                                .tracking(1.2)
                        }
                        
                        // Left and right aligned buttons
                        HStack {
                            // Left-aligned Suggested button
                            if !suggestedSites.isEmpty && searchText.isEmpty && !isSearchMode {
                                Button(action: {
                                    showSuggested.toggle()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: showSuggested ? "lightbulb" : "lightbulb")
                                            .font(DesignSystem.font(size: DesignSystem.fontSizeBase))
                                        Text(Strings.BlocklistEditor.suggested)
                                            .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightMedium))
                                    }
                                    .foregroundColor(showSuggested ? DesignSystem.textTertiary : DesignSystem.textPrimary)
                                    .padding(.horizontal, DesignSystem.spacingSmall)
                                    .padding(.vertical, DesignSystem.spacingXSmall)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                            .fill(isHoveringSuggestedChip ? DesignSystem.hoverBackground : Color.clear)
                                    )
                                    .modifier(DesignSystem.buttonStyle())
                                }
                                .buttonStyle(.plain)
                                .focusable(false)
                                .onHover { hovering in
                                    withAnimation(DesignSystem.animationFast) {
                                        isHoveringSuggestedChip = hovering
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Right-aligned Bulk Edit button
                            if !filteredURLs.isEmpty {
                                Button(action: {
                                    withAnimation {
                                        isBulkEditMode.toggle()
                                        if !isBulkEditMode {
                                            selectedURLs.removeAll()
                                            lastSelectedIndex = nil
                                        }
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: isBulkEditMode ? "checkmark.circle.fill" : "checkmark.circle")
                                            .font(DesignSystem.font(size: DesignSystem.fontSizeBase))
                                        Text(isBulkEditMode ? Strings.Common.done : Strings.BlocklistEditor.bulkEdit)
                                            .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightMedium))
                                    }
                                    .foregroundColor(DesignSystem.textPrimary)
                                    .padding(.horizontal, DesignSystem.spacingSmall)
                                    .padding(.vertical, DesignSystem.spacingXSmall)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                            .fill(isHoveringBulkEdit ? DesignSystem.hoverBackground : Color.clear)
                                    )
                                    .modifier(DesignSystem.buttonStyle())
                                }
                                .buttonStyle(.plain)
                                .focusable(false)
                                .onHover { hovering in
                                    withAnimation(DesignSystem.animationFast) {
                                        isHoveringBulkEdit = hovering
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.spacingLarge)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, DesignSystem.spacingMedium)
                    
                    // Show all suggested sites below the header line
                    if showSuggested && !suggestedSites.isEmpty && searchText.isEmpty && !isSearchMode {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(suggestedSites), id: \.self) { site in
                                    let isAlreadyBlocked = blockedURLs.contains { $0.domain == site }
                                    
                                    Button(action: {
                                        guard !isAlreadyBlocked else { return }
                                        
                                        if isBlockingMode {
                                            // Show confirmation when blocking is active
                                            pendingSiteToAdd = site
                                            // Small delay to ensure state is set before showing alert
                                            DispatchQueue.main.async {
                                                showingAddSiteConfirmation = true
                                            }
                                        } else {
                                            // Add directly when not blocking - no animation to prevent blink
                                            // showSuggested is @AppStorage so it persists automatically
                                            var transaction = Transaction()
                                            transaction.disablesAnimations = true
                                            withTransaction(transaction) {
                                                blockedURLs.append(BlockedURL(domain: site))
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Text(site)
                                                .font(DesignSystem.font(size: DesignSystem.fontSizeSmall))
                                            if isAlreadyBlocked {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(DesignSystem.font(size: DesignSystem.fontSizeXSmall))
                                            }
                                        }
                                        .foregroundColor(DesignSystem.textPrimary)
                                        .padding(.horizontal, DesignSystem.spacingSmallMedium)
                                        .padding(.vertical, DesignSystem.spacingXXSmall)
                                        .background(
                                            Capsule()
                                                .fill(isAlreadyBlocked ? DesignSystem.hoverBackground : DesignSystem.backgroundTertiary)
                                                .overlay(
                                                    Capsule()
                                                        .stroke(isAlreadyBlocked ? DesignSystem.textPrimary.opacity(DesignSystem.disabledOpacity) : Color.clear, lineWidth: 1)
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isAlreadyBlocked)
                                }
                            }
                            .padding(.horizontal, DesignSystem.spacingLarge)
                        }
                        .padding(.top, DesignSystem.spacingSmall)
                        .padding(.bottom, DesignSystem.spacingSmall)
                    }
                }
                
                LazyVStack(spacing: 6) {
                    if filteredURLs.isEmpty {
                            VStack(spacing: DesignSystem.spacingSmall) {
                                Image(systemName: searchText.isEmpty ? "shield.slash" : "magnifyingglass")
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeDisplayXXL))
                                    .foregroundColor(DesignSystem.textPrimary.opacity(DesignSystem.opacityMedium))
                                Text(searchText.isEmpty ? Strings.BlocklistEditor.noBlockedSites : Strings.BlocklistEditor.noResultsFound)
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeXLarge))
                                    .foregroundColor(DesignSystem.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, DesignSystem.spacingXLargePlusMedium)
                        } else {
                            let enumeratedURLs = Array(filteredURLs.enumerated())
                            ForEach(enumeratedURLs, id: \.element.id) { index, url in
                                HStack(alignment: .center, spacing: DesignSystem.spacingSmall) {
                                    // Checkbox in bulk edit mode, toggle otherwise
                                    Group {
                                        if isBulkEditMode {
                                            let isSelected = selectedURLs.contains(url.id)
                                            
                                            Button(action: {
                                                // Check shift key from modifier flags
                                                let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
                                                handleCheckboxClick(for: url.id, at: index, isShiftPressed: isShiftPressed)
                                            }) {
                                                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                                    .font(DesignSystem.font(size: DesignSystem.fontSizeTitle))
                                                    .foregroundColor(isSelected ? DesignSystem.textPrimary : DesignSystem.textQuaternary)
                                                    .frame(width: 20, height: 20, alignment: .center)
                                            }
                                            .buttonStyle(.plain)
                                        } else {
                                            // Toggle switch (can only enable during blocking, not disable)
                                            let isDisabledDuringBlock = isBlockingMode && url.isEnabled
                                            
                                            Toggle("", isOn: Binding(
                                                    get: {
                                                        url.isEnabled
                                                    },
                                                    set: { newValue in
                                                        // Only allow enabling during active block, not disabling
                                                        if isBlockingMode && !newValue {
                                                            // Prevent disabling - don't do anything
                                                            return
                                                        }
                                                        
                                                        // Allow enabling during block or any toggle when not blocking
                                                        if let index = blockedURLs.firstIndex(where: { $0.id == url.id }) {
                                                            var transaction = Transaction()
                                                            transaction.disablesAnimations = true
                                                            withTransaction(transaction) {
                                                                blockedURLs[index].isEnabled = newValue
                                                            }
                                                        }
                                                    }
                                                ))
                                                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.85, green: 0.95, blue: 1.0)))
                                                .labelsHidden()
                                                .disabled(isDisabledDuringBlock)
                                                .opacity(isDisabledDuringBlock ? DesignSystem.disabledOpacity : DesignSystem.opacityFull)
                                                .help(isDisabledDuringBlock ? Strings.Help.cannotDisableDuringBlock : "")
                                                .buttonStyle(.plain)
                                        }
                                    }
                                    .frame(width: 44, height: 24, alignment: .center)
                                    
                                    Button(action: {
                                        if isBulkEditMode {
                                            // Check shift key from modifier flags
                                            let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
                                            handleCheckboxClick(for: url.id, at: index, isShiftPressed: isShiftPressed)
                                        } else {
                                            currentScreen = .domainDetail(url.id)
                                        }
                                    }) {
                                        HStack(spacing: DesignSystem.spacingSmall) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack(spacing: 4) {
                                                    Text(url.domain)
                                                        .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightMedium))
                                                        .foregroundColor(url.isEnabled ? DesignSystem.textPrimary : DesignSystem.textTertiary)
                                                    
                                                    // Show lock icon when disabled during active block
                                                    if isBlockingMode && url.isEnabled {
                                                        Image(systemName: "lock.fill")
                                                            .font(DesignSystem.font(size: DesignSystem.fontSizeXSmall))
                                                            .foregroundColor(DesignSystem.accentOrangeMuted)
                                                        
                                                        Text(Strings.BlocklistEditor.locked)
                                                            .font(DesignSystem.font(size: DesignSystem.fontSizeXSmall, weight: DesignSystem.fontWeightRegular))
                                                            .foregroundColor(DesignSystem.accentOrangeMuted)
                                                    }
                                                }
                                                
                                                if !url.paths.isEmpty {
                                                    Text(Strings.BlocklistEditor.pathCount(url.paths.count))
                                                        .font(DesignSystem.font(size: DesignSystem.fontSizeXSmall))
                                                        .foregroundColor(DesignSystem.textTertiary)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(DesignSystem.font(size: DesignSystem.fontSizeSmall, weight: DesignSystem.fontWeightSemibold))
                                                .foregroundColor(DesignSystem.textQuaternary)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                                .frame(minHeight: 20)
                                .padding(.horizontal, DesignSystem.spacingSmall)
                                .padding(.vertical, DesignSystem.spacingXSmall)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                        .fill(DesignSystem.backgroundPrimary.opacity(url.isEnabled ? 0.6 : 0.3))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                                .stroke(url.isEnabled ? DesignSystem.borderSecondary : DesignSystem.textPrimary.opacity(DesignSystem.opacitySubtle), lineWidth: 1)
                                        )
                                )
                                .opacity(url.isEnabled ? DesignSystem.opacityFull : DesignSystem.opacityAlmost)
                            }
                        }
                    }
                .padding(DesignSystem.spacingXLarge)
            }
        }
    }
    
    var domainDetailView_UNUSED: some View {
        VStack(spacing: 0) {
            if let domainId = selectedDomain,
               let domain = blockedURLs.first(where: { $0.id == domainId }) {
                // Header with back button
                HStack {
                    Button(action: {
                        withAnimation(DesignSystem.animationFast) {
                            selectedDomain = nil
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightSemibold))
                            Text(Strings.Common.back)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeXLarge, weight: DesignSystem.fontWeightMedium))
                        }
                        .foregroundColor(DesignSystem.textPrimary)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.spacingLarge)
                .padding(.vertical, DesignSystem.spacingSmall)
                
                Divider()
                    .background(DesignSystem.borderPrimary)
                
                ScrollView {
                    VStack(spacing: DesignSystem.spacingMedium) {
                        // Domain info
                        VStack(alignment: .leading, spacing: DesignSystem.spacingSmall) {
                            HStack {
            Image(systemName: "globe")
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeDisplay))
                                    .foregroundColor(DesignSystem.textPrimary)
                                
                                Text(domain.domain)
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeDisplay, weight: DesignSystem.fontWeightBold))
                                    .foregroundColor(DesignSystem.textPrimary)
                                
                                Spacer()
                                
                                if !isBlockingMode {
                                    Button(action: {
                                        withAnimation {
                                            blockedURLs.removeAll { $0.id == domainId }
                                            selectedDomain = nil
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "trash")
                                                .font(DesignSystem.font(size: DesignSystem.fontSizeLarge))
                                            Text(Strings.Common.delete)
                                                .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightMedium))
                                        }
                                        .foregroundColor(DesignSystem.textSecondary)
                                        .padding(.horizontal, DesignSystem.spacingMedium)
                                        .padding(.vertical, DesignSystem.spacingSmall)
                                        .modifier(DesignSystem.buttonStyle(isDestructive: true))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            Text(Strings.DomainDetail.managePathsDescription)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeMedium))
                                .foregroundColor(DesignSystem.textTertiary)
                        }
                        .padding(DesignSystem.spacingXLarge)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusLarge)
                                .fill(DesignSystem.backgroundPrimary.opacity(DesignSystem.opacityHigher))
                        )
                        
                        // Add path section
                        VStack(alignment: .leading, spacing: DesignSystem.spacingMedium) {
                            Text(Strings.DomainDetail.addPathOrSubdomain)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightSemibold))
                                .foregroundColor(DesignSystem.textPrimary)
                            
                            HStack(spacing: DesignSystem.spacingSmall) {
                                TextField(Strings.DomainDetail.addPathExamplePlaceholder, text: $newPath, onCommit: { addPath(to: domainId) })
                                    .textFieldStyle(.plain)
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeLarge))
                                    .foregroundColor(DesignSystem.textPrimary)
                                    .padding(DesignSystem.spacingSmall)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                            .fill(DesignSystem.backgroundPrimary)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                                    .stroke(focusedField == .addPath ? DesignSystem.textPrimary : DesignSystem.borderPrimary, lineWidth: focusedField == .addPath ? 2 : 1)
                                            )
                                    )
                                    
                                
                                Button(action: {
                                    addPath(to: domainId)
                                }) {
                                    Text(Strings.Common.add)
                                        .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightMedium))
                                        .foregroundColor(DesignSystem.textPrimary)
                                        .padding(.horizontal, DesignSystem.spacingLarge)
                                        .padding(.vertical, DesignSystem.spacingSmall)
                                        .background(Color.green)
                                        .cornerRadius(DesignSystem.radiusSmall)
                                }
                                .buttonStyle(.plain)
                                .disabled(newPath.isEmpty)
                                .opacity(newPath.isEmpty ? DesignSystem.disabledOpacity : DesignSystem.opacityFull)
                            }
                        }
                        .padding(DesignSystem.spacingXLarge)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusLarge)
                                .fill(DesignSystem.backgroundPrimary.opacity(DesignSystem.opacityHigh))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.radiusLarge)
                                        .stroke(DesignSystem.hoverBorder.opacity(DesignSystem.opacityHigher), lineWidth: 1)
                                )
                        )
                        
                        // Paths list
                        if !domain.paths.isEmpty {
                            VStack(alignment: .leading, spacing: DesignSystem.spacingMedium) {
                                Text(Strings.DomainDetail.pathsCount(domain.paths.count))
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightSemibold))
                                    .foregroundColor(DesignSystem.textPrimary)
                                
                                VStack(spacing: DesignSystem.spacingXSmall) {
                                    ForEach(domain.paths, id: \.self) { path in
                                        HStack(spacing: DesignSystem.spacingSmall) {
                                            Image(systemName: "doc.text")
                                                .font(DesignSystem.font(size: DesignSystem.fontSizeLarge))
                                                .foregroundColor(DesignSystem.accentPurpleMuted)
                                            
                                            Text(path)
                                                .font(DesignSystem.font(size: DesignSystem.fontSizeLarge))
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
                                                    Image(systemName: "trash")
                                                        .font(DesignSystem.font(size: DesignSystem.fontSizeLarge))
                                                        .foregroundColor(DesignSystem.destructiveColor.opacity(DesignSystem.opacityHigher))
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(DesignSystem.spacingMedium)
                                        .background(
                                            RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                                .fill(DesignSystem.backgroundSecondary.opacity(DesignSystem.opacityHigher))
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, DesignSystem.spacingLarge)
                            .padding(.vertical, DesignSystem.spacingSmall)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.radiusLarge)
                                    .fill(DesignSystem.backgroundPrimary.opacity(DesignSystem.opacityHigh))
                            )
                        }
                    }
                    .padding(DesignSystem.spacingXLarge)
                }
            }
        }
    }
    
    var bottomActionBar: some View {
        Group {
            if isBulkEditMode {
                VStack(spacing: 0) {
                    // Divider
                    Divider()
                        .background(DesignSystem.borderPrimary)
                    
                    // Floating action bar
                    ZStack {
                        HStack(spacing: DesignSystem.spacingMedium) {
                            // Select All button
                            Button(action: {
                                withAnimation(DesignSystem.animationFast) {
                                    let filteredIDs = Set(filteredURLs.map { $0.id })
                                    let allFilteredSelected = !filteredURLs.isEmpty && filteredIDs.isSubset(of: selectedURLs)
                                    
                                    if allFilteredSelected {
                                        // Deselect all filtered items (but keep any selections outside filtered view)
                                        for id in filteredIDs {
                                            selectedURLs.remove(id)
                                        }
                                    } else {
                                        // Select all filtered items (and keep any existing selections)
                                        for id in filteredIDs {
                                            selectedURLs.insert(id)
                                        }
                                    }
                                }
                            }) {
                                let filteredIDs = Set(filteredURLs.map { $0.id })
                                let allFilteredSelected = !filteredURLs.isEmpty && filteredIDs.isSubset(of: selectedURLs)
                                
                                HStack(spacing: 6) {
                                    Image(systemName: allFilteredSelected ? "checkmark.square.fill" : "square")
                                        .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightMedium))
                                    Text(allFilteredSelected ? Strings.Common.deselectAll : Strings.Common.selectAll)
                                        .font(DesignSystem.font(size: DesignSystem.fontSizeMedium, weight: DesignSystem.fontWeightMedium))
                                }
                                .foregroundColor(DesignSystem.textPrimary)
                                .padding(.horizontal, DesignSystem.spacingMedium)
                                .padding(.vertical, DesignSystem.spacingSmall)
                                .modifier(DesignSystem.buttonStyle())
                            }
                            .buttonStyle(.plain)
                            .disabled(filteredURLs.isEmpty)
                            .opacity(filteredURLs.isEmpty ? DesignSystem.disabledOpacity : DesignSystem.opacityFull)
                            
                            Spacer()
                            
                            // Delete button
                            Button(action: {
                                showingDeleteConfirmation = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                        .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightMedium))
                                    Text(Strings.Common.delete)
                                        .font(DesignSystem.font(size: DesignSystem.fontSizeMedium, weight: DesignSystem.fontWeightMedium))
                                }
                                .foregroundColor(DesignSystem.destructiveColor)
                                .padding(.horizontal, DesignSystem.spacingMedium)
                                .padding(.vertical, DesignSystem.spacingSmall)
                                .modifier(DesignSystem.buttonStyle(isDestructive: true))
                            }
                            .buttonStyle(.plain)
                            .disabled(selectedURLs.isEmpty)
                            .opacity(selectedURLs.isEmpty ? DesignSystem.disabledOpacity : DesignSystem.opacityFull)
                        }
                        
                        // Selected count - centered
                        if !selectedURLs.isEmpty {
                            Text(Strings.BlocklistEditor.selectedCount(selectedURLs.count))
                                .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightMedium))
                                .foregroundColor(DesignSystem.textSecondary)
                        }
                    }
                    .padding(.horizontal, DesignSystem.spacingLarge)
                    .padding(.vertical, DesignSystem.spacingMedium)
                    .background(
                        ZStack(alignment: .top) {
                            Rectangle()
                                .fill(DesignSystem.backgroundPrimary)
                            Rectangle()
                                .fill(DesignSystem.borderPrimary)
                                .frame(height: 1)
                        }
                    )
                }
            } else {
                EmptyView()
            }
        }
    }
    
    private func addWebsite() {
        let input = newSite.trimmingCharacters(in: .whitespaces)
        if input.isEmpty {
            return
        }
        
        let (domain, path) = BlockedURLsHelpers.parseDomainAndPath(from: input)
        
        if domain.isEmpty {
            return
        }
        
        // Find existing domain or create new one
        var domainId: UUID
        if let existingDomain = blockedURLs.first(where: { $0.domain == domain }) {
            domainId = existingDomain.id
        } else {
            // Domain doesn't exist, check if we should add it
            if isBlockingMode {
                // Show confirmation when blocking is active
                pendingSiteToAdd = input
                showingAddSiteConfirmation = true
                return
            } else {
                // Add new domain
                let newDomain = BlockedURL(domain: domain)
                domainId = newDomain.id
                withAnimation {
                    blockedURLs.append(newDomain)
                }
            }
        }
        
        // If there's a path, add it to the domain
        if let pathToAdd = path {
            if let index = blockedURLs.firstIndex(where: { $0.id == domainId }) {
                let formattedPath = pathToAdd.hasPrefix("/") || pathToAdd.contains(".") ? pathToAdd : "/\(pathToAdd)"
                if !blockedURLs[index].paths.contains(formattedPath) {
                    withAnimation {
                        blockedURLs[index].paths.append(formattedPath)
                        saveChanges()
                        newSite = ""
                        // Navigate to domain detail view to show the path was added
                        currentScreen = .domainDetail(domainId)
                    }
                    return
                } else {
                    // Path already exists, navigate to detail view anyway
                    withAnimation {
                        newSite = ""
                        currentScreen = .domainDetail(domainId)
                    }
                    return
                }
            }
        }
        
        // If no path, navigate to detail view if domain was new
        let domainExisted = blockedURLs.contains(where: { $0.id == domainId && $0.domain == domain })
        if !domainExisted {
            // New domain was added, navigate to detail view
            withAnimation {
                newSite = ""
                currentScreen = .domainDetail(domainId)
            }
        } else {
            newSite = ""
        }
    }
    
    private func confirmAddWebsite() {
        guard let input = pendingSiteToAdd else { return }
        let (domain, path) = BlockedURLsHelpers.parseDomainAndPath(from: input)
        
        if domain.isEmpty {
            pendingSiteToAdd = nil
            return
        }
        
        // Find existing domain or create new one
        var domainId: UUID
        if let existingDomain = blockedURLs.first(where: { $0.domain == domain }) {
            domainId = existingDomain.id
        } else {
            // Add new domain
            let newDomain = BlockedURL(domain: domain)
            domainId = newDomain.id
            withAnimation {
                blockedURLs.append(newDomain)
            }
        }
        
        // If there's a path, add it to the domain
        if let pathToAdd = path {
            if let index = blockedURLs.firstIndex(where: { $0.id == domainId }) {
                let formattedPath = pathToAdd.hasPrefix("/") || pathToAdd.contains(".") ? pathToAdd : "/\(pathToAdd)"
                if !blockedURLs[index].paths.contains(formattedPath) {
                    withAnimation {
                        blockedURLs[index].paths.append(formattedPath)
                        saveChanges()
                        newSite = ""
                        pendingSiteToAdd = nil
                        // Navigate to domain detail view to show the path was added
                        currentScreen = .domainDetail(domainId)
                    }
                    return
                } else {
                    // Path already exists, navigate to detail view anyway
                    withAnimation {
                        newSite = ""
                        pendingSiteToAdd = nil
                        currentScreen = .domainDetail(domainId)
                    }
                    return
                }
            }
        }
        
        // If no path, navigate to detail view if domain was new
        let domainExisted = blockedURLs.contains(where: { $0.id == domainId && $0.domain == domain })
        if !domainExisted {
            // New domain was added, navigate to detail view
            withAnimation {
                newSite = ""
                pendingSiteToAdd = nil
                currentScreen = .domainDetail(domainId)
            }
        } else {
            withAnimation {
                newSite = ""
                pendingSiteToAdd = nil
            }
        }
    }
    
    
    private func addPath(to urlId: UUID) {
        let cleanPath = newPath.trimmingCharacters(in: .whitespaces)
        if !cleanPath.isEmpty, let index = blockedURLs.firstIndex(where: { $0.id == urlId }) {
            // Ensure path starts with / (unless it's a subdomain)
            let formattedPath = cleanPath.hasPrefix("/") || cleanPath.contains(".") ? cleanPath : "/\(cleanPath)"
            
            if !blockedURLs[index].paths.contains(formattedPath) {
                withAnimation {
                    blockedURLs[index].paths.append(formattedPath)
                    saveChanges()
                    newPath = ""
                }
            }
        }
    }
    
    private func saveChanges() {
        viewModel.blockerStorage?.set(blockedURLs)
    }
}

