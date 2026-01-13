import Foundation
import SwiftUI
#if os(iOS)
import FamilyControls
#endif

/// Days of the week for scheduling
enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    var initial: String {
        switch self {
        case .sunday: return "S"
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "T"
        case .friday: return "F"
        case .saturday: return "S"
        }
    }

    static var weekdays: [Weekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday]
    }

    static var weekend: [Weekday] {
        [.saturday, .sunday]
    }
}

/// A recurring focus schedule
struct FocusSchedule: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var startTime: TimeComponents
    var endTime: TimeComponents
    var days: Set<Weekday>
    var isEnabled: Bool
    var isStrictMode: Bool
    var focusModeId: UUID?  // Legacy - prefer direct app selection
    var themeGradient: ThemeGradient

    // Direct app/website blocking (similar to FocusMode)
    var appSelectionData: Data?
    var websiteDomains: [String] = []

    #if os(iOS)
    /// Decoded app selection for iOS
    var appSelection: FamilyActivitySelection? {
        get {
            guard let data = appSelectionData else { return nil }
            return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        }
        set {
            appSelectionData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Number of blocked apps
    var blockedAppsCount: Int {
        appSelection?.applicationTokens.count ?? 0
    }

    /// Number of blocked website categories
    var blockedCategoriesCount: Int {
        appSelection?.categoryTokens.count ?? 0
    }
    #else
    var blockedAppsCount: Int { 0 }
    var blockedCategoriesCount: Int { 0 }
    #endif

    /// Total blocked items for display
    var totalBlockedCount: Int {
        blockedAppsCount + websiteDomains.count
    }

    /// Convenience color accessor
    var primaryColor: Color {
        themeGradient.primaryColor
    }

    /// Rich gradient for backgrounds
    var gradient: LinearGradient {
        themeGradient.gradient
    }

    /// Subtle gradient for cards
    var cardGradient: LinearGradient {
        themeGradient.cardGradient
    }

    var isValid: Bool {
        !days.isEmpty && startTime < endTime
    }

    var daysDescription: String {
        if days == Set(Weekday.weekdays) {
            return "Weekdays"
        } else if days == Set(Weekday.weekend) {
            return "Weekend"
        } else if days == Set(Weekday.allCases) {
            return "Every day"
        } else {
            return days.sorted { $0.rawValue < $1.rawValue }
                .map { $0.shortName }
                .joined(separator: ", ")
        }
    }

    var timeRangeDescription: String {
        "\(startTime.formatted) - \(endTime.formatted)"
    }

    static let `default` = FocusSchedule(
        id: UUID(),
        name: "",
        startTime: TimeComponents(hour: 9, minute: 0),
        endTime: TimeComponents(hour: 17, minute: 0),
        days: Set(Weekday.weekdays),
        isEnabled: true,
        isStrictMode: false,
        focusModeId: nil,
        themeGradient: .violet,
        appSelectionData: nil,
        websiteDomains: []
    )

    /// Create a duplicate of this schedule with a new ID and modified name
    func duplicate() -> FocusSchedule {
        FocusSchedule(
            id: UUID(),
            name: "\(name) Copy",
            startTime: startTime,
            endTime: endTime,
            days: days,
            isEnabled: false,  // Start disabled
            isStrictMode: isStrictMode,
            focusModeId: focusModeId,
            themeGradient: themeGradient,
            appSelectionData: appSelectionData,
            websiteDomains: websiteDomains
        )
    }
}

/// Time components for scheduling (hour and minute only)
struct TimeComponents: Codable, Equatable, Comparable {
    var hour: Int
    var minute: Int

    var formatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let calendar = Calendar.current
        let date = calendar.date(from: components) ?? Date()
        return formatter.string(from: date)
    }

    var date: Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    var totalMinutes: Int {
        hour * 60 + minute
    }

    static func < (lhs: TimeComponents, rhs: TimeComponents) -> Bool {
        lhs.totalMinutes < rhs.totalMinutes
    }

    static func from(date: Date) -> TimeComponents {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return TimeComponents(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }
}
