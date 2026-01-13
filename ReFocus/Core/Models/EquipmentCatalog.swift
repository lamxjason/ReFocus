import Foundation

// MARK: - Equipment Catalog

/// Static catalog of all available equipment in the game
enum EquipmentCatalog {

    // MARK: - All Equipment

    static let all: [Equipment] = weapons + armor + accessories + backgrounds + auras

    static func find(id: String) -> Equipment? {
        all.first { $0.id == id }
    }

    static func equipment(for slot: EquipmentSlot) -> [Equipment] {
        all.filter { $0.slot == slot }
    }

    static func equipment(for slot: EquipmentSlot, heroClass: HeroClass) -> [Equipment] {
        equipment(for: slot).filter { $0.isAvailableFor(heroClass: heroClass) }
    }

    // MARK: - Weapons

    static let weapons: [Equipment] = [
        // Starter weapons (class-specific, given at hero creation)
        Equipment(
            id: "weapon_starter_warrior",
            name: "Training Sword",
            slot: .weapon,
            rarity: .common,
            spriteKey: "weapon_sword_starter",
            unlockRequirement: nil,
            isPremium: false,
            description: "A simple sword for those beginning their journey.",
            forClasses: [.warrior, .paladin]
        ),
        Equipment(
            id: "weapon_starter_mage",
            name: "Apprentice Staff",
            slot: .weapon,
            rarity: .common,
            spriteKey: "weapon_staff_starter",
            unlockRequirement: nil,
            isPremium: false,
            description: "A basic staff crackling with potential.",
            forClasses: [.mage, .sage]
        ),
        Equipment(
            id: "weapon_starter_rogue",
            name: "Practice Daggers",
            slot: .weapon,
            rarity: .common,
            spriteKey: "weapon_daggers_starter",
            unlockRequirement: nil,
            isPremium: false,
            description: "Light blades for the swift of hand.",
            forClasses: [.rogue, .shadow]
        ),

        // Iron tier (1 hour total focus)
        Equipment(
            id: "weapon_iron_sword",
            name: "Iron Sword",
            slot: .weapon,
            rarity: .uncommon,
            spriteKey: "weapon_sword_iron",
            unlockRequirement: .totalFocusTime(hours: 1),
            isPremium: false,
            description: "Forged through dedication.",
            forClasses: [.warrior, .paladin]
        ),
        Equipment(
            id: "weapon_iron_staff",
            name: "Oak Staff",
            slot: .weapon,
            rarity: .uncommon,
            spriteKey: "weapon_staff_iron",
            unlockRequirement: .totalFocusTime(hours: 1),
            isPremium: false,
            description: "Ancient oak channels deeper focus.",
            forClasses: [.mage, .sage]
        ),
        Equipment(
            id: "weapon_iron_daggers",
            name: "Steel Daggers",
            slot: .weapon,
            rarity: .uncommon,
            spriteKey: "weapon_daggers_iron",
            unlockRequirement: .totalFocusTime(hours: 1),
            isPremium: false,
            description: "Balanced for precision strikes.",
            forClasses: [.rogue, .shadow]
        ),

        // Steel tier (10 hours total focus)
        Equipment(
            id: "weapon_steel_sword",
            name: "Steel Greatsword",
            slot: .weapon,
            rarity: .rare,
            spriteKey: "weapon_sword_steel",
            unlockRequirement: .totalFocusTime(hours: 10),
            isPremium: false,
            description: "A blade that speaks of countless hours of discipline.",
            forClasses: [.warrior, .paladin]
        ),
        Equipment(
            id: "weapon_steel_staff",
            name: "Crystal Staff",
            slot: .weapon,
            rarity: .rare,
            spriteKey: "weapon_staff_steel",
            unlockRequirement: .totalFocusTime(hours: 10),
            isPremium: false,
            description: "Topped with a crystal that amplifies intention.",
            forClasses: [.mage, .sage]
        ),
        Equipment(
            id: "weapon_steel_daggers",
            name: "Shadow Blades",
            slot: .weapon,
            rarity: .rare,
            spriteKey: "weapon_daggers_steel",
            unlockRequirement: .totalFocusTime(hours: 10),
            isPremium: false,
            description: "Move like the wind, strike like lightning.",
            forClasses: [.rogue, .shadow]
        ),

        // Epic tier (50 hours total focus)
        Equipment(
            id: "weapon_epic_sword",
            name: "Champion's Blade",
            slot: .weapon,
            rarity: .epic,
            spriteKey: "weapon_sword_epic",
            unlockRequirement: .totalFocusTime(hours: 50),
            isPremium: false,
            description: "Wielded by those who have proven their worth.",
            forClasses: [.warrior, .paladin]
        ),
        Equipment(
            id: "weapon_epic_staff",
            name: "Arcane Scepter",
            slot: .weapon,
            rarity: .epic,
            spriteKey: "weapon_staff_epic",
            unlockRequirement: .totalFocusTime(hours: 50),
            isPremium: false,
            description: "Hums with accumulated wisdom.",
            forClasses: [.mage, .sage]
        ),
        Equipment(
            id: "weapon_epic_daggers",
            name: "Phantom Claws",
            slot: .weapon,
            rarity: .epic,
            spriteKey: "weapon_daggers_epic",
            unlockRequirement: .totalFocusTime(hours: 50),
            isPremium: false,
            description: "Strike before they know you're there.",
            forClasses: [.rogue, .shadow]
        ),

        // Legendary tier (100 hours - Premium)
        Equipment(
            id: "weapon_legendary_sword",
            name: "Excalibur",
            slot: .weapon,
            rarity: .legendary,
            spriteKey: "weapon_sword_legendary",
            unlockRequirement: .totalFocusTime(hours: 100),
            isPremium: true,
            description: "The legendary blade of focus mastery.",
            forClasses: [.warrior, .paladin]
        ),
        Equipment(
            id: "weapon_legendary_staff",
            name: "Staff of Eternity",
            slot: .weapon,
            rarity: .legendary,
            spriteKey: "weapon_staff_legendary",
            unlockRequirement: .totalFocusTime(hours: 100),
            isPremium: true,
            description: "Time bends to the will of its master.",
            forClasses: [.mage, .sage]
        ),
        Equipment(
            id: "weapon_legendary_daggers",
            name: "Void Fangs",
            slot: .weapon,
            rarity: .legendary,
            spriteKey: "weapon_daggers_legendary",
            unlockRequirement: .totalFocusTime(hours: 100),
            isPremium: true,
            description: "Cut through distractions like they don't exist.",
            forClasses: [.rogue, .shadow]
        ),

        // Premium cosmetic weapons
        Equipment(
            id: "weapon_flame_sword",
            name: "Flamebrand",
            slot: .weapon,
            rarity: .epic,
            spriteKey: "weapon_sword_flame",
            unlockRequirement: .premium,
            isPremium: true,
            description: "Burns with the fire of determination.",
            forClasses: [.warrior, .paladin]
        ),
        Equipment(
            id: "weapon_ice_staff",
            name: "Frostweaver",
            slot: .weapon,
            rarity: .epic,
            spriteKey: "weapon_staff_ice",
            unlockRequirement: .premium,
            isPremium: true,
            description: "Cool focus in the heat of distraction.",
            forClasses: [.mage, .sage]
        ),
        Equipment(
            id: "weapon_shadow_daggers",
            name: "Nightfall Blades",
            slot: .weapon,
            rarity: .epic,
            spriteKey: "weapon_daggers_shadow",
            unlockRequirement: .premium,
            isPremium: true,
            description: "Darker than the deepest night.",
            forClasses: [.rogue, .shadow]
        ),
    ]

