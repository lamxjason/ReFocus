import Foundation
import SwiftUI
#if os(iOS)
import FamilyControls
#endif

/// A saved focus mode with duration and block settings
struct FocusMode: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var icon: String // SF Symbol name
    var color: String // Hex color (legacy, kept for backward compatibility)
    var themeGradient: ThemeGradient? // New gradient system
    var duration: TimeInterval // in seconds
    var isStrictMode: Bool
    var createdAt: Date
    var lastUsedAt: Date?

    // App selection is device-specific and stored separately
    #if os(iOS)
    var appSelectionData: Data? // Encoded FamilyActivitySelection
    #endif

    // Website domains to block (synced)
    var websiteDomains: [String]

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "timer",
        color: String = "8B5CF6",
        themeGradient: ThemeGradient? = nil,
        duration: TimeInterval = 25 * 60,
        isStrictMode: Bool = false,
        websiteDomains: [String] = []
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.themeGradient = themeGradient
        self.duration = duration
        self.isStrictMode = isStrictMode
        self.websiteDomains = websiteDomains
        self.createdAt = Date()
        #if os(iOS)
        self.appSelectionData = nil
        #endif
    }

    /// Get the effective gradient (falls back to color-based gradient if themeGradient not set)
    var effectiveGradient: ThemeGradient {
        if let gradient = themeGradient {
            return gradient
        }
        // Map legacy hex colors to gradients
        return ThemeGradient.from(hex: color)
    }

    /// Primary color for the mode
    var primaryColor: Color {
        Color(hex: effectiveGradient.primaryHex)
    }

    /// Rich gradient for backgrounds
    var gradient: LinearGradient {
        effectiveGradient.gradient
    }

    /// Subtle gradient for cards
    var cardGradient: LinearGradient {
        effectiveGradient.cardGradient
    }

    /// Create a duplicate of this mode with a new ID and modified name
    func duplicate() -> FocusMode {
        var copy = self
        copy.id = UUID()
        copy.name = "\(name) Copy"
        copy.createdAt = Date()
        copy.lastUsedAt = nil
        return copy
    }

    var durationFormatted: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    #if os(iOS)
    var appSelection: FamilyActivitySelection? {
        guard let data = appSelectionData else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    mutating func setAppSelection(_ selection: FamilyActivitySelection) {
        appSelectionData = try? JSONEncoder().encode(selection)
    }
    #endif

    // Default modes
    static let defaults: [FocusMode] = [
        FocusMode(name: "Quick Focus", icon: "bolt.fill", color: "F59E0B", duration: 15 * 60),
        FocusMode(name: "Deep Work", icon: "brain.head.profile", color: "8B5CF6", duration: 90 * 60, isStrictMode: true),
        FocusMode(name: "Dream Session", icon: "moon.stars.fill", color: "06B6D4", duration: 45 * 60),
    ]
}

/// Available icons for focus modes
enum FocusModeIcon: String, CaseIterable {
    // Premium dream-focused icons
    case moonStars = "moon.stars.fill"
    case sparkles = "sparkles"
    case wand = "wand.and.stars"
    case target = "scope"
    case mountain = "mountain.2.fill"
    case sunrise = "sunrise.fill"

    // Activity icons
    case brain = "brain.head.profile"
    case bolt = "bolt.fill"
    case flame = "flame.fill"
    case book = "book.closed.fill"
    case briefcase = "briefcase.fill"
    case code = "chevron.left.forwardslash.chevron.right"

    var displayName: String {
        switch self {
        case .moonStars: return "Dreams"
        case .sparkles: return "Magic"
        case .wand: return "Create"
        case .target: return "Focus"
        case .mountain: return "Goals"
        case .sunrise: return "New Day"
        case .brain: return "Deep"
        case .bolt: return "Quick"
        case .flame: return "Intense"
        case .book: return "Study"
        case .briefcase: return "Work"
        case .code: return "Code"
        }
    }
}

/// Rich gradient color presets for focus modes and schedules
enum ThemeGradient: String, CaseIterable, Codable {
    case violet = "violet"
    case indigo = "indigo"
    case ocean = "ocean"
    case teal = "teal"
    case emerald = "emerald"
    case amber = "amber"
    case sunset = "sunset"
    case rose = "rose"
    case slate = "slate"
    case aurora = "aurora"

