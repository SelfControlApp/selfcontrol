//
//  ContentView.swift
//  SelfControlUI
//
//  Created by Vidya Giri on 10/30/25.
//

import SwiftUI
import AppKit

struct NewContentView: View {
    
    @EnvironmentObject var viewModel: FilterViewModel

    @State private var minutes: Double = 11
    @State private var blockedURLs: [BlockedURL] = []
    @State private var currentScreen: AppScreen = .main
    @State private var isBlocking = false
    @State private var isHoveringButton = false
    @State private var remainingTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var focusedField: FocusField?
    @State private var showingConfirmation = false
    @AppStorage("dontShowConfirmation") private var dontShowConfirmation = false
    @AppStorage("blockingMode") private var blockingMode: BlockingMode = .blocklist
    @AppStorage("hideSeconds") private var hideSeconds = false
    @AppStorage("hasSeenTips") private var hasSeenTips = false
    @AppStorage("intensityLevel") private var intensityLevel: IntensityLevel = .low
    @State private var showingTips = false
    @State private var isHoveringIntensity = false
    @State private var isEditingTime = false
    @State private var hoursInput = ""
    @State private var minutesInput = ""
    @State private var isHoveringTime = false
    @State private var isAdjustingTime = false
    @State private var logoRotation: Double = 0
    @State private var isEasterEggUnlocked: Bool = false
    @State private var days: Int = 1
    @State private var daysInput: String = "1"
    @State private var logoDragOffset: CGSize = .zero
    @State private var hasReachedEdge: Bool = false
    @State private var isHoveringEditButton = false
    @State private var isHoveringDoneButton = false
    @State private var showingStopConfirmation = false
    @State private var stopCountdownTime: TimeInterval = 600
    @State private var stopCountdownTimer: Timer?
    @State private var isHoveringStopButton = false
    @State private var isPressingStartButton = false
    @State private var showingIntensityDropdown = false
    @State private var showingExtendTimer = false
    @State private var extensionMinutes: Double = 60
    @State private var isHoveringExtendTimer = false
    @State private var isHoveringAddToList = false
    @AppStorage("isScheduleActive") private var isScheduleActive = false
    @State private var isHoveringSchedule = false
    
    enum FocusField: Hashable {
        case slider
        case timeField
        case startButton
        case editButton
        case addToBlocklist
    }
    
    var activeBlockedCount: Int {
        BlockedURLsHelpers.activeBlockedCount(blockedURLs)
    }
    
    var activePathCount: Int {
        BlockedURLsHelpers.activePathCount(blockedURLs)
    }
    
    // Format blocking count message with separate domain and path counts
    var blockingCountMessage: String {
        BlockedURLsHelpers.blockingCountMessage(blockedURLs)
    }
    
    // Unique identifier for the blockedURLs state to force view updates
    var blockedURLsStateId: String {
        BlockedURLsHelpers.blockedURLsStateId(blockedURLs)
    }
    
    var timeDisplay: String {
        TimeHelpers.timeDisplay(minutes: minutes, isEasterEggUnlocked: isEasterEggUnlocked, days: days)
    }
    
    var countdownDisplay: String {
        TimeHelpers.countdownDisplay(remainingTime: remainingTime, hideSeconds: hideSeconds)
    }
    
    @ViewBuilder
    var currentScreenView: some View {
        switch currentScreen {
        case .main:
            mainView
        case .editList:
            BlocklistEditorView(
                blockedURLs: $blockedURLs, isBlockingMode: isBlocking,
                blockingMode: $blockingMode,
                currentScreen: $currentScreen,
                showingTips: $showingTips
            )
        case .domainDetail(let domainId):
            DomainDetailView(
                blockedURLs: $blockedURLs,
                domainId: domainId,
                isBlockingMode: isBlocking,
                currentScreen: $currentScreen,
                blockingMode: $blockingMode
            )
        case .advancedSettings:
            AdvancedSettingsView(currentScreen: $currentScreen, blockingMode: $blockingMode, isBlockingMode: isBlocking)
        case .blockSchedule:
            BlockScheduleView(currentScreen: $currentScreen, blockingMode: $blockingMode, isScheduleActive: $isScheduleActive)
        case .about:
            AboutView(currentScreen: $currentScreen)
        }
    }
    