    // MARK: - Armor

    static let armor: [Equipment] = [
        // Starter armor (3-day streak)
        Equipment(
            id: "armor_training",
            name: "Training Gear",
            slot: .armor,
            rarity: .common,
            spriteKey: "armor_training",
            unlockRequirement: .streak(days: 3),
            isPremium: false,
            description: "Simple but reliable protection.",
            forClasses: nil
        ),

        // Adventurer's cloak (10 sessions)
        Equipment(
            id: "armor_adventurer",
            name: "Adventurer's Cloak",
            slot: .armor,
            rarity: .uncommon,
            spriteKey: "armor_adventurer",
            unlockRequirement: .sessionsCompleted(count: 10),
            isPremium: false,
            description: "The mark of one who has begun their journey.",
            forClasses: nil
        ),

        // Champion armor (Level 26)
        Equipment(
            id: "armor_champion",
            name: "Champion's Plate",
            slot: .armor,
            rarity: .rare,
            spriteKey: "armor_champion",
            unlockRequirement: .level(minimum: 26),
            isPremium: false,
            description: "Worn by those who have proven their dedication.",
            forClasses: nil
        ),

        // Hero armor (Level 51)
        Equipment(
            id: "armor_hero",
            name: "Hero's Regalia",
            slot: .armor,
            rarity: .epic,
            spriteKey: "armor_hero",
            unlockRequirement: .level(minimum: 51),
            isPremium: false,
            description: "Armor fit for a legend in the making.",
            forClasses: nil
        ),

        // Legendary cape (30-day streak)
        Equipment(
            id: "armor_legendary_cape",
            name: "Legendary Cape",
            slot: .armor,
            rarity: .legendary,
            spriteKey: "armor_cape_legendary",
            unlockRequirement: .streak(days: 30),
            isPremium: false,
            description: "A month of unwavering dedication.",
            forClasses: nil
        ),

        // Premium armor sets
        Equipment(
            id: "armor_dragon",
            name: "Dragon Scale Armor",
            slot: .armor,
            rarity: .legendary,
            spriteKey: "armor_dragon",
            unlockRequirement: .premium,
            isPremium: true,
            description: "Forged from the scales of focused dragons.",
            forClasses: nil
        ),
        Equipment(
            id: "armor_crystal",
            name: "Crystal Armor",
            slot: .armor,
            rarity: .legendary,
            spriteKey: "armor_crystal",
            unlockRequirement: .premium,
            isPremium: true,
            description: "Transparent determination made solid.",
            forClasses: nil
        ),
        Equipment(
            id: "armor_void",
            name: "Void Shroud",
            slot: .armor,
            rarity: .legendary,
            spriteKey: "armor_void",
            unlockRequirement: .premium,
            isPremium: true,
            description: "Wrapped in the absence of distraction.",
            forClasses: nil
        ),
        Equipment(
            id: "armor_celestial",
            name: "Celestial Vestments",
            slot: .armor,
            rarity: .legendary,
            spriteKey: "armor_celestial",
            unlockRequirement: .premium,
            isPremium: true,
            description: "Blessed by the stars themselves.",
            forClasses: nil
        ),
    ]

