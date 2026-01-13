import Foundation
import SwiftUI

/// Manages variable rewards to maintain user engagement
/// Based on research: Variable rewards maintain anticipation and reduce predictability fatigue
/// - 20% chance of bonus reward per completed session
/// - Rewards scale with streak length and session duration
@MainActor
final class RewardManager: ObservableObject {
    static let shared = RewardManager()

    // MARK: - Published State

    @Published private(set) var lastReward: SessionReward?
    @Published private(set) var pendingRewards: [SessionReward] = []
    @Published private(set) var totalBonusXPEarned: Int = 0

    // MARK: - Reward Configuration

    /// Base chance of getting a bonus reward (20%)
    private let baseRewardChance: Double = 0.20

    /// Streak bonus to reward chance (extra 2% per day of streak, max 10%)
    private let streakChanceBonus: Double = 0.02
    private let maxStreakBonus: Double = 0.10

    /// Session length bonus (extra 5% for sessions > 45 min)
    private let longSessionBonus: Double = 0.05
    private let longSessionThreshold: TimeInterval = 45 * 60

    // MARK: - Reward Types

    enum RewardType: String, CaseIterable, Codable {
        case xpBonus = "xp_bonus"
        case streakFreeze = "streak_freeze"
        case doubleXP = "double_xp"      // Next session
        case luckyDrop = "lucky_drop"    // Rare cosmetic
        case motivationalBoost = "motivational_boost"

        var icon: String {
            switch self {
            case .xpBonus: return "star.fill"
            case .streakFreeze: return "snowflake"
            case .doubleXP: return "sparkles"
            case .luckyDrop: return "gift.fill"
            case .motivationalBoost: return "heart.fill"
            }
        }

        var color: Color {
            switch self {
            case .xpBonus: return .yellow
            case .streakFreeze: return .cyan
            case .doubleXP: return .purple
            case .luckyDrop: return .orange
            case .motivationalBoost: return .pink
            }
        }

        var displayName: String {
            switch self {
            case .xpBonus: return "Bonus XP"
            case .streakFreeze: return "Streak Freeze"
            case .doubleXP: return "Double XP"
            case .luckyDrop: return "Lucky Drop"
            case .motivationalBoost: return "Motivation Boost"
            }
        }

        /// Rarity affects drop rate
        var rarity: RewardRarity {
            switch self {
            case .xpBonus: return .common
            case .motivationalBoost: return .common
            case .doubleXP: return .uncommon
            case .streakFreeze: return .rare
            case .luckyDrop: return .legendary
            }
        }
    }

    enum RewardRarity: String, Codable {
        case common      // 60% of rewards
        case uncommon    // 25% of rewards
        case rare        // 12% of rewards
        case legendary   // 3% of rewards

        var dropWeight: Double {
            switch self {
            case .common: return 0.60
            case .uncommon: return 0.25
            case .rare: return 0.12
            case .legendary: return 0.03
            }
        }

        var color: Color {
            switch self {
            case .common: return .gray
            case .uncommon: return .green
            case .rare: return .blue
            case .legendary: return .orange
            }
        }
    }

    // MARK: - Session Reward

    struct SessionReward: Identifiable, Codable {
        let id: UUID
        let type: RewardType
        let value: Int?           // For XP rewards
        let message: String
        let earnedAt: Date
        let sessionId: UUID?

        init(type: RewardType, value: Int? = nil, message: String, sessionId: UUID? = nil) {
            self.id = UUID()
            self.type = type
            self.value = value
            self.message = message
            self.earnedAt = Date()
            self.sessionId = sessionId
        }
    }

    // MARK: - Initialization

    private init() {
        loadState()
    }

    // MARK: - Reward Generation

    /// Check if user should receive a bonus reward after session
    /// Returns nil if no reward, or the reward if earned
    func checkForReward(
        session: FocusSession,
        currentStreak: Int,
        wasCompleted: Bool
    ) -> SessionReward? {
        // Only completed sessions can earn bonus rewards
        guard wasCompleted else { return nil }

        // Calculate reward chance
        let chance = calculateRewardChance(
            duration: TimeInterval(session.actualDurationSeconds ?? 0),
            streak: currentStreak
        )

        // Roll for reward
        let roll = Double.random(in: 0...1)
        guard roll < chance else { return nil }

        // Generate reward
        let reward = generateReward(session: session, streak: currentStreak)
        lastReward = reward
        pendingRewards.append(reward)

        if let xp = reward.value {
            totalBonusXPEarned += xp
        }

        // Send reward notification
        NotificationManager.shared.sendRewardNotification(
            rewardName: reward.message,
            rarity: reward.type.rarity.rawValue
        )

        saveState()
        return reward
    }

