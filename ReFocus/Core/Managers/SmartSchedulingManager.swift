import Foundation
import Combine

/// Analyzes session history to provide smart scheduling suggestions
@MainActor
final class SmartSchedulingManager: ObservableObject {
    static let shared = SmartSchedulingManager()

    // MARK: - Published State

    @Published private(set) var suggestions: [ScheduleSuggestion] = []
    @Published private(set) var insights: [ScheduleInsight] = []
    @Published private(set) var isAnalyzing: Bool = false
    @Published private(set) var optimalTimeSlots: [TimeSlot] = []
    @Published private(set) var productivityByDay: [Weekday: Double] = [:]
    @Published private(set) var optimalSessionLength: Int = 25 // minutes

    // MARK: - Dependencies

    private var supabase: SupabaseManager { .shared }
    private var sessions: [FocusSession] = []

    private init() {}

    // MARK: - Analysis

    /// Fetch session history and analyze patterns
    func analyzePatterns() async {
        guard supabase.isAuthenticated else {
            generateDefaultSuggestions()
            return
        }

        isAnalyzing = true

        do {
            let userId = try supabase.requireUserId()
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -90, to: Date())!

            sessions = try await supabase.client
                .from("focus_sessions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("created_at", value: ISO8601DateFormatter().string(from: cutoffDate))
                .order("created_at", ascending: false)
                .execute()
                .value

            if sessions.count < 5 {
                generateDefaultSuggestions()
                insights.append(ScheduleInsight(
                    type: .needsMoreData,
                    title: "Building Your Profile",
                    description: "Complete more focus sessions to get personalized suggestions.",
                    icon: "chart.line.uptrend.xyaxis"
                ))
            } else {
                analyzeTimePatterns()
                analyzeDayPatterns()
                analyzeSessionLengths()
                generateSmartSuggestions()
            }
        } catch {
            generateDefaultSuggestions()
        }

        isAnalyzing = false
    }

    private func analyzeTimePatterns() {
        var hourlyCompletion: [Int: (completed: Int, total: Int)] = [:]

        for session in sessions {
            let hour = Calendar.current.component(.hour, from: session.startTime)
            var stats = hourlyCompletion[hour] ?? (0, 0)
            stats.total += 1
            if session.wasCompleted { stats.completed += 1 }
            hourlyCompletion[hour] = stats
        }

        var slots: [TimeSlot] = []
        for (hour, stats) in hourlyCompletion where stats.total >= 3 {
            let rate = Double(stats.completed) / Double(stats.total)
            if rate >= 0.7 {
                slots.append(TimeSlot(startHour: hour, endHour: (hour + 1) % 24, completionRate: rate, sessionCount: stats.total))
            }
        }

        optimalTimeSlots = slots.sorted { $0.completionRate > $1.completionRate }

        if let best = optimalTimeSlots.first {
            insights.append(ScheduleInsight(
                type: .peakProductivity,
                title: "Peak Focus Time",
                description: "You complete \(Int(best.completionRate * 100))% of sessions around \(best.formattedTime)",
                icon: "sparkles"
            ))
        }
    }

    private func analyzeDayPatterns() {
        var dailyCompletion: [Weekday: (completed: Int, total: Int)] = [:]

        for session in sessions {
            let weekdayNum = Calendar.current.component(.weekday, from: session.startTime)
            guard let weekday = Weekday(rawValue: weekdayNum) else { continue }
            var stats = dailyCompletion[weekday] ?? (0, 0)
            stats.total += 1
            if session.wasCompleted { stats.completed += 1 }
            dailyCompletion[weekday] = stats
        }

        for (day, stats) in dailyCompletion {
            productivityByDay[day] = stats.total > 0 ? Double(stats.completed) / Double(stats.total) : 0
        }

        let sortedDays = productivityByDay.sorted { $0.value > $1.value }
        if let best = sortedDays.first, let worst = sortedDays.last, best.value > worst.value + 0.2 {
            insights.append(ScheduleInsight(
                type: .bestDay,
                title: "Most Productive Day",
                description: "\(best.key.shortName) has your highest completion rate at \(Int(best.value * 100))%",
                icon: "calendar.badge.checkmark"
            ))
        }
    }

    private func analyzeSessionLengths() {
        var lengthSuccess: [Int: (completed: Int, total: Int)] = [:]

        for session in sessions {
            let minutes = session.plannedDurationSeconds / 60
            let bucket = (minutes / 5) * 5
            var stats = lengthSuccess[bucket] ?? (0, 0)
            stats.total += 1
            if session.wasCompleted { stats.completed += 1 }
            lengthSuccess[bucket] = stats
        }

        var bestLength = 25
        var bestRate = 0.0

        for (length, stats) in lengthSuccess where stats.total >= 3 {
            let rate = Double(stats.completed) / Double(stats.total)
            if rate > bestRate {
                bestRate = rate
                bestLength = length
            }
        }

        optimalSessionLength = bestLength

        if bestRate > 0.7 {
            insights.append(ScheduleInsight(
                type: .optimalDuration,
                title: "Optimal Session Length",
                description: "\(bestLength)-minute sessions have your best completion rate",
                icon: "timer"
            ))
        }
    }

