import Foundation

/// Post-session review data
struct SessionReview: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var sessionId: UUID
    var reviewedAt: Date = Date()

    /// What the user worked on (brief description)
    var whatWorkedOn: String

    /// "Was it worth it?" rating (1-5)
    var worthItRating: Int

    /// Tags for categorization
    var tags: [String]

    /// Optional notes
    var notes: String?

    // MARK: - Computed Properties

    /// Whether this was considered a productive session (rating >= 4)
    var wasProductive: Bool {
        worthItRating >= 4
    }

    /// Rating as a descriptive string
    var ratingDescription: String {
        switch worthItRating {
        case 1: return "Not worth it"
        case 2: return "Barely worth it"
        case 3: return "Somewhat worth it"
        case 4: return "Worth it"
        case 5: return "Totally worth it"
        default: return "Unknown"
        }
    }
}

// MARK: - Predefined Tags

enum SessionTag: String, CaseIterable, Identifiable {
    case deepWork = "Deep Work"
    case meeting = "Meeting"
    case learning = "Learning"
    case creative = "Creative"
    case admin = "Admin"
    case communication = "Communication"
    case planning = "Planning"
    case coding = "Coding"
    case writing = "Writing"
    case research = "Research"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .deepWork: return "brain.head.profile"
        case .meeting: return "person.2"
        case .learning: return "book"
        case .creative: return "paintbrush"
        case .admin: return "folder"
        case .communication: return "envelope"
        case .planning: return "list.bullet.clipboard"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .writing: return "pencil"
        case .research: return "magnifyingglass"
        }
    }
}

// MARK: - Haptic Milestone

/// Milestone during a focus session that triggers haptic feedback
enum HapticMilestone: Int, CaseIterable, Identifiable {
    case quarterComplete = 25
    case halfComplete = 50
    case threeQuartersComplete = 75
    case complete = 100

    var id: Int { rawValue }

    var progressThreshold: Double {
        Double(rawValue) / 100.0
    }

    var message: String {
        switch self {
        case .quarterComplete: return "25% complete"
        case .halfComplete: return "Halfway there!"
        case .threeQuartersComplete: return "Almost there"
        case .complete: return "Session complete!"
        }
    }

    var feedbackIntensity: HapticIntensity {
        switch self {
        case .quarterComplete: return .light
        case .halfComplete: return .medium
        case .threeQuartersComplete: return .medium
        case .complete: return .success
        }
    }
}

enum HapticIntensity {
    case light
    case medium
    case success
}

// MARK: - Deep Work Companion Config

struct DeepWorkCompanionConfig: Codable, Equatable {
    var isEnabled: Bool = false
    var hapticsEnabled: Bool = true
    var reviewPromptEnabled: Bool = true
    var ambientModeEnabled: Bool = false

    /// Milestones to trigger haptics
    var enabledMilestones: Set<Int> = [25, 50, 75, 100]

    /// Favorite tags (shown first in picker)
    var favoriteTags: [String] = []
}
