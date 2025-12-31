import Foundation
import FirebaseFirestore
import SwiftData

@MainActor
class FirestoreService {
    static let shared = FirestoreService()

    private let db = Firestore.firestore()
    private let reportsCollection = "reports"
    private let quickUpdatesCollection = "quickUpdates"

    private init() {}

    // MARK: - Report Syncing

    /// Upload a single report to Firestore
    func uploadReport(_ report: Report, userId: String?, userName: String?, userProfileImageURL: String?) async throws {
        var reportData: [String: Any] = [
            "id": report.id.uuidString,
            "noise": report.noise,
            "crowds": report.crowds,
            "lighting": report.lighting,
            "comfort": report.comfort,
            "comments": report.comments,
            "latitude": report.latitude,
            "longitude": report.longitude,
            "timestamp": Timestamp(date: report.timestamp),
            "submittedByUserId": userId ?? "anonymous",
            "submittedByUserName": userName ?? "Anonymous",
            "displayName": report.displayName as Any,
            "displayTierRaw": report.displayTierRaw as Any,
            "confidence": report.confidence as Any,
            "points": report.points as Any
        ]

        if let profileImageURL = userProfileImageURL {
            reportData["submittedByUserProfileImageURL"] = profileImageURL
        }

        try await db.collection(reportsCollection).document(report.id.uuidString).setData(reportData)
    }

    /// Upload multiple reports to Firestore
    func uploadReports(_ reports: [Report], userId: String?, userName: String?, userProfileImageURL: String?) async throws -> Int {
        var uploadedCount = 0

        for report in reports {
            do {
                try await uploadReport(report, userId: userId, userName: userName, userProfileImageURL: userProfileImageURL)
                uploadedCount += 1
            } catch {
                print("Failed to upload report \(report.id): \(error)")
                // Continue with other reports
            }
        }

        return uploadedCount
    }

    /// Download all reports from Firestore
    func downloadAllReports() async throws -> [FirestoreReport] {
        let snapshot = try await db.collection(reportsCollection).getDocuments()

        var reports: [FirestoreReport] = []

        for document in snapshot.documents {
            if let report = parseFirestoreReport(from: document.data(), id: document.documentID) {
                reports.append(report)
            }
        }

        return reports
    }

    /// Download reports near a location (within radius in kilometers)
    func downloadNearbyReports(latitude: Double, longitude: Double, radiusKm: Double = 50) async throws -> [FirestoreReport] {
        // Firestore doesn't support geoqueries natively, so we'll fetch all and filter
        // For production, consider using GeoFirestore or implement geohashing
        let allReports = try await downloadAllReports()

        return allReports.filter { report in
            let distance = calculateDistance(
                from: (latitude, longitude),
                to: (report.latitude, report.longitude)
            )
            return distance <= radiusKm
        }
    }

    /// Set up real-time listener for reports
    func listenToReports(completion: @escaping ([FirestoreReport]) -> Void) -> ListenerRegistration {
        return db.collection(reportsCollection)
            .order(by: "timestamp", descending: true)
            .limit(to: 1000) // Limit to most recent 1000 reports
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching reports: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }

                let reports = documents.compactMap { doc in
                    self.parseFirestoreReport(from: doc.data(), id: doc.documentID)
                }

                completion(reports)
            }
    }

    // MARK: - Quick Update Syncing

    /// Upload a quick update to Firestore
    func uploadQuickUpdate(_ update: QuickUpdate) async throws {
        let updateData: [String: Any] = [
            "id": update.id.uuidString,
            "placeId": update.placeId,
            "quietState": update.quietStateRaw,
            "latitude": update.latitude,
            "longitude": update.longitude,
            "timestamp": Timestamp(date: update.timestamp),
            "userId": update.userId as Any,
            "anonymousId": update.anonymousId as Any,
            "displayName": update.displayName as Any
        ]

        try await db.collection(quickUpdatesCollection).document(update.id.uuidString).setData(updateData)
    }

    // MARK: - Helper Methods

    private func parseFirestoreReport(from data: [String: Any], id: String) -> FirestoreReport? {
        guard let latitude = data["latitude"] as? Double,
              let longitude = data["longitude"] as? Double,
              let noise = data["noise"] as? Double,
              let crowds = data["crowds"] as? Double,
              let lighting = data["lighting"] as? Double,
              let comfort = data["comfort"] as? Double,
              let comments = data["comments"] as? String,
              let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
            return nil
        }

        return FirestoreReport(
            id: id,
            noise: noise,
            crowds: crowds,
            lighting: lighting,
            comfort: comfort,
            comments: comments,
            latitude: latitude,
            longitude: longitude,
            timestamp: timestamp,
            submittedByUserId: data["submittedByUserId"] as? String,
            submittedByUserName: data["submittedByUserName"] as? String,
            submittedByUserProfileImageURL: data["submittedByUserProfileImageURL"] as? String,
            displayName: data["displayName"] as? String,
            displayTierRaw: data["displayTierRaw"] as? String,
            confidence: data["confidence"] as? Double,
            points: data["points"] as? Int
        )
    }

    private func calculateDistance(from: (lat: Double, lon: Double), to: (lat: Double, lon: Double)) -> Double {
        // Haversine formula for distance calculation
        let earthRadius = 6371.0 // km

        let lat1Rad = from.lat * .pi / 180
        let lat2Rad = to.lat * .pi / 180
        let deltaLat = (to.lat - from.lat) * .pi / 180
        let deltaLon = (to.lon - from.lon) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(deltaLon / 2) * sin(deltaLon / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadius * c
    }
}

// MARK: - Firestore Report Model

struct FirestoreReport: Identifiable {
    let id: String
    let noise: Double
    let crowds: Double
    let lighting: Double
    let comfort: Double
    let comments: String
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let submittedByUserId: String?
    let submittedByUserName: String?
    let submittedByUserProfileImageURL: String?
    let displayName: String?
    let displayTierRaw: String?
    let confidence: Double?
    let points: Int?

    /// Convert to SwiftData Report model
    func toReport() -> Report {
        let report = Report(
            noise: noise,
            crowds: crowds,
            lighting: lighting,
            comfort: comfort,
            comments: comments,
            latitude: latitude,
            longitude: longitude,
            timestamp: timestamp
        )

        // Preserve the original UUID from Firestore document ID
        if let uuid = UUID(uuidString: id) {
            report.id = uuid
        }

        report.displayName = displayName
        report.displayTierRaw = displayTierRaw
        report.confidence = confidence
        report.points = points
        report.submittedByUserId = submittedByUserId
        report.submittedByUserName = submittedByUserName
        report.submittedByUserProfileImageURL = submittedByUserProfileImageURL

        return report
    }
}
