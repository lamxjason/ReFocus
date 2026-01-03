import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Manages Deep Work Companion features - haptics, session reviews, ambient mode
@MainActor
final class DeepWorkCompanionManager: ObservableObject {
    static let shared = DeepWorkCompanionManager()

    // MARK: - Published State

    @Published var config: DeepWorkCompanionConfig {
        didSet { saveConfig() }
    }

    @Published var sessionReviews: [SessionReview] = []

    /// Milestones already triggered for the current session
    @Published var triggeredMilestones: Set<Int> = []

    /// Whether we should show the review prompt after session ends
    @Published var shouldShowReviewPrompt: Bool = false

    /// Current session ID for tracking
    @Published var currentSessionId: UUID?

    // MARK: - Private

    private let configKey = "deepWorkCompanionConfig"
    private let reviewsKey = "sessionReviews"

    // MARK: - Init

    private init() {
        self.config = Self.loadConfig()
        self.sessionReviews = Self.loadReviews()
    }

    // MARK: - Session Lifecycle

    /// Called when a focus session starts
    func onSessionStart(sessionId: UUID) {
        currentSessionId = sessionId
        triggeredMilestones.removeAll()
    }

    /// Called when session progress updates - checks for milestone haptics
    func onProgressUpdate(progress: Double) {
        guard config.isEnabled, config.hapticsEnabled else { return }

        for milestone in HapticMilestone.allCases {
            let milestoneValue = milestone.rawValue

            // Check if this milestone should be triggered
            if config.enabledMilestones.contains(milestoneValue) &&
               !triggeredMilestones.contains(milestoneValue) &&
               progress >= milestone.progressThreshold {

                triggeredMilestones.insert(milestoneValue)
                triggerHaptic(for: milestone)
            }
        }
    }

    /// Called when a focus session ends
    func onSessionEnd(sessionId: UUID, completed: Bool) {
        // Only prompt for review if:
        // 1. Reviews are enabled
        // 2. Session completed naturally or was at least 50% complete
        guard config.isEnabled, config.reviewPromptEnabled else { return }

        // Set the session for review
        currentSessionId = sessionId
        shouldShowReviewPrompt = true
    }

    /// Reset session tracking
    func resetSession() {
        currentSessionId = nil
        triggeredMilestones.removeAll()
        shouldShowReviewPrompt = false
    }

    // MARK: - Haptics

    private func triggerHaptic(for milestone: HapticMilestone) {
        #if os(iOS)
        switch milestone.feedbackIntensity {
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()

        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()

        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
        #endif

        print("[DeepWorkCompanion] Haptic triggered: \(milestone.message)")
    }

    /// Trigger a test haptic
    func testHaptic(intensity: HapticIntensity) {
        #if os(iOS)
        switch intensity {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        #endif
    }

    // MARK: - Session Reviews

    /// Submit a session review
    func submitReview(
        whatWorkedOn: String,
        worthItRating: Int,
        tags: [String],
        notes: String? = nil
    ) {
        guard let sessionId = currentSessionId else { return }

        let review = SessionReview(
            sessionId: sessionId,
            whatWorkedOn: whatWorkedOn,
            worthItRating: worthItRating,
            tags: tags,
            notes: notes
        )

        sessionReviews.append(review)
        saveReviews()

        // Update favorite tags based on usage
        updateFavoriteTags(with: tags)

        // Reset
        shouldShowReviewPrompt = false
        currentSessionId = nil
    }

    /// Skip the review
    func skipReview() {
        shouldShowReviewPrompt = false
        currentSessionId = nil
    }

    private func updateFavoriteTags(with tags: [String]) {
        // Count tag usage
        var tagCounts: [String: Int] = [:]
        for review in sessionReviews {
            for tag in review.tags {
                tagCounts[tag, default: 0] += 1
            }
        }

        // Sort by usage and take top 5
        config.favoriteTags = tagCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }

    // MARK: - Analytics

    /// Average "worth it" rating across all reviews
    var averageWorthItRating: Double? {
        guard !sessionReviews.isEmpty else { return nil }
        let sum = sessionReviews.reduce(0) { $0 + $1.worthItRating }
        return Double(sum) / Double(sessionReviews.count)
    }

    /// Percentage of productive sessions (rating >= 4)
    var productiveSessionPercentage: Double? {
        guard !sessionReviews.isEmpty else { return nil }
        let productive = sessionReviews.filter { $0.wasProductive }.count
        return Double(productive) / Double(sessionReviews.count) * 100
    }

    /// Most used tags
    var topTags: [(tag: String, count: Int)] {
        var tagCounts: [String: Int] = [:]
        for review in sessionReviews {
            for tag in review.tags {
                tagCounts[tag, default: 0] += 1
            }
        }
        return tagCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { (tag: $0.key, count: $0.value) }
    }

    /// Reviews for the past week
    var recentReviews: [SessionReview] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessionReviews.filter { $0.reviewedAt >= weekAgo }
    }

    // MARK: - Persistence

    private static func loadConfig() -> DeepWorkCompanionConfig {
        guard let data = UserDefaults.standard.data(forKey: "deepWorkCompanionConfig"),
              let config = try? JSONDecoder().decode(DeepWorkCompanionConfig.self, from: data)
        else {
            return DeepWorkCompanionConfig()
        }
        return config
    }

    private func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }

    private static func loadReviews() -> [SessionReview] {
        guard let data = UserDefaults.standard.data(forKey: "sessionReviews"),
              let reviews = try? JSONDecoder().decode([SessionReview].self, from: data)
        else {
            return []
        }
        return reviews
    }

    private func saveReviews() {
        if let data = try? JSONEncoder().encode(sessionReviews) {
            UserDefaults.standard.set(data, forKey: reviewsKey)
        }
    }

    /// Clear all reviews (for testing/reset)
    func clearReviews() {
        sessionReviews = []
        saveReviews()
    }
}
