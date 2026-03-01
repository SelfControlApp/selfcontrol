//
//  BlockScheduleView.swift
//  SelfControlUI
//
//  Created on 2025-10-31.
//

import SwiftUI
import AppKit

// MARK: - Block Schedule View
struct BlockScheduleView: View {
    @Binding var currentScreen: AppScreen
    @Binding var blockingMode: BlockingMode
    @Binding var isScheduleActive: Bool
    @EnvironmentObject var viewModel: FilterViewModel

    @State private var schedules: [Schedule] = []
    
    // Helper to check if any schedule is active
    private func updateScheduleStatus() {
        isScheduleActive = schedules.contains { schedule in
            schedule.isEnabled && 
            !schedule.timeSlots.isEmpty && 
            !schedule.enabledDays.isEmpty
        }
    }
    
    private func loadSchedules() {
        schedules = EventSchedulerStore.loadSchedules()
    }
    
    private func saveSchedules() {
        EventSchedulerStore.saveSchedules(schedules: schedules)
    }
    
    var body: some View {
        ZStack {
            // Dark gradient background
            DesignSystem.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
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
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    
                    Spacer()
                    
                    Text(Strings.BlockSchedule.title)
                        .font(DesignSystem.font(size: DesignSystem.fontSizeXXLarge, weight: DesignSystem.fontWeightSemibold))
                        .foregroundColor(DesignSystem.textPrimary)
                    
                    Spacer()
                    
                    // Add schedule button
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            schedules.append(Schedule(timeSlots: [], enabledDays: []))
                            saveSchedules()
                            updateScheduleStatus()
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(DesignSystem.font(size: DesignSystem.fontSizeLarge, weight: DesignSystem.fontWeightSemibold))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 60, alignment: .trailing)
                }
                .padding(.horizontal, DesignSystem.spacingLarge)
                .padding(.vertical, DesignSystem.spacingSmall)
                
                Divider()
                    .background(DesignSystem.borderPrimary)
                
                ScrollView {
                    VStack(spacing: DesignSystem.spacingMedium) {
                        
                        // Schedule list
                        VStack(spacing: DesignSystem.spacingMedium) {
                            ForEach($schedules) { $schedule in
                                ScheduleRow(
                                    schedule: $schedule,
                                    blockingMode: blockingMode,
                                    onDelete: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            schedules.removeAll { $0.id == schedule.id }
                                            saveSchedules()
                                            updateScheduleStatus()
                                        }
                                    }
                                )
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .move(edge: .bottom).combined(with: .opacity)
                                ))
                            }
                            
                            // Invisible spacer to anchor animations (always present)
                            Color.clear
                                .frame(height: 1)
                                .allowsHitTesting(false)
                        }
                        .padding(.horizontal, DesignSystem.spacingLarge)
                    }
                    .padding(.vertical, DesignSystem.spacingLarge)
                }
            }
        }
        .onChange(of: schedules) { _ in
            saveSchedules()
            updateScheduleStatus()
        }
        .onAppear {
            loadSchedules()
            updateScheduleStatus()
        }
        .onDisappear {
            print("Schedule off-screen")
            viewModel.updateScheduledEvents()
        }
    }
}

// MARK: - Schedule Row
struct ScheduleRow: View {
    @Binding var schedule: Schedule
    let blockingMode: BlockingMode
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header row with time slots summary and weekdays
            VStack(spacing: DesignSystem.spacingSmall) {
                HStack(spacing: DesignSystem.spacingMedium) {
                    // Toggle switch to enable/disable schedule
                    Toggle("", isOn: $schedule.isEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.85, green: 0.95, blue: 1.0)))
                        .labelsHidden()
                    
