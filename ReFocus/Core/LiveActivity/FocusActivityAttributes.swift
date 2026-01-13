import Foundation

#if os(iOS)
import ActivityKit

/// Live Activity attributes for focus sessions
@available(iOS 16.1, *)
struct FocusActivityAttributes: ActivityAttributes {
    /// Static content that doesn't change during the activity
    public struct ContentState: Codable, Hashable {
        /// Remaining time in seconds
        var remainingSeconds: Int
        /// Whether the session is paused
        var isPaused: Bool
        /// Current focus mode name
        var modeName: String
        /// End time for timer display
        var endTime: Date
    }

    /// Static data set when activity starts
    let sessionId: UUID
    let totalDurationMinutes: Int
    let focusModeIcon: String
}
#endif
