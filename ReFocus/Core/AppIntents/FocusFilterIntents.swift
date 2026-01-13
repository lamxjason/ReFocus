#if os(iOS)
import AppIntents

/// Focus Filter that activates when a system Focus mode is enabled
/// Users can configure this in Settings > Focus > [Focus Mode] > Focus Filters
@available(iOS 16.0, *)
struct ReFocusFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "ReFocus Session"
    static let description: IntentDescription = IntentDescription(
        "Automatically start a focus session when this Focus mode is active",
        categoryName: "Focus"
    )

    // Configuration parameters users can set
    @Parameter(title: "Session Duration", default: 25)
    var sessionDuration: Int

    @Parameter(title: "Focus Mode", optionsProvider: FocusModeOptionsProvider())
    var focusModeId: String?

    @Parameter(title: "Auto-start Session", default: true)
    var autoStartSession: Bool

    /// Display configuration for the Focus Filter card
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "ReFocus",
            subtitle: autoStartSession ? "\(sessionDuration) min session" : "Blocking only",
            image: .init(systemName: "brain.head.profile")
        )
    }

    /// Called when the Focus mode is enabled
    func perform() async throws -> some IntentResult {
        if autoStartSession {
            await MainActor.run {
                Task {
                    // Get the focus mode if specified
                    let modeName: String?
                    let modeIcon: String?

                    if let modeId = focusModeId,
                       let mode = FocusModeManager.shared.modes.first(where: { $0.id.uuidString == modeId }) {
                        modeName = mode.name
                        modeIcon = mode.icon
                    } else {
                        modeName = nil
                        modeIcon = nil
                    }

                    try? await TimerSyncManager.shared.startTimer(
                        durationMinutes: sessionDuration,
                        modeName: modeName,
                        modeIcon: modeIcon
                    )
                }
            }
        } else {
            // Just activate blocking without a timer
            await MainActor.run {
                BlockEnforcementManager.shared.startEnforcement()
            }
        }

        return .result()
    }
}

/// Provides options for selecting a Focus Mode
@available(iOS 16.0, *)
struct FocusModeOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [String] {
        await MainActor.run {
            FocusModeManager.shared.modes.map { $0.id.uuidString }
        }
    }

    func defaultResult() async -> String? {
        await MainActor.run {
            FocusModeManager.shared.selectedMode?.id.uuidString
        }
    }
}

/// Entity for Focus Mode selection
@available(iOS 16.0, *)
struct FocusModeEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Focus Mode"
    static let defaultQuery = FocusModeQuery()

    var id: String
    var name: String
    var icon: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            image: .init(systemName: icon)
        )
    }
}

@available(iOS 16.0, *)
struct FocusModeQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [FocusModeEntity] {
        await MainActor.run {
            FocusModeManager.shared.modes
                .filter { identifiers.contains($0.id.uuidString) }
                .map { FocusModeEntity(id: $0.id.uuidString, name: $0.name, icon: $0.icon) }
        }
    }

    func suggestedEntities() async throws -> [FocusModeEntity] {
        await MainActor.run {
            FocusModeManager.shared.modes
                .map { FocusModeEntity(id: $0.id.uuidString, name: $0.name, icon: $0.icon) }
        }
    }

    func defaultResult() async -> FocusModeEntity? {
        await MainActor.run {
            guard let mode = FocusModeManager.shared.selectedMode else { return nil }
            return FocusModeEntity(id: mode.id.uuidString, name: mode.name, icon: mode.icon)
        }
    }
}
#endif