    private func generateSmartSuggestions() {
        suggestions.removeAll()

        let morningSlots = optimalTimeSlots.filter { $0.startHour >= 6 && $0.startHour < 12 }
        if let best = morningSlots.first {
            suggestions.append(ScheduleSuggestion(
                id: UUID(),
                type: .morningRoutine,
                title: "Morning Focus Block",
                description: "Your prime focus time is around \(best.formattedTime)",
                schedule: FocusSchedule(
                    id: UUID(), name: "Morning Focus",
                    startTime: TimeComponents(hour: best.startHour, minute: 0),
                    endTime: TimeComponents(hour: best.startHour + 2, minute: 0),
                    days: Set(productiveDays()), isEnabled: true, isStrictMode: false,
                    focusModeId: nil, themeGradient: .amber
                ),
                confidence: best.completionRate
            ))
        }

        let afternoonSlots = optimalTimeSlots.filter { $0.startHour >= 12 && $0.startHour < 17 }
        if let best = afternoonSlots.first {
            suggestions.append(ScheduleSuggestion(
                id: UUID(),
                type: .deepWork,
                title: "Afternoon Deep Work",
                description: "Your completion rate peaks in the early afternoon",
                schedule: FocusSchedule(
                    id: UUID(), name: "Deep Work",
                    startTime: TimeComponents(hour: best.startHour, minute: 0),
                    endTime: TimeComponents(hour: best.startHour + 3, minute: 0),
                    days: Set(Weekday.weekdays), isEnabled: true, isStrictMode: false,
                    focusModeId: nil, themeGradient: .ocean
                ),
                confidence: best.completionRate
            ))
        }

        if let bestDay = productivityByDay.max(by: { $0.value < $1.value }), bestDay.value > 0.75 {
            suggestions.append(ScheduleSuggestion(
                id: UUID(),
                type: .powerDay,
                title: "\(bestDay.key.shortName) Power Session",
                description: "You're most focused on \(bestDay.key.shortName)s",
                schedule: FocusSchedule(
                    id: UUID(), name: "\(bestDay.key.shortName) Focus",
                    startTime: TimeComponents(hour: 9, minute: 0),
                    endTime: TimeComponents(hour: 12, minute: 0),
                    days: [bestDay.key], isEnabled: true, isStrictMode: true,
                    focusModeId: nil, themeGradient: .sunset
                ),
                confidence: bestDay.value
            ))
        }
    }

    private func generateDefaultSuggestions() {
        suggestions = [
            ScheduleSuggestion(
                id: UUID(), type: .morningRoutine,
                title: "Morning Focus",
                description: "Start your day with a focused work block",
                schedule: FocusSchedule(
                    id: UUID(), name: "Morning Focus",
                    startTime: TimeComponents(hour: 9, minute: 0),
                    endTime: TimeComponents(hour: 11, minute: 0),
                    days: Set(Weekday.weekdays), isEnabled: true, isStrictMode: false,
                    focusModeId: nil, themeGradient: .amber
                ),
                confidence: 0.5
            ),
            ScheduleSuggestion(
                id: UUID(), type: .deepWork,
                title: "Afternoon Deep Work",
                description: "Protect time for focused, uninterrupted work",
                schedule: FocusSchedule(
                    id: UUID(), name: "Deep Work",
                    startTime: TimeComponents(hour: 14, minute: 0),
                    endTime: TimeComponents(hour: 17, minute: 0),
                    days: Set(Weekday.weekdays), isEnabled: true, isStrictMode: false,
                    focusModeId: nil, themeGradient: .ocean
                ),
                confidence: 0.5
            ),
            ScheduleSuggestion(
                id: UUID(), type: .eveningWind,
                title: "Evening Wind Down",
                description: "Block distractions before bed",
                schedule: FocusSchedule(
                    id: UUID(), name: "Wind Down",
                    startTime: TimeComponents(hour: 21, minute: 0),
                    endTime: TimeComponents(hour: 23, minute: 0),
                    days: Set(Weekday.allCases), isEnabled: true, isStrictMode: false,
                    focusModeId: nil, themeGradient: .slate
                ),
                confidence: 0.5
            )
        ]

        insights = [
            ScheduleInsight(type: .tip, title: "Pro Tip",
                description: "Consistent daily schedules build habits faster than sporadic sessions",
                icon: "lightbulb"
            )
        ]
    }

    private func productiveDays() -> [Weekday] {
        productivityByDay.filter { $0.value > 0.6 }.map { $0.key }.sorted { $0.rawValue < $1.rawValue }
    }
}

// MARK: - Models

struct ScheduleSuggestion: Identifiable {
    let id: UUID
    let type: SuggestionType
    let title: String
    let description: String
    let schedule: FocusSchedule
    let confidence: Double

    var confidenceLabel: String {
        switch confidence {
        case 0.8...: return "Highly Recommended"
        case 0.6..<0.8: return "Recommended"
        default: return "Suggested"
        }
    }

    enum SuggestionType { case morningRoutine, deepWork, eveningWind, powerDay, custom }
}

struct ScheduleInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let description: String
    let icon: String

    enum InsightType { case peakProductivity, bestDay, optimalDuration, needsMoreData, tip }
}

struct TimeSlot: Identifiable {
    let id = UUID()
    let startHour: Int
    let endHour: Int
    let completionRate: Double
    let sessionCount: Int

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = startHour
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }
}
