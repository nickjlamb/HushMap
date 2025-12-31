import Foundation
import SwiftData
import CoreLocation

// MARK: - QuickUpdate State

/// Represents the noise state for a quick update
enum QuietState: String, Codable {
    case quiet = "quiet"
    case noisy = "noisy"
}

// MARK: - Recency Configuration

/// Configuration for determining "recent" quick updates
enum QuickUpdateRecency {
    /// Window in seconds for considering an update "recent" (90 minutes)
    static let recentWindowSeconds: TimeInterval = 90 * 60

    /// Check if a timestamp is within the recent window
    static func isRecent(_ timestamp: Date) -> Bool {
        let cutoff = Date().addingTimeInterval(-recentWindowSeconds)
        return timestamp > cutoff
    }
}

// MARK: - Recent Quick Update Info

/// Lightweight struct for displaying recent quick update status on pins and detail views.
/// Does not retain the full QuickUpdate model to avoid memory overhead.
struct RecentQuickUpdateInfo {
    let quietState: QuietState
    let timestamp: Date

    /// Whether this update is still within the "recent" window
    var isRecent: Bool {
        QuickUpdateRecency.isRecent(timestamp)
    }

    /// Human-readable relative time (e.g., "12 min ago")
    var relativeTimeText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    /// Display text for the status badge (e.g., "Quiet · 12 min ago")
    var statusText: String {
        let stateText = quietState == .quiet ? "Quiet" : "Noisy"
        return "\(stateText) · \(relativeTimeText)"
    }
}

// MARK: - QuickUpdate Model

/// Lightweight data model for fast, one-tap sensory updates.
/// Separate from the full Report model to enable frictionless reporting
/// while preserving the detailed "Log My Visit" workflow.
@Model
class QuickUpdate {
    @Attribute(.unique) var id: UUID = UUID()

    /// Location identifier (rounded coordinates for grouping)
    /// Uses same format as Report.locationIdentifier for consistency
    var placeId: String

    /// When this update was submitted
    var timestamp: Date

    /// The sensory state: quiet or noisy
    var quietStateRaw: String

    /// Firebase user ID if authenticated, nil for anonymous users
    var userId: String?

    /// Device identifier for anonymous users (allows "still quiet/noisy" feature)
    var anonymousId: String?

    /// Precise location data
    var latitude: Double
    var longitude: Double

    /// Optional display name of the place
    var displayName: String?

    init(
        placeId: String,
        quietState: QuietState,
        latitude: Double,
        longitude: Double,
        userId: String? = nil,
        anonymousId: String? = nil,
        displayName: String? = nil,
        timestamp: Date = .now
    ) {
        self.id = UUID()
        self.placeId = placeId
        self.quietStateRaw = quietState.rawValue
        self.latitude = latitude
        self.longitude = longitude
        self.userId = userId
        self.anonymousId = anonymousId
        self.displayName = displayName
        self.timestamp = timestamp
    }

    // MARK: - Computed Properties

    /// Type-safe access to quiet state
    var quietState: QuietState {
        get { QuietState(rawValue: quietStateRaw) ?? .quiet }
        set { quietStateRaw = newValue.rawValue }
    }

    /// Coordinate for map display
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Check if this update is recent (within last 2 hours)
    /// Used to determine if user has already submitted a quick update
    var isRecent: Bool {
        let twoHoursAgo = Date().addingTimeInterval(-2 * 60 * 60)
        return timestamp > twoHoursAgo
    }

    /// Human-readable recency text
    var recencyText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    // MARK: - Static Helpers

    /// Generate a location identifier from coordinates (matches Report.locationIdentifier)
    static func locationIdentifier(latitude: Double, longitude: Double) -> String {
        let roundedLat = (latitude * 1000).rounded() / 1000
        let roundedLon = (longitude * 1000).rounded() / 1000
        return "\(roundedLat),\(roundedLon)"
    }
}
