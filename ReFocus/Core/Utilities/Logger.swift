import Foundation
import os.log

/// Centralized logging utility for ReFocus
/// Uses os_log for production-grade logging with proper log levels
enum Log {
    // MARK: - Subsystem and Categories

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.refocus"

    private static let syncLogger = Logger(subsystem: subsystem, category: "Sync")
    private static let timerLogger = Logger(subsystem: subsystem, category: "Timer")
    private static let blockingLogger = Logger(subsystem: subsystem, category: "Blocking")
    private static let authLogger = Logger(subsystem: subsystem, category: "Auth")
    private static let socialLogger = Logger(subsystem: subsystem, category: "Social")
    private static let heroLogger = Logger(subsystem: subsystem, category: "Hero")
    private static let scheduleLogger = Logger(subsystem: subsystem, category: "Schedule")
    private static let rewardLogger = Logger(subsystem: subsystem, category: "Reward")
    private static let liveActivityLogger = Logger(subsystem: subsystem, category: "LiveActivity")
    private static let generalLogger = Logger(subsystem: subsystem, category: "General")

    // MARK: - Sync Logging

    enum Sync {
        static func info(_ message: String) {
            syncLogger.info("\(message, privacy: .public)")
        }

        static func error(_ message: String, error: Error? = nil) {
            if let error = error {
                syncLogger.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
            } else {
                syncLogger.error("\(message, privacy: .public)")
            }
        }

        static func debug(_ message: String) {
            #if DEBUG
            syncLogger.debug("\(message, privacy: .public)")
            #endif
        }
    }

    // MARK: - Timer Logging

    enum Timer {
        static func info(_ message: String) {
            timerLogger.info("\(message, privacy: .public)")
        }

        static func error(_ message: String, error: Error? = nil) {
            if let error = error {
                timerLogger.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
            } else {
                timerLogger.error("\(message, privacy: .public)")
            }
        }

        static func debug(_ message: String) {
            #if DEBUG
            timerLogger.debug("\(message, privacy: .public)")
            #endif
        }
    }

    // MARK: - Blocking Logging

    enum Blocking {
        static func info(_ message: String) {
            blockingLogger.info("\(message, privacy: .public)")
        }

        static func error(_ message: String, error: Error? = nil) {
            if let error = error {
                blockingLogger.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
            } else {
                blockingLogger.error("\(message, privacy: .public)")
            }
        }

        static func debug(_ message: String) {
            #if DEBUG
            blockingLogger.debug("\(message, privacy: .public)")
            #endif
        }
    }

    // MARK: - Auth Logging

    enum Auth {
        static func info(_ message: String) {
            authLogger.info("\(message, privacy: .public)")
        }

        static func error(_ message: String, error: Error? = nil) {
            if let error = error {
                authLogger.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
            } else {
                authLogger.error("\(message, privacy: .public)")
            }
        }

        static func debug(_ message: String) {
            #if DEBUG
            authLogger.debug("\(message, privacy: .public)")
            #endif
        }
    }

    // MARK: - Social Logging

    enum Social {
        static func info(_ message: String) {
            socialLogger.info("\(message, privacy: .public)")
        }

        static func error(_ message: String, error: Error? = nil) {
            if let error = error {
                socialLogger.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
            } else {
                socialLogger.error("\(message, privacy: .public)")
            }
        }

        static func debug(_ message: String) {
            #if DEBUG
            socialLogger.debug("\(message, privacy: .public)")
            #endif
        }
    }

    // MARK: - Hero Logging

    enum Hero {
        static func info(_ message: String) {
            heroLogger.info("\(message, privacy: .public)")
        }

        static func error(_ message: String, error: Error? = nil) {
            if let error = error {
                heroLogger.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
            } else {
                heroLogger.error("\(message, privacy: .public)")
            }
        }

        static func debug(_ message: String) {
            #if DEBUG
            heroLogger.debug("\(message, privacy: .public)")
            #endif
        }
    }

    // MARK: - Schedule Logging

    enum Schedule {
        static func info(_ message: String) {
            scheduleLogger.info("\(message, privacy: .public)")
        }

        static func error(_ message: String, error: Error? = nil) {
            if let error = error {
                scheduleLogger.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
            } else {
                scheduleLogger.error("\(message, privacy: .public)")
            }
        }

        static func debug(_ message: String) {
            #if DEBUG
            scheduleLogger.debug("\(message, privacy: .public)")
            #endif
        }
    }

    // MARK: - Reward Logging

    enum Reward {
        static func info(_ message: String) {
            rewardLogger.info("\(message, privacy: .public)")
        }

        static func error(_ message: String, error: Error? = nil) {
            if let error = error {
                rewardLogger.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
            } else {
                rewardLogger.error("\(message, privacy: .public)")
            }
        }

        static func debug(_ message: String) {
            #if DEBUG
            rewardLogger.debug("\(message, privacy: .public)")
            #endif
        }
    }

    // MARK: - Live Activity Logging

    enum LiveActivity {
        static func info(_ message: String) {
            liveActivityLogger.info("\(message, privacy: .public)")
        }

        static func error(_ message: String, error: Error? = nil) {
            if let error = error {
                liveActivityLogger.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
            } else {
                liveActivityLogger.error("\(message, privacy: .public)")
            }
        }

        static func debug(_ message: String) {
            #if DEBUG
            liveActivityLogger.debug("\(message, privacy: .public)")
            #endif
        }
    }

    // MARK: - General Logging

    static func info(_ message: String) {
        generalLogger.info("\(message, privacy: .public)")
    }

    static func error(_ message: String, error: Error? = nil) {
        if let error = error {
            generalLogger.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
        } else {
            generalLogger.error("\(message, privacy: .public)")
        }
    }

    static func debug(_ message: String) {
        #if DEBUG
        generalLogger.debug("\(message, privacy: .public)")
        #endif
    }

    static func warning(_ message: String) {
        generalLogger.warning("\(message, privacy: .public)")
    }
}