                    // Time slots summary or placeholder
                    if schedule.timeSlots.isEmpty {
                        Text(Strings.BlockSchedule.noTimeSlots)
                            .font(DesignSystem.font(size: DesignSystem.fontSizeBase))
                            .foregroundColor(DesignSystem.textTertiary)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(schedule.timeSlots) { slot in
                                Text(slot.displayString)
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeBase))
                                    .foregroundColor(DesignSystem.textSecondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Weekday circles
                    HStack(spacing: 6) {
                        ForEach(SCWeekday.allCases, id: \.self) { weekday in
                            WeekdayCircle(
                                weekday: weekday,
                                isEnabled: schedule.enabledDays.contains(weekday),
                                blockingMode: blockingMode,
                                onToggle: {
                                    withAnimation(DesignSystem.animationFast) {
                                        if schedule.enabledDays.contains(weekday) {
                                            schedule.enabledDays.remove(weekday)
                                        } else {
                                            schedule.enabledDays.insert(weekday)
                                        }
                                    }
                                }
                            )
                        }
                    }
                    
                    // Expand/collapse chevron (on the right)
                    Button(action: {
                        withAnimation(DesignSystem.animationFast) {
                            schedule.isExpanded.toggle()
                            // Auto-add first time slot when expanded and no slots exist
                            if schedule.isExpanded && schedule.timeSlots.isEmpty {
                                let defaultSlot = TimeSlot(
                                    startHour: 9,
                                    startMinute: 0,
                                    endHour: 17,
                                    endMinute: 0
                                )
                                schedule.timeSlots.append(defaultSlot)
                            }
                        }
                    }) {
                        Image(systemName: schedule.isExpanded ? "chevron.down" : "chevron.right")
                            .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightSemibold))
                            .foregroundColor(DesignSystem.textSecondary)
                            .frame(width: 20)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DesignSystem.spacingMedium)
                .padding(.vertical, DesignSystem.spacingMedium)
                
                // Expanded time slots
                if schedule.isExpanded {
                    VStack(spacing: 4) {
                        ForEach(schedule.timeSlots) { slot in
                            if let index = schedule.timeSlots.firstIndex(where: { $0.id == slot.id }) {
                                TimeSlotRow(
                                    timeSlot: $schedule.timeSlots[index],
                                    blockingMode: blockingMode,
                                    onDelete: {
                                        withAnimation(DesignSystem.animationFast) {
                                            schedule.timeSlots.removeAll { $0.id == slot.id }
                                        }
                                    },
                                    showDelete: schedule.timeSlots.count > 1
                                )
                            }
                        }
                        
                        // Add time slot button
                        Button(action: {
                            withAnimation(DesignSystem.animationFast) {
                                let lastEndHour = schedule.timeSlots.last?.endHour ?? 17
                                let lastEndMinute = schedule.timeSlots.last?.endMinute ?? 0
                                
                                let defaultSlot = TimeSlot(
                                    startHour: schedule.timeSlots.isEmpty ? 9 : lastEndHour,
                                    startMinute: schedule.timeSlots.isEmpty ? 0 : lastEndMinute,
                                    endHour: schedule.timeSlots.isEmpty ? 17 : min(23, lastEndHour + 2),
                                    endMinute: schedule.timeSlots.isEmpty ? 0 : lastEndMinute
                                )
                                schedule.timeSlots.append(defaultSlot)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeBase))
                                Text(Strings.BlockSchedule.addTimeSlot)
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightMedium))
                            }
                            .foregroundColor(Color(white: 0.85))
                            .padding(.horizontal, DesignSystem.spacingMedium)
                            .padding(.vertical, DesignSystem.spacingSmallMedium)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                    .fill(DesignSystem.textPrimary.opacity(DesignSystem.opacityLow))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                            .stroke(DesignSystem.textPrimary.opacity(DesignSystem.opacityLow), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, DesignSystem.spacingSmallMedium)
                        
                        // Delete schedule button (chip style)
                        Button(action: onDelete) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash.fill")
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeBase))
                                Text(Strings.BlockSchedule.deleteSchedule)
                                    .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightMedium))
                            }
                            .foregroundColor(DesignSystem.destructiveColor)
                            .padding(.horizontal, DesignSystem.spacingMedium)
                            .padding(.vertical, DesignSystem.spacingSmallMedium)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                    .fill(DesignSystem.destructiveColor.opacity(DesignSystem.opacityLow))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                            .stroke(DesignSystem.destructiveColor.opacity(DesignSystem.opacityMedium), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, DesignSystem.spacingSmall)
                    }
                    .padding(.horizontal, DesignSystem.spacingMedium)
                    .padding(.bottom, DesignSystem.spacingMedium)
                }
            }
        }
        .modifier(DesignSystem.cardStyle())
    }
}

