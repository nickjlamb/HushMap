import Foundation
import WatchConnectivity
import Combine

class WCSessionManager: NSObject, ObservableObject {
    static let shared = WCSessionManager()

    @Published var isConnected: Bool = false
    @Published var quietScore: Int = 50
    @Published var nearestPlace: Place?
    @Published var lastUpdateTime: Date = Date()

    private override init() {
        super.init()

        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func requestUpdate() {
        guard WCSession.default.isReachable else {
            print("iPhone not reachable")
            return
        }

        let message: [String: Any] = ["action": "requestUpdate"]

        WCSession.default.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                self?.handleUpdateReply(reply)
            }
        }) { error in
            print("Error sending message: \(error.localizedDescription)")
        }
    }

    func sendLogEntry(isQuiet: Bool) {
        guard WCSession.default.isReachable else {
            print("iPhone not reachable - log will be queued")
            // Queue the log entry for later
            queueLogEntry(isQuiet: isQuiet)
            return
        }

        let message: [String: Any] = [
            "action": "logEntry",
            "isQuiet": isQuiet,
            "timestamp": Date().timeIntervalSince1970
        ]

        WCSession.default.sendMessage(message, replyHandler: { reply in
            print("Log entry sent successfully")
        }) { error in
            print("Error sending log entry: \(error.localizedDescription)")
            // Queue for retry
            self.queueLogEntry(isQuiet: isQuiet)
        }
    }

    private func handleUpdateReply(_ reply: [String: Any]) {
        if let score = reply["quietScore"] as? Int {
            self.quietScore = score
        }

        if let placeData = reply["nearestPlace"] as? [String: Any],
           let idString = placeData["id"] as? String,
           let id = UUID(uuidString: idString),
           let name = placeData["name"] as? String,
           let emoji = placeData["emoji"] as? String,
           let latitude = placeData["latitude"] as? Double,
           let longitude = placeData["longitude"] as? Double,
           let distance = placeData["distance"] as? Double,
           let quietScore = placeData["quietScore"] as? Int {

            self.nearestPlace = Place(
                id: id,
                name: name,
                emoji: emoji,
                latitude: latitude,
                longitude: longitude,
                distance: distance,
                quietScore: quietScore
            )
        } else {
            self.nearestPlace = nil
        }

        self.lastUpdateTime = Date()
    }

    private func queueLogEntry(isQuiet: Bool) {
        // Store in UserDefaults for later sync
        var queue = UserDefaults.standard.array(forKey: "queuedLogEntries") as? [[String: Any]] ?? []
        queue.append([
            "isQuiet": isQuiet,
            "timestamp": Date().timeIntervalSince1970
        ])
        UserDefaults.standard.set(queue, forKey: "queuedLogEntries")
        print("Queued log entry for later sync")
    }

    func syncQueuedEntries() {
        guard WCSession.default.isReachable else { return }
        guard let queue = UserDefaults.standard.array(forKey: "queuedLogEntries") as? [[String: Any]], !queue.isEmpty else {
            return
        }

        print("Syncing \(queue.count) queued log entries")

        // Send all queued entries
        for entry in queue {
            let message: [String: Any] = [
                "action": "logEntry",
                "isQuiet": entry["isQuiet"] as? Bool ?? true,
                "timestamp": entry["timestamp"] as? TimeInterval ?? Date().timeIntervalSince1970
            ]

            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("Error syncing queued entry: \(error.localizedDescription)")
            }
        }

        // Clear queue after sending
        UserDefaults.standard.removeObject(forKey: "queuedLogEntries")
    }
}

// MARK: - WCSessionDelegate

extension WCSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated && session.isReachable

            if self.isConnected {
                // Sync any queued entries
                self.syncQueuedEntries()
                // Request initial update
                self.requestUpdate()
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = session.isReachable

            if self.isConnected {
                // Sync queued entries when connection is restored
                self.syncQueuedEntries()
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.handleUpdateReply(message)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.handleUpdateReply(applicationContext)
        }
    }
}
