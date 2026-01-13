import SwiftUI

/// View for managing all focus schedules - Grid layout like Focus Modes
struct ScheduleListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scheduleManager = ScheduleManager.shared

    @State private var editingScheduleId: UUID?
    @State private var isAddingNew = false
    @State private var scheduleToDelete: FocusSchedule?
    @State private var showingSmartScheduling = false

    private var editingSchedule: FocusSchedule? {
        guard let id = editingScheduleId else { return nil }
        return scheduleManager.schedules.first { $0.id == id }
    }

    /// Dynamic accent color based on active or first enabled schedule
    private var pageAccentColor: Color {
        if let active = scheduleManager.activeSchedule {
            return active.primaryColor
        }
        if let firstEnabled = scheduleManager.schedules.first(where: { $0.isEnabled }) {
            return firstEnabled.primaryColor
        }
        return DesignSystem.Colors.accent
    }

    /// Dynamic gradient for page background
    private var pageGradient: ThemeGradient {
        if let active = scheduleManager.activeSchedule {
            return active.themeGradient
        }
        if let firstEnabled = scheduleManager.schedules.first(where: { $0.isEnabled }) {
            return firstEnabled.themeGradient
        }
        return .violet
    }

    var body: some View {
        ZStack {
            // Dark background
            DesignSystem.Colors.background
                .ignoresSafeArea()

            // Show either the list or the editor
            if isAddingNew {
                // New schedule editor
                ScheduleEditorView(
                    onSave: { isAddingNew = false },
                    onCancel: { isAddingNew = false }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if let schedule = editingSchedule {
                // Edit schedule editor
                ScheduleEditorView(
                    schedule: schedule,
                    onSave: { editingScheduleId = nil },
                    onCancel: { editingScheduleId = nil }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                // Schedule list
                scheduleListContent
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isAddingNew)
        .animation(.easeInOut(duration: 0.25), value: editingScheduleId)
        .preferredColorScheme(.dark)
        .confirmationDialog(
            "Delete Schedule",
            isPresented: Binding(
                get: { scheduleToDelete != nil },
                set: { if !$0 { scheduleToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let schedule = scheduleToDelete {
                    withAnimation {
                        scheduleManager.deleteSchedule(id: schedule.id)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the schedule \"\(scheduleToDelete?.name ?? "")\".")
        }
        .sheet(isPresented: $showingSmartScheduling) {
            SmartSchedulingView()
        }
    }

    // MARK: - Schedule List Content

    private var scheduleListContent: some View {
        ZStack {
            // Subtle gradient overlay based on active schedule
            LinearGradient(
                colors: [
                    Color(hex: pageGradient.primaryHex).opacity(0.15),
                    Color(hex: pageGradient.secondaryHex).opacity(0.08),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Schedules")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                    Spacer()

                    // Smart Scheduling button
                    Button {
                        showingSmartScheduling = true
                    } label: {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 20))
                            .foregroundStyle(pageAccentColor)
                    }
                    .buttonStyle(.plain)

                    Button {
                        isAddingNew = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(pageAccentColor)
                    }
                    .buttonStyle(.plain)

                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .padding(.leading, DesignSystem.Spacing.sm)
                }
                .padding()

                Divider()
                    .background(DesignSystem.Colors.border)

                if scheduleManager.schedules.isEmpty {
                    emptyState
                } else {
                    scheduleGrid
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(pageAccentColor)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("No Schedules Yet")
                    .font(DesignSystem.Typography.title)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                Text("Create recurring focus schedules to automatically block distractions during your most productive hours.")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }

            Button {
                isAddingNew = true
            } label: {
                Text("Create Schedule")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background {
                        Capsule()
                            .fill(pageAccentColor)
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, DesignSystem.Spacing.md)

            Spacer()
        }
    }

    // MARK: - Schedule Grid (2 columns like Focus Modes)

    private var scheduleGrid: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Active schedule indicator
                if let active = scheduleManager.activeSchedule {
                    activeScheduleBanner(active)
                        .padding(.horizontal)
                }

                // Grid of schedules
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: DesignSystem.Spacing.md) {
                    ForEach(scheduleManager.schedules) { schedule in
                        ScheduleGridCard(
                            schedule: schedule,
                            isActive: schedule.id == scheduleManager.activeSchedule?.id,
                            onToggle: {
                                withAnimation(DesignSystem.Animation.quick) {
                                    scheduleManager.toggleSchedule(id: schedule.id)
                                }
                            },
                            onEdit: {
                                withAnimation {
                                    editingScheduleId = schedule.id
                                }
                            },
                            onCopy: {
                                scheduleManager.duplicateSchedule(id: schedule.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .padding(.vertical)
        }
    }

    private func activeScheduleBanner(_ schedule: FocusSchedule) -> some View {
        let scheduleColor = schedule.primaryColor

        return HStack(spacing: DesignSystem.Spacing.sm) {
            Circle()
                .fill(DesignSystem.Colors.success)
                .frame(width: 8, height: 8)

            Text("Active Now")
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(scheduleColor)

            Spacer()

            if let remaining = scheduleManager.remainingTimeInSchedule {
                Text(formatRemaining(remaining))
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background {
            Capsule()
                .fill(scheduleColor.opacity(0.15))
        }
    }

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        } else {
            return "\(minutes)m left"
        }
    }
}

// MARK: - Schedule Grid Card (Same design as FocusModeCard)

struct ScheduleGridCard: View {
    let schedule: FocusSchedule
    let isActive: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onCopy: () -> Void

    private var scheduleColor: Color {
        schedule.primaryColor
    }

    private var scheduleGradient: ThemeGradient {
        schedule.themeGradient
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main card - tap to toggle
            Button {
                onToggle()
            } label: {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    // Icon with schedule color
                    ZStack {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(schedule.isEnabled ? .white : scheduleColor)

                        // Active indicator badge
                        if isActive {
                            VStack {
                                HStack {
                                    Spacer()
                                    Circle()
                                        .fill(DesignSystem.Colors.success)
                                        .frame(width: 10, height: 10)
                                        .overlay {
                                            Circle()
                                                .stroke(DesignSystem.Colors.background, lineWidth: 2)
                                        }
                                }
                                Spacer()
                            }
                            .frame(width: 52, height: 52)
                        }

                        // Strict mode lock badge
                        if schedule.isStrictMode {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(schedule.isEnabled ? .white : scheduleColor)
                                        .padding(3)
                                        .background {
                                            Circle()
                                                .fill(schedule.isEnabled ? scheduleColor : scheduleColor.opacity(0.2))
                                        }
                                        .offset(x: 4, y: 4)
                                }
                            }
                        }
                    }
                    .frame(width: 52, height: 52)
                    .background {
                        Circle()
                            .fill(
                                schedule.isEnabled
                                    ? LinearGradient(
                                        colors: [
                                            Color(hex: scheduleGradient.primaryHex),
                                            Color(hex: scheduleGradient.secondaryHex)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [
                                            Color(hex: scheduleGradient.primaryHex).opacity(0.15),
                                            Color(hex: scheduleGradient.secondaryHex).opacity(0.08)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                            )
                    }

                    // Name
                    Text(schedule.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)

                    // Time range
                    Text(schedule.timeRangeDescription)
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
                .padding(.horizontal, DesignSystem.Spacing.sm)
            }
            .buttonStyle(.plain)

            // Action buttons row (same as FocusModeCard)
            HStack(spacing: 0) {
                Button {
                    onEdit()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                        Text("Edit")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(scheduleColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(scheduleColor.opacity(0.3))
                    .frame(width: 1, height: 16)

                Button {
                    onCopy()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                        Text("Copy")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(scheduleColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }
                .buttonStyle(.plain)
            }
            .background(Color(hex: scheduleGradient.primaryHex).opacity(0.1))
        }
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: schedule.isEnabled
                            ? [
                                Color(hex: scheduleGradient.primaryHex).opacity(0.6),
                                Color(hex: scheduleGradient.secondaryHex).opacity(0.4),
                                Color(hex: scheduleGradient.tertiaryHex).opacity(0.25)
                            ]
                            : [
                                Color(hex: scheduleGradient.primaryHex).opacity(0.25),
                                Color(hex: scheduleGradient.secondaryHex).opacity(0.12),
                                DesignSystem.Colors.backgroundCard
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: schedule.isEnabled
                            ? [scheduleColor, scheduleColor.opacity(0.7)]
                            : [scheduleColor.opacity(0.4), scheduleColor.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: schedule.isEnabled ? 2 : 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ScheduleListView()
}