// MARK: - Weekday Circle
struct WeekdayCircle: View {
    let weekday: SCWeekday
    let isEnabled: Bool
    let blockingMode: BlockingMode
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            Text(weekday.letter)
                .font(DesignSystem.font(size: DesignSystem.fontSizeSmall, weight: DesignSystem.fontWeightSemibold))
                .foregroundColor(isEnabled ? Color(red: 0.15, green: 0.15, blue: 0.17) : DesignSystem.textSecondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isEnabled ? DesignSystem.textPrimary : DesignSystem.backgroundSecondary)
                        .overlay(
                            Circle()
                                .stroke(isEnabled ? DesignSystem.textPrimary : DesignSystem.borderPrimary, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Time Slot Row
struct TimeSlotRow: View {
    @Binding var timeSlot: TimeSlot
    let blockingMode: BlockingMode
    let onDelete: () -> Void
    let showDelete: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            // Start time picker
            DatePicker(
                "",
                selection: Binding(
                    get: { TimeHelpers.dateFromTime(hour: timeSlot.startHour, minute: timeSlot.startMinute) },
                    set: { newDate in
                        let time = TimeHelpers.timeFromDate(newDate)
                        timeSlot.startHour = time.hour
                        timeSlot.startMinute = time.minute
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .styleDatePicker(cornerRadius: DesignSystem.radiusSmall, backgroundColor: DesignSystem.backgroundPrimary, borderColor: DesignSystem.borderPrimary)
            .frame(width: 105)
            
            Text(Strings.BlockSchedule.to)
                .font(DesignSystem.font(size: DesignSystem.fontSizeBase, weight: DesignSystem.fontWeightMedium))
                .foregroundColor(DesignSystem.textTertiary)
                .padding(.horizontal, DesignSystem.spacingXXSmall)
            
            // End time picker
            DatePicker(
                "",
                selection: Binding(
                    get: { TimeHelpers.dateFromTime(hour: timeSlot.endHour, minute: timeSlot.endMinute) },
                    set: { newDate in
                        let time = TimeHelpers.timeFromDate(newDate)
                        timeSlot.endHour = time.hour
                        timeSlot.endMinute = time.minute
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .styleDatePicker(cornerRadius: DesignSystem.radiusSmall, backgroundColor: DesignSystem.backgroundPrimary, borderColor: DesignSystem.borderPrimary)
            .frame(width: 105)
            
            Spacer()
            
            // Delete button
            if showDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(DesignSystem.font(size: DesignSystem.fontSizeSmall))
                        .foregroundColor(Color(white: 0.7))
                        .padding(DesignSystem.spacingXSmall)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                .fill(DesignSystem.textPrimary.opacity(DesignSystem.opacityLow))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                                        .stroke(DesignSystem.textPrimary.opacity(DesignSystem.opacityMedium), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, DesignSystem.spacingXSmall)
        .padding(.horizontal, DesignSystem.spacingMedium)
    }
}

// MARK: - DatePicker Styler
struct DatePickerStyler: NSViewRepresentable {
    let cornerRadius: CGFloat
    let backgroundColor: NSColor
    let borderColor: NSColor
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        
        DispatchQueue.main.async {
            if let superview = view.superview {
                self.styleDatePicker(in: superview)
            }
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let superview = nsView.superview {
                self.styleDatePicker(in: superview)
            }
        }
    }
    
    private func styleDatePicker(in view: NSView) {
        // Find the main container view (usually an NSStackView or similar)
        if let stackView = view as? NSStackView {
            stackView.wantsLayer = true
            stackView.layer?.cornerRadius = cornerRadius
            stackView.layer?.backgroundColor = backgroundColor.cgColor
            stackView.layer?.borderWidth = 1
            stackView.layer?.borderColor = borderColor.cgColor
        }
        
        // Style text fields
        for subview in view.subviews {
            if let textField = subview as? NSTextField {
                textField.drawsBackground = false
                textField.backgroundColor = .clear
                textField.isBordered = false
                textField.focusRingType = .none
            }
            
            // Apply rounded corners to subviews
            if subview.wantsLayer {
                subview.layer?.cornerRadius = cornerRadius
                subview.layer?.backgroundColor = backgroundColor.cgColor
            }
            
            styleDatePicker(in: subview)
        }
    }
}

extension Color {
    var nsColor: NSColor {
        if let cgColor = self.cgColor {
            return NSColor(cgColor: cgColor) ?? NSColor(white: 0.5, alpha: 1.0)
        }
        return NSColor(white: 0.5, alpha: 1.0)
    }
}

extension View {
    func styleDatePicker(cornerRadius: CGFloat, backgroundColor: Color, borderColor: Color) -> some View {
        self.background(
            DatePickerStyler(
                cornerRadius: cornerRadius,
                backgroundColor: backgroundColor.nsColor,
                borderColor: borderColor.nsColor
            )
        )
    }
}

