import SwiftUI

struct FriendsView: View {
    @StateObject private var socialManager = SocialManager.shared
    @State private var showingAddFriend = false
    @State private var usernameToAdd = ""
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var isAddingFriend = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Your friend code section
                yourCodeSection

                // Friends list
                if !socialManager.friends.isEmpty {
                    friendsListSection
                } else {
                    emptyState
                }
            }
            .padding()
        }
        .navigationTitle("Friends")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddFriend = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .alert("Add Friend", isPresented: $showingAddFriend) {
            TextField("Enter username", text: $usernameToAdd)
            Button("Cancel", role: .cancel) { usernameToAdd = "" }
            Button("Add") {
                addFriend()
            }
        } message: {
            Text("Enter your friend's username to connect")
        }
        .task {
            await socialManager.fetchCurrentUsername()
            await socialManager.fetchFriends()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
    }

    private var yourCodeSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "person.circle")
                    .font(.title2)
                    .foregroundStyle(DesignSystem.Colors.accent)
                Text("Your Username")
                    .font(.headline)
                Spacer()
            }

            HStack {
                Text(socialManager.currentUsername ?? "Anonymous")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)

                Spacer()

                Button {
                    // Copy to clipboard
                    let username = socialManager.currentUsername ?? "Anonymous"
                    #if os(iOS)
                    UIPasteboard.general.string = username
                    #else
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(username, forType: .string)
                    #endif
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }

            Text("Share your username with friends so they can add you")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.cardBackground)
        }
    }

    private var friendsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR FRIENDS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(socialManager.friends) { friend in
                FriendRowView(friend: friend)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No friends yet")
                .font(.headline)
            Text("Add friends to see each other's progress and compete on the leaderboard")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingAddFriend = true
            } label: {
                Label("Add Friend", systemImage: "person.badge.plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 40)
    }

    private func addFriend() {
        guard !usernameToAdd.isEmpty else { return }

        isAddingFriend = true

        Task {
            do {
                try await socialManager.sendFriendRequestByUsername(usernameToAdd)
                // Success - refresh friends list
                await socialManager.fetchFriends()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }

            isAddingFriend = false
            usernameToAdd = ""
        }
    }
}

struct FriendRowView: View {
    let friend: FocusFriend
    @StateObject private var socialManager = SocialManager.shared

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay {
                    Text(friend.username.prefix(1).uppercased())
                        .font(.title2.bold())
                }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.username)
                    .font(.headline)

                HStack(spacing: 12) {
                    Label("Lv.\(friend.level)", systemImage: "star.fill")
                    Label("\(friend.currentStreak)d", systemImage: "flame.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Status badge
            if friend.status == .pending {
                Text("Pending")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background {
                        Capsule()
                            .fill(Color.orange.opacity(0.2))
                    }
            } else {
                Menu {
                    Button(role: .destructive) {
                        Task {
                            try? await socialManager.removeFriend(friend.id)
                        }
                    } label: {
                        Label("Remove Friend", systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
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

#Preview {
    NavigationStack {
        FriendsView()
    }
}
