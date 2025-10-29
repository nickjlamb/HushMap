import Foundation
import SwiftData

@MainActor
class ReportSyncService {
    static let shared = ReportSyncService()

    private init() {}

    enum SyncError: Error, LocalizedError {
        case notImplemented
        case networkError(String)
        case authenticationRequired
        case invalidData

        var errorDescription: String? {
            switch self {
            case .notImplemented:
                return "Cloud sync is not yet implemented. This feature will be available in a future update."
            case .networkError(let message):
                return "Network error: \(message)"
            case .authenticationRequired:
                return "Authentication required to sync reports"
            case .invalidData:
                return "Invalid report data"
            }
        }
    }

    /// Sync all local reports to cloud backend
    /// - Parameter modelContext: The SwiftData model context containing reports
    /// - Returns: Number of reports synced
    func syncAllReports(from modelContext: ModelContext) async throws -> Int {
        // Get all reports from SwiftData
        let descriptor = FetchDescriptor<Report>()
        let reports = try modelContext.fetch(descriptor)

        guard !reports.isEmpty else {
            return 0
        }

        // Get user info if authenticated
        let authService = AuthenticationService.shared
        let userId = authService.currentUser?.id
        let userName = authService.currentUser?.name
        let userProfileImageURL = authService.currentUser?.profileImageURL?.absoluteString

        // Upload reports to Firestore
        let firestoreService = FirestoreService.shared
        let uploadedCount = try await firestoreService.uploadReports(
            reports,
            userId: userId,
            userName: userName,
            userProfileImageURL: userProfileImageURL
        )

        return uploadedCount
    }

    /// Download reports from cloud and merge with local data
    func downloadReports(to modelContext: ModelContext) async throws -> Int {
        // Download all reports from Firestore
        let firestoreService = FirestoreService.shared
        let firestoreReports = try await firestoreService.downloadAllReports()

        var importedCount = 0

        // Get existing report IDs to avoid duplicates
        let existingDescriptor = FetchDescriptor<Report>()
        let existingReports = try modelContext.fetch(existingDescriptor)
        let existingIds = Set(existingReports.map { $0.id.uuidString })

        // Import reports that don't exist locally
        for firestoreReport in firestoreReports {
            if !existingIds.contains(firestoreReport.id) {
                let report = firestoreReport.toReport()
                modelContext.insert(report)
                importedCount += 1
            }
        }

        // Save changes
        try modelContext.save()

        return importedCount
    }

    /// Sync a single report to cloud
    func syncReport(_ report: Report) async throws {
        let authService = AuthenticationService.shared
        let userId = authService.currentUser?.id
        let userName = authService.currentUser?.name
        let userProfileImageURL = authService.currentUser?.profileImageURL?.absoluteString

        let firestoreService = FirestoreService.shared
        try await firestoreService.uploadReport(
            report,
            userId: userId,
            userName: userName,
            userProfileImageURL: userProfileImageURL
        )
    }
}
