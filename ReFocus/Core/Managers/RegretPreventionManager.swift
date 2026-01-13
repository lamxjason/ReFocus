import Foundation
import SwiftUI
import Combine

/// Manages Regret Prevention Mode - auto-activates blocking during high-regret time windows
@MainActor
final class RegretPreventionManager: ObservableObject {
    static let shared = RegretPreventionManager()

    // MARK: - Published State

    @Published var config: RegretPreventionConfig {
        didSet { saveConfig() }
    }

    /// Currently active protection (nil if none)
    @Published var activeProtection: ActiveProtection?

    /// Post-session protection end time (if active)
    @Published var postSessionEndTime: Date?

    // MARK: - Private

    private let configKey = "regretPreventionConfig"
    private var checkTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Types

    struct ActiveProtection: Equatable {
        let window: RegretWindow
        let activatedAt: Date
        let reason: ProtectionReason

        enum ProtectionReason: Equatable {
            case timeWindow
            case postSession(endTime: Date)
        }

        var message: String {
            window.message
        }

        var icon: String {
            window.type.icon
        }

        var remainingTime: TimeInterval? {
            switch reason {
            case .timeWindow:
                return nil  // Time windows don't have remaining time
            case .postSession(let endTime):
                return max(0, endTime.timeIntervalSinceNow)
            }
        }
    }

    // MARK: - Init

    private init() {
        self.config = Self.loadConfig()
        setupPeriodicCheck()
    }

    // MARK: - Core Methods

    /// Check if protection should be active and update state
    func checkProtection() {
        guard config.isEnabled else {
            deactivateProtection()
            return
        }

        // Check post-session protection first (highest priority)
        if let endTime = postSessionEndTime {
            if Date() < endTime {
                if let window = config.postSessionWindow {
                    activateProtection(
                        window: window,
                        reason: .postSession(endTime: endTime)
                    )
                    return
                }
            } else {
                // Post-session window expired
                postSessionEndTime = nil
            }
        }

        // Check time-based windows
        if let activeWindow = config.activeTimeWindow() {
            activateProtection(window: activeWindow, reason: .timeWindow)
            return
        }

        // No active protection needed
        deactivateProtection()
    }

    /// Start post-session protection
    func startPostSessionProtection() {
        guard config.isEnabled,
              let window = config.postSessionWindow,
              let duration = window.durationMinutes
        else { return }

        postSessionEndTime = Date().addingTimeInterval(TimeInterval(duration * 60))
        checkProtection()
    }

    /// Cancel post-session protection early
    func cancelPostSessionProtection() {
        postSessionEndTime = nil
        checkProtection()
    }

    /// Request to bypass protection (returns whether bypass is allowed)
    func requestBypass() -> BypassResult {
        guard let protection = activeProtection else {
            return .allowed
        }

        switch protection.reason {
        case .timeWindow:
            // Time windows cannot be bypassed without explicit unlock
            return .blocked(message: protection.message)

        case .postSession(let endTime):
            let remaining = endTime.timeIntervalSinceNow
            if remaining > 0 {
                return .mustWait(remaining)
            } else {
                return .allowed
            }
        }
    }

    enum BypassResult: Equatable {
        case allowed
        case blocked(message: String)
        case mustWait(TimeInterval)
    }

    // MARK: - Protection Activation

    private func activateProtection(window: RegretWindow, reason: ActiveProtection.ProtectionReason) {
        let newProtection = ActiveProtection(
            window: window,
            activatedAt: Date(),
            reason: reason
        )

        // Only update if different to avoid unnecessary updates
        if activeProtection != newProtection {
            activeProtection = newProtection
            notifyBlockingActivated()
        }
    }

    private func deactivateProtection() {
        if activeProtection != nil {
            activeProtection = nil
            notifyBlockingDeactivated()
        }
    }

    private func notifyBlockingActivated() {
        BlockEnforcementManager.shared.activateRegretPrevention()
        print("[RegretPrevention] Protection activated: \(activeProtection?.window.name ?? "unknown")")
    }

    private func notifyBlockingDeactivated() {
        BlockEnforcementManager.shared.deactivateRegretPrevention()
        print("[RegretPrevention] Protection deactivated")
    }

    // MARK: - Periodic Check

    private func setupPeriodicCheck() {
        // Check every 30 seconds
        checkTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkProtection()
            }
        }

        // Initial check
        checkProtection()
    }

    /// Stop periodic checks (for testing)
    func stopPeriodicCheck() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    // MARK: - Computed Properties

    /// Whether any protection is currently active
    var isProtectionActive: Bool {
        activeProtection != nil
    }

    /// Get formatted remaining time for post-session protection
    var formattedPostSessionRemaining: String? {
        guard let remaining = activeProtection?.remainingTime, remaining > 0 else {
            return nil
        }

        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60

        if minutes > 0 {
            return "\(minutes)m \(seconds)s remaining"
        } else {
            return "\(seconds)s remaining"
        }
    }

    /// Message explaining current protection status
    var statusMessage: String {
        guard config.isEnabled else {
            return "Regret Prevention is disabled"
        }

        if let protection = activeProtection {
            return protection.message
        }

        // Check upcoming windows
        let enabledCount = config.enabledWindows.count
        if enabledCount > 0 {
            return "\(enabledCount) protection window\(enabledCount == 1 ? "" : "s") configured"
        }

        return "No protection windows configured"
    }

    // MARK: - Window Management

    /// Add a custom window
    func addCustomWindow(name: String, startTime: TimeComponents, endTime: TimeComponents, message: String? = nil) {
        let window = RegretWindow.custom(
            name: name,
            startTime: startTime,
            endTime: endTime,
            message: message
        )
        config.addWindow(window)
    }

    /// Toggle window enabled state
    func toggleWindow(id: UUID) {
        guard var window = config.windows.first(where: { $0.id == id }) else { return }
        window.isEnabled.toggle()
        config.updateWindow(window)
        checkProtection()
    }

    /// Remove a custom window (built-in windows can be disabled but not removed)
    func removeWindow(id: UUID) {
        guard let window = config.windows.first(where: { $0.id == id }),
              window.type == .custom
        else { return }

        config.removeWindow(id: id)
        checkProtection()
    }

    // MARK: - Persistence

    private static func loadConfig() -> RegretPreventionConfig {
        guard let data = UserDefaults.standard.data(forKey: "regretPreventionConfig"),
              let config = try? JSONDecoder().decode(RegretPreventionConfig.self, from: data)
        else {
            return RegretPreventionConfig()
        }
        return config
    }

    private func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }

    /// Reset to defaults
    func resetToDefaults() {
        config = RegretPreventionConfig()
        postSessionEndTime = nil
        checkProtection()
    }
}
