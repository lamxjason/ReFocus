import SwiftUI

struct TopAppsView: View {
    let activityReport: ActivityReport

    private let appColors: [Color] = [
        Color(red: 0.95, green: 0.4, blue: 0.5),   // Coral
        Color(red: 0.98, green: 0.65, blue: 0.3),  // Orange
        Color(red: 0.95, green: 0.85, blue: 0.3),  // Gold
        Color(red: 0.4, green: 0.85, blue: 0.55),  // Green
        Color(red: 0.3, green: 0.75, blue: 0.9),   // Cyan
        Color(red: 0.5, green: 0.5, blue: 0.95),   // Indigo
        Color(red: 0.7, green: 0.45, blue: 0.9),   // Purple
        Color(red: 0.95, green: 0.45, blue: 0.7),  // Pink
        Color(red: 0.6, green: 0.6, blue: 0.65),   // Gray
        Color(red: 0.4, green: 0.65, blue: 0.85),  // Steel Blue
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("App Usage")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Your most used apps today")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                // Total time badge
                Text(formatDuration(activityReport.totalDuration))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [appColors[0], appColors[1]],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
            }
            .padding(.horizontal, 4)

            // Apps list
            VStack(spacing: 2) {
                ForEach(Array(activityReport.topApps.enumerated()), id: \.offset) { index, app in
                    AppUsageRow(
                        rank: index + 1,
                        name: app.name,
                        duration: app.duration,
                        totalDuration: activityReport.totalDuration,
                        color: appColors[index % appColors.count],
                        isTop3: index < 3
                    )
                }
            }
        }
        .padding(20)
        .background(Color(white: 0.06))
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

// MARK: - App Usage Row

struct AppUsageRow: View {
    let rank: Int
    let name: String
    let duration: TimeInterval
    let totalDuration: TimeInterval
    let color: Color
    let isTop3: Bool

    private var percentage: Double {
        guard totalDuration > 0 else { return 0 }
        return duration / totalDuration
    }

    var body: some View {
        HStack(spacing: 14) {
            // Rank badge
            ZStack {
                if isTop3 {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 28, height: 28)
                }

                Text("\(rank)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(isTop3 ? .white : .white.opacity(0.5))
            }

            // App icon placeholder
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.8), color.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay {
                    Text(String(name.prefix(1)))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }

            // App name and progress
            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.1))

                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(percentage))
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            // Duration and percentage
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDuration(duration))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("\(Int(percentage * 100))%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background {
            if isTop3 {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.08))
            }
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
