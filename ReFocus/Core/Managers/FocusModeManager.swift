import Foundation
import SwiftUI

/// Manages saved focus modes (presets)
@MainActor
final class FocusModeManager: ObservableObject {
    static let shared = FocusModeManager()

    // MARK: - Published State

    @Published var modes: [FocusMode] = []
    @Published var selectedModeId: UUID?

    // MARK: - Storage Keys

    private let modesKey = "savedFocusModes"
    private let selectedModeKey = "selectedFocusModeId"

    // MARK: - Init

    private init() {
        loadModes()
    }

    // MARK: - Computed

    var selectedMode: FocusMode? {
        guard let id = selectedModeId else { return modes.first }
        return modes.first { $0.id == id }
    }

    // MARK: - Mode Management

    func addMode(_ mode: FocusMode) {
        modes.append(mode)
        saveModes()

        // Sync to server
        Task {
            try? await FocusModeSyncManager.shared.pushMode(mode)
        }
    }

    func updateMode(_ mode: FocusMode) {
        if let index = modes.firstIndex(where: { $0.id == mode.id }) {
            modes[index] = mode
            saveModes()

            // Sync to server
            Task {
                try? await FocusModeSyncManager.shared.updateMode(mode)
            }
        }
    }

    func deleteMode(_ mode: FocusMode) {
        modes.removeAll { $0.id == mode.id }
        if selectedModeId == mode.id {
            selectedModeId = nil
        }
        saveModes()

        // Sync to server
        Task {
            try? await FocusModeSyncManager.shared.deleteMode(mode)
        }
    }

    func selectMode(_ mode: FocusMode?) {
        selectedModeId = mode?.id
        UserDefaults.standard.set(selectedModeId?.uuidString, forKey: selectedModeKey)

        // Update last used
        if var mode = mode, let index = modes.firstIndex(where: { $0.id == mode.id }) {
            mode.lastUsedAt = Date()
            modes[index] = mode
            saveModes()
        }
    }

    func duplicateMode(_ mode: FocusMode) {
        var newMode = mode
        newMode.id = UUID()
        newMode.name = "\(mode.name) Copy"
        newMode.createdAt = Date()
        newMode.lastUsedAt = nil
        modes.append(newMode)
        saveModes()
    }

    // MARK: - Persistence

    private func saveModes() {
        do {
            let data = try JSONEncoder().encode(modes)
            UserDefaults.standard.set(data, forKey: modesKey)
        } catch {
            print("Failed to save focus modes: \(error)")
        }
    }

    private func loadModes() {
        // Load saved modes
        if let data = UserDefaults.standard.data(forKey: modesKey),
           let savedModes = try? JSONDecoder().decode([FocusMode].self, from: data) {
            modes = savedModes
        }

        // Add default modes if none exist
        if modes.isEmpty {
            modes = FocusMode.defaults
            saveModes()
        } else {
            // Migrate existing modes to add themeGradient if missing
            migrateModesWithGradients()
        }

        // Load selected mode
        if let idString = UserDefaults.standard.string(forKey: selectedModeKey),
           let id = UUID(uuidString: idString) {
            selectedModeId = id
        }
    }

    /// Migrate existing modes to use the new themeGradient system
    private func migrateModesWithGradients() {
        var needsSave = false

        for index in modes.indices {
            // Only migrate if themeGradient is nil
            guard modes[index].themeGradient == nil else { continue }

            // Map known default modes by name to their proper gradients
            let gradient: ThemeGradient?
            switch modes[index].name {
            case "Quick Focus":
                gradient = .amber
            case "Deep Work":
                gradient = .violet
            case "Dream Session":
                gradient = .teal
            default:
                // For custom modes, derive gradient from color
                gradient = ThemeGradient.from(hex: modes[index].color)
            }

            modes[index].themeGradient = gradient
            needsSave = true
        }

        if needsSave {
            saveModes()
        }
    }

    // MARK: - Quick Create

    func createMode(
        name: String,
        icon: String = "timer",
        color: String = "8B5CF6",
        duration: TimeInterval,
        isStrictMode: Bool = false
    ) -> FocusMode {
        let mode = FocusMode(
            name: name,
            icon: icon,
            color: color,
            duration: duration,
            isStrictMode: isStrictMode
        )
        addMode(mode)
        return mode
    }
}
