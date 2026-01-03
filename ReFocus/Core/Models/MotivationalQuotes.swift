import Foundation

/// Motivational quotes focused on dreams, achievement, and time
enum MotivationalQuotes {

    // MARK: - Quote Categories

    /// Quotes about dreams and vision
    static let dreams: [Quote] = [
        Quote(text: "The future belongs to those who believe in the beauty of their dreams.", author: "Eleanor Roosevelt"),
        Quote(text: "All our dreams can come true, if we have the courage to pursue them.", author: "Walt Disney"),
        Quote(text: "Dream big and dare to fail.", author: "Norman Vaughan"),
        Quote(text: "The only thing worse than starting something and failing is not starting something.", author: "Seth Godin"),
        Quote(text: "Your dreams are valid. Your focus makes them real.", author: nil),
        Quote(text: "Every great achievement was once considered impossible.", author: nil),
        Quote(text: "Dreams don't work unless you do.", author: "John C. Maxwell"),
        Quote(text: "The distance between your dreams and reality is called action.", author: nil),
    ]

    /// Quotes about focus and discipline
    static let focus: [Quote] = [
        Quote(text: "Focus on being productive instead of busy.", author: "Tim Ferriss"),
        Quote(text: "The successful warrior is the average person with laser-like focus.", author: "Bruce Lee"),
        Quote(text: "Where focus goes, energy flows.", author: "Tony Robbins"),
        Quote(text: "Concentrate all your thoughts upon the work at hand.", author: "Alexander Graham Bell"),
        Quote(text: "Your focus determines your reality.", author: nil),
        Quote(text: "Starve your distractions. Feed your focus.", author: nil),
        Quote(text: "The key to success is to focus on goals, not obstacles.", author: nil),
        Quote(text: "What you focus on expands.", author: nil),
    ]

    /// Quotes about time and its value
    static let time: [Quote] = [
        Quote(text: "Time is what we want most, but what we use worst.", author: "William Penn"),
        Quote(text: "The way we spend our time defines who we are.", author: "Jonathan Estrin"),
        Quote(text: "Lost time is never found again.", author: "Benjamin Franklin"),
        Quote(text: "Don't count the days, make the days count.", author: "Muhammad Ali"),
        Quote(text: "Your time is limited. Don't waste it living someone else's life.", author: "Steve Jobs"),
        Quote(text: "Time is the most valuable thing you can spend.", author: "Theophrastus"),
        Quote(text: "Every moment is a fresh beginning.", author: "T.S. Eliot"),
        Quote(text: "The best time to plant a tree was 20 years ago. The second best time is now.", author: nil),
    ]

    /// Quotes about perseverance
    static let perseverance: [Quote] = [
        Quote(text: "It does not matter how slowly you go as long as you do not stop.", author: "Confucius"),
        Quote(text: "Success is not final, failure is not fatal: it is the courage to continue that counts.", author: "Winston Churchill"),
        Quote(text: "The only way to do great work is to love what you do.", author: "Steve Jobs"),
        Quote(text: "Believe you can and you're halfway there.", author: "Theodore Roosevelt"),
        Quote(text: "You are stronger than you think.", author: nil),
        Quote(text: "Small steps every day lead to big results.", author: nil),
        Quote(text: "Progress, not perfection.", author: nil),
        Quote(text: "Keep going. Everything you need will come to you at the perfect time.", author: nil),
    ]

    /// Short encouragements for block screens
    static let blockScreenMessages: [Quote] = [
        Quote(text: "Stay focused. Your dreams are waiting.", author: nil),
        Quote(text: "This moment of discipline is building your future.", author: nil),
        Quote(text: "Your goals are more important than this distraction.", author: nil),
        Quote(text: "Future you will thank present you.", author: nil),
        Quote(text: "You're building something great. Keep going.", author: nil),
        Quote(text: "Every minute focused is a step toward your dreams.", author: nil),
        Quote(text: "Distractions fade. Achievement lasts.", author: nil),
        Quote(text: "You chose focus. Trust that choice.", author: nil),
        Quote(text: "This is where discipline becomes freedom.", author: nil),
        Quote(text: "Your potential is limitless. Protect your focus.", author: nil),
    ]

    // MARK: - All Quotes

    static let all: [Quote] = dreams + focus + time + perseverance

    // MARK: - Random Selection

    /// Get a random quote from all categories
    static func random() -> Quote {
        all.randomElement() ?? Quote(text: "Stay focused.", author: nil)
    }

    /// Get a random quote for delay screens
    static func randomForDelay() -> Quote {
        (dreams + focus + perseverance).randomElement() ?? random()
    }

    /// Get a random quote for block screens
    static func randomForBlockScreen() -> Quote {
        blockScreenMessages.randomElement() ?? Quote(text: "Stay focused.", author: nil)
    }

    /// Get a random quote about time (for waiting/delay)
    static func randomAboutTime() -> Quote {
        time.randomElement() ?? random()
    }

    /// Get a rotating sequence of quotes (no immediate repeats)
    static func rotatingSequence(count: Int = 10) -> [Quote] {
        var result: [Quote] = []
        var remaining = all.shuffled()

        for _ in 0..<count {
            if remaining.isEmpty {
                remaining = all.shuffled()
            }
            result.append(remaining.removeFirst())
        }

        return result
    }
}

// MARK: - Quote Model

struct Quote: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let author: String?

    var attributedText: String {
        if let author = author {
            return "\"\(text)\"\n— \(author)"
        }
        return "\"\(text)\""
    }

    var shortText: String {
        text
    }
}
