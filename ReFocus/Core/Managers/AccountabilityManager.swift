import Foundation
import Supabase
import Combine
#if canImport(UIKit)
import UIKit
#endif

/// Manages Accountability Partner feature
/// Responsibilities:
/// - Partner relationships (invite, accept, revoke)
/// - Unlock request lifecycle
/// - Config management
/// - Cross-device sync coordination
@MainActor
final class AccountabilityManager: ObservableObject {
    static let shared = AccountabilityManager()

    // MARK: - Dependencies

    private var supabase: SupabaseManager { .shared }

    // MARK: - Published State

    @Published private(set) var config: AccountabilityConfig?
    @Published private(set) var partnerships: [AccountabilityPartnership] = []
    @Published private(set) var activeRequest: UnlockRequest?
    @Published private(set) var pendingRequestsToApprove: [UnlockRequest] = []
    @Published private(set) var lastRequestTime: Date?
    @Published private(set) var syncError: Error?
    @Published private(set) var isConnected: Bool = false

    // MARK: - Callbacks for Enforcement

    var onAccountabilityActivated: (() -> Void)?
    var onAccountabilityDeactivated: (() -> Void)?
    var onUnlockApproved: ((UnlockRequest) -> Void)?

    // MARK: - Private

    private var realtimeChannel: Any?
    private var approvalsChannel: Any?
    private let configKey = "accountabilityConfig"
    private let lastRequestKey = "lastUnlockRequestTime"

    // MARK: - Computed Properties

    var activePartners: [AccountabilityPartnership] {
        partnerships.filter { $0.status == .active }
    }

    var pendingInvites: [AccountabilityPartnership] {
        partnerships.filter { $0.status == .pending && !$0.isInviteExpired }
    }

    var isAccountabilityEnabled: Bool {
        guard let config = config else { return false }
        return config.isEnabled && !activePartners.isEmpty
    }

    var canRequestUnlock: Bool {
        guard isAccountabilityEnabled else { return false }
        guard activeRequest == nil || activeRequest?.isPending == false else { return false }
        return cooldownRemaining == nil
    }

    var cooldownRemaining: TimeInterval? {
        guard let lastTime = lastRequestTime,
              let cooldown = config?.cooldown else { return nil }
        let elapsed = Date().timeIntervalSince(lastTime)
        return elapsed < cooldown ? cooldown - elapsed : nil
    }

    // MARK: - Init

    private init() {
        loadLocalState()
    }

    private func loadLocalState() {
        if let data = UserDefaults.standard.data(forKey: configKey),
           let cached = try? JSONDecoder().decode(AccountabilityConfig.self, from: data) {
            config = cached
        }
        lastRequestTime = UserDefaults.standard.object(forKey: lastRequestKey) as? Date
    }

    private func saveLocalConfig() {
        guard let config = config else { return }
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }

    // MARK: - Sync Methods

    func subscribe() async throws {
        guard supabase.isAuthenticated else { return }
        let userId = try supabase.requireUserId()

        await fetchConfig(userId: userId)
        await fetchPartnerships(userId: userId)
        await fetchActiveRequest(userId: userId)
        await fetchPendingApprovals(userId: userId)
        await setupRealtimeSubscriptions(userId: userId)

        isConnected = true
    }

    func unsubscribe() async {
        realtimeChannel = nil
        approvalsChannel = nil
        isConnected = false
    }

    private func fetchConfig(userId: UUID) async {
        do {
            let response: [AccountabilityConfig] = try await supabase.client
                .from("accountability_config")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            if let serverConfig = response.first {
                config = serverConfig
                saveLocalConfig()
            } else {
                config = AccountabilityConfig.defaultConfig(for: userId)
            }
        } catch {
            syncError = error
        }
    }

    private func fetchPartnerships(userId: UUID) async {
        do {
            let response: [AccountabilityPartnership] = try await supabase.client
                .from("accountability_partnerships")
                .select()
                .or("user_id.eq.\(userId.uuidString),partner_user_id.eq.\(userId.uuidString)")
                .execute()
                .value

            partnerships = response
        } catch {
            syncError = error
        }
    }

