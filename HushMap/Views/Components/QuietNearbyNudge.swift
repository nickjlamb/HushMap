import SwiftUI

/// A subtle, non-intrusive nudge that surfaces nearby quiet places.
/// Shows only when there are places with recent "quiet" Quick Updates visible on the map.
/// Designed to feel like a quiet observation, not a call to action.
struct QuietNearbyNudge: View {
    let pins: [ReportPin]

    /// Filter pins to those with recent quiet updates
    private var quietPlaces: [ReportPin] {
        pins.filter { pin in
            guard let quickUpdate = pin.recentQuickUpdate else { return false }
            return quickUpdate.isRecent && quickUpdate.quietState == .quiet
        }
    }

    /// The most recent quiet update among nearby places
    private var mostRecentQuietUpdate: RecentQuickUpdateInfo? {
        quietPlaces
            .compactMap { $0.recentQuickUpdate }
            .max(by: { $0.timestamp < $1.timestamp })
    }

    /// Generate the nudge text based on quiet places count and recency
    private var nudgeText: String? {
        let count = quietPlaces.count

        guard count > 0 else { return nil }

        if count == 1, let recent = mostRecentQuietUpdate {
            // Single place: show relative time
            return "A quiet place nearby · \(recent.relativeTimeText)"
        } else {
            // Multiple places: show count
            return "\(count) quiet places nearby"
        }
    }

    var body: some View {
        if let text = nudgeText {
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))

                Text(text)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(.systemBackground).opacity(0.85))
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(text)
        }
    }
}

#Preview("Single quiet place") {
    ZStack {
        Color.gray.opacity(0.3)
        QuietNearbyNudge(pins: [
            ReportPin(
                coordinate: .init(latitude: 37.7749, longitude: -122.4194),
                displayName: "Test Cafe",
                displayTier: .poi,
                confidence: 0.9,
                reportCount: 1,
                averageNoise: 0.2,
                averageCrowds: 0.3,
                averageLighting: 0.4,
                averageQuietScore: 80,
                latestTimestamp: Date(),
                submittedByUserName: "Test",
                submittedByUserProfileImageURL: nil,
                recentQuickUpdate: RecentQuickUpdateInfo(quietState: .quiet, timestamp: Date().addingTimeInterval(-600))
            )
        ])
    }
}

#Preview("Multiple quiet places") {
    ZStack {
        Color.gray.opacity(0.3)
        QuietNearbyNudge(pins: [
            ReportPin(
                coordinate: .init(latitude: 37.7749, longitude: -122.4194),
                displayName: "Test Cafe",
                displayTier: .poi,
                confidence: 0.9,
                reportCount: 1,
                averageNoise: 0.2,
                averageCrowds: 0.3,
                averageLighting: 0.4,
                averageQuietScore: 80,
                latestTimestamp: Date(),
                submittedByUserName: "Test",
                submittedByUserProfileImageURL: nil,
                recentQuickUpdate: RecentQuickUpdateInfo(quietState: .quiet, timestamp: Date().addingTimeInterval(-300))
            ),
            ReportPin(
                coordinate: .init(latitude: 37.78, longitude: -122.42),
                displayName: "Test Library",
                displayTier: .poi,
                confidence: 0.9,
                reportCount: 1,
                averageNoise: 0.1,
                averageCrowds: 0.2,
                averageLighting: 0.3,
                averageQuietScore: 90,
                latestTimestamp: Date(),
                submittedByUserName: "Test",
                submittedByUserProfileImageURL: nil,
                recentQuickUpdate: RecentQuickUpdateInfo(quietState: .quiet, timestamp: Date().addingTimeInterval(-900))
            )
        ])
    }
}

#Preview("No quiet places") {
    ZStack {
        Color.gray.opacity(0.3)
        QuietNearbyNudge(pins: [])
        Text("(Nothing should appear above)")
            .foregroundColor(.secondary)
    }
}
