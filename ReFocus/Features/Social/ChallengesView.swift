import SwiftUI

struct ChallengesView: View {
    @StateObject private var socialManager = SocialManager.shared
    @State private var showingCreateChallenge = false
    @State private var showingJoinByCode = false
    @State private var joinCode = ""
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Active Challenges
                if !socialManager.activeChallenges.isEmpty {
                    challengeSection(
                        title: "Your Challenges",
                        challenges: socialManager.activeChallenges,
                        isActive: true
                    )
                }
                
                // Available Challenges
                if !socialManager.availableChallenges.isEmpty {
                    challengeSection(
                        title: "Join a Challenge",
                        challenges: socialManager.availableChallenges,
                        isActive: false
                    )
                }
                
                // Empty state
                if socialManager.activeChallenges.isEmpty && socialManager.availableChallenges.isEmpty {
                    emptyState
                }
            }
            .padding()
        }
        .navigationTitle("Challenges")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingJoinByCode = true
                } label: {
                    Image(systemName: "ticket")
                }
                
                Button {
                    showingCreateChallenge = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateChallenge) {
            CreateChallengeView()
        }
        .alert("Join Challenge", isPresented: $showingJoinByCode) {
            TextField("Enter invite code", text: $joinCode)
            Button("Cancel", role: .cancel) { joinCode = "" }
            Button("Join") {
                Task { @MainActor in
                    do {
                        try await socialManager.joinChallengeByCode(joinCode)
                        joinCode = ""
                    } catch {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
        .task {
            await socialManager.fetchChallenges()
        }
    }
    
    private func challengeSection(title: String, challenges: [FocusChallenge], isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            
            ForEach(challenges) { challenge in
                ChallengeCardView(challenge: challenge, isActive: isActive)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No challenges yet")
                .font(.headline)
            Text("Create or join a challenge to compete with others")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingCreateChallenge = true
            } label: {
                Label("Create Challenge", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 40)
    }
}

struct ChallengeCardView: View {
    let challenge: FocusChallenge
    let isActive: Bool
    @StateObject private var socialManager = SocialManager.shared
    @State private var isJoining = false
    @State private var joinError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.name)
                        .font(.headline)
                    
                    Text(challenge.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // XP reward badge
                Text("+\(challenge.xpReward) XP")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(8)
            }
            
            // Progress (for active challenges)
            if isActive {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(challenge.progressPercentage * 100))%")
                            .font(.caption.bold())
                    }
                    
                    ProgressView(value: challenge.progressPercentage)
                        .tint(.accentColor)
                }
            }
            
            // Footer
            HStack {
                // Participants
                Label("\(challenge.participants.count)", systemImage: "person.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Time remaining
                if challenge.isActive {
                    Label("\(challenge.daysRemaining)d left", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Join button (for available challenges)
                if !isActive {
                    Button(isJoining ? "Joining..." : "Join") {
                        isJoining = true
                        Task { @MainActor in
                            do {
                                try await socialManager.joinChallenge(challenge.id)
                            } catch {
                                joinError = error.localizedDescription
                            }
                            isJoining = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isJoining)
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.1))
        }
    }
}

struct CreateChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var socialManager = SocialManager.shared
    
    @State private var name = ""
    @State private var description = ""
    @State private var type: FocusChallenge.ChallengeType = .weekly
    @State private var targetHours = 5
    @State private var durationDays = 7
    @State private var isPublic = true
    @State private var isCreating = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Challenge Info") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3)
                }
                
                Section("Goal") {
                    Picker("Type", selection: $type) {
                        ForEach(FocusChallenge.ChallengeType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    Stepper("Target: \(targetHours) hours", value: $targetHours, in: 1...100)
                    Stepper("Duration: \(durationDays) days", value: $durationDays, in: 1...30)
                }
                
                Section("Visibility") {
                    Toggle("Public Challenge", isOn: $isPublic)
                    
                    if !isPublic {
                        Text("You'll get an invite code to share")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New Challenge")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createChallenge()
                    }
                    .disabled(name.isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createChallenge() {
        isCreating = true
        Task {
            do {
                _ = try await socialManager.createChallenge(
                    name: name,
                    description: description,
                    type: type,
                    targetMinutes: targetHours * 60,
                    durationDays: durationDays,
                    isPublic: isPublic
                )
                dismiss()
            } catch {
                // Handle error
            }
            isCreating = false
        }
    }
}

#Preview {
    NavigationStack {
        ChallengesView()
    }
}
