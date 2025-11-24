import Foundation
import WatchConnectivity
import SwiftData
import CoreLocation

@MainActor
class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published var isWatchAppInstalled = false
    @Published var isWatchReachable = false

    private var modelContext: ModelContext?
    private let locationManager = LocationManager()

    private override init() {
        super.init()

        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // Send update to Watch
    func sendUpdateToWatch() {
        guard WCSession.default.isReachable else { return }

        Task {
            let data = await prepareWatchUpdateData()

            WCSession.default.sendMessage(data, replyHandler: nil) { error in
                print("Error sending update to Watch: \(error.localizedDescription)")
            }
        }
    }

    private func prepareWatchUpdateData() async -> [String: Any] {
        var data: [String: Any] = [:]

        // Calculate current quiet score based on nearby reports
        if let userLocation = locationManager.lastLocation {
            let quietScore = await calculateQuietScore(near: userLocation)
            data["quietScore"] = quietScore

            // Find nearest place with reports
            if let nearestPlace = await findNearestPlace(to: userLocation) {
                data["nearestPlace"] = [
                    "id": nearestPlace.id.uuidString,
                    "name": nearestPlace.name,
                    "emoji": nearestPlace.emoji,
                    "latitude": nearestPlace.latitude,
                    "longitude": nearestPlace.longitude,
                    "distance": nearestPlace.distance,
                    "quietScore": nearestPlace.quietScore
                ]
            }
        } else {
            data["quietScore"] = 50 // Default score when no location
        }

        return data
    }

    private func calculateQuietScore(near location: CLLocationCoordinate2D) async -> Int {
        guard let context = modelContext else { return 50 }

        do {
            // Fetch nearby reports (within 500m)
            let descriptor = FetchDescriptor<Report>()
            let allReports = try context.fetch(descriptor)

            let nearbyReports = allReports.filter { report in
                let reportLocation = CLLocation(latitude: report.latitude, longitude: report.longitude)
                let userLocationCL = CLLocation(latitude: location.latitude, longitude: location.longitude)
                let distance = userLocationCL.distance(from: reportLocation)
                return distance <= 500
            }

            guard !nearbyReports.isEmpty else { return 50 }

            // Calculate average quiet score from nearby reports
            let totalQuietScore = nearbyReports.reduce(0) { $0 + $1.quietScore }
            return totalQuietScore / nearbyReports.count

        } catch {
            print("Error fetching reports: \(error)")
            return 50
        }
    }

    private func findNearestPlace(to location: CLLocationCoordinate2D) async -> (id: UUID, name: String, emoji: String, latitude: Double, longitude: Double, distance: Double, quietScore: Int)? {
        guard let context = modelContext else { return nil }

        do {
            let descriptor = FetchDescriptor<Report>()
            let allReports = try context.fetch(descriptor)

            // Group by location and find nearest
            let groupedReports = Dictionary(grouping: allReports) { $0.locationIdentifier }

            var nearestPlace: (id: UUID, name: String, emoji: String, latitude: Double, longitude: Double, distance: Double, quietScore: Int)?
            var minDistance = Double.infinity

            for (_, reports) in groupedReports {
                guard let firstReport = reports.first else { continue }

                let reportLocation = CLLocation(latitude: firstReport.latitude, longitude: firstReport.longitude)
                let userLocationCL = CLLocation(latitude: location.latitude, longitude: location.longitude)
                let distance = userLocationCL.distance(from: reportLocation)

                if distance < minDistance && distance <= 1000 { // Within 1km
                    minDistance = distance

                    let averageQuietScore = reports.map(\.quietScore).reduce(0, +) / reports.count
                    let emoji = emojiForQuietScore(averageQuietScore)
                    let placeName = firstReport.displayName ?? firstReport.friendlyDisplayName

                    nearestPlace = (
                        id: UUID(),
                        name: placeName,
                        emoji: emoji,
                        latitude: firstReport.latitude,
                        longitude: firstReport.longitude,
                        distance: distance,
                        quietScore: averageQuietScore
                    )
                }
            }

            return nearestPlace

        } catch {
            print("Error finding nearest place: \(error)")
            return nil
        }
    }

    private func emojiForQuietScore(_ score: Int) -> String {
        switch score {
        case 80...100: return "😌"
        case 60..<80: return "☕️"
        case 40..<60: return "🏪"
        case 20..<40: return "🚗"
        default: return "📢"
        }
    }

    // Handle log entry from Watch
    private func handleLogEntry(isQuiet: Bool, timestamp: TimeInterval) {
        guard let context = modelContext,
              let userLocation = locationManager.lastLocation else {
            print("Cannot create report: missing context or location")
            return
        }

        // Create a simplified report from Watch input
        // For quiet reports: average should be < 0.3 to show as green (excellent)
        // For noisy reports: average should be >= 0.7 to show as red/orange
        let noise = isQuiet ? 0.15 : 0.85
        let crowds = isQuiet ? 0.20 : 0.75
        let lighting = isQuiet ? 0.35 : 0.60 // Adjusted based on context
        let comfort = isQuiet ? 0.85 : 0.25

        let report = Report(
            noise: noise,
            crowds: crowds,
            lighting: lighting,
            comfort: comfort,
            comments: "Logged from Apple Watch",
            latitude: userLocation.latitude,
            longitude: userLocation.longitude,
            timestamp: Date(timeIntervalSince1970: timestamp)
        )

        context.insert(report)

        do {
            try context.save()
            print("✅ Saved Watch log entry")

            // Upload report to Firestore for community sharing
            Task {
                do {
                    let syncService = ReportSyncService.shared
                    try await syncService.syncReport(report)
                    print("✅ Watch report synced to Firestore")
                } catch {
                    print("⚠️ Failed to sync Watch report to Firestore: \(error.localizedDescription)")
                }
            }

            // Send updated data back to Watch
            sendUpdateToWatch()
        } catch {
            print("❌ Error saving Watch log entry: \(error)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("Watch session became inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        print("Watch session deactivated")
        session.activate()
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isWatchReachable = session.isReachable

            if activationState == .activated {
                print("✅ Watch session activated")
                if session.isReachable {
                    sendUpdateToWatch()
                }
            } else if let error = error {
                print("❌ Watch session activation error: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable

            if session.isReachable {
                print("✅ Watch became reachable")
                sendUpdateToWatch()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            if let action = message["action"] as? String {
                switch action {
                case "requestUpdate":
                    let data = await prepareWatchUpdateData()
                    replyHandler(data)

                case "logEntry":
                    if let isQuiet = message["isQuiet"] as? Bool,
                       let timestamp = message["timestamp"] as? TimeInterval {
                        handleLogEntry(isQuiet: isQuiet, timestamp: timestamp)
                        replyHandler(["status": "success"])
                    } else {
                        replyHandler(["status": "error", "message": "Invalid log entry data"])
                    }

                default:
                    replyHandler(["status": "error", "message": "Unknown action"])
                }
            } else {
                replyHandler(["status": "error", "message": "No action specified"])
            }
        }
    }
}
