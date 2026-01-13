import Foundation

// MARK: - Unlock Request Model

/// Request from user to unlock blocked apps, requiring partner approval
struct UnlockRequest: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var userId: UUID
    var status: RequestStatus
    var requiredApprovals: Int
    var receivedApprovals: Int
    var requestReason: String?
    var createdAt: Date
    var expiresAt: Date
    var resolvedAt: Date?
    var requestingDeviceId: String

    enum RequestStatus: String, Codable, Sendable {
        case pending
        case approved
        case expired
        case cancelled
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case status
        case requiredApprovals = "required_approvals"
        case receivedApprovals = "received_approvals"
        case requestReason = "request_reason"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case resolvedAt = "resolved_at"
        case requestingDeviceId = "requesting_device_id"
    }

    // MARK: - Computed Properties

    var isApproved: Bool {
        status == .approved || receivedApprovals >= requiredApprovals
    }

    var isPending: Bool {
        status == .pending && !hasExpired
    }

    var hasExpired: Bool {
        Date() > expiresAt
    }

    var remainingTime: TimeInterval {
        max(0, expiresAt.timeIntervalSinceNow)
    }

    var remainingApprovals: Int {
        max(0, requiredApprovals - receivedApprovals)
    }

    var progressFraction: Double {
        guard requiredApprovals > 0 else { return 1.0 }
        return Double(receivedApprovals) / Double(requiredApprovals)
    }

    // MARK: - Factory

    static func create(
        userId: UUID,
        requiredApprovals: Int,
        timeoutMinutes: Int,
        reason: String?,
        deviceId: String
    ) -> UnlockRequest {
        UnlockRequest(
            id: UUID(),
            userId: userId,
            status: .pending,
            requiredApprovals: requiredApprovals,
            receivedApprovals: 0,
            requestReason: reason,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(TimeInterval(timeoutMinutes * 60)),
            resolvedAt: nil,
            requestingDeviceId: deviceId
        )
    }
}

// MARK: - Unlock Approval Model

/// Partner's approval of an unlock request
struct UnlockApproval: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var requestId: UUID
    var partnerUserId: UUID
    var approvalMethod: ApprovalMethod
    var approvedAt: Date
    var approvingDeviceId: String?

    enum ApprovalMethod: String, Codable, Sendable {
        case notification
        case proximity
    }

    enum CodingKeys: String, CodingKey {
        case id
        case requestId = "request_id"
        case partnerUserId = "partner_user_id"
        case approvalMethod = "approval_method"
        case approvedAt = "approved_at"
        case approvingDeviceId = "approving_device_id"
    }

    static func create(
        requestId: UUID,
        partnerUserId: UUID,
        method: ApprovalMethod,
        deviceId: String?
    ) -> UnlockApproval {
        UnlockApproval(
            id: UUID(),
            requestId: requestId,
            partnerUserId: partnerUserId,
            approvalMethod: method,
            approvedAt: Date(),
            approvingDeviceId: deviceId
        )
    }
}

// MARK: - Push Token Model

/// Device push notification token for APNs
struct DevicePushToken: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var userId: UUID
    var deviceId: String
    var pushToken: String
    var platform: Platform
    var createdAt: Date
    var updatedAt: Date

    enum Platform: String, Codable, Sendable {
        case ios
        case macos
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case deviceId = "device_id"
        case pushToken = "push_token"
        case platform
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Request for Partner View

/// Unlock request as seen by an accountability partner
struct PendingApprovalRequest: Identifiable, Sendable {
    let id: UUID
    let request: UnlockRequest
    let requesterName: String?
    let requesterEmail: String?

    var displayName: String {
        requesterName ?? requesterEmail ?? "Your Partner"
    }

    var reason: String {
        request.requestReason ?? "No reason provided"
    }

    var remainingTime: TimeInterval {
        request.remainingTime
    }

    var formattedRemainingTime: String {
        let minutes = Int(remainingTime / 60)
        let seconds = Int(remainingTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
