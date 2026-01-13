import SwiftUI

struct SmartSchedulingView: View {
    @StateObject private var smartManager = SmartSchedulingManager.shared
    @StateObject private var scheduleManager = ScheduleManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Insights
                    if !smartManager.insights.isEmpty {
                        insightsSection
                    }

                    // Suggestions
                    if smartManager.isAnalyzing {
                        ProgressView("Analyzing your patterns...")
                            .padding(.vertical, 40)
                    } else if !smartManager.suggestions.isEmpty {
                        suggestionsSection
                    }

                    // Productivity by day chart
                    if !smartManager.productivityByDay.isEmpty {
                        productivityChartSection
                    }
                }
                .padding()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Smart Scheduling")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await smartManager.analyzePatterns()
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 50))
                .foregroundStyle(DesignSystem.Colors.accent)

            Text("AI-Powered Scheduling")
                .font(.title2.bold())

            Text("Based on your focus history, here are personalized schedule suggestions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INSIGHTS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(smartManager.insights) { insight in
                InsightCard(insight: insight)
            }
        }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SUGGESTED SCHEDULES")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(smartManager.suggestions) { suggestion in
                SuggestionCard(suggestion: suggestion) {
                    addSchedule(suggestion.schedule)
                }
            }
        }
    }

    private var productivityChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PRODUCTIVITY BY DAY")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(Weekday.allCases) { day in
                    let productivity = smartManager.productivityByDay[day] ?? 0

                    VStack(spacing: 4) {
                        // Bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(productivity > 0.7 ? DesignSystem.Colors.positive : 
                                  productivity > 0.4 ? DesignSystem.Colors.accent : 
                                  Color.secondary.opacity(0.3))
                            .frame(height: CGFloat(productivity * 80))
                            .frame(maxHeight: 80, alignment: .bottom)

                        // Day label
                        Text(day.initial)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.cardBackground)
            }
        }
    }

    private func addSchedule(_ schedule: FocusSchedule) {
        scheduleManager.addSchedule(schedule)
        dismiss()
    }
}

struct InsightCard: View {
    let insight: ScheduleInsight

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: insight.icon)
                .font(.title2)
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.headline)
                Text(insight.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.cardBackground)
        }
    }
}

struct SuggestionCard: View {
    let suggestion: ScheduleSuggestion
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(suggestion.title)
                            .font(.headline)

                        Text(suggestion.confidenceLabel)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background {
                                Capsule()
                                    .fill(confidenceColor)
                            }
                    }

                    Text(suggestion.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Schedule preview
            HStack(spacing: 16) {
                Label(suggestion.schedule.timeRangeDescription, systemImage: "clock")
                Label(suggestion.schedule.daysDescription, systemImage: "calendar")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Add button
            Button {
                onAdd()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add to Schedules")
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(suggestion.schedule.gradient)
                .foregroundStyle(.white)
                .cornerRadius(10)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.cardBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(suggestion.schedule.primaryColor.opacity(0.3), lineWidth: 1)
        }
    }

    private var confidenceColor: Color {
        switch suggestion.confidence {
        case 0.8...: return DesignSystem.Colors.positive
        case 0.6..<0.8: return DesignSystem.Colors.accent
        default: return .secondary
        }
    }
}

#Preview {
    SmartSchedulingView()
}