    private func fetchActiveRequest(userId: UUID) async {
        do {
            let response: [UnlockRequest] = try await supabase.client
                .from("unlock_requests")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value

            activeRequest = response.first
        } catch {
            syncError = error
        }
    }

    private func fetchPendingApprovals(userId: UUID) async {
        do {
            let partnerUserIds = partnerships
                .filter { $0.status == .active && $0.partnerUserId == userId }
                .map { $0.userId.uuidString }

            guard !partnerUserIds.isEmpty else {
                pendingRequestsToApprove = []
                return
            }

            let response: [UnlockRequest] = try await supabase.client
                .from("unlock_requests")
                .select()
                .in("user_id", values: partnerUserIds)
                .eq("status", value: "pending")
                .execute()
                .value

            pendingRequestsToApprove = response.filter { !$0.hasExpired }
        } catch {
            syncError = error
        }
    }

    private func setupRealtimeSubscriptions(userId: UUID) async {
        let channel = supabase.client.realtimeV2.channel("accountability-\(userId.uuidString)")

        let requestChanges = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "unlock_requests"
        )

        let approvalChanges = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "unlock_approvals"
        )

        await channel.subscribe()

        Task {
            for await change in requestChanges {
                await handleRequestChange(change, userId: userId)
            }
        }

        Task {
            for await change in approvalChanges {
                await handleApprovalChange(change, userId: userId)
            }
        }

        realtimeChannel = channel
    }

    private func handleRequestChange(_ change: AnyAction, userId: UUID) async {
        switch change {
        case .update(let action):
            if let request = try? action.decodeRecord(as: UnlockRequest.self, decoder: JSONDecoder()) {
                if request.userId == userId {
                    activeRequest = request
                    if request.isApproved {
                        onUnlockApproved?(request)
                        onAccountabilityDeactivated?()
                    }
                } else {
                    await fetchPendingApprovals(userId: userId)
                }
            }
        case .insert(let action):
            if let request = try? action.decodeRecord(as: UnlockRequest.self, decoder: JSONDecoder()) {
                if request.userId != userId {
                    pendingRequestsToApprove.append(request)
                }
            }
        case .delete:
            await fetchPendingApprovals(userId: userId)
        default:
            break
        }
    }

    private func handleApprovalChange(_ change: AnyAction, userId: UUID) async {
        await fetchActiveRequest(userId: userId)
    }

    // MARK: - Config Management

    func updateConfig(_ newConfig: AccountabilityConfig) async throws {
        guard supabase.isAuthenticated else { return }

        try await supabase.client
            .from("accountability_config")
            .upsert(newConfig, onConflict: "user_id")
            .execute()

        config = newConfig
        saveLocalConfig()

        if newConfig.isEnabled && !activePartners.isEmpty {
            onAccountabilityActivated?()
        } else {
            onAccountabilityDeactivated?()
        }
    }

    func setEnabled(_ enabled: Bool) async throws {
        guard var currentConfig = config else { return }
        currentConfig.isEnabled = enabled
        try await updateConfig(currentConfig)
    }

    func setRequiredApprovals(_ count: Int) async throws {
        guard var currentConfig = config else { return }
        currentConfig.requiredApprovals = max(1, count)
        try await updateConfig(currentConfig)
    }

    // MARK: - Partnership Management

    func createInvite() async throws -> AccountabilityInvite {
        let userId = try supabase.requireUserId()
        let code = generateInviteCode()
        let expiresAt = Date().addingTimeInterval(48 * 60 * 60)

        let partnership = AccountabilityPartnership(
            id: UUID(),
            userId: userId,
            partnerUserId: userId,
            status: .pending,
            inviteCode: code,
            inviteExpiresAt: expiresAt,
            createdAt: Date(),
            acceptedAt: nil,
            revokedAt: nil
        )

        try await supabase.client
            .from("accountability_partnerships")
            .insert(partnership)
            .execute()

        partnerships.append(partnership)

        return AccountabilityInvite(
            code: code,
            expiresAt: expiresAt,
            shareURL: AccountabilityInvite.createShareURL(code: code)
        )
    }

    func acceptInvite(code: String) async throws {
        let userId = try supabase.requireUserId()
        let normalizedCode = code.replacingOccurrences(of: "-", with: "").uppercased()

        let response: [AccountabilityPartnership] = try await supabase.client
            .from("accountability_partnerships")
            .select()
            .eq("invite_code", value: normalizedCode)
            .eq("status", value: "pending")
            .execute()
            .value

        guard var invite = response.first else {
            throw AccountabilityError.inviteNotFound
        }

        guard !invite.isInviteExpired else {
            throw AccountabilityError.inviteExpired
        }

        guard invite.userId != userId else {
            throw AccountabilityError.cannotPartnerWithSelf
        }

        invite.partnerUserId = userId
        invite.status = .active
        invite.acceptedAt = Date()
        invite.inviteCode = nil

        try await supabase.client
            .from("accountability_partnerships")
            .update(invite)
            .eq("id", value: invite.id.uuidString)
            .execute()

        partnerships.append(invite)
    }

    func revokePartnership(_ partnershipId: UUID) async throws {
        guard let index = partnerships.firstIndex(where: { $0.id == partnershipId }) else {
            return
        }

        var partnership = partnerships[index]
        partnership.status = .revoked
        partnership.revokedAt = Date()

        try await supabase.client
            .from("accountability_partnerships")
            .update(partnership)
            .eq("id", value: partnershipId.uuidString)
            .execute()

        partnerships.remove(at: index)

        if activePartners.isEmpty {
            onAccountabilityDeactivated?()
        }
    }

    // MARK: - Unlock Requests

    func createUnlockRequest(reason: String?) async throws -> UnlockRequest {
        guard canRequestUnlock else {
            if cooldownRemaining != nil {
                throw AccountabilityError.cooldownActive
            }
            throw AccountabilityError.requestAlreadyPending
        }

        let userId = try supabase.requireUserId()
        guard let config = config else {
            throw AccountabilityError.notConfigured
        }

        let request = UnlockRequest.create(
            userId: userId,
            requiredApprovals: config.requiredApprovals,
            timeoutMinutes: config.requestTimeoutMinutes,
            reason: reason,
            deviceId: Self.currentDeviceId
        )

        try await supabase.client
            .from("unlock_requests")
            .insert(request)
            .execute()

        activeRequest = request
        lastRequestTime = Date()
        UserDefaults.standard.set(lastRequestTime, forKey: lastRequestKey)

        return request
    }

    func cancelRequest() async throws {
        guard var request = activeRequest, request.isPending else { return }

        request.status = .cancelled
        request.resolvedAt = Date()

        try await supabase.client
            .from("unlock_requests")
            .update(request)
            .eq("id", value: request.id.uuidString)
            .execute()

        activeRequest = nil
    }

    // MARK: - Partner Approval

    func approveRequest(_ requestId: UUID, method: UnlockApproval.ApprovalMethod) async throws {
        let userId = try supabase.requireUserId()

        let approval = UnlockApproval.create(
            requestId: requestId,
            partnerUserId: userId,
            method: method,
            deviceId: Self.currentDeviceId
        )

        try await supabase.client
            .from("unlock_approvals")
            .insert(approval)
            .execute()

        pendingRequestsToApprove.removeAll { $0.id == requestId }
    }

    // MARK: - Helpers

    private func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<8).map { _ in chars.randomElement()! })
    }

    private static var currentDeviceId: String {
        #if os(iOS)
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #elseif os(macOS)
        return Host.current().localizedName ?? UUID().uuidString
        #endif
    }
}

// MARK: - Errors

enum AccountabilityError: LocalizedError {
    case inviteNotFound
    case inviteExpired
    case cannotPartnerWithSelf
    case cooldownActive
    case requestAlreadyPending
    case notConfigured
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .inviteNotFound:
            return "Invite code not found or already used."
        case .inviteExpired:
            return "This invite has expired."
        case .cannotPartnerWithSelf:
            return "You cannot be your own accountability partner."
        case .cooldownActive:
            return "Please wait before requesting another unlock."
        case .requestAlreadyPending:
            return "You already have a pending unlock request."
        case .notConfigured:
            return "Accountability is not configured."
        case .notAuthenticated:
            return "Please sign in to use accountability partners."
        }
    }
}