    // MARK: - Accessories

    static let accessories: [Equipment] = [
        // Focus amulet (7-day streak)
        Equipment(
            id: "accessory_focus_amulet",
            name: "Focus Amulet",
            slot: .accessory,
            rarity: .uncommon,
            spriteKey: "accessory_amulet_focus",
            unlockRequirement: .streak(days: 7),
            isPremium: false,
            description: "A week of dedication crystallized.",
            forClasses: nil
        ),

        // Determination ring (25 sessions)
        Equipment(
            id: "accessory_determination_ring",
            name: "Ring of Determination",
            slot: .accessory,
            rarity: .rare,
            spriteKey: "accessory_ring_determination",
            unlockRequirement: .sessionsCompleted(count: 25),
            isPremium: false,
            description: "Each session makes it shine brighter.",
            forClasses: nil
        ),

        // Weekly goal pendant
        Equipment(
            id: "accessory_goal_pendant",
            name: "Achievement Pendant",
            slot: .accessory,
            rarity: .rare,
            spriteKey: "accessory_pendant_goal",
            unlockRequirement: .weeklyGoalCompleted,
            isPremium: false,
            description: "Proof that goals are meant to be achieved.",
            forClasses: nil
        ),

        // Premium pet companions
        Equipment(
            id: "accessory_pet_dragon",
            name: "Baby Dragon",
            slot: .accessory,
            rarity: .legendary,
            spriteKey: "accessory_pet_dragon",
            unlockRequirement: .premium,
            isPremium: true,
            description: "A loyal companion who grows with you.",
            forClasses: nil
        ),
        Equipment(
            id: "accessory_pet_fairy",
            name: "Focus Fairy",
            slot: .accessory,
            rarity: .epic,
            spriteKey: "accessory_pet_fairy",
            unlockRequirement: .premium,
            isPremium: true,
            description: "Sprinkles motivation wherever she goes.",
            forClasses: nil
        ),
        Equipment(
            id: "accessory_pet_owl",
            name: "Wisdom Owl",
            slot: .accessory,
            rarity: .epic,
            spriteKey: "accessory_pet_owl",
            unlockRequirement: .premium,
            isPremium: true,
            description: "Watches over your focus sessions.",
            forClasses: nil
        ),
    ]

    // MARK: - Backgrounds

