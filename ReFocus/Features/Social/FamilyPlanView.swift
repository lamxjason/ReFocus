import SwiftUI

struct FamilyPlanView: View {
    @StateObject private var familyManager = FamilyManager.shared
    @State private var showingCreateFamily = false
    @State private var showingJoinFamily = false
    @State private var joinCode = ""
    @State private var familyName = ""
    @State private var showingLockRequest = false
    @State private var selectedMemberForLock: FamilyMember?
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if familyManager.isLoading {
                    ProgressView()
                        .padding(.vertical, 60)
                } else if let group = familyManager.familyGroup {
                    // In a family - show dashboard
                    familyDashboard(group)
                } else {
                    // Not in family - show join/create options
                    notInFamilyView
                }
            }
            .padding()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Family Plan")
        .task {
            await familyManager.fetchFamilyGroup()
            // Subscribe to real-time updates once we have the family group
            if familyManager.isInFamily {
                await familyManager.subscribe()
            }
        }
        .onDisappear {
            Task {
                await familyManager.unsubscribe()
            }
        }
        .alert("Create Family", isPresented: $showingCreateFamily) {
            TextField("Family Name", text: $familyName)
            Button("Cancel", role: .cancel) { familyName = "" }
            Button("Create") { createFamily() }
        } message: {
            Text("Create a family group to share your subscription with up to 5 people")
        }
        .alert("Join Family", isPresented: $showingJoinFamily) {
            TextField("Invite Code", text: $joinCode)
            Button("Cancel", role: .cancel) { joinCode = "" }
            Button("Join") { joinFamily() }
        } message: {
            Text("Enter the invite code from your family owner")
        }
        .sheet(isPresented: $showingLockRequest) {
            if let member = selectedMemberForLock {
                LockRequestSheet(member: member)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
    }

    // MARK: - Not In Family View

    private var notInFamilyView: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(DesignSystem.Colors.accent)

                Text("Family Plan")
                    .font(.title.bold())

                Text("Share one subscription with up to 5 family members. Hold each other accountable and track progress together.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)

            // Benefits
            VStack(alignment: .leading, spacing: 16) {
                benefitRow(icon: "dollarsign.circle", title: "Save Money", description: "One subscription for the whole family")
                benefitRow(icon: "lock.shield", title: "Accountability Locks", description: "Family members can request focus locks for each other")
                benefitRow(icon: "chart.bar", title: "Shared Progress", description: "See everyone's streaks and achievements")
                benefitRow(icon: "bell.badge", title: "Activity Feed", description: "Celebrate wins together")
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.cardBackground)
            }

            // Actions
            VStack(spacing: 12) {
                Button {
                    showingCreateFamily = true
                } label: {
                    Text("Create Family")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DesignSystem.Colors.accent)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }

                Button {
                    showingJoinFamily = true
                } label: {
                    Text("Join with Code")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.cardBackground)
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .cornerRadius(12)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(DesignSystem.Colors.accent, lineWidth: 1)
                        }
                }
            }
        }
    }

    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Family Dashboard

    private func familyDashboard(_ group: FamilyGroup) -> some View {
        VStack(spacing: 24) {
            // Header card with invite code
            familyHeaderCard(group)

            // Pending lock requests
            if !familyManager.pendingLocks.isEmpty {
                pendingLocksSection
            }

            // Active locks
            if !familyManager.activeLocks.isEmpty {
                activeLocksSection
            }

            // Members
            membersSection(group)

            // Activity feed
            if !familyManager.activityFeed.isEmpty {
                activityFeedSection
            }

            // Leave button
            if !familyManager.isOwner {
                Button(role: .destructive) {
                    Task { @MainActor in
                        do {
                            try await familyManager.leaveFamily()
                        } catch {
                            errorMessage = error.localizedDescription
                            showingError = true
                        }
                    }
                } label: {
                    Text("Leave Family")
                        .font(.subheadline)
                }
                .padding(.top)
            }
        }
    }

    private func familyHeaderCard(_ group: FamilyGroup) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.title2.bold())
                    Text("\(group.memberCount)/5 members")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Invite code
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Invite Code")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(group.inviteCode)
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
            }

            // Copy invite code button
            Button {
                #if os(iOS)
                UIPasteboard.general.string = group.inviteCode
                #else
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(group.inviteCode, forType: .string)
                #endif
            } label: {
                Label("Copy Invite Code", systemImage: "doc.on.doc")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(DesignSystem.Colors.accent.opacity(0.15))
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.cardBackground)
        }
    }

    private var pendingLocksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Pending Requests", systemImage: "exclamationmark.circle")
                .font(.headline)
                .foregroundStyle(.orange)

            ForEach(familyManager.pendingLocks) { lock in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(lock.requesterName) wants you to focus")
                            .font(.subheadline.weight(.medium))
                        Text("\(lock.durationMinutes) minutes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let reason = lock.reason, !reason.isEmpty {
                            Text("\"\(reason)\"")
                                .font(.caption)
                                .italic()
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button {
                            Task { @MainActor in
                                do {
                                    try await familyManager.respondToLock(lock.id, approve: false)
                                } catch {
                                    errorMessage = error.localizedDescription
                                    showingError = true
                                }
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .padding(8)
                                .background(Color.red.opacity(0.2))
                                .clipShape(Circle())
                        }

                        Button {
                            Task { @MainActor in
                                do {
                                    try await familyManager.respondToLock(lock.id, approve: true)
                                } catch {
                                    errorMessage = error.localizedDescription
                                    showingError = true
                                }
                            }
                        } label: {
                            Image(systemName: "checkmark")
                                .padding(8)
                                .background(Color.green.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                }
            }
        }
    }

    private var activeLocksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Active Focus Lock", systemImage: "lock.fill")
                .font(.headline)
                .foregroundStyle(DesignSystem.Colors.accent)

            ForEach(familyManager.activeLocks) { lock in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Locked by \(lock.requesterName)")
                            .font(.subheadline.weight(.medium))
                        if let expires = lock.expiresAt {
                            Text("Expires \(expires, style: .relative)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "lock.fill")
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(DesignSystem.Colors.accent.opacity(0.1))
                }
            }
        }
    }

    private func membersSection(_ group: FamilyGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MEMBERS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(group.members) { member in
                FamilyMemberRowView(
                    member: member,
                    isCurrentUser: member.oderId == familyManager.currentMember?.oderId,
                    onRequestLock: {
                        selectedMemberForLock = member
                        showingLockRequest = true
                    }
                )
            }
        }
    }

    private var activityFeedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT ACTIVITY")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(familyManager.activityFeed.prefix(10)) { activity in
                HStack(spacing: 12) {
                    activityIcon(for: activity.activityType)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(activity.username) \(activity.description)")
                            .font(.subheadline)
                        Text(activity.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func activityIcon(for type: FamilyActivity.ActivityType) -> some View {
        let (icon, color): (String, Color) = {
            switch type {
            case .sessionCompleted: return ("checkmark.circle.fill", .green)
            case .streakMilestone: return ("flame.fill", .orange)
            case .levelUp: return ("star.fill", .yellow)
            case .achievementUnlocked: return ("trophy.fill", .purple)
            case .memberJoined: return ("person.badge.plus", .blue)
            case .lockRequested: return ("lock.badge.clock", .orange)
            case .lockApproved: return ("lock.fill", .green)
            }
        }()

        return Image(systemName: icon)
            .foregroundStyle(color)
    }

    // MARK: - Actions

    private func createFamily() {
        guard !familyName.isEmpty else { return }
        Task { @MainActor in
            do {
                try await familyManager.createFamilyGroup(name: familyName)
                familyName = ""
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func joinFamily() {
        guard !joinCode.isEmpty else { return }
        Task { @MainActor in
            do {
                try await familyManager.joinFamilyByCode(joinCode)
                joinCode = ""
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

// MARK: - Member Row

struct FamilyMemberRowView: View {
    let member: FamilyMember
    let isCurrentUser: Bool
    let onRequestLock: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(isCurrentUser ? DesignSystem.Colors.accent.opacity(0.3) : Color.secondary.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay {
                    Text(member.username.prefix(1).uppercased())
                        .font(.title2.bold())
                }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(member.username)
                        .font(.headline)
                    if member.role == .owner {
                        Text("Owner")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.accent)
                            .cornerRadius(4)
                    }
                    if isCurrentUser {
                        Text("You")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    Label("Lv.\(member.level)", systemImage: "star.fill")
                    Label("\(member.currentStreak)d", systemImage: "flame.fill")
                    Label(member.focusTimeFormatted, systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Request lock button (only for other members)
            if !isCurrentUser {
                Button {
                    onRequestLock()
                } label: {
                    Image(systemName: "lock.badge.clock")
                        .font(.title3)
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.cardBackground)
        }
    }
}

// MARK: - Lock Request Sheet

struct LockRequestSheet: View {
    let member: FamilyMember
    @Environment(\.dismiss) private var dismiss
    @StateObject private var familyManager = FamilyManager.shared

    @State private var durationMinutes = 30
    @State private var reason = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Request focus lock for")
                        Spacer()
                        Text(member.username)
                            .fontWeight(.semibold)
                    }
                }

                Section("Duration") {
                    Picker("Duration", selection: $durationMinutes) {
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("1 hour").tag(60)
                        Text("2 hours").tag(120)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Message (optional)") {
                    TextField("Why should they focus?", text: $reason, axis: .vertical)
                        .lineLimit(3)
                }

                Section {
                    Text("When \(member.username) accepts, their distracting apps will be blocked for the selected duration.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Request Lock")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        sendRequest()
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }

    private func sendRequest() {
        isSubmitting = true
        Task { @MainActor in
            do {
                try await familyManager.requestLock(
                    for: member.oderId,
                    durationMinutes: durationMinutes,
                    reason: reason.isEmpty ? nil : reason
                )
                dismiss()
            } catch {
                isSubmitting = false
                // Error is handled by familyManager.error
            }
        }
    }
}

#Preview {
    NavigationStack {
        FamilyPlanView()
    }
}
