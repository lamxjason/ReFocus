import SwiftUI
#if os(iOS)
import DeviceActivity
import FamilyControls

// Define report contexts that match the extension
extension DeviceActivityReport.Context {
    static let totalActivity = Self("totalActivity")
    static let topApps = Self("topApps")
}
#endif

struct StatsView: View {
    @ObservedObject private var statsManager = StatsManager.shared
    @ObservedObject private var modeManager = FocusModeManager.shared
    @StateObject private var sessionSyncManager = FocusSessionSyncManager.shared
    @StateObject private var localPreferences = LocalPreferencesManager.shared
    @EnvironmentObject var supabaseManager: SupabaseManager

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.section) {
                    // Status Overview (Level/XP) - hidden in minimal mode
                    if localPreferences.shouldShowXPDisplay {
                        statusOverview
                    }

                    // Primary Metrics (always shown - these are useful data, not gamification)
                    primaryMetrics

                    // Cross-Device Stats (if synced)
                    if supabaseManager.isAuthenticated && !sessionSyncManager.syncedSessions.isEmpty {
                        crossDeviceSection
                    }

                    // Weekly Activity (always shown - useful data)
                    weeklyActivity

                    #if os(iOS)
                    // Device Usage
                    deviceUsageSection
                    #endif

                    // Session Log (always shown - useful data)
                    sessionLogSection

                    // Consistency Record (streaks - shown always, has research backing)
                    consistencyRecord

                    // Milestones (achievements) - hidden in minimal mode
                    if !localPreferences.isMinimalModeEnabled {
                        milestonesSection
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }
        }
        .navigationTitle("Activity")
        #if os(iOS)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        #endif
        .task {
            // Load synced sessions on appear
            if supabaseManager.isAuthenticated {
                await sessionSyncManager.fetchAllSessions()
            }
        }
    }

    // MARK: - Status Overview

    private var statusOverview: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            // Level Status
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("STATUS")
                    .font(DesignSystem.Typography.label)
                    .foregroundStyle(AppTheme.textMuted)
                    .tracking(1.2)

                Text("Level \(statsManager.level)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("\(statsManager.xp) XP")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            // Progress Ring
            ZStack {
                Circle()
                    .stroke(AppTheme.border, lineWidth: 4)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: statsManager.levelProgress)
                    .stroke(DesignSystem.Colors.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(statsManager.levelProgress * 100))%")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.cardBackground)
        }
    }

    // MARK: - Primary Metrics

    private var primaryMetrics: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("METRICS")
                .font(DesignSystem.Typography.label)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.2)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.md) {
                MetricCell(
                    label: "Today",
                    value: formatTime(statsManager.todayFocusTime),
                    sublabel: nil
                )

                MetricCell(
                    label: "This Week",
                    value: formatTime(statsManager.weeklyProgress),
                    sublabel: weeklyProgressSublabel
                )

                MetricCell(
                    label: "Total",
                    value: formatTime(statsManager.totalFocusTime),
                    sublabel: nil
                )

                MetricCell(
                    label: "Completion",
                    value: "\(Int(statsManager.completionRate * 100))%",
                    sublabel: "\(statsManager.sessions.filter { $0.wasCompleted }.count) of \(statsManager.sessions.count)"
                )
            }
        }
    }

    private var weeklyProgressSublabel: String? {
        let goal = statsManager.weeklyGoal
        let progress = statsManager.weeklyProgress
        if goal > 0 {
            return "\(Int((progress / goal) * 100))% of goal"
        }
        return nil
    }

    // MARK: - Weekly Activity

    private var weeklyActivity: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("THIS WEEK")
                    .font(DesignSystem.Typography.label)
                    .foregroundStyle(AppTheme.textMuted)
                    .tracking(1.2)

                Spacer()

                // Streak indicator
                if statsManager.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                        Text("\(statsManager.currentStreak) day streak")
                            .font(DesignSystem.Typography.captionMedium)
                    }
                    .foregroundStyle(AppTheme.warning)
                }
            }

            let stats = statsManager.dailyStats(for: 7)
            let maxMinutes = max(stats.map { $0.focusMinutes }.max() ?? 60, 60)

            HStack(alignment: .bottom, spacing: DesignSystem.Spacing.xs) {
                ForEach(stats) { stat in
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        // Value
                        Text("\(stat.focusMinutes)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(stat.isToday ? AppTheme.textPrimary : AppTheme.textMuted)

                        // Bar - simple, clean
                        RoundedRectangle(cornerRadius: 3)
                            .fill(stat.isToday ? DesignSystem.Colors.accent : DesignSystem.Colors.accent.opacity(0.3))
                            .frame(height: max(6, CGFloat(stat.focusMinutes) / CGFloat(maxMinutes) * 70))

                        // Day
                        Text(stat.dayName)
                            .font(.system(size: 10, weight: stat.isToday ? .semibold : .regular))
                            .foregroundStyle(stat.isToday ? AppTheme.textPrimary : AppTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .frame(height: 120)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.cardBackground)
            }
        }
    }

    // MARK: - Cross-Device Section

    private var crossDeviceSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("ALL DEVICES")
                    .font(DesignSystem.Typography.label)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(1.2)

                Spacer()

                if sessionSyncManager.isSyncing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        Task {
                            await sessionSyncManager.fetchAllSessions()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Device breakdown
            let deviceStats = sessionSyncManager.focusTimeByDevice()

            if deviceStats.isEmpty {
                Text("Sync enabled - sessions will appear here")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignSystem.Spacing.lg)
                    .background {
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                            .fill(DesignSystem.Colors.backgroundCard)
                    }
            } else {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(Array(deviceStats.keys.sorted()), id: \.self) { deviceId in
                        if let time = deviceStats[deviceId] {
                            DeviceStatsRow(
                                deviceId: deviceId,
                                focusTime: time,
                                isCurrentDevice: deviceId == DeviceInfo.currentDeviceId
                            )
                        }
                    }

                    // Total across all devices
                    HStack {
                        Text("Total")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        Spacer()

                        Text(formatTime(sessionSyncManager.totalFocusTime))
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background {
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                            .fill(DesignSystem.Colors.accent.opacity(0.1))
                    }
                }
            }
        }
    }

    // MARK: - Device Usage Section

    #if os(iOS)
    private var deviceUsageSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("DEVICE USAGE")
                .font(DesignSystem.Typography.label)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.2)

            // Device Activity Report
            DeviceActivityReport(.totalActivity, filter: todayFilter)
                .frame(minHeight: 260)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))

            // System report link
            Button {
                if let url = URL(string: "App-Prefs:SCREEN_TIME") {
                    UIApplication.shared.open(url)
                } else if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Text("View System Report")
                        .font(DesignSystem.Typography.caption)
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 10))
                }
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var todayFilter: DeviceActivityFilter {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        return DeviceActivityFilter(
            segment: .daily(
                during: DateInterval(start: startOfDay, end: now)
            )
        )
    }
    #endif

    // MARK: - Session Log

    private var sessionLogSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("SESSION LOG")
                    .font(DesignSystem.Typography.label)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(1.2)

                Spacer()

                Text("\(statsManager.sessions.count)")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }

            if statsManager.sessions.isEmpty {
                emptySessionState
            } else {
                VStack(spacing: 1) {
                    ForEach(statsManager.sessions.suffix(5).reversed()) { session in
                        SessionLogRow(session: session)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            }
        }
    }

    private var emptySessionState: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("No sessions recorded")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)

            Text("Sessions will appear here once completed")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.xl)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(DesignSystem.Colors.backgroundCard)
        }
    }

    // MARK: - Consistency Record

    private var consistencyRecord: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("STREAKS")
                .font(DesignSystem.Typography.label)
                .foregroundStyle(AppTheme.textMuted)
                .tracking(1.2)

            HStack(spacing: DesignSystem.Spacing.md) {
                // Current
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("Current")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(AppTheme.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(statsManager.currentStreak)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("days")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(AppTheme.border)
                    .frame(width: 1, height: 40)

                // Best
                VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxs) {
                    Text("Best")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(AppTheme.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(statsManager.longestStreak)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("days")
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(DesignSystem.Spacing.lg)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.cardBackground)
            }
        }
    }

    // MARK: - Milestones Section

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("MILESTONES")
                    .font(DesignSystem.Typography.label)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .tracking(1.2)

                Spacer()

                Text("\(statsManager.achievements.count)")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }

            if statsManager.achievements.isEmpty {
                Text("Milestones unlock with consistent use")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignSystem.Spacing.lg)
                    .background {
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                            .fill(DesignSystem.Colors.backgroundCard)
                    }
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: DesignSystem.Spacing.sm) {
                    ForEach(statsManager.achievements) { achievement in
                        MilestoneCell(achievement: achievement)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Metric Cell

struct MetricCell: View {
    let label: String
    let value: String
    let sublabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            Text(value)
                .font(DesignSystem.Typography.metricSmall)
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            if let sublabel = sublabel {
                Text(sublabel)
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.Colors.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(DesignSystem.Colors.backgroundCard)
        }
    }
}

// MARK: - Session Log Row

struct SessionLogRow: View {
    let session: FocusSession

    @State private var isExpanded = false

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }

    private var hourFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(DesignSystem.Animation.quick) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Status indicator
                    Circle()
                        .fill(session.wasCompleted ? DesignSystem.Colors.positive : DesignSystem.Colors.negative)
                        .frame(width: 8, height: 8)

                    // Date & time
                    VStack(alignment: .leading, spacing: 2) {
                        Text(timeFormatter.string(from: session.startTime))
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundStyle(DesignSystem.Colors.textPrimary)

                        Text(hourFormatter.string(from: session.startTime))
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }

                    Spacer()

                    // Duration
                    Text(session.formattedDuration)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)

                    // Expand indicator
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textMuted)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.backgroundCard)
            }
            .buttonStyle(.plain)

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    // Mode name
                    if let modeName = session.modeName {
                        DetailRow(label: "Mode", value: modeName)
                    }

                    // Blocked counts
                    HStack(spacing: DesignSystem.Spacing.lg) {
                        DetailRow(label: "Apps", value: "\(session.blockedAppCount)")
                        DetailRow(label: "Sites", value: "\(session.blockedWebsiteCount)")
                    }

                    // Websites
                    if !session.blockedWebsites.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Blocked Sites")
                                .font(DesignSystem.Typography.label)
                                .foregroundStyle(DesignSystem.Colors.textMuted)
                                .tracking(1)

                            FlowLayout(spacing: 6) {
                                ForEach(session.blockedWebsites.prefix(6), id: \.self) { domain in
                                    Text(domain)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(DesignSystem.Colors.backgroundElevated)
                                        }
                                }
                                if session.blockedWebsites.count > 6 {
                                    Text("+\(session.blockedWebsites.count - 6)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(DesignSystem.Colors.textMuted)
                                }
                            }
                        }
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .padding(.top, 0)
                .background(DesignSystem.Colors.backgroundCard)
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)

            Text(value)
                .font(DesignSystem.Typography.captionMedium)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }
}