    var body: some View {
        currentScreenView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minWidth: 520, minHeight: 420)
            .id(blockedURLsStateId) // Force view refresh when blockedURLs changes
            .alert(isPresented: $showingConfirmation) {
                let messageText: Text = {
                    let countText = blockingCountMessage
                    return Text(Strings.MainScreen.startBlockingMessage(blockingMode: blockingMode, countText: countText, timeDisplay: timeDisplay))
                }()
                return Alert(
                    title: Text(Strings.MainScreen.startBlockingTitle),
                    message: messageText,
                    primaryButton: .default(Text(Strings.MainScreen.startBlock), action: { startBlocking() }),
                    secondaryButton: .cancel(Text(Strings.Common.cancel))
                )
            }
            .overlay(
                Group {
                    if showingTips {
                        TipsOverlayView(
                            onDismiss: {
                                showingTips = false
                                hasSeenTips = true
                            }
                        )
                        .zIndex(1000)
                        .allowsHitTesting(true)
                    }
                    if showingStopConfirmation {
                        StopConfirmationOverlayView(
                            countdownTime: stopCountdownTime,
                            onResume: {
                                resumeBlocking()
                            },
                            onStopBlocking: {
                                stopBlocking()
                            }
                        )
                        .zIndex(1000)
                        .allowsHitTesting(true)
                    }
                    if showingIntensityDropdown {
                        IntensityDropdownOverlay(
                            selectedLevel: $intensityLevel,
                            onDismiss: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showingIntensityDropdown = false
                                }
                            }
                        )
                        .zIndex(999)
                        .allowsHitTesting(true)
                    }
                    if showingExtendTimer {
                        ExtendTimerOverlayView(
                            extensionMinutes: $extensionMinutes,
                            onConfirm: { minutes in
                                extendTimer(by: minutes)
                                HelperConnection.shared.send_extendBlocking(minutes: Int(minutes))
                                viewModel.extendBlockTimer(by: Int(minutes))
                                withAnimation(DesignSystem.animationNormal) {
                                    showingExtendTimer = false
                                }
                            },
                            onDismiss: {
                                withAnimation(DesignSystem.animationNormal) {
                                    showingExtendTimer = false
                                }
                            }
                        )
                        .zIndex(998)
                        .allowsHitTesting(true)
                    }
                }
            )
            .onAppear {
                // Show tips on first launch only
                if !hasSeenTips {
                    // Small delay to ensure view is fully loaded
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingTips = true
                        // Clear focus when tips modal shows
                        focusedField = nil
                    }
                } else {
                    // Focus slider on startup
                    focusedField = .slider
                }
                blockedURLs = viewModel.blockerStorage?.items ?? []
            }
            .onChange(of: showingTips) { isShowing in
                // Clear focus when tips modal is shown
                if isShowing {
                    focusedField = nil
                } else {
                    // Set focus to slider after tips are dismissed (if not editing time)
                    if !isEditingTime {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            focusedField = .slider
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowAboutScreen"))) { _ in
                currentScreen = .about
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowEditListScreen"))) { _ in
                currentScreen = .editList
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowAdvancedSettingsScreen"))) { _ in
                currentScreen = .advancedSettings
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowBlockScheduleScreen"))) { _ in
                currentScreen = .blockSchedule
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowTipsScreen"))) { _ in
                showingTips = true
            }
    }
    
    var mainView: some View {
        ZStack {
            // Dark gradient background
            DesignSystem.backgroundGradient
                .ignoresSafeArea(.all)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture {
                    if showingIntensityDropdown {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showingIntensityDropdown = false
                        }
                    }
                }
            
            if isBlocking {
                // Countdown mode - large timer display
                VStack(spacing: 20) {
                    Spacer()
                    
                    // Logo
                    if let nsImage = NSImage(named: "icon") {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(DesignSystem.font(size: DesignSystem.fontSizeDisplayXXXL))
                            .foregroundColor(DesignSystem.accentOrange)
                    }
                    
                    // Large countdown timer
                    Text(countdownDisplay)
                        .font(DesignSystem.font(size: DesignSystem.fontSizeDisplayHuge, weight: DesignSystem.fontWeightBold, design: .monospaced))
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
                                Text(countdownDisplay)
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeDisplayHuge, weight: DesignSystem.fontWeightBold, design: .monospaced))
                            )
                        )
                        .shadow(color: DesignSystem.overlayBackground.opacity(DesignSystem.opacityHigh), radius: 2, x: 0, y: 2)
                    
                    // Blocking info
                    VStack(spacing: DesignSystem.spacingXSmall) {
                        if blockingMode == .blocklist {
                            if activeBlockedCount == 0 {
                                Text(Strings.MainScreen.noSitesBlocked)
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightSemibold))
                                    .foregroundColor(DesignSystem.textSecondary)
                                Text(Strings.MainScreen.blocklistEmpty)
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeMedium))
                                    .foregroundColor(DesignSystem.textTertiary)
                            } else {
                                Text("\(Strings.MainScreen.blocking) \(blockingCountMessage)")
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightSemibold))
                                    .foregroundColor(DesignSystem.textSecondary)
                                    .onTapGesture {
                                        currentScreen = .editList
                                    }
                            }
                        } else {
                            if activeBlockedCount == 0 {
                                Text(Strings.MainScreen.noSitesAllowed)
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightSemibold))
                                    .foregroundColor(DesignSystem.textSecondary)
                                Text(Strings.MainScreen.allWebsitesBlocked)
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeMedium))
                                    .foregroundColor(DesignSystem.textTertiary)
                            } else {
                                Text("\(Strings.MainScreen.allowing) \(blockingCountMessage)")
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightSemibold))
                                    .foregroundColor(DesignSystem.textSecondary)
                                Text(Strings.MainScreen.allOtherSitesBlocked)
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeMedium))
                                    .foregroundColor(DesignSystem.textTertiary)
                            }
                        }
                    }
                    .padding(.bottom, DesignSystem.spacingMedium)
                    
                    // Add to list and Extend Timer buttons (chip style)
                    HStack(spacing: DesignSystem.spacingSmall) {
                        Button(action: {
                            showingExtendTimer = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeBase))
                                Text("Extend Timer")
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightMedium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, DesignSystem.spacingSmall)
                            .padding(.vertical, DesignSystem.spacingXSmall)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                    .fill(isHoveringExtendTimer ? DesignSystem.hoverBackground : Color.clear)
                            )
                            .modifier(DesignSystem.buttonStyle(color: .white))
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .onHover { hovering in
                            withAnimation(DesignSystem.animationFast) {
                                isHoveringExtendTimer = hovering
                            }
                        }
                        
                        Button(action: {
                            currentScreen = .editList
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle")
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeBase))
                                Text(blockingMode == .blocklist ? Strings.MainScreen.addToBlocklist : Strings.MainScreen.addToAllowlist)
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightMedium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, DesignSystem.spacingSmall)
                            .padding(.vertical, DesignSystem.spacingXSmall)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                    .fill(isHoveringAddToList ? DesignSystem.hoverBackground : Color.clear)
                            )
                            .modifier(DesignSystem.buttonStyle(color: .white))
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .keyboardShortcut("a", modifiers: .command)
                        .onHover { hovering in
                            withAnimation(DesignSystem.animationFast) {
                                isHoveringAddToList = hovering
                            }
                        }
                    }
                    .padding(.bottom, DesignSystem.spacingSmall)
                    
                    // Stop Blocking button (only for low and medium intensity)
                    if intensityLevel == .low || intensityLevel == .medium {
                        Button(action: {
                            if intensityLevel == .low {
                                // Low intensity: stop immediately
                                stopBlocking()
                            } else {
                                // Medium intensity: show confirmation with countdown
                                showStopConfirmation()
                            }
                        }) {
                            Text(Strings.MainScreen.stopBlocking)
                                .font(DesignSystem.font(size: DesignSystem.fontSizeXLarge, weight: DesignSystem.fontWeightMedium))
                                .foregroundColor(DesignSystem.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .contentShape(Rectangle())
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.radiusXXLarge)
                                        .fill(isHoveringStopButton ? DesignSystem.hoverBackground : Color.clear)
                                )
                                .modifier(DesignSystem.buttonStyle(color: .white))
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusXXLarge))
                        }
                        .buttonStyle(.plain)
                        .help(intensityLevel == .low ? Strings.Help.stopBlockingImmediately : Strings.Help.stopBlockingWithConfirmation)
                        .focusable(false)
                        .onHover { hovering in
                            withAnimation(DesignSystem.animationFast) {
                                isHoveringStopButton = hovering
                            }
                        }
                        .padding(.horizontal, DesignSystem.spacingLarge)
                        .padding(.bottom, DesignSystem.spacingXLargePlusMedium)
                    } else {
                        // Add spacer for high intensity to maintain consistent layout
                        Spacer()
                            .frame(height: DesignSystem.spacingXLargePlusMedium)
                    }
                }
            } else {
                // Configuration mode
                VStack(spacing: 0) {
                    // Logo at top (draggable easter egg)
                    GeometryReader { geometry in
                    HStack {
                        Spacer()
                        ZStack {
                            // Background view to prevent window dragging
                            NonDraggableBackgroundView()
                                    .frame(width: 56, height: 56)
                                
                            Group {
                            if let nsImage = NSImage(named: "AppIcon") {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 48, height: 48)
                                } else {
                                    Image(systemName: "shield.lefthalf.filled")
                                        .font(DesignSystem.font(size: DesignSystem.fontSizeDisplayXL))
                                        .foregroundColor(DesignSystem.textPrimary)
                                }
                            }
                                    .rotationEffect(.degrees(logoRotation))
                            .offset(logoDragOffset)
                            .contentShape(Rectangle())
                                    .gesture(
                                isEasterEggUnlocked ? nil : DragGesture()
                                    .onChanged { value in
                                        let logoSize: CGFloat = 48
                                        let windowWidth = geometry.size.width
                                        
                                        // Get window bounds for vertical edge detection
                                        let windowHeight: CGFloat
                                        if let window = NSApplication.shared.windows.first {
                                            windowHeight = window.contentView?.bounds.height ?? 450
                                        } else {
                                            windowHeight = 450 // fallback
                                        }
                                        
                                        // Calculate where logo center would be (starts at window center horizontally, near top vertically)
                                        let centerX = windowWidth / 2
                                        let logoCenterX = centerX + value.translation.width
                                        
                                        // For vertical, logo starts near top (approximately 40-50px from top)
                                        // Check if it reaches top or bottom edge
                                        let approximateTopOffset: CGFloat = 50
                                        let logoCenterY = approximateTopOffset + value.translation.height
                                        
                                        // Check if logo reaches any edge
                                        let halfLogo = logoSize / 2
                                        let reachedLeftEdge = logoCenterX - halfLogo <= 0
                                        let reachedRightEdge = logoCenterX + halfLogo >= windowWidth
                                        let reachedTopEdge = logoCenterY - halfLogo <= 0
                                        let reachedBottomEdge = logoCenterY + halfLogo >= windowHeight
                                        let reachedAnyEdge = reachedLeftEdge || reachedRightEdge || reachedTopEdge || reachedBottomEdge
                                        
                                        if reachedAnyEdge && !hasReachedEdge {
                                            hasReachedEdge = true
                                        }
                                        
                                        // Apply rubberbanding effect when dragging beyond edge
                                        var newOffset = value.translation
                                        
                                        // Horizontal rubberbanding
                                        if reachedLeftEdge {
                                            let edgePosition = -centerX + halfLogo
                                            let overshoot = abs(value.translation.width - edgePosition)
                                            newOffset.width = edgePosition - overshoot * 0.3
                                        } else if reachedRightEdge {
                                            let edgePosition = centerX - halfLogo
                                            let overshoot = abs(value.translation.width - edgePosition)
                                            newOffset.width = edgePosition + overshoot * 0.3
                                        }
                                        
                                        // Vertical rubberbanding
                                        if reachedTopEdge {
                                            let edgePosition = -approximateTopOffset + halfLogo
                                            let overshoot = abs(value.translation.height - edgePosition)
                                            newOffset.height = edgePosition - overshoot * 0.3
                                        } else if reachedBottomEdge {
                                            let edgePosition = windowHeight - approximateTopOffset - halfLogo
                                            let overshoot = abs(value.translation.height - edgePosition)
                                            newOffset.height = edgePosition + overshoot * 0.3
                                        }
                                        
                                        logoDragOffset = newOffset
                                    }
                                    .onEnded { value in
                                        guard !isEasterEggUnlocked else { return }
                                        
                                        // If we reached the edge, bounce back and unlock
                                        if hasReachedEdge {
                                            // Bounce back to center
                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                                                logoDragOffset = .zero
                                            }
                                            
                                            // After bounce back, spin and unlock
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                // Spin animation
                                                    withAnimation(.easeOut(duration: 1.5)) {
                                                        logoRotation = 1080 // 3 full spins
                                                    }
                                                    
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                                            isEasterEggUnlocked = true
                                                            logoRotation = 0
                                                        logoDragOffset = .zero
                                                        hasReachedEdge = false
                                                            // Initialize to 1 day when unlocked
                                                            days = 1
                                                            daysInput = "1"
                                                            hoursInput = "0"
                                                            minutesInput = "0"
                                                            minutes = Double(days * 24 * 60)
                                                    }
                                                        }
                                                    }
                                                } else {
                                            // Normal drag end - bounce back to center
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                logoDragOffset = .zero
                                                hasReachedEdge = false
                                            }
                                        }
                                    }
                            )
                        }
                        .frame(width: 56, height: 56)
                        Spacer()
                    }
                    .offset(y: -16)
                    .padding(.top, DesignSystem.spacingLarge)
                    .padding(.bottom, DesignSystem.spacingXXSmall)
                    }
                    .frame(height: 70)
                    
                    // Schedule indicator pill below logo
                    HStack {
                        Spacer()
                        Button(action: {
                            currentScreen = .blockSchedule
                        }) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(isScheduleActive ? Color.green.opacity(0.7) : Color.gray.opacity(0.5))
                                    .frame(width: 6, height: 6)
                                Text(isScheduleActive ? "Schedule On" : "Schedule Off")
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeXSmall))
                                    .foregroundColor(Color.gray.opacity(0.7))
                            }
                            .padding(.horizontal, DesignSystem.spacingSmall)
                            .padding(.vertical, DesignSystem.spacingXSmall)
                            .background(
                                Capsule()
                                    .stroke(Color.gray.opacity(isHoveringSchedule ? 0.4 : 0.25), lineWidth: 1)
                                    .background(
                                        Capsule()
                                            .fill(isHoveringSchedule ? Color.gray.opacity(0.1) : Color.clear)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            withAnimation(DesignSystem.animationFast) {
                                isHoveringSchedule = hovering
                            }
                        }
                        Spacer()
                    }
                    .padding(.bottom, DesignSystem.spacingSmall)
                    
                    Spacer()
                    
                    // Main content with consistent spacing
                    VStack(spacing: DesignSystem.spacingMedium) {
                    // Time slider card
                    VStack(spacing: DesignSystem.spacingMedium) {
                        HStack(alignment: .top, spacing: DesignSystem.spacingXSmall) {
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
                            
                            if isEditingTime && !isEasterEggUnlocked {
                                HStack(spacing: 8) {
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
                                                commitTimeEdit()
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
                                                focusedField = nil
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
                                                focusedField = nil
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
                                                commitTimeEdit()
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
                                                focusedField = nil
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
                                                focusedField = nil
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
                                    
                                    // Done button
                                    Button(action: {
                                        commitTimeEdit()
                                    }) {
                                        Text(Strings.Common.done)
                                            .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightMedium))
                                            .foregroundColor(DesignSystem.textPrimary)
                                            .padding(.horizontal, DesignSystem.spacingMedium)
                                            .padding(.vertical, DesignSystem.spacingSmall)
                                            .background(
                                                RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                                    .fill(isHoveringDoneButton ? DesignSystem.hoverBackground : Color.clear)
                                            )
                                            .modifier(DesignSystem.buttonStyle())
                                    }
                                    .buttonStyle(.plain)
                                    .focusable(false)
                                    .onHover { hovering in
                                        withAnimation(DesignSystem.animationFast) {
                                            isHoveringDoneButton = hovering
                                        }
                                    }
                                }
                                .frame(height: 42, alignment: .center)
                            } else if isEditingTime && isEasterEggUnlocked {
                                // Show days/hours/minutes editor when unlocked and editing
                                HStack(spacing: 8) {
                                    HStack(spacing: 6) {
                                        // Days
                                        HStack(spacing: 2) {
                                            ArrowKeyTextField(
                                                text: $daysInput,
                                                onUpArrow: { adjustDays(by: 1) },
                                                onDownArrow: { adjustDays(by: -1) },
                                                onSubmit: { updateMinutesFromAllInputs() },
                                                onFocusChange: { hasFocus in
                                                    if !hasFocus {
                                                        updateMinutesFromAllInputs()
                                                    }
                                                }
                                            )
                                            .frame(width: max(40, CGFloat(daysInput.count) * 20 + 10))
                                            
                                            VStack(spacing: 2) {
                                                Button(action: { adjustDays(by: 1) }) {
                                                    Image(systemName: "chevron.up")
                                                        .font(DesignSystem.font(size: DesignSystem.fontSizeXSmall, weight: DesignSystem.fontWeightBold))
                                                        .foregroundColor(DesignSystem.textPrimary)
                                                        .frame(width: 20, height: 16)
                                                        .contentShape(Rectangle())
                                                }
                                                .buttonStyle(.plain)
                                                .focusable(false)
                                                
                                                Button(action: { adjustDays(by: -1) }) {
                                                    Image(systemName: "chevron.down")
                                                        .font(DesignSystem.font(size: DesignSystem.fontSizeXSmall, weight: DesignSystem.fontWeightBold))
                                                        .foregroundColor(DesignSystem.textPrimary)
                                                        .frame(width: 20, height: 16)
                                                        .contentShape(Rectangle())
                                                }
                                                .buttonStyle(.plain)
                                                .focusable(false)
                                            }
                                            
                                            Text(Strings.MainScreen.days)
                                                .font(DesignSystem.font(size: DesignSystem.fontSizeHeading, weight: DesignSystem.fontWeightMedium))
                                                .foregroundColor(DesignSystem.textSecondary)
                                                .padding(.top, DesignSystem.spacingXSmall)
                                        }
                                        
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
                                                onSubmit: { updateMinutesFromAllInputs() },
                                                onFocusChange: { hasFocus in
                                                    if !hasFocus {
                                                        updateMinutesFromAllInputs()
                                                    }
                                                }
                                            )
                                            .frame(width: max(40, CGFloat(hoursInput.count) * 20 + 10))
                                            
                                            VStack(spacing: 2) {
                                                Button(action: {
                                                    focusedField = nil
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
                                                    focusedField = nil
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
                                                onSubmit: { updateMinutesFromAllInputs() },
                                                onFocusChange: { hasFocus in
                                                    if !hasFocus {
                                                        updateMinutesFromAllInputs()
                                                    }
                                                }
                                            )
                                            .frame(width: max(40, CGFloat(minutesInput.count) * 20 + 10))
                                            
                                            VStack(spacing: 2) {
                                                Button(action: {
                                                    focusedField = nil
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
                                                    focusedField = nil
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
                                        
                                        // Done button
                                        Button(action: {
                                        commitTimeEdit()
                                        }) {
                                            Text(Strings.Common.done)
                                                .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightMedium))
                                                .foregroundColor(DesignSystem.textPrimary)
                                                .padding(.horizontal, DesignSystem.spacingMedium)
                                                .padding(.vertical, DesignSystem.spacingSmall)
                                                .background(
                                                    RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                                        .fill(isHoveringDoneButton ? DesignSystem.hoverBackground : Color.clear)
                                                )
                                                .modifier(DesignSystem.buttonStyle())
                                        }
                                        .buttonStyle(.plain)
                                        .focusable(false)
                                        .onHover { hovering in
                                            withAnimation(DesignSystem.animationFast) {
                                                isHoveringDoneButton = hovering
                                            }
                                        }
                                    }
                                    .frame(height: 42, alignment: .center)
                                } else {
                                // Display mode - show formatted time (works for both unlocked and locked)
                                    Text(timeDisplay)
                                        .font(DesignSystem.font(size: DesignSystem.fontSizeDisplayXL, weight: DesignSystem.fontWeightBold))
                                        .foregroundColor(DesignSystem.textPrimary)
                                        .padding(.horizontal, DesignSystem.spacingMediumSmall)
                                        .padding(.vertical, DesignSystem.spacingXSmall)
                                        .background(
                                        RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                            .fill(isHoveringTime ? DesignSystem.textPrimary.opacity(DesignSystem.opacityMedium) : Color.clear)
                                            .overlay(
                                                    RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                                    .stroke(isHoveringTime ? DesignSystem.hoverBorder : Color.clear, lineWidth: 1)
                                                )
                                        )
                                        .frame(height: 42, alignment: .center)
                                        .animation(DesignSystem.animationFast, value: isHoveringTime)
                                        .onTapGesture {
                                            startEditingTime()
                                        }
                                        .onHover { hovering in
                                            isHoveringTime = hovering
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }
                                        .help(Strings.Help.clickToEditTime)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Show slider only if easter egg is not unlocked
                        if !isEasterEggUnlocked {
                            // Custom styled slider (original, only shown when easter egg not unlocked)
                            VStack(spacing: DesignSystem.spacingXSmall) {
                                ZStack(alignment: .center) {
                                    // Tick marks integrated into slider
                                    GeometryReader { geometry in
                                        HStack(spacing: 0) {
                                            ForEach(0..<97) { index in
                                                let minuteValue = index * 15
                                                if minuteValue <= 1440 {
                                                    VStack(spacing: 0) {
                                                        Rectangle()
                                                            .fill(DesignSystem.textPrimary.opacity(DesignSystem.opacitySubtle))
                                                            .frame(width: 0.5, height: index % 4 == 0 ? 8 : 4)
                                                    }
                                                    .frame(maxWidth: .infinity)
                                                }
                                            }
                                        }
                                    }
                                    .frame(height: 8)
                                    .allowsHitTesting(false)
                                    
                                    Group {
                                    Group {
                                        if showingTips {
                                            Slider(value: $minutes, in: 0...1440, step: 15)
                                                .accentColor(.white)
                                                .disabled(true)
                                                .opacity(1.0)
                                                .allowsHitTesting(false)
                                        } else {
                                            Slider(value: $minutes, in: 0...1440, step: 15)
                                                .accentColor(.white)
                                                .disabled(isEditingTime)
                                                .opacity(isEditingTime ? 0.4 : 1.0)
                                                .focusable(false)
                                        }
                                    }
                                    }
                                }
                                
                                HStack {
                                    Text(Strings.MainScreen.oneMinute)
                                        .font(DesignSystem.font(size: DesignSystem.fontSizeSmall))
                                        .foregroundColor(DesignSystem.textTertiary)
                                    Spacer()
                                    Text(Strings.MainScreen.sixHours)
                                        .font(DesignSystem.font(size: DesignSystem.fontSizeSmall))
                                        .foregroundColor(DesignSystem.textTertiary)
                                    Spacer()
                                    Text(Strings.MainScreen.twelveHours)
                                        .font(DesignSystem.font(size: DesignSystem.fontSizeSmall))
                                        .foregroundColor(DesignSystem.textTertiary)
                                    Spacer()
                                    Text(Strings.MainScreen.eighteenHours)
                                        .font(DesignSystem.font(size: DesignSystem.fontSizeSmall))
                                        .foregroundColor(DesignSystem.textTertiary)
                                    Spacer()
                                    Text(Strings.MainScreen.twentyFourHours)
                                        .font(DesignSystem.font(size: DesignSystem.fontSizeSmall))
                                        .foregroundColor(DesignSystem.textTertiary)
                                }
                            }
                        }
                    }
                    .padding(DesignSystem.spacingXLarge)
                    .modifier(DesignSystem.cardStyle())
                    .padding(.horizontal, DesignSystem.spacingLarge)
                    
                    // Site section with intensity integrated
                    VStack(spacing: DesignSystem.spacingMedium) {
                        HStack(spacing: DesignSystem.spacingSmall) {
                            Image(systemName: blockingMode == .blocklist ? "hand.raised.slash" : "hand.raised.fill")
                                .font(DesignSystem.font(size: DesignSystem.fontSizeXXLarge))
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
                                        Image(systemName: blockingMode == .blocklist ? "hand.raised.slash" : "hand.raised.fill")
                                            .font(DesignSystem.font(size: DesignSystem.fontSizeXXLarge))
                                    )
                                )
                                .shadow(color: DesignSystem.overlayBackground.opacity(DesignSystem.opacityHigh), radius: 2, x: 0, y: 2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(blockingMode == .blocklist ? Strings.MainScreen.willBlock : Strings.MainScreen.willAllow)
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeXSmall, weight: DesignSystem.fontWeightMedium))
                                    .foregroundColor(blockingMode == .allowlist ? DesignSystem.textPrimary : DesignSystem.textTertiary)
                                    .textCase(.uppercase)
                                Text(blockedSitesText)
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightMedium))
                                    .foregroundColor(DesignSystem.textPrimary)
                                    .lineLimit(1)
                                    .padding(.top, DesignSystem.spacingXXSmall)
                                    .padding(.bottom, DesignSystem.spacingXXSmall)
                            }
                            
                            Spacer()
                            
                            // Intensity selector (centered in middle, aligned with Will Block)
                            VStack(alignment: .center, spacing: 2) {
                                // Intensity label row (centered above dropdown)
                                Text(Strings.MainScreen.intensity)
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeXSmall, weight: DesignSystem.fontWeightMedium))
                                    .foregroundColor(DesignSystem.textTertiary)
                                    .textCase(.uppercase)
                                
                                // Custom intensity dropdown button
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        showingIntensityDropdown.toggle()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Text(intensityLevel.displayName)
                                            .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightMedium))
                                            .foregroundColor(DesignSystem.textPrimary)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 8, weight: DesignSystem.fontWeightSemibold))
                                            .foregroundColor(isHoveringIntensity ? DesignSystem.textPrimary : DesignSystem.textSecondary)
                                            .rotationEffect(.degrees(showingIntensityDropdown ? 180 : 0))
                                    }
                                    .padding(.horizontal, DesignSystem.spacingXSmall)
                                    .padding(.vertical, DesignSystem.spacingXXSmallPlus)
                                    .frame(minWidth: 100)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                            .fill(isHoveringIntensity ? DesignSystem.textPrimary.opacity(DesignSystem.opacityMedium) : Color.clear)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                                    .stroke(isHoveringIntensity ? DesignSystem.hoverBorder : Color.clear, lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    withAnimation(DesignSystem.animationFast) {
                                        isHoveringIntensity = hovering
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Edit button
                            Button(action: {
                                currentScreen = .editList
                            }) {
                                HStack(spacing: DesignSystem.spacingXSmall) {
                                    Image(systemName: "list.bullet.rectangle")
                                        .font(DesignSystem.font(size: DesignSystem.fontSizeMedium))
                                    Text(Strings.Common.edit)
                                        .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightMedium))
                                }
                                .foregroundColor(DesignSystem.textPrimary)
                                .padding(.horizontal, DesignSystem.spacingMedium)
                                .padding(.vertical, DesignSystem.spacingSmall)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                        .fill(isHoveringEditButton ? DesignSystem.hoverBackground : Color.clear)
                                )
                                .modifier(DesignSystem.buttonStyle())
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .onHover { hovering in
                                withAnimation(DesignSystem.animationFast) {
                                    isHoveringEditButton = hovering
                                }
                            }
                            .keyboardShortcut("e", modifiers: .command)
                        }
                    }
                    .padding(DesignSystem.spacingMedium)
                    .modifier(DesignSystem.cardStyle())
                    .padding(.horizontal, DesignSystem.spacingLarge)
                    }
                    // End of main content VStack
                    .padding(.bottom, DesignSystem.spacingMedium)
                    
                    Spacer()
                    
                    // Start button at bottom
                    Button(action: {
                        if intensityLevel == .high {
                            showingConfirmation = true
                        } else {
                            startBlocking()
                        }
                    }) {
                        Text(Strings.MainScreen.startBlock)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "#4A4A4A"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .contentShape(Rectangle())
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: DesignSystem.radiusXXLarge)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(stops: [
                                                .init(color: Color(hex: "#F0F5F5"), location: 0.0),
                                                .init(color: Color(hex: "#8A9A98"), location: 0.5),
                                                .init(color: Color(hex: "#B5C9C5"), location: 1.0)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                
                                RoundedRectangle(cornerRadius: DesignSystem.radiusXXLarge)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(hex: "#E8EDED"),
                                                Color(hex: "#A8B5B3")
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .padding(DesignSystem.spacingTiny)
                                
                                if isPressingStartButton {
                                    RoundedRectangle(cornerRadius: DesignSystem.radiusXXLarge)
                                        .fill(DesignSystem.overlayBackground.opacity(DesignSystem.opacityLow))
                                        .padding(DesignSystem.spacingTiny)
                                }
                                
                                // Metallic border - smoother blended gradient
                                RoundedRectangle(cornerRadius: DesignSystem.radiusXXLarge)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(stops: [
                                                .init(color: DesignSystem.textPrimary.opacity(DesignSystem.opacityHigh), location: 0.0),
                                                .init(color: Color.gray.opacity(DesignSystem.opacityMedium), location: 0.2),
                                                .init(color: Color.gray.opacity(DesignSystem.opacityMedium), location: 0.4),
                                                .init(color: DesignSystem.overlayBackground.opacity(DesignSystem.opacityMedium), location: 0.6),
                                                .init(color: Color.gray.opacity(DesignSystem.opacityMedium), location: 0.8),
                                                .init(color: Color.gray.opacity(DesignSystem.opacityMedium), location: 1.0)
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 1.5
                                    )
                            }
                        )
                        .scaleEffect(isHoveringButton ? 1.01 : 1.0)
                        .scaleEffect(isPressingStartButton ? 0.99 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .help(Strings.Help.startBlocking)
                    .focusable(false)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !isPressingStartButton {
                                    withAnimation(DesignSystem.animationFast) {
                                        isPressingStartButton = true
                                    }
                                }
                            }
                            .onEnded { _ in
                                withAnimation(DesignSystem.animationFast) {
                                    isPressingStartButton = false
                                }
                            }
                    )
                    .onHover { hovering in
                        withAnimation(DesignSystem.animationFast) {
                            isHoveringButton = hovering
                        }
                    }
                    .padding(.horizontal, DesignSystem.spacingLarge)
                    .padding(.bottom, DesignSystem.spacingXLargePlusMedium)
                }
            }
        }
        .onAppear {
            print("onAppear main view")
            HelperConnection.shared.blockedStateHandler = { minutes in
                print("Already in blocked state, show remaining minutes:\(minutes)")
                Task { @MainActor in
                    print("Already in blocked state, show remaining minutes:\(minutes)")
                    await showBlockingStateForReminingMinutes(minutes: minutes)
                }
            }
            
            HelperConnection.shared.send_getBlockedStates()
            // Don't focus slider on startup - let tips modal show first if needed
            // Focus will be set after tips are dismissed
        }
    }
    
    private func incrementIntensity() {
        intensityLevel = IntensityHelpers.nextIntensity(current: intensityLevel)
    }
    
    private func decrementIntensity() {
        intensityLevel = IntensityHelpers.previousIntensity(current: intensityLevel)
    }
    
    private func startBlocking() {
        if AppPreferences.showVerifyNetworkAlertBeforeBlock {
           if  SCUIUtility.checkNetworkAndShowNetworkAlert() == false {
                return
            }
        }
        startBlocking(minutes: minutes)
        viewModel.startBlocking(endDate: Date().addingTimeInterval(minutes * 60))
    }
    
    private func showBlockingStateForReminingMinutes(minutes: Double) {
        withAnimation(DesignSystem.animationNormal) {
            isBlocking = true
//            viewModel.updateBlockList(newBlockedDomains: blockedURLs, time: minutes)
            // Calculate total time including days if easter egg is unlocked
            remainingTime = minutes * 60
            // Start countdown timer
            if timer != nil {
                timer?.invalidate()
                timer = nil
            }
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if remainingTime > 0 {
                    remainingTime -= 1
                } else {
                    showNonBlockingState()
                }
            }
        }
 
    }
    
    private func showNonBlockingState() {
        viewModel.stopBlocking()
        withAnimation(DesignSystem.animationNormal) {
            isBlocking = true
        }
        withAnimation(DesignSystem.animationNormal) {
            isBlocking = false
        }
        timer?.invalidate()
        timer = nil
        remainingTime = 0
        cancelStopCountdown()
    }
    
    private func startBlocking(minutes: Double) {
        HelperConnection.shared.send_startNetwrokBlocking(minutes: Int(minutes))
    }

    private func stopBlocking() {
        showNonBlockingState()
        HelperConnection.shared.send_stopNetworkBlocking()
        viewModel.stopBlocking()
    }
    
    private func showStopConfirmation() {
        stopCountdownTime = 600
        showingStopConfirmation = true
        
        // Start the countdown timer
        stopCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if stopCountdownTime > 0 {
                stopCountdownTime -= 1
            } else {
                // Countdown finished, just stop the timer (user must click Yes to stop)
                stopCountdownTimer?.invalidate()
                stopCountdownTimer = nil
            }
        }
    }
    
    private func cancelStopCountdown() {
        stopCountdownTimer?.invalidate()
        stopCountdownTimer = nil
        stopCountdownTime = 600
        showingStopConfirmation = false
    }
    
    private func resumeBlocking() {
        cancelStopCountdown()
    }
    
    private func extendTimer(by minutes: Double) {
        remainingTime += minutes * 60
    }
    
    private var blockedSitesText: String {
        BlockedURLsHelpers.blockedSitesText(blockedURLs)
    }
    
    private func startEditingTime() {
        let components = TimeHelpers.extractTimeComponents(minutes: minutes, isEasterEggUnlocked: isEasterEggUnlocked, days: days)
        daysInput = String(components.days)
        hoursInput = String(components.hours)
        minutesInput = String(components.minutes)
        isEditingTime = true
        focusedField = .timeField
    }
    
    private func commitTimeEdit() {
        // Update minutes from the current input values
        if isEasterEggUnlocked {
            updateMinutesFromAllInputs()
        } else {
            updateMinutesFromInputs()
        }
        isEditingTime = false
        focusedField = nil
    }
    
    private func updateMinutesFromInputs() {
        let result = TimeHelpers.calculateMinutesFromInputs(
            hoursInput: hoursInput,
            minutesInput: minutesInput,
            isEasterEggUnlocked: isEasterEggUnlocked
        )
        hoursInput = result.hoursInput
        minutesInput = result.minutesInput
        minutes = result.totalMinutes
    }
    
    private func updateMinutesFromAllInputs() {
        let result = TimeHelpers.calculateMinutesFromAllInputs(
            daysInput: daysInput,
            hoursInput: hoursInput,
            minutesInput: minutesInput,
            currentDays: days,
            isEasterEggUnlocked: isEasterEggUnlocked
        )
        days = result.days
        daysInput = result.daysInput
        hoursInput = result.hoursInput
        minutesInput = result.minutesInput
        minutes = result.totalMinutes
    }
    
    private func adjustDays(by amount: Int) {
        if isEasterEggUnlocked {
            let result = TimeHelpers.adjustDays(
                currentDaysInput: daysInput,
                currentDays: days,
                amount: amount
            )
            days = result.days
            daysInput = result.daysInput
            updateMinutesFromAllInputs()
        }
    }
    
    private func adjustHours(by amount: Int) {
        let result = TimeHelpers.adjustHours(
            daysInput: daysInput,
            hoursInput: hoursInput,
            minutesInput: minutesInput,
            currentDays: days,
            currentMinutes: minutes,
            amount: amount,
            isEasterEggUnlocked: isEasterEggUnlocked
        )
        days = result.days
        daysInput = result.daysInput
        hoursInput = result.hoursInput
        minutesInput = result.minutesInput
        minutes = result.totalMinutes
    }
    
    private func adjustMinutes(by amount: Int) {
        let result = TimeHelpers.adjustMinutes(
            daysInput: daysInput,
            hoursInput: hoursInput,
            minutesInput: minutesInput,
            currentDays: days,
            currentMinutes: minutes,
            amount: amount,
            isEasterEggUnlocked: isEasterEggUnlocked
        )
        days = result.days
        daysInput = result.daysInput
        hoursInput = result.hoursInput
        minutesInput = result.minutesInput
        minutes = result.totalMinutes
    }
}

#Preview {
    NewContentView()
}
