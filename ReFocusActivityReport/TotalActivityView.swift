import SwiftUI

struct TotalActivityView: View {
    let totalActivity: ActivityReport

    // Premium color palette
    private let gradientColors: [Color] = [
        Color(red: 0.4, green: 0.3, blue: 0.9),   // Purple
        Color(red: 0.3, green: 0.5, blue: 0.95),  // Blue
        Color(red: 0.2, green: 0.7, blue: 0.8),   // Teal
    ]

    private let categoryColors: [Color] = [
        Color(red: 0.95, green: 0.4, blue: 0.5),  // Coral
        Color(red: 0.98, green: 0.7, blue: 0.3),  // Gold
        Color(red: 0.4, green: 0.8, blue: 0.6),   // Mint
        Color(red: 0.6, green: 0.5, blue: 0.95),  // Lavender
        Color(red: 0.3, green: 0.7, blue: 0.95),  // Sky
        Color(red: 0.95, green: 0.5, blue: 0.7),  // Pink
    ]

    var body: some View {
        VStack(spacing: 20) {
            // Total time header with beautiful gradient ring
            totalTimeHeader

            // Category breakdown with elegant bars
            if !totalActivity.categoryBreakdown.isEmpty {
                categorySection
            }

            // Top apps preview
            if !totalActivity.topApps.isEmpty {
                topAppsPreview
            }
        }
        .padding(20)
        .background(Color(white: 0.06))
    }

    // MARK: - Total Time Header

    private var totalTimeHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [gradientColors[0].opacity(0.3), .clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)

                // Ring background
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 12)
                    .frame(width: 140, height: 140)

                // Gradient ring
                Circle()
                    .trim(from: 0, to: min(1.0, totalActivity.totalDuration / (8 * 3600))) // 8 hour max
                    .stroke(
                        AngularGradient(
                            colors: gradientColors + [gradientColors[0]],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))

                // Center content
                VStack(spacing: 4) {
                    Text(formatDuration(totalActivity.totalDuration))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("screen time")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(1.5)
                }
            }

            // Subtle message
            Text("Today's Usage")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BY CATEGORY")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.5)

            VStack(spacing: 8) {
                let sortedCategories = totalActivity.categoryBreakdown.sorted { $0.value > $1.value }
                let maxDuration = sortedCategories.first?.value ?? 1

                ForEach(Array(sortedCategories.prefix(5).enumerated()), id: \.element.key) { index, category in
                    CategoryRow(
                        name: category.key,
                        duration: category.value,
                        maxDuration: maxDuration,
                        color: categoryColors[index % categoryColors.count]
                    )
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        }
    }

    // MARK: - Top Apps Preview

    private var topAppsPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MOST USED")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.5)

            HStack(spacing: 12) {
                ForEach(Array(totalActivity.topApps.prefix(4).enumerated()), id: \.offset) { index, app in
                    VStack(spacing: 8) {
                        // App icon placeholder with gradient
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        categoryColors[index % categoryColors.count],
                                        categoryColors[index % categoryColors.count].opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                            .overlay {
                                Text(String(app.name.prefix(1)))
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white)
                            }

                        Text(app.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)

                        Text(formatDuration(app.duration, short: true))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval, short: Bool = false) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if short {
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(minutes)m"
        }

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let name: String
    let duration: TimeInterval
    let maxDuration: TimeInterval
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            // Color dot
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            // Name
            Text(name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))

            Spacer()

            // Duration
            Text(formatDuration(duration))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.vertical, 4)
        .background(alignment: .leading) {
            // Progress bar
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.2))
                    .frame(width: geo.size.width * CGFloat(duration / maxDuration))
            }
            .frame(height: 4)
            .offset(y: 20)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
