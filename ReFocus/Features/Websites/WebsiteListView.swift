import SwiftUI

struct WebsiteListView: View {
    @EnvironmentObject var websiteSyncManager: WebsiteSyncManager
    #if os(iOS)
    @StateObject private var contentBlocker = SafariContentBlockerManager.shared
    #endif
    @State private var newWebsite = ""
    @State private var isAdding = false
    @State private var recentlyAdded: UUID?
    @FocusState private var isInputFocused: Bool
    @State private var shouldRefocus = false

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Safari blocking notice
                #if os(iOS)
                safariBlockingNotice
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.sm)
                #endif

                // Add website input
                addWebsiteSection
                    .padding(DesignSystem.Spacing.lg)

                // Website list
                if websiteSyncManager.blockedWebsites.isEmpty {
                    emptyState
                } else {
                    websiteList
                }
            }
        }
        .navigationTitle("Websites")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            contentBlocker.checkBlockerStatus()
            // Auto-focus input field for immediate typing
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                isInputFocused = true
            }
        }
        #else
        .onAppear {
            // Auto-focus input field for immediate typing
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                isInputFocused = true
            }
        }
        #endif
    }

    // MARK: - Safari Blocking Notice

    #if os(iOS)
    private var safariBlockingNotice: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: contentBlocker.isEnabled ? "safari.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(contentBlocker.isEnabled ? AppTheme.success : AppTheme.warning)

            VStack(alignment: .leading, spacing: 2) {
                Text(contentBlocker.isEnabled ? "Safari blocking enabled" : "Enable in Safari Settings")
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(AppTheme.textPrimary)

                Text(contentBlocker.isEnabled
                     ? "Websites blocked in Safari"
                     : "Settings → Safari → Extensions → ReFocus Blocker")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textMuted)
            }

            Spacer()

            if !contentBlocker.isEnabled {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open")
                        .font(DesignSystem.Typography.captionMedium)
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(contentBlocker.isEnabled
                      ? AppTheme.success.opacity(0.1)
                      : AppTheme.warning.opacity(0.1))
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .strokeBorder(
                    contentBlocker.isEnabled
                        ? AppTheme.success.opacity(0.3)
                        : AppTheme.warning.opacity(0.3),
                    lineWidth: 1
                )
        }
    }
    #endif

    // MARK: - Add Website Section

    private var addWebsiteSection: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "globe")
                .font(.system(size: 16))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 24)

            TextField("Add website (e.g., twitter.com)", text: $newWebsite)
                .textFieldStyle(.plain)
                .font(DesignSystem.Typography.body)
                .autocorrectionDisabled()
                .focused($isInputFocused)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .submitLabel(.next)
                #endif
                .foregroundStyle(AppTheme.textPrimary)
                .onSubmit {
                    addWebsiteKeepFocus()
                }

            if !newWebsite.isEmpty {
                Button {
                    addWebsite()
                } label: {
                    if isAdding {
                        ProgressView()
                            .tint(DesignSystem.Colors.accent)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(DesignSystem.Colors.accent)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isAdding)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(AppTheme.cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .strokeBorder(
                    isInputFocused ? DesignSystem.Colors.accent.opacity(0.5) : AppTheme.border,
                    lineWidth: 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Spacer()

            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textMuted)

            Text("No Blocked Websites")
                .font(DesignSystem.Typography.headline)
                .foregroundStyle(AppTheme.textSecondary)

            Text("Add websites above to block them during focus sessions.")
                .font(DesignSystem.Typography.callout)
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)

            Spacer()
        }
    }

    // MARK: - Website List

    private var websiteList: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(websiteSyncManager.blockedWebsites) { website in
                    WebsiteRowView(
                        website: website,
                        isNew: recentlyAdded == website.id
                    ) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            deleteWebsite(website)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: websiteSyncManager.blockedWebsites.count)
        }
    }

    // MARK: - Actions

    private func addWebsite() {
        let domain = newWebsite.trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !domain.isEmpty else {
            newWebsite = ""
            return
        }

        // Check for duplicates
        guard !websiteSyncManager.blockedWebsites.contains(where: { $0.domain == domain }) else {
            newWebsite = ""
            return
        }

        isAdding = true

        // Use local method for immediate feedback
        let addedWebsite = websiteSyncManager.addWebsiteLocal(domain)

        // Trigger animation for newly added item
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            recentlyAdded = addedWebsite?.id
        }

        // Set flag to refocus after text clears (onChange will handle this)
        shouldRefocus = true

        // Clear input - onChange will detect this and refocus
        newWebsite = ""

        // Also try direct refocus as backup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isInputFocused = true
        }

        // Clear the "new" highlight after a moment
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation {
                recentlyAdded = nil
            }
        }

        isAdding = false

        // Also try to sync in background
        Task {
            try? await websiteSyncManager.addWebsite(domain)
        }
    }

    /// Add website and immediately restore focus for continuous adding
    private func addWebsiteKeepFocus() {
        let domain = newWebsite.trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !domain.isEmpty else {
            newWebsite = ""
            // Keep focus even if empty
            isInputFocused = true
            return
        }

        // Check for duplicates
        guard !websiteSyncManager.blockedWebsites.contains(where: { $0.domain == domain }) else {
            newWebsite = ""
            isInputFocused = true
            return
        }

        // Use local method for immediate feedback
        let addedWebsite = websiteSyncManager.addWebsiteLocal(domain)

        // Trigger animation for newly added item
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            recentlyAdded = addedWebsite?.id
        }

        // Clear input and restore focus after SwiftUI finishes dismissing
        newWebsite = ""

        // Restore focus with delay - onSubmit dismisses keyboard AFTER this function returns
        // so we need to wait for that dismissal to complete, then refocus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isInputFocused = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.isInputFocused = true
        }

        // Clear the "new" highlight after a moment
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation {
                recentlyAdded = nil
            }
        }

        // Sync in background
        Task {
            try? await websiteSyncManager.addWebsite(domain)
        }
    }

    private func deleteWebsite(_ website: BlockedWebsite) {
        // Use local method for immediate feedback
        websiteSyncManager.removeWebsiteLocal(website)

        // Also try to sync in background
        Task {
            try? await websiteSyncManager.removeWebsite(website)
        }
    }
}

// MARK: - Website Row

struct WebsiteRowView: View {
    let website: BlockedWebsite
    var isNew: Bool = false
    let onDelete: () -> Void

    @State private var showingDeleteConfirm = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Favicon using consistent design
            WebsiteFavicon(domain: website.domain, size: 40)
                .overlay {
                    if isNew {
                        Circle()
                            .strokeBorder(DesignSystem.Colors.accent, lineWidth: 2)
                    }
                }

            // Domain
            VStack(alignment: .leading, spacing: 2) {
                Text(website.domain)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Added \(website.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(AppTheme.textMuted)
            }

            Spacer()

            // Delete button
            Button {
                showingDeleteConfirm = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AppTheme.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(DesignSystem.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(isNew ? DesignSystem.Colors.accent.opacity(0.1) : AppTheme.cardBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .strokeBorder(isNew ? DesignSystem.Colors.accent : AppTheme.border, lineWidth: isNew ? 2 : 1)
        }
        .confirmationDialog("Remove \(website.domain)?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

#Preview {
    NavigationStack {
        WebsiteListView()
    }
    .environmentObject(WebsiteSyncManager.shared)
}