// MARK: - Device Stats Row

struct DeviceStatsRow: View {
    let deviceId: String
    let focusTime: TimeInterval
    let isCurrentDevice: Bool

    private var deviceIcon: String {
        // Try to determine device type from ID
        if deviceId.lowercased().contains("mac") {
            return "desktopcomputer"
        } else if deviceId.lowercased().contains("ipad") {
            return "ipad"
        } else {
            return "iphone"
        }
    }

    private var deviceLabel: String {
        if isCurrentDevice {
            return "This Device"
        }
        // Shorten the UUID for display
        let shortId = String(deviceId.prefix(8))
        return "Device \(shortId)"
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Device icon
            Image(systemName: deviceIcon)
                .font(.system(size: 16))
                .foregroundStyle(isCurrentDevice ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
                .frame(width: 24)

            // Device name
            VStack(alignment: .leading, spacing: 2) {
                Text(deviceLabel)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)

                if isCurrentDevice {
                    Text("Current")
                        .font(.system(size: 10))
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
            }

            Spacer()

            // Focus time
            Text(formatTime(focusTime))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .padding(DesignSystem.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(DesignSystem.Colors.backgroundCard)
        }
    }
}

// MARK: - Milestone Cell

struct MilestoneCell: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            // Icon - consistent accent color
            Image(systemName: achievement.icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(DesignSystem.Colors.accent.opacity(0.15))
                }

            // Name
            Text(achievement.name)
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.cardBackground)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}

#Preview {
    NavigationStack {
        StatsView()
    }
}
