import SwiftUI

/// Post-session review prompt - "What did you work on?" + "Was it worth it?"
struct SessionReviewView: View {
    @StateObject private var companionManager = DeepWorkCompanionManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var whatWorkedOn: String = ""
    @State private var selectedRating: Int = 3
    @State private var selectedTags: Set<String> = []
    @State private var notes: String = ""
    @State private var showingNotes = false

    var modeColor: Color = DesignSystem.Colors.accent

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Header
                        headerSection

                        // What did you work on?
                        workDescriptionSection

                        // Was it worth it?
                        ratingSection

                        // Tags
                        tagsSection

                        // Optional notes
                        if showingNotes {
                            notesSection
                        }

                        // Actions
                        actionButtons
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
            }
            .navigationTitle("Session Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        companionManager.skipReview()
                        dismiss()
                    }
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
        }
        .preferredColorScheme(.dark)
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #endif
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(modeColor.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44, weight: .thin))
                    .foregroundStyle(modeColor)
            }

            Text("Great focus session!")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)

            Text("Take a moment to reflect on what you accomplished.")
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DesignSystem.Spacing.lg)
    }

    // MARK: - Work Description

    private var workDescriptionSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("WHAT DID YOU WORK ON?")
                .sectionHeader()

            TextField("Brief description...", text: $whatWorkedOn, axis: .vertical)
                .textFieldStyle(.plain)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .lineLimit(2...4)
                .padding(DesignSystem.Spacing.md)
                .background {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .fill(DesignSystem.Colors.backgroundCard)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
                }
        }
    }

    // MARK: - Rating

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("WAS IT WORTH IT?")
                .sectionHeader()

            VStack(spacing: DesignSystem.Spacing.md) {
                // Star rating
                HStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(1...5, id: \.self) { rating in
                        Button {
                            withAnimation(DesignSystem.Animation.quick) {
                                selectedRating = rating
                            }
                        } label: {
                            Image(systemName: rating <= selectedRating ? "star.fill" : "star")
                                .font(.system(size: 32))
                                .foregroundStyle(
                                    rating <= selectedRating
                                        ? ratingColor(for: selectedRating)
                                        : DesignSystem.Colors.textMuted
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Rating description
                Text(ratingDescription)
                    .font(DesignSystem.Typography.captionMedium)
                    .foregroundStyle(ratingColor(for: selectedRating))
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.lg)
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(DesignSystem.Colors.backgroundCard)
            }
        }
    }

    private var ratingDescription: String {
        switch selectedRating {
        case 1: return "Not worth it - lost focus"
        case 2: return "Barely worth it"
        case 3: return "Somewhat productive"
        case 4: return "Productive session!"
        case 5: return "Deep work achieved!"
        default: return ""
        }
    }

    private func ratingColor(for rating: Int) -> Color {
        switch rating {
        case 1, 2: return DesignSystem.Colors.destructive
        case 3: return DesignSystem.Colors.warning
        case 4, 5: return DesignSystem.Colors.success
        default: return DesignSystem.Colors.textMuted
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("WHAT TYPE OF WORK?")
                .sectionHeader()

            FlowLayout(spacing: DesignSystem.Spacing.sm) {
                ForEach(SessionTag.allCases) { tag in
                    tagButton(tag)
                }
            }
        }
    }

    private func tagButton(_ tag: SessionTag) -> some View {
        let isSelected = selectedTags.contains(tag.rawValue)

        return Button {
            withAnimation(DesignSystem.Animation.quick) {
                if isSelected {
                    selectedTags.remove(tag.rawValue)
                } else {
                    selectedTags.insert(tag.rawValue)
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Image(systemName: tag.icon)
                    .font(.system(size: 12))

                Text(tag.rawValue)
                    .font(DesignSystem.Typography.caption)
            }
            .foregroundStyle(isSelected ? .white : DesignSystem.Colors.textSecondary)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background {
                Capsule()
                    .fill(isSelected ? modeColor : DesignSystem.Colors.backgroundCard)
            }
            .overlay {
                if !isSelected {
                    Capsule()
                        .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("NOTES (OPTIONAL)")
                .sectionHeader()

            TextField("Any additional thoughts...", text: $notes, axis: .vertical)
                .textFieldStyle(.plain)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .lineLimit(3...6)
                .padding(DesignSystem.Spacing.md)
                .background {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .fill(DesignSystem.Colors.backgroundCard)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .strokeBorder(DesignSystem.Colors.border, lineWidth: 1)
                }
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            if !showingNotes {
                Button {
                    withAnimation {
                        showingNotes = true
                    }
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                        Text("Add notes")
                    }
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }

            Button {
                submitReview()
            } label: {
                Text("Save Review")
            }
            .buttonStyle(ColoredPrimaryButtonStyle(color: modeColor))
            .disabled(whatWorkedOn.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.top, DesignSystem.Spacing.md)
        .padding(.bottom, DesignSystem.Spacing.xxl)
    }

    // MARK: - Actions

    private func submitReview() {
        companionManager.submitReview(
            whatWorkedOn: whatWorkedOn.trimmingCharacters(in: .whitespaces),
            worthItRating: selectedRating,
            tags: Array(selectedTags),
            notes: notes.isEmpty ? nil : notes
        )
        dismiss()
    }
}

#Preview {
    SessionReviewView()
}
