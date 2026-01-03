import Foundation

// MARK: - Strict Mode Configuration

/// Configuration for Strict Mode with escalating exit pricing
/// Psychology: Session is LOCKED. Exit is available but gets progressively more expensive.
/// Hidden feature - not advertised, just available when truly needed.
struct StrictModeConfig: Codable, Equatable {
    /// Whether strict mode locking is enabled globally
    var isEnabled: Bool = true

    /// Minimum time user must focus before emergency exit becomes available
    /// Default: 5 minutes (enough to establish commitment)
    var minimumCommitmentMinutes: Int = 5

    // MARK: - Escalating Pricing

    /// Base price for first exit: $2
    static let basePriceAmount: Decimal = 2.00

    /// Maximum price cap: $50
    static let maxPriceAmount: Decimal = 50.00

    /// Price multiplier for each subsequent exit (doubles each time)
    /// Exit 1: $2, Exit 2: $4, Exit 3: $8, Exit 4: $16, Exit 5: $32, Exit 6+: $50
    static let priceMultiplier: Decimal = 2.0

    /// Number of exits used this month
    var exitsUsedThisMonth: Int = 0

    /// Month when exits were last reset
    var monthStartDate: Date = Date().startOfMonth

    /// Minimum commitment time in seconds
    var minimumCommitmentTime: TimeInterval {
        TimeInterval(minimumCommitmentMinutes * 60)
    }

    /// Current exit price based on number of exits this month
    var currentExitPrice: Decimal {
        // Check if we're in a new month (non-mutating check)
        let currentMonthStart = Date().startOfMonth
        let effectiveExits = monthStartDate < currentMonthStart ? 0 : exitsUsedThisMonth

        if effectiveExits == 0 {
            return Self.basePriceAmount
        }
        // Each exit doubles the price: $2, $4, $8, $16, $32, capped at $50
        var price = Self.basePriceAmount
        for _ in 0..<effectiveExits {
            price *= Self.priceMultiplier
        }
        return min(price, Self.maxPriceAmount)
    }

    /// Formatted price string
    var currentExitPriceFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: currentExitPrice as NSDecimalNumber) ?? "$\(currentExitPrice)"
    }

    /// Price after this exit (for showing escalation warning)
    var nextExitPrice: Decimal {
        let nextCount = exitsUsedThisMonth + 1
        var price = Self.basePriceAmount
        for _ in 0..<nextCount {
            price *= Self.priceMultiplier
        }
        return min(price, Self.maxPriceAmount)
    }

    /// Formatted next price string
    var nextExitPriceFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: nextExitPrice as NSDecimalNumber) ?? "$\(nextExitPrice)"
    }

    /// Reset monthly count if needed
    mutating func resetMonthlyLimitIfNeeded() {
        let currentMonthStart = Date().startOfMonth
        if monthStartDate < currentMonthStart {
            monthStartDate = currentMonthStart
            exitsUsedThisMonth = 0
        }
    }

    /// Record an emergency exit was used
    mutating func recordExitUsed() {
        resetMonthlyLimitIfNeeded()
        exitsUsedThisMonth += 1
    }

    // Legacy compatibility
    var emergencyExitPrice: Decimal { currentExitPrice }
    var canUseEmergencyExit: Bool { true } // Always available, just expensive
    var remainingExits: Int { Int.max } // No limit, just escalating price
}

// Keep old name for compatibility during migration
typealias HardModeConfig = StrictModeConfig

// MARK: - Commitment Tiers (for settings UI)

enum CommitmentTier: Int, Codable, CaseIterable, Identifiable {
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15
    case noExit = 0  // 0 means no emergency exit ever

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .fiveMinutes: return "5 minutes"
        case .tenMinutes: return "10 minutes"
        case .fifteenMinutes: return "15 minutes"
        case .noExit: return "Never (fully locked)"
        }
    }

    var description: String {
        switch self {
        case .fiveMinutes:
            return "Emergency exit available after 5 min of focus"
        case .tenMinutes:
            return "Emergency exit available after 10 min of focus"
        case .fifteenMinutes:
            return "Emergency exit available after 15 min of focus"
        case .noExit:
            return "No escape - session must complete naturally"
        }
    }
}

// Legacy alias for backward compatibility
typealias DelayTier = CommitmentTier

// MARK: - Emergency Exit Record

/// Tracks when user pays to use emergency exit
struct OverrideRecord: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var sessionId: UUID
    var overrideTime: Date
    var remainingSessionTime: TimeInterval
    var focusedTime: TimeInterval = 0  // How long they focused before exiting
    var purchaseAmount: Decimal = 1.99

    // Feedback collected later
    var regretRating: Int? // 1-5, filled in after exit
    var whatHappenedNote: String?
    var feedbackCollectedAt: Date?

    /// Whether feedback has been collected
    var hasFeedback: Bool {
        regretRating != nil
    }

    /// Time since exit (for showing recap prompt)
    var timeSinceOverride: TimeInterval {
        Date().timeIntervalSince(overrideTime)
    }

    /// Should prompt for feedback (after 30 min)
    var shouldPromptForFeedback: Bool {
        !hasFeedback && timeSinceOverride > 30 * 60
    }

    /// Formatted focused time
    var focusedTimeFormatted: String {
        let minutes = Int(focusedTime) / 60
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainingMins = minutes % 60
        return "\(hours)h \(remainingMins)m"
    }
}

// Legacy alias
typealias EmergencyExitRecord = OverrideRecord

// MARK: - Date Extension

extension Date {
    /// Start of the current week (Monday)
    var startOfWeek: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        components.weekday = 2 // Monday
        return calendar.date(from: components) ?? self
    }

    /// Start of the current month
    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }
}