    static let backgrounds: [Equipment] = [
        // Free backgrounds
        Equipment(
            id: "background_meadow",
            name: "Peaceful Meadow",
            slot: .background,
            rarity: .common,
            spriteKey: "background_meadow",
            unlockRequirement: nil,
            isPremium: false,
            description: "A calm field perfect for focus.",
            forClasses: nil
        ),
        Equipment(
            id: "background_library",
            name: "Ancient Library",
            slot: .background,
            rarity: .uncommon,
            spriteKey: "background_library",
            unlockRequirement: .level(minimum: 10),
            isPremium: false,
            description: "Surrounded by the wisdom of ages.",
            forClasses: nil
        ),

        // Premium backgrounds
        Equipment(
            id: "background_forest",
            name: "Enchanted Forest",
            slot: .background,
            rarity: .rare,
            spriteKey: "background_forest",
            unlockRequirement: .premium,
            isPremium: true,
            description: "Where magic and focus intertwine.",
            forClasses: nil
        ),
        Equipment(
            id: "background_castle",
            name: "Grand Castle",
            slot: .background,
            rarity: .rare,
            spriteKey: "background_castle",
            unlockRequirement: .premium,
            isPremium: true,
            description: "A fortress of productivity.",
            forClasses: nil
        ),
        Equipment(
            id: "background_void",
            name: "Void Realm",
            slot: .background,
            rarity: .epic,
            spriteKey: "background_void",
            unlockRequirement: .premium,
            isPremium: true,
            description: "Pure emptiness. Pure focus.",
            forClasses: nil
        ),
        Equipment(
            id: "background_sky_temple",
            name: "Sky Temple",
            slot: .background,
            rarity: .legendary,
            spriteKey: "background_sky_temple",
            unlockRequirement: .premium,
            isPremium: true,
            description: "Above the clouds, above distraction.",
            forClasses: nil
        ),
    ]

    // MARK: - Auras

    static let auras: [Equipment] = [
        // Free auras
        Equipment(
            id: "aura_subtle",
            name: "Subtle Glow",
            slot: .aura,
            rarity: .common,
            spriteKey: "aura_subtle",
            unlockRequirement: .level(minimum: 5),
            isPremium: false,
            description: "A gentle light of awakening focus.",
            forClasses: nil
        ),

        // Premium auras
        Equipment(
            id: "aura_flame",
            name: "Flame Aura",
            slot: .aura,
            rarity: .rare,
            spriteKey: "aura_flame",
            unlockRequirement: .premium,
            isPremium: true,
            description: "Burning with passionate determination.",
            forClasses: nil
        ),
        Equipment(
            id: "aura_frost",
            name: "Frost Aura",
            slot: .aura,
            rarity: .rare,
            spriteKey: "aura_frost",
            unlockRequirement: .premium,
            isPremium: true,
            description: "Cool, calm, collected.",
            forClasses: nil
        ),
        Equipment(
            id: "aura_lightning",
            name: "Lightning Aura",
            slot: .aura,
            rarity: .epic,
            spriteKey: "aura_lightning",
            unlockRequirement: .premium,
            isPremium: true,
            description: "Crackling with energy.",
            forClasses: nil
        ),
        Equipment(
            id: "aura_celestial",
            name: "Celestial Aura",
            slot: .aura,
            rarity: .legendary,
            spriteKey: "aura_celestial",
            unlockRequirement: .premium,
            isPremium: true,
            description: "Blessed by the cosmos.",
            forClasses: nil
        ),
        Equipment(
            id: "aura_void",
            name: "Void Aura",
            slot: .aura,
            rarity: .legendary,
            spriteKey: "aura_void",
            unlockRequirement: .premium,
            isPremium: true,
            description: "The absence of all distraction.",
            forClasses: nil
        ),
    ]

    // MARK: - Helper Methods

    /// Get all equipment that can be unlocked by a specific requirement
    static func equipment(unlockedBy requirement: UnlockRequirement) -> [Equipment] {
        all.filter { $0.unlockRequirement == requirement }
    }

    /// Get all free equipment
    static var freeEquipment: [Equipment] {
        all.filter { !$0.isPremium }
    }

    /// Get all premium equipment
    static var premiumEquipment: [Equipment] {
        all.filter { $0.isPremium }
    }

    /// Get starter weapon for a specific class
    static func starterWeapon(for heroClass: HeroClass) -> Equipment? {
        let id: String
        switch heroClass {
        case .warrior, .paladin:
            id = "weapon_starter_warrior"
        case .mage, .sage:
            id = "weapon_starter_mage"
        case .rogue, .shadow:
            id = "weapon_starter_rogue"
        }
        return find(id: id)
    }
}
