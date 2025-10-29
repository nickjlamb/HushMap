import Foundation
import CoreLocation

struct Place: Codable, Identifiable {
    let id: UUID
    let name: String
    let emoji: String
    let latitude: Double
    let longitude: Double
    let distance: Double // in meters
    let quietScore: Int

    var formattedDistance: String {
        if distance < 1000 {
            return "\(Int(distance))m away"
        } else {
            let km = distance / 1000
            return String(format: "%.1fkm away", km)
        }
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Preview Data

extension Place {
    static let preview = Place(
        id: UUID(),
        name: "Quiet Cafe",
        emoji: "☕️",
        latitude: 37.7749,
        longitude: -122.4194,
        distance: 150,
        quietScore: 85
    )

    static let previewNoisy = Place(
        id: UUID(),
        name: "Busy Street",
        emoji: "🚗",
        latitude: 37.7749,
        longitude: -122.4194,
        distance: 50,
        quietScore: 35
    )
}