    /// Calculate chance of earning a bonus reward
    private func calculateRewardChance(duration: TimeInterval, streak: Int) -> Double {
        var chance = baseRewardChance

        // Streak bonus (max 10% extra)
        let streakBonus = min(Double(streak) * streakChanceBonus, maxStreakBonus)
        chance += streakBonus

        // Long session bonus
        if duration > longSessionThreshold {
            chance += longSessionBonus
        }

        return min(chance, 0.40) // Cap at 40%
    }

    /// Generate a specific reward based on rarity weights
    private func generateReward(session: FocusSession, streak: Int) -> SessionReward {
        let rewardType = rollForRewardType()

        switch rewardType {
        case .xpBonus:
            let bonusXP = calculateBonusXP(streak: streak)
            return SessionReward(
                type: .xpBonus,
                value: bonusXP,
                message: "Bonus XP earned! +\(bonusXP) XP",
                sessionId: session.id
            )

        case .streakFreeze:
            return SessionReward(
                type: .streakFreeze,
                value: 1,
                message: "Streak Freeze earned! Your streak is protected for one day.",
                sessionId: session.id
            )

        case .doubleXP:
            return SessionReward(
                type: .doubleXP,
                message: "Double XP activated! Your next session earns 2x XP.",
                sessionId: session.id
            )

        case .luckyDrop:
            return SessionReward(
                type: .luckyDrop,
                message: "Lucky Drop! You found a rare item.",
                sessionId: session.id
            )

        case .motivationalBoost:
            let quotes = [
                "Your dedication is inspiring!",
                "Champions are made in moments like these.",
                "Every session brings you closer to your dreams.",
                "Consistency is your superpower.",
                "The future belongs to those who focus today."
            ]
            return SessionReward(
                type: .motivationalBoost,
                message: quotes.randomElement() ?? "Keep going!",
                sessionId: session.id
            )
        }
    }

    /// Roll for reward type based on rarity weights
    private func rollForRewardType() -> RewardType {
        let roll = Double.random(in: 0...1)
        var cumulative: Double = 0

        // Group rewards by rarity
        let rarityOrder: [RewardRarity] = [.common, .uncommon, .rare, .legendary]

        for rarity in rarityOrder {
            cumulative += rarity.dropWeight
            if roll < cumulative {
                // Pick a random reward of this rarity
                let rewardsOfRarity = RewardType.allCases.filter { $0.rarity == rarity }
                return rewardsOfRarity.randomElement() ?? .xpBonus
            }
        }

        return .xpBonus // Fallback
    }

    /// Calculate bonus XP based on streak
    private func calculateBonusXP(streak: Int) -> Int {
        let baseBonus = 50

        // Streak multiplier
        let multiplier: Double
        if streak >= 30 {
            multiplier = 3.0
        } else if streak >= 14 {
            multiplier = 2.0
        } else if streak >= 7 {
            multiplier = 1.5
        } else {
            multiplier = 1.0
        }

        // Add some randomness (80% - 120%)
        let variance = Double.random(in: 0.8...1.2)

        return Int(Double(baseBonus) * multiplier * variance)
    }

    // MARK: - Reward Claiming

    /// Mark a reward as claimed/viewed
    func claimReward(_ reward: SessionReward) {
        // Handle streak freeze specially - add to user's inventory
        if reward.type == .streakFreeze {
            StatsManager.shared.addStreakFreeze()
        }

        pendingRewards.removeAll { $0.id == reward.id }
        saveState()
    }

    /// Clear all pending rewards
    func clearPendingRewards() {
        pendingRewards.removeAll()
        saveState()
    }

    // MARK: - Double XP Tracking

    /// Check if user has active double XP
    var hasActiveDoubleXP: Bool {
        pendingRewards.contains { $0.type == .doubleXP }
    }

    /// Consume double XP reward
    func consumeDoubleXP() -> Bool {
        guard let index = pendingRewards.firstIndex(where: { $0.type == .doubleXP }) else {
            return false
        }
        pendingRewards.remove(at: index)
        saveState()
        return true
    }

    // MARK: - Persistence

    private let stateKey = "rewardManagerState"

    private func saveState() {
        let state = RewardManagerState(
            pendingRewards: pendingRewards,
            totalBonusXPEarned: totalBonusXPEarned
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: stateKey)
        }
    }

    private func loadState() {
        guard let data = UserDefaults.standard.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(RewardManagerState.self, from: data) else {
            return
        }
        pendingRewards = state.pendingRewards
        totalBonusXPEarned = state.totalBonusXPEarned
    }

    private struct RewardManagerState: Codable {
        let pendingRewards: [SessionReward]
        let totalBonusXPEarned: Int
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension RewardManager {
    static var preview: RewardManager {
        let manager = RewardManager()
        manager.lastReward = SessionReward(
            type: .xpBonus,
            value: 75,
            message: "Bonus XP earned! +75 XP"
        )
        manager.pendingRewards = [
            SessionReward(type: .doubleXP, message: "Double XP activated!"),
            SessionReward(type: .streakFreeze, value: 1, message: "Streak Freeze earned!")
        ]
        return manager
    }
}
#endif
