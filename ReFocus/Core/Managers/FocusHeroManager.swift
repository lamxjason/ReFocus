import Foundation
import SwiftUI

/// Manages the user's focus hero(es), equipment, and progression
@MainActor
final class FocusHeroManager: ObservableObject {
    static let shared = FocusHeroManager()

    // MARK: - Published State

    @Published var currentHero: FocusHero?
    @Published var allHeroes: [FocusHero] = []
    @Published var ownedEquipmentIds: Set<String> = []
    @Published var pendingEvolution: EvolutionTier?
    @Published var showEvolutionCelebration = false

    // MARK: - Private

    private let heroesKey = "focusHeroes"
    private let currentHeroIdKey = "currentHeroId"
    private let ownedEquipmentKey = "ownedEquipment"

    // MARK: - Initialization

    private init() {
        load()
    }

    // MARK: - Hero Management

    /// Create a new hero
    @discardableResult
    func createHero(name: String, heroClass: HeroClass) -> FocusHero {
        let hero = FocusHero.createNew(name: name, heroClass: heroClass)

        allHeroes.append(hero)

        // If this is the first hero, make it current
        if currentHero == nil {
            currentHero = hero
        }

        // Grant starter equipment
        if let starterWeapon = EquipmentCatalog.starterWeapon(for: heroClass) {
            unlockEquipment(starterWeapon)
        }

        // Grant default background
        unlockEquipment(id: "background_meadow")

        save()
        return hero
    }

    /// Select a different hero as current (Premium feature)
    func selectHero(_ hero: FocusHero) {
        guard allHeroes.contains(where: { $0.id == hero.id }) else { return }
        currentHero = hero
        save()
    }

    /// Delete a hero
    func deleteHero(_ hero: FocusHero) {
        allHeroes.removeAll { $0.id == hero.id }

        // If we deleted the current hero, select another
        if currentHero?.id == hero.id {
            currentHero = allHeroes.first
        }

        save()
    }

    /// Rename current hero
    func renameHero(to newName: String) {
        guard var hero = currentHero else { return }
        hero.name = newName
        updateHero(hero)
    }

    /// Check if user can create more heroes (Premium feature)
    func canCreateMoreHeroes(isPremium: Bool) -> Bool {
        if isPremium { return true }
        return allHeroes.isEmpty // Free users can only have 1 hero
    }

    // MARK: - Progression

    /// Sync hero stats with StatsManager - call this after each session
    func syncWithStats() {
        let statsManager = StatsManager.shared

        guard var hero = currentHero else { return }

        let previousTier = hero.evolutionTier
        let previousLevel = hero.currentLevel

        // Update from stats
        hero.currentXP = statsManager.xp
        hero.currentLevel = statsManager.level

        let newTier = hero.evolutionTier

        // Check for evolution
        if newTier > previousTier {
            pendingEvolution = newTier
            showEvolutionCelebration = true
        }

        updateHero(hero)

        // Check for equipment unlocks
        checkEquipmentUnlocks()
    }

    /// Mark evolution as seen
    func dismissEvolutionCelebration() {
        pendingEvolution = nil
        showEvolutionCelebration = false
    }

    /// Unlock ascended form (Premium feature)
    func unlockAscendedForm() {
        guard var hero = currentHero else { return }
        guard hero.currentLevel >= 51 else { return } // Must be Hero tier+

        hero.hasAscended = true
        updateHero(hero)
    }

    // MARK: - Equipment

    /// Unlock a piece of equipment by ID
    func unlockEquipment(id: String) {
        guard !ownedEquipmentIds.contains(id) else { return }
        ownedEquipmentIds.insert(id)
        save()
    }

    /// Unlock a piece of equipment
    func unlockEquipment(_ equipment: Equipment) {
        unlockEquipment(id: equipment.id)
    }

    /// Check if equipment is owned
    func ownsEquipment(id: String) -> Bool {
        ownedEquipmentIds.contains(id)
    }

    /// Check if equipment is owned
    func ownsEquipment(_ equipment: Equipment) -> Bool {
        ownsEquipment(id: equipment.id)
    }

    /// Get all owned equipment
    var ownedEquipment: [Equipment] {
        ownedEquipmentIds.compactMap { EquipmentCatalog.find(id: $0) }
    }

    /// Get owned equipment for a specific slot
    func ownedEquipment(for slot: EquipmentSlot) -> [Equipment] {
        ownedEquipment.filter { $0.slot == slot }
    }

    /// Equip an item
    func equipItem(_ equipment: Equipment) {
        guard var hero = currentHero else { return }
        guard ownsEquipment(equipment) else { return }
        guard equipment.isAvailableFor(heroClass: hero.heroClass) else { return }

        switch equipment.slot {
        case .weapon:
            hero.equippedWeaponId = equipment.id
        case .armor:
            hero.equippedArmorId = equipment.id
        case .accessory:
            hero.equippedAccessoryId = equipment.id
        case .background:
            hero.selectedBackgroundId = equipment.id
        case .aura:
            hero.selectedAuraId = equipment.id
        }

        updateHero(hero)
    }

