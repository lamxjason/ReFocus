import Foundation

// MARK: - Partnership Model

/// Represents a partnership between a user and their accountability partner
struct AccountabilityPartnership: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var userId: UUID
    var partnerUserId: UUID
    var status: PartnershipStatus
    var inviteCode: String?
    var inviteExpiresAt: Date?
    var createdAt: Date
    var acceptedAt: Date?
    var revokedAt: Date?

    enum PartnershipStatus: String, Codable, Sendable {
        case pending
        case active
        case revoked
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case partnerUserId = "partner_user_id"
        case status
        case inviteCode = "invite_code"
        case inviteExpiresAt = "invite_expires_at"
        case createdAt = "created_at"
        case acceptedAt = "accepted_at"
        case revokedAt = "revoked_at"
    }

    var isActive: Bool { status == .active }
    var isPending: Bool { status == .pending }

    var isInviteExpired: Bool {
        guard let expiresAt = inviteExpiresAt else { return false }
        return Date() > expiresAt
    }
}

// MARK: - Config Model

/// Per-user accountability configuration
struct AccountabilityConfig: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var userId: UUID
    var isEnabled: Bool
    var requiredApprovals: Int
    var requestTimeoutMinutes: Int
    var cooldownMinutes: Int
    var allowProximityUnlock: Bool
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case isEnabled = "is_enabled"
        case requiredApprovals = "required_approvals"
        case requestTimeoutMinutes = "request_timeout_minutes"
        case cooldownMinutes = "cooldown_minutes"
        case allowProximityUnlock = "allow_proximity_unlock"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static func defaultConfig(for userId: UUID) -> AccountabilityConfig {
        AccountabilityConfig(
            id: UUID(),
            userId: userId,
            isEnabled: false,
            requiredApprovals: 1,
            requestTimeoutMinutes: 10,
            cooldownMinutes: 5,
            allowProximityUnlock: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    var requestTimeout: TimeInterval {
        TimeInterval(requestTimeoutMinutes * 60)
    }

    var cooldown: TimeInterval {
        TimeInterval(cooldownMinutes * 60)
    }
}

// MARK: - Partner Display Info

/// Simplified partner info for display (joined with user profile)
struct PartnerInfo: Identifiable, Equatable, Sendable {
    let id: UUID
    let partnershipId: UUID
    let userId: UUID
    let displayName: String?
    let email: String?
    let status: AccountabilityPartnership.PartnershipStatus
    let acceptedAt: Date?

    var displayNameOrEmail: String {
        displayName ?? email ?? "Partner"
    }
}

// MARK: - Invite

/// Invite code for sharing with potential partners
struct AccountabilityInvite: Sendable {
    let code: String
    let expiresAt: Date
    let shareURL: URL?

    var isExpired: Bool {
        Date() > expiresAt
    }

    var formattedCode: String {
        // Format as XXXX-XXXX for readability
        guard code.count == 8 else { return code }
        return "\(code.prefix(4))-\(code.suffix(4))"
    }

    static func createShareURL(code: String) -> URL? {
        // Universal link format: https://refocus.app/invite/CODE
        URL(string: "https://refocus.app/invite/\(code)")
    }
}
