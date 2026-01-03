import Foundation
import SwiftUI

/// Manages Strict Mode with commitment-based emergency exit
/// Psychology: Session is LOCKED. After minimum commitment, PRO users can pay to exit.
@MainActor
final class HardModeManager: ObservableObject {
    static let shared = HardModeManager()

    // MARK: - Published State

    @Published var config: StrictModeConfig {
        didSet { saveConfig() }
    }

    @Published var exitHistory: [OverrideRecord] = []

    // MARK: - StoreKit Product IDs

    static let emergencyExitProductId = "com.refocus.emergency.exit"

    // MARK: - Private

    private let configKey = "strictModeConfig"
    private let historyKey = "emergencyExitHistory"

    // MARK: - Init

    private init() {
        self.config = Self.loadConfig()
        self.exitHistory = Self.loadHistory()
        config.resetMonthlyLimitIfNeeded()
    }

    // MARK: - Core Methods

    /// Check if emergency exit is available for a strict session
    /// - Parameters:
    ///   - sessionStartTime: When the session started
    ///   - isPremiumUser: Whether user has PRO subscription
    /// - Returns: The availability status
    func checkEmergencyExitAvailability(
        sessionStartTime: Date,
        isPremiumUser: Bool
    ) -> EmergencyExitStatus {
        // Must be PRO user
        guard isPremiumUser else {
            return .notAvailable(reason: .requiresPro)
        }

        // Check if commitment period allows emergency exit at all
        if config.minimumCommitmentMinutes == 0 {
            return .notAvailable(reason: .fullyLocked)
        }

        // Check commitment time
        let focusedTime = Date().timeIntervalSince(sessionStartTime)
        let requiredTime = config.minimumCommitmentTime

        if focusedTime < requiredTime {
            let remaining = requiredTime - focusedTime
            return .notAvailable(reason: .notEnoughCommitment(remaining: remaining))
        }

        // Reset monthly counter if needed
        config.resetMonthlyLimitIfNeeded()

        // Emergency exit is always available (with escalating price)
        return .available(
            focusedMinutes: Int(focusedTime / 60),
            currentPrice: config.currentExitPriceFormatted
        )
    }

    /// Format the time spent focusing for display
    func formatFocusedTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainingMins = minutes % 60
        return "\(hours)h \(remainingMins)m"
    }

    // MARK: - Emergency Exit Purchase

    /// Record that user used emergency exit
    func recordEmergencyExitUsed(sessionId: UUID, focusedTime: TimeInterval, remainingTime: TimeInterval) {
        config.recordExitUsed()

        let record = OverrideRecord(
            sessionId: sessionId,
            overrideTime: Date(),
            remainingSessionTime: remainingTime,
            focusedTime: focusedTime
        )
        exitHistory.append(record)
        saveHistory()
    }

    /// Record feedback for an emergency exit
    func recordFeedback(
        for exitId: UUID,
        regretRating: Int,
        note: String?
    ) {
        guard let index = exitHistory.firstIndex(where: { $0.id == exitId }) else {
            return
        }

        exitHistory[index].regretRating = regretRating
        exitHistory[index].whatHappenedNote = note
        exitHistory[index].feedbackCollectedAt = Date()
        saveHistory()
    }

    // MARK: - Analytics

    /// Get exits that need feedback
    var exitsPendingFeedback: [OverrideRecord] {
        exitHistory.filter { $0.shouldPromptForFeedback }
    }

    /// Average regret rating across all exits with feedback
    var averageRegretRating: Double? {
        let withFeedback = exitHistory.compactMap { $0.regretRating }
        guard !withFeedback.isEmpty else { return nil }
        return Double(withFeedback.reduce(0, +)) / Double(withFeedback.count)
    }

    /// Count of exits where user rated high regret (1-2)
    var highRegretCount: Int {
        exitHistory.filter { ($0.regretRating ?? 5) <= 2 }.count
    }

    /// Percentage of exits that were regretted
    var regretPercentage: Double? {
        let withFeedback = exitHistory.filter { $0.hasFeedback }
        guard !withFeedback.isEmpty else { return nil }
        let regretted = withFeedback.filter { ($0.regretRating ?? 5) <= 2 }.count
        return Double(regretted) / Double(withFeedback.count) * 100
    }

    /// Message about exit patterns (shown before purchase)
    var patternWarning: String? {
        guard exitHistory.count >= 3 else { return nil }

        if let regretPct = regretPercentage, regretPct >= 70 {
            return "You've regretted \(Int(regretPct))% of your emergency exits."
        }

        if let avgRating = averageRegretRating, avgRating <= 2.5 {
            return "Your exits average \(String(format: "%.1f", avgRating))/5 — most weren't worth it."
        }

        return nil
    }

    // Legacy compatibility
    var overrideHistory: [OverrideRecord] { exitHistory }
    var patternMessage: String? { patternWarning }

    // MARK: - Persistence

    private static func loadConfig() -> StrictModeConfig {
        // Try new key first, then fall back to old key for migration
        if let data = UserDefaults.standard.data(forKey: "strictModeConfig"),
           let config = try? JSONDecoder().decode(StrictModeConfig.self, from: data) {
            return config
        }
        // Fall back to legacy hardModeConfig
        if let data = UserDefaults.standard.data(forKey: "hardModeConfig"),
           let config = try? JSONDecoder().decode(StrictModeConfig.self, from: data) {
            return config
        }
        return StrictModeConfig()
    }

    private func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }

    private static func loadHistory() -> [OverrideRecord] {
        // Try new key first, then fall back to old key for migration
        if let data = UserDefaults.standard.data(forKey: "emergencyExitHistory"),
           let history = try? JSONDecoder().decode([OverrideRecord].self, from: data) {
            return history
        }
        if let data = UserDefaults.standard.data(forKey: "overrideHistory"),
           let history = try? JSONDecoder().decode([OverrideRecord].self, from: data) {
            return history
        }
        return []
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(exitHistory) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    /// Clear all exit history (for testing/reset)
    func clearHistory() {
        exitHistory = []
        saveHistory()
    }
}

// MARK: - Emergency Exit Status

/// Status of emergency exit availability for strict mode sessions
enum EmergencyExitStatus: Equatable {
    /// Emergency exit is available - user can pay escalating price to exit
    case available(focusedMinutes: Int, currentPrice: String)

    /// Emergency exit is not available
    case notAvailable(reason: EmergencyExitUnavailableReason)

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }
}

/// Reasons why emergency exit is not available
enum EmergencyExitUnavailableReason: Equatable {
    /// User doesn't have PRO subscription
    case requiresPro

    /// Session is fully locked (no exit configured)
    case fullyLocked

    /// Haven't focused long enough yet
    case notEnoughCommitment(remaining: TimeInterval)

    var message: String {
        switch self {
        case .requiresPro:
            return "Emergency exit requires PRO"
        case .fullyLocked:
            return "This session cannot be exited early"
        case .notEnoughCommitment(let remaining):
            let minutes = Int(remaining / 60) + 1
            return "Focus for \(minutes) more min to unlock emergency exit"
        }
    }
}

// Legacy compatibility
typealias EarlyEndResult = EmergencyExitStatus