    /// Primary color (used for solid fills)
    var primaryHex: String {
        switch self {
        case .violet: return "8B5CF6"
        case .indigo: return "6366F1"
        case .ocean: return "3B82F6"
        case .teal: return "14B8A6"
        case .emerald: return "10B981"
        case .amber: return "F59E0B"
        case .sunset: return "F97316"
        case .rose: return "F43F5E"
        case .slate: return "64748B"
        case .aurora: return "8B5CF6"
        }
    }

    /// Secondary color for gradient
    var secondaryHex: String {
        switch self {
        case .violet: return "A78BFA"
        case .indigo: return "818CF8"
        case .ocean: return "60A5FA"
        case .teal: return "5EEAD4"
        case .emerald: return "34D399"
        case .amber: return "FCD34D"
        case .sunset: return "FB923C"
        case .rose: return "FB7185"
        case .slate: return "94A3B8"
        case .aurora: return "22D3EE"
        }
    }

    /// Tertiary color for rich gradients
    var tertiaryHex: String {
        switch self {
        case .violet: return "C4B5FD"
        case .indigo: return "A5B4FC"
        case .ocean: return "93C5FD"
        case .teal: return "99F6E4"
        case .emerald: return "6EE7B7"
        case .amber: return "FDE68A"
        case .sunset: return "FDBA74"
        case .rose: return "FDA4AF"
        case .slate: return "CBD5E1"
        case .aurora: return "67E8F9"
        }
    }

    var displayName: String {
        switch self {
        case .violet: return "Violet"
        case .indigo: return "Indigo"
        case .ocean: return "Ocean"
        case .teal: return "Teal"
        case .emerald: return "Emerald"
        case .amber: return "Amber"
        case .sunset: return "Sunset"
        case .rose: return "Rose"
        case .slate: return "Slate"
        case .aurora: return "Aurora"
        }
    }

    /// Primary color
    var primaryColor: Color {
        Color(hex: primaryHex)
    }

    /// Rich gradient for backgrounds
    var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: primaryHex),
                Color(hex: secondaryHex).opacity(0.8),
                Color(hex: tertiaryHex).opacity(0.6)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Subtle gradient for cards
    var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: primaryHex).opacity(0.3),
                Color(hex: secondaryHex).opacity(0.15),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Map a hex color to the closest ThemeGradient
    static func from(hex: String) -> ThemeGradient {
        let upperHex = hex.uppercased()
        switch upperHex {
        case "8B5CF6", "A78BFA", "C4B5FD": return .violet
        case "6366F1", "818CF8", "A5B4FC": return .indigo
        case "3B82F6", "60A5FA", "93C5FD": return .ocean
        case "14B8A6", "5EEAD4", "99F6E4", "06B6D4": return .teal
        case "10B981", "34D399", "6EE7B7": return .emerald
        case "F59E0B", "FCD34D", "FDE68A": return .amber
        case "F97316", "FB923C", "FDBA74": return .sunset
        case "F43F5E", "FB7185", "FDA4AF", "EF4444", "EC4899": return .rose
        case "64748B", "94A3B8", "CBD5E1": return .slate
        default: return .violet // Default fallback
        }
    }
}

/// Legacy color support - maps to ThemeGradient
enum FocusModeColor: String, CaseIterable {
    case purple = "8B5CF6"
    case blue = "3B82F6"
    case cyan = "06B6D4"
    case green = "10B981"
    case yellow = "F59E0B"
    case orange = "F97316"
    case red = "EF4444"
    case pink = "EC4899"

    var displayName: String {
        switch self {
        case .purple: return "Purple"
        case .blue: return "Blue"
        case .cyan: return "Cyan"
        case .green: return "Green"
        case .yellow: return "Yellow"
        case .orange: return "Orange"
        case .red: return "Red"
        case .pink: return "Pink"
        }
    }

    /// Convert to ThemeGradient
    var themeGradient: ThemeGradient {
        switch self {
        case .purple: return .violet
        case .blue: return .ocean
        case .cyan: return .teal
        case .green: return .emerald
        case .yellow: return .amber
        case .orange: return .sunset
        case .red: return .rose
        case .pink: return .rose
        }
    }
}
