import SwiftUI

/// View for managing all focus schedules
struct ScheduleListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scheduleManager = ScheduleManager.shared

    @State private var showingAddSchedule = false
    @State private var editingSchedule: FocusSchedule?
    @State private var scheduleToDelete: FocusSchedule?

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
        return .ocean
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Dynamic gradient background
                DesignSystem.Colors.background
                    .ignoresSafeArea()

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

                if scheduleManager.schedules.isEmpty {
                    emptyState
                } else {
                    scheduleList
                }
            }
            .navigationTitle("Schedules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSchedule = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(pageAccentColor)
                    }
                }
            }
            .sheet(isPresented: $showingAddSchedule) {
                ScheduleEditorView()
            }
            .sheet(item: $editingSchedule) { schedule in
                ScheduleEditorView(schedule: schedule)
            }
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
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(DesignSystem.Colors.accent)

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
                showingAddSchedule = true
            } label: {
                Text("Create Schedule")
            }
            .buttonStyle(.primary)
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.top, DesignSystem.Spacing.md)
        }
    }

    // MARK: - Schedule List

    private var scheduleList: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Active schedule indicator
                if let active = scheduleManager.activeSchedule {
                    activeScheduleCard(active)
                        .padding(.horizontal)
                }

                // All schedules
                ForEach(scheduleManager.schedules) { schedule in
                    ScheduleCard(
                        schedule: schedule,
                        isActive: schedule.id == scheduleManager.activeSchedule?.id,
                        onToggle: {
                            withAnimation(DesignSystem.Animation.quick) {
                                scheduleManager.toggleSchedule(id: schedule.id)
                            }
                        },
                        onEdit: {
                            editingSchedule = schedule
                        },
                        onDelete: {
                            scheduleToDelete = schedule
                        }
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    private func activeScheduleCard(_ schedule: FocusSchedule) -> some View {
        let scheduleColor = schedule.primaryColor

        return VStack(spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(scheduleColor)

                Text("Currently Active")
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

            Text("\"\(schedule.name)\" is blocking distractions until \(schedule.endTime.formatted)")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: schedule.themeGradient.primaryHex).opacity(0.25),
                            Color(hex: schedule.themeGradient.secondaryHex).opacity(0.15),
                            Color(hex: schedule.themeGradient.tertiaryHex).opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .strokeBorder(scheduleColor.opacity(0.4), lineWidth: 1)
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

// MARK: - Schedule Card

struct ScheduleCard: View {
    let schedule: FocusSchedule
    let isActive: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var scheduleColor: Color {
        schedule.primaryColor
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Gradient status indicator
            Circle()
                .fill(
                    isActive ? DesignSystem.Colors.success :
                    (schedule.isEnabled ? scheduleColor : DesignSystem.Colors.backgroundElevated)
                )
                .frame(width: 10, height: 10)

            // Schedule info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(schedule.name)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundStyle(schedule.isEnabled ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textMuted)

                    if schedule.isStrictMode {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(scheduleColor)
                    }
                }

                Text("\(schedule.timeRangeDescription) • \(schedule.daysDescription)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }

            Spacer()

            // Toggle with schedule color
            Toggle("", isOn: Binding(
                get: { schedule.isEnabled },
                set: { _ in onToggle() }
            ))
            .tint(scheduleColor)
            .labelsHidden()
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(DesignSystem.Colors.backgroundCard)
                .overlay {
                    // Subtle gradient overlay when enabled
                    if schedule.isEnabled {
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                            .fill(schedule.cardGradient)
                    }
                }
        }
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .strokeBorder(scheduleColor, lineWidth: 2)
            } else if schedule.isEnabled {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .strokeBorder(scheduleColor.opacity(0.3), lineWidth: 1)
            }
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    ScheduleListView()
}
