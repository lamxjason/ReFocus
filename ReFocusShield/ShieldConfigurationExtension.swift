import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Provides custom shield configuration for blocked apps and websites
/// Shows dream-focused messaging to encourage users to stay focused
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    // MARK: - Shield Quotes
    // Organized by psychological category for maximum effectiveness
    // Based on research: Loss aversion, goal visualization, and self-identity are key drivers

    private static let quotes = [
        // Goal-Focused (visualization)
        "Your dreams are worth more than this distraction.",
        "Every moment of focus brings you closer to your goals.",
        "Your goals deserve your full attention.",
        "What you do now defines who you become.",
        "Success is built one focused moment at a time.",
        "Your vision requires your full presence.",

        // Future Self (temporal motivation)
        "Stay focused. Your future self will thank you.",
        "The future belongs to those who focus today.",
        "Today's focus is tomorrow's freedom.",
        "Your future is shaped by what you do right now.",
        "Build the life you want, one session at a time.",
        "The best time to focus is now.",

        // Loss Aversion (protecting progress)
        "This distraction fades. Your achievements last forever.",
        "Don't trade your dreams for temporary comfort.",
        "Every distraction costs more than you think.",
        "Your streak is worth protecting.",
        "Progress lost is harder to regain.",
        "Protect what you've built.",

        // Self-Identity (who you are)
        "You chose focus. Trust that choice.",
        "Focused people don't give up this easily.",
        "This is who you're becoming.",
        "Champions are made in moments like these.",
        "Discipline is choosing what you want most over what you want now.",
        "You're stronger than this urge.",

        // Potential (growth mindset)
        "Your potential is limitless. Protect it.",
        "Small sacrifices lead to big dreams.",
        "Focus now. Celebrate later.",
        "Deep work unlocks extraordinary results.",
        "Consistency beats intensity.",
        "Excellence is a habit, not an act."
    ]

    private static let dreamMessages = [
        // Encouraging
        "Remember why you started",
        "Dream bigger",
        "Your dreams are waiting",
        "Stay the course",
        "Keep building",
        "You've got this",

        // Action-oriented
        "One more minute of focus",
        "Stay in the zone",
        "Almost there",
        "Keep going",
        "Trust the process",
        "Eyes on the prize",

        // Identity-reinforcing
        "You're a focused person",
        "This is your time",
        "Make it count",
        "Stay committed"
    ]

    // MARK: - App Shield Configuration

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        // Get app name if available
        let appName = application.localizedDisplayName ?? "This app"

        return createShieldConfiguration(
            title: .init(text: "\(appName) is blocked", color: .white),
            subtitle: getRandomQuote(),
            primaryButtonLabel: .init(text: "Keep Focusing", color: .white),
            secondaryButtonLabel: nil
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        let categoryName = category.localizedDisplayName ?? "This category"

        return createShieldConfiguration(
            title: .init(text: "\(categoryName) apps are blocked", color: .white),
            subtitle: getRandomQuote(),
            primaryButtonLabel: .init(text: "Keep Focusing", color: .white),
            secondaryButtonLabel: nil
        )
    }

    // MARK: - Web Shield Configuration

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        let domain = webDomain.domain ?? "This website"

        return createShieldConfiguration(
            title: .init(text: "\(domain) is blocked", color: .white),
            subtitle: getRandomQuote(),
            primaryButtonLabel: .init(text: "Keep Focusing", color: .white),
            secondaryButtonLabel: nil
        )
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        let categoryName = category.localizedDisplayName ?? "This category"

        return createShieldConfiguration(
            title: .init(text: "\(categoryName) sites are blocked", color: .white),
            subtitle: getRandomQuote(),
            primaryButtonLabel: .init(text: "Keep Focusing", color: .white),
            secondaryButtonLabel: nil
        )
    }

    // MARK: - Configuration Builder

    private func createShieldConfiguration(
        title: ShieldConfiguration.Label,
        subtitle: ShieldConfiguration.Label,
        primaryButtonLabel: ShieldConfiguration.Label,
        secondaryButtonLabel: ShieldConfiguration.Label?
    ) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0),
            icon: UIImage(systemName: "sparkles"),
            title: title,
            subtitle: subtitle,
            primaryButtonLabel: primaryButtonLabel,
            primaryButtonBackgroundColor: UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0),
            secondaryButtonLabel: secondaryButtonLabel
        )
    }

    private func getRandomQuote() -> ShieldConfiguration.Label {
        let quote = Self.quotes.randomElement() ?? "Stay focused."
        let message = Self.dreamMessages.randomElement() ?? "Dream bigger"
        let fullText = "\"\(quote)\"\n\n\(message)"
        return .init(text: fullText, color: UIColor(white: 0.7, alpha: 1.0))
    }
}
