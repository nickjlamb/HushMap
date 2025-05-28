import Foundation
import SwiftData
import CoreLocation

@Model
class Report {
    @Attribute(.unique) var id: UUID = UUID()
    var noise: Double
    var crowds: Double
    var lighting: Double
    var comfort: Double // 0.0 = very uncomfortable, 1.0 = very comfortable
    var comments: String
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var points: Int?
    
    // Relationship to user (owner of the report)
    @Relationship(inverse: \User.reports) var user: User?

    init(noise: Double, crowds: Double, lighting: Double, comfort: Double, comments: String, latitude: Double, longitude: Double, timestamp: Date = .now) {
        self.id = UUID()
        self.noise = noise
        self.crowds = crowds
        self.lighting = lighting
        self.comfort = comfort
        self.comments = comments
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
    }
    
    // Helper computed properties
    
    // Get coordinate
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // Calculate average sensory level
    var averageSensoryLevel: Double {
        return (noise + crowds + lighting) / 3.0
    }
    
    // Check if report is from this week
    var isFromThisWeek: Bool {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return timestamp >= startOfWeek
    }
    
    // Location identifier (for finding unique locations)
    var locationIdentifier: String {
        // Round to 3 decimal places (~100m precision)
        let roundedLat = (latitude * 1000).rounded() / 1000
        let roundedLon = (longitude * 1000).rounded() / 1000
        return "\(roundedLat),\(roundedLon)"
    }
}
