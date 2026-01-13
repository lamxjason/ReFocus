import Foundation
#if os(iOS)
import UIKit
import Intents
#endif

/// Manages integration with iOS system Focus modes
@MainActor
final class SystemFocusManager: ObservableObject {
    static let shared = SystemFocusManager()

    /// Whether the user has any system Focus mode active
    @Published private(set) var isSystemFocusActive: Bool = false

    /// The name of the current system Focus (if available)
    @Published private(set) var currentFocusName: String?

    private init() {
        #if os(iOS)
        startMonitoring()
        #endif
    }

    // MARK: - Focus State Monitoring

    #if os(iOS)
    private func startMonitoring() {
        // Monitor for Focus state changes using Notification Center
        // iOS 15+ posts notifications when Focus state changes
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkFocusState()
            }
        }

        // Initial check
        checkFocusState()
    }

    private func checkFocusState() {
        // Check Focus status via INFocusStatusCenter (iOS 15+)
        if #available(iOS 15.0, *) {
            let focusCenter = INFocusStatusCenter.default
            focusCenter.requestAuthorization { status in
                Task { @MainActor in
                    if status == .authorized {
                        let isFocused = focusCenter.focusStatus.isFocused ?? false
                        self.isSystemFocusActive = isFocused
                        // Focus name is not directly available via public API
                        self.currentFocusName = isFocused ? "Focus" : nil
                    }
                }
            }
        }
    }
    #endif

    // MARK: - Integration Helpers

    /// Check if ReFocus should auto-block based on system Focus
    var shouldAutoBlock: Bool {
        isSystemFocusActive && UserDefaults.standard.bool(forKey: "syncWithSystemFocus")
    }

    /// Enable/disable sync with system Focus
    func setSyncWithSystemFocus(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "syncWithSystemFocus")
    }

    /// Check if sync with system Focus is enabled
    var isSyncWithSystemFocusEnabled: Bool {
        UserDefaults.standard.bool(forKey: "syncWithSystemFocus")
    }
}