    /// Unequip a slot
    func unequipSlot(_ slot: EquipmentSlot) {
        guard var hero = currentHero else { return }

        switch slot {
        case .weapon:
            hero.equippedWeaponId = nil
        case .armor:
            hero.equippedArmorId = nil
        case .accessory:
            hero.equippedAccessoryId = nil
        case .background:
            hero.selectedBackgroundId = nil
        case .aura:
            hero.selectedAuraId = nil
        }

        updateHero(hero)
    }

    /// Get currently equipped item for a slot
    func equippedItem(for slot: EquipmentSlot) -> Equipment? {
        guard let hero = currentHero else { return nil }

        let id: String?
        switch slot {
        case .weapon:
            id = hero.equippedWeaponId
        case .armor:
            id = hero.equippedArmorId
        case .accessory:
            id = hero.equippedAccessoryId
        case .background:
            id = hero.selectedBackgroundId
        case .aura:
            id = hero.selectedAuraId
        }

        guard let equipmentId = id else { return nil }
        return EquipmentCatalog.find(id: equipmentId)
    }

    // MARK: - Equipment Unlock Checks

    /// Check if any equipment should be unlocked based on current stats
    func checkEquipmentUnlocks() {
        let stats = StatsManager.shared
        let isPremium = PremiumManager.shared.isPremium

        for equipment in EquipmentCatalog.all {
            // Skip if already owned
            guard !ownsEquipment(equipment) else { continue }

            // Skip premium items for non-premium users
            if equipment.isPremium && !isPremium { continue }

            // Check unlock requirement
            guard let requirement = equipment.unlockRequirement else { continue }

            if shouldUnlock(equipment: equipment, requirement: requirement, stats: stats, isPremium: isPremium) {
                unlockEquipment(equipment)
            }
        }
    }

    private func shouldUnlock(
        equipment: Equipment,
        requirement: UnlockRequirement,
        stats: StatsManager,
        isPremium: Bool
    ) -> Bool {
        switch requirement {
        case .firstSession:
            return stats.sessions.count >= 1

        case .sessionsCompleted(let count):
            return stats.sessions.filter { $0.wasCompleted }.count >= count

        case .streak(let days):
            return stats.currentStreak >= days || stats.longestStreak >= days

        case .totalFocusTime(let hours):
            let totalHours = stats.totalFocusTime / 3600
            return totalHours >= Double(hours)

        case .weeklyGoalCompleted:
            return stats.weeklyProgress >= stats.weeklyGoal

        case .achievement(let type):
            return stats.achievements.contains { $0.type.rawValue == type }

        case .level(let minimum):
            return stats.level >= minimum

        case .premium:
            return isPremium
        }
    }

    // MARK: - Persistence

    private func updateHero(_ hero: FocusHero) {
        if let index = allHeroes.firstIndex(where: { $0.id == hero.id }) {
            allHeroes[index] = hero
        }
        if currentHero?.id == hero.id {
            currentHero = hero
        }
        save()
    }

    private func save() {
        // Save heroes
        if let heroData = try? JSONEncoder().encode(allHeroes) {
            UserDefaults.standard.set(heroData, forKey: heroesKey)
        }

        // Save current hero ID
        if let currentId = currentHero?.id {
            UserDefaults.standard.set(currentId.uuidString, forKey: currentHeroIdKey)
        }

        // Save owned equipment
        let equipmentArray = Array(ownedEquipmentIds)
        if let equipmentData = try? JSONEncoder().encode(equipmentArray) {
            UserDefaults.standard.set(equipmentData, forKey: ownedEquipmentKey)
        }
    }

    private func load() {
        // Load heroes
        if let heroData = UserDefaults.standard.data(forKey: heroesKey),
           let heroes = try? JSONDecoder().decode([FocusHero].self, from: heroData) {
            allHeroes = heroes
        }

        // Load current hero
        if let currentIdString = UserDefaults.standard.string(forKey: currentHeroIdKey),
           let currentId = UUID(uuidString: currentIdString) {
            currentHero = allHeroes.first { $0.id == currentId }
        } else {
            currentHero = allHeroes.first
        }

        // Load owned equipment
        if let equipmentData = UserDefaults.standard.data(forKey: ownedEquipmentKey),
           let equipmentArray = try? JSONDecoder().decode([String].self, from: equipmentData) {
            ownedEquipmentIds = Set(equipmentArray)
        }
    }

    // MARK: - Debug / Reset

    #if DEBUG
    func resetAllData() {
        allHeroes = []
        currentHero = nil
        ownedEquipmentIds = []
        pendingEvolution = nil
        showEvolutionCelebration = false

        UserDefaults.standard.removeObject(forKey: heroesKey)
        UserDefaults.standard.removeObject(forKey: currentHeroIdKey)
        UserDefaults.standard.removeObject(forKey: ownedEquipmentKey)
    }
    #endif
}

// MARK: - Convenience Extensions

extension FocusHeroManager {
    /// Whether user has created a hero yet
    var hasHero: Bool {
        currentHero != nil
    }

    /// Quick access to hero's current tier
    var currentTier: EvolutionTier? {
        currentHero?.evolutionTier
    }

    /// Quick access to hero's class
    var currentClass: HeroClass? {
        currentHero?.heroClass
    }
}
