import Foundation
import SwiftData

@Model
final class Badge {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String
    var descriptionText: String
    var iconName: String
    var earnedDate: Date = Date()
    
    // Relationship to User (will be set up later)
    @Relationship(inverse: \User.badges) var user: User?
    
    init(title: String, description: String, iconName: String, earnedDate: Date = .now) {
        self.id = UUID()
        self.title = title
        self.descriptionText = description
        self.iconName = iconName
        self.earnedDate = earnedDate
    }
}

// Badge types for the system
enum BadgeType: String, CaseIterable {
    case firstReport = "First Report"
    case threeReportsWeek = "3 Reports This Week"
    case threeUniqueLocations = "Explorer"
    case lowNoiseReport = "Silence Seeker"
    case lowCrowdReport = "Solitude Finder" 
    case perfectLighting = "Perfect Light"
    
    var description: String {
        switch self {
        case .firstReport:
            return "Submitted your first noise report"
        case .threeReportsWeek:
            return "Submitted 3 reports in a single week"
        case .threeUniqueLocations:
            return "Visited 3 different locations"
        case .lowNoiseReport:
            return "Found a place with noise level below 0.2"
        case .lowCrowdReport:
            return "Found a place with crowd level below 0.2"
        case .perfectLighting:
            return "Found a place with ideal lighting (0.4-0.6)"
        }
    }
    
    var iconName: String {
        switch self {
        case .firstReport:
            return "1.circle.fill"
        case .threeReportsWeek:
            return "3.circle.fill"
        case .threeUniqueLocations:
            return "map.fill"
        case .lowNoiseReport:
            return "ear.fill"
        case .lowCrowdReport:
            return "person.fill"
        case .perfectLighting:
            return "lightbulb.fill"
        }
    }
}