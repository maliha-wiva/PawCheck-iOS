import OSLog

/// Centralized logger for the app using Apple's OSLog framework.
/// OSLog is the recommended approach — logs appear in Xcode console
/// AND in Console.app, are filterable by subsystem/category,
/// and have zero overhead in release builds when not observed.
///
/// Usage:
///   AppLogger.api.debug("raw response: \(json)")
///   AppLogger.storage.error("failed to save: \(error)")
///   AppLogger.ui.info("HomeView appeared")
enum AppLogger {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.doghealth"

    /// OpenAI API calls — request, raw response, parsing
    static let api      = Logger(subsystem: subsystem, category: "API")

    /// Local storage — read, write, delete operations
    static let storage  = Logger(subsystem: subsystem, category: "Storage")

    /// Navigation and view lifecycle events
    static let ui       = Logger(subsystem: subsystem, category: "UI")

    /// Use case and domain logic events
    static let domain   = Logger(subsystem: subsystem, category: "Domain")

    /// General / uncategorized
    static let general  = Logger(subsystem: subsystem, category: "General")
}
