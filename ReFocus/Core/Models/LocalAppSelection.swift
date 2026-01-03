import Foundation

#if os(iOS)
import FamilyControls

/// Device-local app selection using FamilyControls (never synced between devices)
/// ApplicationTokens and CategoryTokens are opaque and device-specific
struct LocalAppSelection: Codable {
    var selection: FamilyActivitySelection
    var lastModified: Date

    /// Number of selected apps
    var appCount: Int {
        selection.applicationTokens.count
    }

    /// Number of selected categories
    var categoryCount: Int {
        selection.categoryTokens.count
    }

    /// Number of selected website domains
    var websiteCount: Int {
        selection.webDomainTokens.count
    }

    /// Total number of blocked items
    var totalCount: Int {
        appCount + categoryCount + websiteCount
    }

    /// Whether any items are selected
    var hasSelections: Bool {
        !selection.applicationTokens.isEmpty ||
        !selection.categoryTokens.isEmpty ||
        !selection.webDomainTokens.isEmpty
    }

    /// Empty selection
    static var empty: LocalAppSelection {
        LocalAppSelection(selection: FamilyActivitySelection(), lastModified: Date())
    }

    // MARK: - Persistence

    private static let storageKey = "localAppSelection"

    /// Saves the selection to UserDefaults
    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    /// Loads the selection from UserDefaults
    static func load() -> LocalAppSelection {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let selection = try? JSONDecoder().decode(LocalAppSelection.self, from: data) else {
            return .empty
        }
        return selection
    }

    /// Clears the saved selection
    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
#endif
