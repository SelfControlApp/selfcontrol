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

    // Top-level UI state
    @State private var newSite: String = ""
    @State private var newPath: String = ""
    @State private var searchText: String = ""
    @AppStorage("showSuggestedSites") private var showSuggested: Bool = false
    @State private var selectedDomain: UUID? = nil
    @State private var focusedField: EditorFocusField?
    @State private var showingAddSiteConfirmation = false
    @State private var pendingSiteToAdd: String? = nil

    // Bulk-edit + selection
    @State private var isBulkEditMode: Bool = false
    @State private var selectedURLs: Set<UUID> = []
    @State private var lastSelectedIndex: Int? = nil

    // Delete confirmation
    @State private var showingDeleteConfirmation: Bool = false

    // Search/add UI
    @State private var isSearchMode: Bool = false

    // Hover states
    @State private var isHoveringSuggestedChip = false
    @State private var isHoveringBulkEdit = false
    @State private var isHoveringImport = false
    @State private var isHoveringExport = false
    @State private var isHoveringAdd = false

    // Suggested scroll
    @State private var firstVisibleSuggestedID: String?

    enum EditorFocusField: Hashable {
        case addWebsite
        case search
        case addPath
        case doneButton
    }

    // Suggested sites for quick adding
    let suggestedSites = DomainConstants.suggestedSites

    // MARK: - Derived state

    var filteredURLs: [BlockedURL] {
        if searchText.isEmpty {
            return blockedURLs.sorted { $0.domain < $1.domain }
        }
        return blockedURLs
            .filter { url in
                url.domain.localizedCaseInsensitiveContains(searchText) ||
                url.paths.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
            .sorted { $0.domain < $1.domain }
    }

    var totalCount: Int {
        blockedURLs.count + blockedURLs.reduce(0) { $0 + $1.paths.count }
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

    // MARK: - Body

    var body: some View {
        ZStack {
            DesignSystem.backgroundGradient
                .ignoresSafeArea(.all)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 0) {
                BlocklistHeader(
                    title: blockingMode == .blocklist ? Strings.BlocklistEditor.title : Strings.BlocklistEditor.allowlist,
                    onBack: {
                        selectedDomain = nil
                        currentScreen = .main
                    },
                    onImport: { importurls() },
                    onExport: { exporturls() },
                    isBlockingMode: isBlockingMode,
                    isHoveringImport: $isHoveringImport,
                    isHoveringExport: $isHoveringExport
                )
                .padding(.horizontal, DesignSystem.spacingLarge)
                .padding(.vertical, DesignSystem.spacingSmall)

                Divider().background(DesignSystem.borderPrimary)

                if blockingMode == .allowlist {
                    AllowlistBanner()
                        .padding(.horizontal, DesignSystem.spacingLarge)
                        .padding(.top, DesignSystem.spacingMedium)
                }

                AddSearchBar(
                    isSearchMode: $isSearchMode,
                    focusedField: $focusedField,
                    searchText: $searchText,
                    newSite: $newSite,
                    isHoveringAdd: $isHoveringAdd,
                    onAdd: { addWebsite() }
                )
                .padding(.horizontal, DesignSystem.spacingLarge)
                .padding(.vertical, DesignSystem.spacingSmall)

                Divider().background(DesignSystem.borderPrimary)

                DomainListSection(
                    filteredURLs: filteredURLs,
                    blockedURLs: $blockedURLs,
                    isBlockingMode: isBlockingMode,
                    isSearchMode: isSearchMode,
                    searchText: searchText,
                    showSuggested: $showSuggested,
                    suggestedSites: suggestedSites,
                    isHoveringSuggestedChip: $isHoveringSuggestedChip,
                    isBulkEditMode: $isBulkEditMode,
                    isHoveringBulkEdit: $isHoveringBulkEdit,
                    selectedURLs: $selectedURLs,
                    lastSelectedIndex: $lastSelectedIndex,
                    onToggleBulkEdit: toggleBulkEdit,
                    onSelectRow: handleRowSelection(urlId:index:isShiftPressed:),
                    onNavigateToDetail: { id in currentScreen = .domainDetail(id) },
                    onRequestAddSuggested: handleAddSuggested(site:)
                )
                .padding(DesignSystem.spacingXLarge)

                BottomActionBarView(
                    filteredURLs: filteredURLs,
                    selectedURLs: $selectedURLs,
                    isBulkEditMode: isBulkEditMode,
                    onToggleAllFiltered: toggleAllFilteredSelection,
                    onDelete: { showingDeleteConfirmation = true }
                )
            }

            if showingDeleteConfirmation {
                DeleteConfirmationModal(
                    count: selectedURLs.count,
                    onCancel: { showingDeleteConfirmation = false },
                    onConfirm: {
                        deleteSelectedURLs()
                        showingDeleteConfirmation = false
                    }
                )
            }
        }
        .alert(
            Strings.BlocklistEditor.addToExistingBlockTitle,
            isPresented: $showingAddSiteConfirmation,
            presenting: pendingSiteToAdd
        ) { site in
            Button(Strings.BlocklistEditor.addSite) {
                confirmAddWebsite()
            }
            Button(Strings.Common.cancel, role: .cancel) {
                pendingSiteToAdd = nil
            }
        } message: { site in
            Text(Strings.BlocklistEditor.addToExistingBlockMessage(site, blockingMode: blockingMode))
        }

        .onAppear {
            // Reset to list view and focus on add website field when editor opens
            selectedDomain = nil
            focusedField = .addWebsite
        }
    }

    // MARK: - Actions

    func handleRowSelection(urlId: UUID, index: Int, isShiftPressed: Bool) {
        handleCheckboxClick(for: urlId, at: index, isShiftPressed: isShiftPressed)
    }

    func toggleBulkEdit() {
        withAnimation {
            isBulkEditMode.toggle()
            if !isBulkEditMode {
                selectedURLs.removeAll()
                lastSelectedIndex = nil
            }
        }
    }

    func toggleAllFilteredSelection() {
        withAnimation(DesignSystem.animationFast) {
            let filteredIDs = Set(filteredURLs.map { $0.id })
            let allFilteredSelected = !filteredURLs.isEmpty && filteredIDs.isSubset(of: selectedURLs)

            if allFilteredSelected {
                for id in filteredIDs {
                    selectedURLs.remove(id)
                }
            } else {
                for id in filteredIDs {
                    selectedURLs.insert(id)
                }
            }
        }
    }

    func handleAddSuggested(site: String) {
        let isAlreadyBlocked = blockedURLs.contains { $0.domain == site }
        guard !isAlreadyBlocked else { return }

        if isBlockingMode {
            pendingSiteToAdd = site
            DispatchQueue.main.async {
                showingAddSiteConfirmation = true
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                blockedURLs.append(BlockedURL(domain: site))
            }
        }
    }

    func handleCheckboxClick(for urlId: UUID, at index: Int, isShiftPressed: Bool = false) {
        if isShiftPressed, let lastIndex = lastSelectedIndex {
            let startIndex = min(lastIndex, index)
            let endIndex = max(lastIndex, index)
            let range = startIndex...endIndex

            let isCurrentlySelected = selectedURLs.contains(urlId)

            for i in range {
                let itemId = filteredURLs[i].id
                if isCurrentlySelected {
                    selectedURLs.remove(itemId)
                } else {
                    selectedURLs.insert(itemId)
                }
            }
        } else {
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
            blockedURLs = blockedURLs.filter { !selectedURLs.contains($0.id) }
            selectedURLs.removeAll()

            if blockedURLs.isEmpty {
                isBulkEditMode = false
            }
        }
    }

    // MARK: - Domain/path editing

    private func addWebsite() {
        let input = newSite.trimmingCharacters(in: .whitespaces)
        if input.isEmpty { return }

        let (domain, path) = BlockedURLsHelpers.parseDomainAndPath(from: input)
        if domain.isEmpty { return }

        var domainId: UUID
        if let existingDomain = blockedURLs.first(where: { $0.domain == domain }) {
            domainId = existingDomain.id
        } else {
            if isBlockingMode {
                pendingSiteToAdd = input
                showingAddSiteConfirmation = true
                return
            } else {
                let newDomain = BlockedURL(domain: domain)
                domainId = newDomain.id
                withAnimation {
                    blockedURLs.append(newDomain)
                }
            }
        }

        if let pathToAdd = path {
            if let index = blockedURLs.firstIndex(where: { $0.id == domainId }) {
                let formattedPath = pathToAdd.hasPrefix("/") || pathToAdd.contains(".") ? pathToAdd : "/\(pathToAdd)"
                if !blockedURLs[index].paths.contains(formattedPath) {
                    withAnimation {
                        blockedURLs[index].paths.append(formattedPath)
                        saveChanges()
                        newSite = ""
                        currentScreen = .domainDetail(domainId)
                    }
                    return
                } else {
                    withAnimation {
                        newSite = ""
                        currentScreen = .domainDetail(domainId)
                    }
                    return
                }
            }
        }

        let domainExisted = blockedURLs.contains(where: { $0.id == domainId && $0.domain == domain })
        if !domainExisted {
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

        var domainId: UUID
        if let existingDomain = blockedURLs.first(where: { $0.domain == domain }) {
            domainId = existingDomain.id
        } else {
            let newDomain = BlockedURL(domain: domain)
            domainId = newDomain.id
            withAnimation {
                blockedURLs.append(newDomain)
            }
        }

        if let pathToAdd = path {
            if let index = blockedURLs.firstIndex(where: { $0.id == domainId }) {
                let formattedPath = pathToAdd.hasPrefix("/") || pathToAdd.contains(".") ? pathToAdd : "/\(pathToAdd)"
                if !blockedURLs[index].paths.contains(formattedPath) {
                    withAnimation {
                        blockedURLs[index].paths.append(formattedPath)
                        saveChanges()
                        newSite = ""
                        pendingSiteToAdd = nil
                        currentScreen = .domainDetail(domainId)
                    }
                    return
                } else {
                    withAnimation {
                        newSite = ""
                        pendingSiteToAdd = nil
                        currentScreen = .domainDetail(domainId)
                    }
                    return
                }
            }
        }

        let domainExisted = blockedURLs.contains(where: { $0.id == domainId && $0.domain == domain })
        if !domainExisted {
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
        viewModel.saveAndupdateBlockList(blockedURLs)
    }
}

// MARK: - Import/Export

extension BlocklistEditorView {
    func importurls() {
        if let window = NSApplication.shared.keyWindow {
            Task { @MainActor in
                do {
                    let imported = try await ImportExportManager.importBlockedUrls(presentingWindow: window)
                    self.blockedURLs = imported
                } catch {
                    NSLog("Import failed: \(error.localizedDescription)")
                }
            }
        } else {
            Task { @MainActor in
                do {
                    let imported = try await ImportExportManager.importBlockedUrls()
                    self.blockedURLs = imported
                } catch {
                    NSLog("Import failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func exporturls() {
        ImportExportManager.exportBlockedUrls(blockedURLs: self.blockedURLs)
    }
}

// MARK: - Subviews

private struct BlocklistHeader: View {
    let title: String
    let onBack: () -> Void
    let onImport: () -> Void
    let onExport: () -> Void
    let isBlockingMode: Bool

    @Binding var isHoveringImport: Bool
    @Binding var isHoveringExport: Bool

    var body: some View {
        HStack(alignment: .center) {
            Button(action: onBack) {
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

            Button(action: onImport) {
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
            .disabled(isBlockingMode)
            .onHover { hovering in
                withAnimation(DesignSystem.animationFast) {
                    isHoveringImport = hovering
                }
            }

            Button(action: onExport) {
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
            Text(title)
                .font(DesignSystem.font(size: DesignSystem.fontSizeXXLarge, weight: DesignSystem.fontWeightSemibold))
                .foregroundColor(DesignSystem.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
        )
    }
}

private struct AllowlistBanner: View {
    var body: some View {
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
    }
}

private struct AddSearchBar: View {
    @Binding var isSearchMode: Bool
    @Binding var focusedField: BlocklistEditorView.EditorFocusField?
    @Binding var searchText: String
    @Binding var newSite: String
    @Binding var isHoveringAdd: Bool

    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.spacingSmall) {
            HStack(spacing: 8) {
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

                Group {
                    if isSearchMode {
                        TextField(Strings.BlocklistEditor.searchPlaceholder, text: $searchText)
                            .textFieldStyle(.plain)
                            .font(DesignSystem.font(size: DesignSystem.fontSizeMedium))
                            .foregroundColor(DesignSystem.textPrimary)
                            .placeholder(when: searchText.isEmpty, alignment: .leading) {
                                Text(Strings.BlocklistEditor.searchPlaceholder)
                                    .foregroundColor(DesignSystem.disabledText)
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeMedium))
                                    .padding(.vertical, 8)
                            }
                    } else {
                        TextField(Strings.BlocklistEditor.addWebsitePlaceholder, text: $newSite, onCommit: onAdd)
                            .textFieldStyle(.plain)
                            .font(DesignSystem.font(size: DesignSystem.fontSizeMedium))
                            .foregroundColor(DesignSystem.textPrimary)
                            .placeholder(when: newSite.isEmpty, alignment: .leading) {
                                Text(Strings.BlocklistEditor.addWebsitePlaceholder)
                                    .foregroundColor(DesignSystem.disabledText)
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeMedium))
                                    .padding(.vertical, 8)
                            }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))

                if isSearchMode {
                    Spacer().frame(minWidth: 8)
                }

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
                        Button(action: onAdd) {
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
            .frame(height: 44)
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
    }
}

private struct DomainListSection: View {
    let filteredURLs: [BlockedURL]
    @Binding var blockedURLs: [BlockedURL]

    let isBlockingMode: Bool
    let isSearchMode: Bool
    let searchText: String

    @Binding var showSuggested: Bool
    let suggestedSites: [String]
    @Binding var isHoveringSuggestedChip: Bool

    @Binding var isBulkEditMode: Bool
    @Binding var isHoveringBulkEdit: Bool
    @Binding var selectedURLs: Set<UUID>
    @Binding var lastSelectedIndex: Int?

    let onToggleBulkEdit: () -> Void
    let onSelectRow: (_ urlId: UUID, _ index: Int, _ isShiftPressed: Bool) -> Void
    let onNavigateToDetail: (UUID) -> Void
    let onRequestAddSuggested: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !filteredURLs.isEmpty || (!suggestedSites.isEmpty && searchText.isEmpty && !isSearchMode) {
                    ZStack {
                        if !filteredURLs.isEmpty {
                            Text(Strings.BlocklistEditor.siteCount(blockedURLs.count))
                                .font(DesignSystem.font(size: DesignSystem.fontSizeSmall, weight: DesignSystem.fontWeightSemibold))
                                .foregroundColor(DesignSystem.textTertiary)
                                .tracking(1.2)
                        }

                        HStack {
                            if !suggestedSites.isEmpty && searchText.isEmpty && !isSearchMode {
                                Button(action: { showSuggested.toggle() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "lightbulb")
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

                            if !filteredURLs.isEmpty {
                                Button(action: onToggleBulkEdit) {
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
                                .disabled(isBlockingMode)
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

                    if showSuggested && !suggestedSites.isEmpty && searchText.isEmpty && !isSearchMode {
                        SuggestedChipsScroll(
                            suggestedSites: suggestedSites,
                            blockedURLs: blockedURLs,
                            onTap: onRequestAddSuggested
                        )
                        .padding(.top, DesignSystem.spacingSmall)
                        .padding(.bottom, DesignSystem.spacingSmall)
                    }
                }

                LazyVStack(spacing: 6) {
                    if filteredURLs.isEmpty {
                        EmptyListView(isSearching: !searchText.isEmpty)
                            .frame(maxWidth: .infinity)
                            .padding(.top, DesignSystem.spacingXLargePlusMedium)
                    } else {
                        let enumeratedURLs = Array(filteredURLs.enumerated())
                        ForEach(enumeratedURLs, id: \.element.id) { index, url in
                            DomainRow(
                                url: url,
                                index: index,
                                isBulkEditMode: isBulkEditMode,
                                isBlockingMode: isBlockingMode,
                                isSelected: selectedURLs.contains(url.id),
                                onToggleSelect: { id, idx in
                                    let isShift = NSEvent.modifierFlags.contains(.shift)
                                    onSelectRow(id, idx, isShift)
                                },
                                onTapRow: {
                                    if isBulkEditMode {
                                        let isShift = NSEvent.modifierFlags.contains(.shift)
                                        onSelectRow(url.id, index, isShift)
                                    } else {
                                        onNavigateToDetail(url.id)
                                    }
                                },
                                onToggleEnabled: { newValue in
                                    guard let idx = blockedURLs.firstIndex(where: { $0.id == url.id }) else { return }
                                    var transaction = Transaction()
                                    transaction.disablesAnimations = true
                                    withTransaction(transaction) {
                                        blockedURLs[idx].isEnabled = newValue
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct SuggestedChipsScroll: View {
    let suggestedSites: [String]
    let blockedURLs: [BlockedURL]
    let onTap: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(suggestedSites), id: \.self) { site in
                    let isAlreadyBlocked = blockedURLs.contains { $0.domain == site }

                    Button(action: { onTap(site) }) {
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
    }
}

private struct EmptyListView: View {
    let isSearching: Bool

    var body: some View {
        VStack(spacing: DesignSystem.spacingSmall) {
            Image(systemName: isSearching ? "magnifyingglass" : "shield.slash")
                .font(DesignSystem.font(size: DesignSystem.fontSizeDisplayXXL))
                .foregroundColor(DesignSystem.textPrimary.opacity(DesignSystem.opacityMedium))
            Text(isSearching ? Strings.BlocklistEditor.noResultsFound : Strings.BlocklistEditor.noBlockedSites)
                .font(DesignSystem.font(size: DesignSystem.fontSizeXLarge))
                .foregroundColor(DesignSystem.textTertiary)
        }
    }
}

private struct DomainRow: View {
    let url: BlockedURL
    let index: Int
    let isBulkEditMode: Bool
    let isBlockingMode: Bool
    let isSelected: Bool

    let onToggleSelect: (_ id: UUID, _ index: Int) -> Void
    let onTapRow: () -> Void
    let onToggleEnabled: (_ newValue: Bool) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.spacingSmall) {
            Group {
                if isBulkEditMode {
                    Button(action: { onToggleSelect(url.id, index) }) {
                        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                            .font(DesignSystem.font(size: DesignSystem.fontSizeTitle))
                            .foregroundColor(isSelected ? DesignSystem.textPrimary : DesignSystem.textQuaternary)
                            .frame(width: 20, height: 20, alignment: .center)
                    }
                    .buttonStyle(.plain)
                } else {
                    let isDisabledDuringBlock = isBlockingMode && url.isEnabled
                    Toggle("", isOn: Binding(
                        get: { url.isEnabled },
                        set: { newValue in
                            if isBlockingMode && !newValue {
                                return
                            }
                            onToggleEnabled(newValue)
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

            Button(action: onTapRow) {
                HStack(spacing: DesignSystem.spacingSmall) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(url.domain)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightMedium))
                                .foregroundColor(url.isEnabled ? DesignSystem.textPrimary : DesignSystem.textTertiary)

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

private struct BottomActionBarView: View {
    let filteredURLs: [BlockedURL]
    @Binding var selectedURLs: Set<UUID>
    let isBulkEditMode: Bool

    let onToggleAllFiltered: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Group {
            if isBulkEditMode {
                VStack(spacing: 0) {
                    Divider().background(DesignSystem.borderPrimary)

                    ZStack {
                        HStack(spacing: DesignSystem.spacingMedium) {
                            Button(action: onToggleAllFiltered) {
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

                            Button(action: onDelete) {
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
                            Rectangle().fill(DesignSystem.backgroundPrimary)
                            Rectangle().fill(DesignSystem.borderPrimary).frame(height: 1)
                        }
                    )
                }
            } else {
                EmptyView()
            }
        }
    }
}

private struct DeleteConfirmationModal: View {
    let count: Int
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        DesignSystem.overlayBackground
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: DesignSystem.spacingMedium) {
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
                        Button(action: onCancel) {
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

                        Button(action: onConfirm) {
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
            )
            .zIndex(999)
    }
}

// MARK: - Suggested chips geometry helpers (retained for potential reuse)

private struct VisibleHItem: Equatable {
    let id: String
    let minX: CGFloat
}

private struct FirstVisibleHPreferenceKey: PreferenceKey {
    static var defaultValue: [VisibleHItem] = []
    static func reduce(value: inout [VisibleHItem], nextValue: () -> [VisibleHItem]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - onChangeCompat

extension View {
    @ViewBuilder
    func onChangeCompat<Value: Equatable>(
        of value: Value,
        initial: Bool = false,
        _ action: @escaping (_ oldValue: Value?, _ newValue: Value) -> Void
    ) -> some View {
        if #available(macOS 14.0, *) {
            if initial {
                self.onChange(of: value, initial: true) { old, new in
                    action(old, new)
                }
            } else {
                self.onChange(of: value) { old, new in
                    action(old, new)
                }
            }
        } else {
            self
                .onChange(of: value, perform: { new in
                    action(nil, new)
                })
                .onAppear {
                    if initial {
                        action(nil, value)
                    }
                }
        }
    }
}
