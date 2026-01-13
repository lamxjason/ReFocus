import Foundation
import SwiftUI

// MARK: - Equipment Slot

enum EquipmentSlot: String, Codable, CaseIterable {
    case weapon
    case armor
    case accessory
    case background
    case aura

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .weapon: return "sword.fill"
        case .armor: return "shield.lefthalf.filled"
        case .accessory: return "sparkles"
        case .background: return "photo.fill"
        case .aura: return "rays"
        }
    }

    var emptySlotIcon: String {
        switch self {
        case .weapon: return "plus.circle.dashed"
        case .armor: return "plus.circle.dashed"
        case .accessory: return "plus.circle.dashed"
        case .background: return "photo.badge.plus"
        case .aura: return "plus.circle.dashed"
        }
    }
}

// MARK: - Rarity

enum Rarity: String, Codable, CaseIterable, Comparable {
    case common
    case uncommon
    case rare
    case epic
    case legendary

    var displayName: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .common: return Color(hex: "95A5A6")     // Gray
        case .uncommon: return Color(hex: "27AE60")   // Green
        case .rare: return Color(hex: "3498DB")       // Blue
        case .epic: return Color(hex: "9B59B6")       // Purple
        case .legendary: return Color(hex: "F1C40F")  // Gold
        }
    }

    var sortOrder: Int {
        switch self {
        case .common: return 0
        case .uncommon: return 1
        case .rare: return 2
        case .epic: return 3
        case .legendary: return 4
        }
    }

    static func < (lhs: Rarity, rhs: Rarity) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - Unlock Requirement

enum UnlockRequirement: Codable, Equatable {
    case firstSession
    case sessionsCompleted(count: Int)
    case streak(days: Int)
    case totalFocusTime(hours: Int)
    case weeklyGoalCompleted
    case achievement(type: String)
    case level(minimum: Int)
    case premium

    var description: String {
        switch self {
        case .firstSession:
            return "Complete your first session"
        case .sessionsCompleted(let count):
            return "Complete \(count) sessions"
        case .streak(let days):
            return "Reach a \(days)-day streak"
        case .totalFocusTime(let hours):
            return "Focus for \(hours) total hours"
        case .weeklyGoalCompleted:
            return "Complete your weekly goal"
        case .achievement(let type):
            return "Unlock the \(type) achievement"
        case .level(let minimum):
            return "Reach level \(minimum)"
        case .premium:
            return "Premium exclusive"
        }
    }

    var icon: String {
        switch self {
        case .firstSession: return "star.fill"
        case .sessionsCompleted: return "checkmark.circle.fill"
        case .streak: return "flame.fill"
        case .totalFocusTime: return "clock.fill"
        case .weeklyGoalCompleted: return "target"
        case .achievement: return "medal.fill"
        case .level: return "arrow.up.circle.fill"
        case .premium: return "crown.fill"
        }
    }
}

// MARK: - Equipment

struct Equipment: Codable, Identifiable, Equatable {
    let id: String                      // e.g., "weapon_sword_iron"
    let name: String
    let slot: EquipmentSlot
    let rarity: Rarity
    let spriteKey: String               // Asset name for the sprite
    let unlockRequirement: UnlockRequirement?
    let isPremium: Bool
    let description: String
    let forClasses: [HeroClass]?        // nil = all classes

    // MARK: - Computed

    var isUniversal: Bool {
        forClasses == nil || forClasses?.count == HeroClass.allCases.count
    }

    func isAvailableFor(heroClass: HeroClass) -> Bool {
        guard let classes = forClasses else { return true }
        return classes.contains(heroClass)
    }

    // MARK: - Equatable

    static func == (lhs: Equipment, rhs: Equipment) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Equipment Set (for grouped cosmetics)

struct EquipmentSet: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let equipmentIds: [String]      // IDs of equipment in this set
    let isPremium: Bool
    let bonusEffect: String?        // e.g., "Golden aura when full set equipped"

    var pieceCount: Int {
        equipmentIds.count
    }
}
