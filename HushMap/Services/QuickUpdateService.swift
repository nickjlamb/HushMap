import Foundation
import SwiftData
import CoreLocation
import UIKit

/// Service for managing quick sensory updates.
/// Follows the existing singleton pattern used throughout the app.
@MainActor
class QuickUpdateService {
    static let shared = QuickUpdateService()

    private init() {}

    // MARK: - Anonymous ID Management

    /// Get or create a persistent anonymous ID for this device.
    /// Used to track whether a user has already submitted a quick update.
    private var anonymousId: String {
        let key = "QuickUpdateAnonymousId"
        if let existingId = UserDefaults.standard.string(forKey: key) {
            return existingId
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }

    // MARK: - Quick Update Submission

    /// Submit a quick update for a place.
    /// Also creates a full Report to increment the shared experiences counter,
    /// matching the behavior of Apple Watch updates.
    /// - Parameters:
    ///   - quietState: Whether the place is quiet or noisy right now
    ///   - coordinate: The location coordinates
    ///   - displayName: Optional display name of the place
    ///   - modelContext: SwiftData context for persistence
    /// - Returns: The created QuickUpdate
    @discardableResult
    func submitQuickUpdate(
        quietState: QuietState,
        coordinate: CLLocationCoordinate2D,
        displayName: String?,
        modelContext: ModelContext
    ) async throws -> QuickUpdate {
        let placeId = QuickUpdate.locationIdentifier(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        // Get user ID if authenticated
        let authService = AuthenticationService.shared
        let userId = authService.currentUser?.id

        let update = QuickUpdate(
            placeId: placeId,
            quietState: quietState,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            userId: userId,
            anonymousId: userId == nil ? anonymousId : nil,
            displayName: displayName
        )

        // Save QuickUpdate to SwiftData (for "Still quiet/noisy" feature)
        modelContext.insert(update)

        // Also create a full Report to increment the shared experiences counter.
        // This matches the Apple Watch behavior where quick inputs create full reports.
        // Sensory values are derived from quiet/noisy state (same formula as WatchConnectivityService).
        let report = createReportFromQuickUpdate(
            quietState: quietState,
            coordinate: coordinate,
            displayName: displayName
        )
        modelContext.insert(report)

        try modelContext.save()

        // Sync both to Firestore asynchronously (fire and forget)
        Task {
            // Sync the Report (this increments shared experiences counter)
            do {
                let syncService = ReportSyncService.shared
                try await syncService.syncReport(report)
                #if DEBUG
                print("✅ Quick update report synced to Firestore")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ Failed to sync quick update report: \(error)")
                #endif
            }

            // Also sync the QuickUpdate metadata (optional, for future analytics)
            do {
                try await syncQuickUpdate(update)
            } catch {
                #if DEBUG
                print("Failed to sync quick update metadata: \(error)")
                #endif
            }
        }

        return update
    }

    // MARK: - Report Creation

    /// Create a full Report from a quick update, using derived sensory values.
    /// This matches the Apple Watch pattern (WatchConnectivityService.handleLogEntry)
    /// to ensure consistent behavior and counter incrementing.
    private func createReportFromQuickUpdate(
        quietState: QuietState,
        coordinate: CLLocationCoordinate2D,
        displayName: String?
    ) -> Report {
        // Derive sensory values from quiet/noisy state
        // These values match WatchConnectivityService.handleLogEntry for consistency:
        // - Quiet: low sensory levels → green pin (excellent)
        // - Noisy: high sensory levels → red/orange pin
        let isQuiet = quietState == .quiet
        let noise = isQuiet ? 0.15 : 0.85
        let crowds = isQuiet ? 0.20 : 0.75
        let lighting = isQuiet ? 0.35 : 0.60
        let comfort = isQuiet ? 0.85 : 0.25

        let report = Report(
            noise: noise,
            crowds: crowds,
            lighting: lighting,
            comfort: comfort,
            comments: "Quick update",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        // Set display name if available
        report.displayName = displayName

        // Set user attribution for community sharing
        let authService = AuthenticationService.shared
        report.submittedByUserId = authService.currentUser?.id ?? "anonymous"
        report.submittedByUserName = authService.currentUser?.name ?? "Anonymous"
        report.submittedByUserProfileImageURL = authService.currentUser?.profileImageURL?.absoluteString

        return report
    }

    // MARK: - Recent Update Checks

    /// Check if the current user has submitted a quick update for this place recently.
    /// Returns the most recent update if found.
    /// - Parameters:
    ///   - placeId: The location identifier
    ///   - modelContext: SwiftData context for queries
    /// - Returns: The most recent quick update for this place by this user, if any
    func recentUpdate(for placeId: String, modelContext: ModelContext) -> QuickUpdate? {
        let authService = AuthenticationService.shared
        let userId = authService.currentUser?.id
        let anonId = anonymousId

        // Query for recent updates at this place by this user
        let twoHoursAgo = Date().addingTimeInterval(-2 * 60 * 60)

        let descriptor = FetchDescriptor<QuickUpdate>(
            predicate: #Predicate<QuickUpdate> { update in
                update.placeId == placeId &&
                update.timestamp > twoHoursAgo
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        guard let updates = try? modelContext.fetch(descriptor) else {
            return nil
        }

        // Find updates by this user (authenticated or anonymous)
        return updates.first { update in
            if let userId = userId, let updateUserId = update.userId {
                return userId == updateUserId
            } else if userId == nil {
                return update.anonymousId == anonId
            }
            return false
        }
    }

    /// Check if user has already submitted a quick update for this place
    func hasRecentUpdate(for placeId: String, modelContext: ModelContext) -> Bool {
        return recentUpdate(for: placeId, modelContext: modelContext) != nil
    }

    // MARK: - Latest Update for Display

    /// Get the most recent quick update for a place (from any user).
    /// Used to show "Updated X minutes ago" in the UI.
    func latestUpdate(for placeId: String, modelContext: ModelContext) -> QuickUpdate? {
        let descriptor = FetchDescriptor<QuickUpdate>(
            predicate: #Predicate<QuickUpdate> { update in
                update.placeId == placeId
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        return (try? modelContext.fetch(descriptor))?.first
    }

    // MARK: - Cloud Sync

    /// Sync a quick update to Firestore
    private func syncQuickUpdate(_ update: QuickUpdate) async throws {
        let firestoreService = FirestoreService.shared
        try await firestoreService.uploadQuickUpdate(update)
    }
}
