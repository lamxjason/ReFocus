import Foundation
import SwiftUI

// MARK: - Hero Class

enum HeroClass: String, Codable, CaseIterable, Identifiable {
    case warrior
    case mage
    case rogue
    // Premium classes
    case paladin
    case sage
    case shadow

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warrior: return "Warrior"
        case .mage: return "Mage"
        case .rogue: return "Rogue"
        case .paladin: return "Paladin"
        case .sage: return "Sage"
        case .shadow: return "Shadow"
        }
    }

    var description: String {
        switch self {
        case .warrior: return "Strength and discipline. A stalwart defender who never backs down."
        case .mage: return "Wisdom and focus. Masters the arcane through deep concentration."
        case .rogue: return "Speed and efficiency. Accomplishes more in less time."
        case .paladin: return "Balance and protection. Guards their goals with holy resolve."
        case .sage: return "Deep knowledge. Unlocks ancient secrets through patience."
        case .shadow: return "Stealth mastery. Works in silence, achieves in shadow."
        }
    }

    var icon: String {
        switch self {
        case .warrior: return "shield.fill"
        case .mage: return "wand.and.stars"
        case .rogue: return "bolt.fill"
        case .paladin: return "sun.max.fill"
        case .sage: return "book.fill"
        case .shadow: return "moon.fill"
        }
    }

    var isPremium: Bool {
        switch self {
        case .warrior, .mage, .rogue:
            return false
        case .paladin, .sage, .shadow:
            return true
        }
    }

    var primaryColor: Color {
        switch self {
        case .warrior: return Color(hex: "E74C3C")  // Red
        case .mage: return Color(hex: "9B59B6")     // Purple
        case .rogue: return Color(hex: "27AE60")    // Green
        case .paladin: return Color(hex: "F1C40F")  // Gold
        case .sage: return Color(hex: "3498DB")     // Blue
        case .shadow: return Color(hex: "2C3E50")   // Dark blue
        }
    }

    var ascendedName: String? {
        switch self {
        case .warrior: return "Titan"
        case .mage: return "Archmage"
        case .rogue: return "Phantom"
        case .paladin: return "Seraph"
        case .sage: return "Oracle"
        case .shadow: return "Void Walker"
        }
    }

    static var freeClasses: [HeroClass] {
        [.warrior, .mage, .rogue]
    }

    static var premiumClasses: [HeroClass] {
        [.paladin, .sage, .shadow]
    }
}

// MARK: - Evolution Tier

enum EvolutionTier: String, Codable, CaseIterable, Comparable {
    case apprentice   // Level 1-10
    case adventurer   // Level 11-25
    case champion     // Level 26-50
    case hero         // Level 51-75
    case legend       // Level 76+

    var displayName: String {
        rawValue.capitalized
    }

    var levelRange: ClosedRange<Int> {
        switch self {
        case .apprentice: return 1...10
        case .adventurer: return 11...25
        case .champion: return 26...50
        case .hero: return 51...75
        case .legend: return 76...999
        }
    }

    var minLevel: Int {
        levelRange.lowerBound
    }

    var description: String {
        switch self {
        case .apprentice: return "Just beginning the journey"
        case .adventurer: return "Finding your path"
        case .champion: return "Proving your worth"
        case .hero: return "A legend in the making"
        case .legend: return "Master of focus"
        }
    }

    var badgeColor: Color {
        switch self {
        case .apprentice: return Color(hex: "95A5A6")  // Gray
        case .adventurer: return Color(hex: "27AE60")  // Green
        case .champion: return Color(hex: "3498DB")    // Blue
        case .hero: return Color(hex: "9B59B6")        // Purple
        case .legend: return Color(hex: "F1C40F")      // Gold
        }
    }

    static func from(level: Int) -> EvolutionTier {
        switch level {
        case 1...10: return .apprentice
        case 11...25: return .adventurer
        case 26...50: return .champion
        case 51...75: return .hero
        default: return .legend
        }
    }

    static func < (lhs: EvolutionTier, rhs: EvolutionTier) -> Bool {
        lhs.minLevel < rhs.minLevel
    }
}

// MARK: - Focus Hero

struct FocusHero: Codable, Identifiable {
    let id: UUID
    var name: String
    var heroClass: HeroClass
    var createdAt: Date

    // Progression (synced from StatsManager)
    var currentLevel: Int
    var currentXP: Int

    // Equipment IDs (actual equipment looked up from catalog)
    var equippedWeaponId: String?
    var equippedArmorId: String?
    var equippedAccessoryId: String?
    var selectedBackgroundId: String?
    var selectedAuraId: String?

    // Premium ascended form unlocked
    var hasAscended: Bool

    // MARK: - Computed Properties

    var evolutionTier: EvolutionTier {
        EvolutionTier.from(level: currentLevel)
    }

    /// Key for looking up the correct sprite
    var spriteKey: String {
        if hasAscended && currentLevel >= 51 {
            return "\(heroClass.rawValue)_ascended"
        }
        return "\(heroClass.rawValue)_\(evolutionTier.rawValue)"
    }

    /// XP needed for next level (1000 per level)
    var xpForNextLevel: Int {
        1000
    }

    /// Progress toward next level (0.0 - 1.0)
    var levelProgress: Double {
        Double(currentXP % xpForNextLevel) / Double(xpForNextLevel)
    }

    /// XP remaining until next level
    var xpToNextLevel: Int {
        xpForNextLevel - (currentXP % xpForNextLevel)
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        heroClass: HeroClass,
        createdAt: Date = Date(),
        currentLevel: Int = 1,
        currentXP: Int = 0,
        equippedWeaponId: String? = nil,
        equippedArmorId: String? = nil,
        equippedAccessoryId: String? = nil,
        selectedBackgroundId: String? = nil,
        selectedAuraId: String? = nil,
        hasAscended: Bool = false
    ) {
        self.id = id
        self.name = name
        self.heroClass = heroClass
        self.createdAt = createdAt
        self.currentLevel = currentLevel
        self.currentXP = currentXP
        self.equippedWeaponId = equippedWeaponId
        self.equippedArmorId = equippedArmorId
        self.equippedAccessoryId = equippedAccessoryId
        self.selectedBackgroundId = selectedBackgroundId
        self.selectedAuraId = selectedAuraId
        self.hasAscended = hasAscended
    }

    // MARK: - Factory

    static func createNew(name: String, heroClass: HeroClass) -> FocusHero {
        FocusHero(
            name: name,
            heroClass: heroClass,
            equippedWeaponId: "weapon_starter_\(heroClass.rawValue)"
        )
    }
}

// MARK: - Hero Stats (for display)

struct HeroStats {
    let totalFocusTime: TimeInterval
    let sessionsCompleted: Int
    let currentStreak: Int
    let longestStreak: Int
    let achievementsUnlocked: Int

    var formattedFocusTime: String {
        let hours = Int(totalFocusTime) / 3600
        let minutes = (Int(totalFocusTime) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
