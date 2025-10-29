import Foundation
import SwiftData

@Model
final class Badge {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String
    var descriptionText: String
    var iconName: String
    var earnedDate: Date = Date()
    var bonusPoints: Int = 0 // Points awarded for earning this badge

    // Relationship to User (will be set up later)
    @Relationship(inverse: \User.badges) var user: User?

    init(title: String, description: String, iconName: String, bonusPoints: Int = 0, earnedDate: Date = .now) {
        self.id = UUID()
        self.title = title
        self.descriptionText = description
        self.iconName = iconName
        self.bonusPoints = bonusPoints
        self.earnedDate = earnedDate
    }
}

// Badge types for the system
enum BadgeType: String, CaseIterable {
    // Basic Achievement Badges
    case firstReport = "First Report"
    case threeReportsWeek = "3 Reports This Week"
    case threeUniqueLocations = "Explorer"

    // Sensory Discovery Badges
    case lowNoiseReport = "Silence Seeker"
    case lowCrowdReport = "Solitude Finder"
    case perfectLighting = "Perfect Light"
    case perfectComfort = "Comfort Champion"

    // Milestone Badges
    case tenReports = "Getting Started"
    case twentyFiveReports = "Community Builder"
    case fiftyReports = "Sensory Champion"
    case hundredReports = "Accessibility Hero"

    // Streak Badges
    case threeDayStreak = "Consistent Explorer"
    case weekStreak = "Dedicated Mapper"
    case monthStreak = "Sensory Guardian"

    // Venue-Specific Badges
    case libraryLover = "Library Lover"
    case cafeCritic = "Cafe Connoisseur"
    case parkPioneer = "Park Pioneer"

    // Profile & Special Badges
    case profileBuilder = "Self-Aware"
    case earlyBird = "Early Explorer"
    case nightOwl = "Night Owl"

    var description: String {
        switch self {
        // Basic Achievement Badges
        case .firstReport:
            return "Submitted your first sensory report"
        case .threeReportsWeek:
            return "Submitted 3 reports in a single week"
        case .threeUniqueLocations:
            return "Visited 3 different locations"

        // Sensory Discovery Badges
        case .lowNoiseReport:
            return "Found a place with noise level below 0.2"
        case .lowCrowdReport:
            return "Found a place with crowd level below 0.2"
        case .perfectLighting:
            return "Found a place with ideal lighting (0.4-0.6)"
        case .perfectComfort:
            return "Found a place with comfort level above 0.8"

        // Milestone Badges
        case .tenReports:
            return "Submitted 10 sensory reports"
        case .twentyFiveReports:
            return "Submitted 25 sensory reports"
        case .fiftyReports:
            return "Submitted 50 sensory reports"
        case .hundredReports:
            return "Submitted 100 sensory reports"

        // Streak Badges
        case .threeDayStreak:
            return "Submitted reports for 3 days in a row"
        case .weekStreak:
            return "Submitted reports for 7 days in a row"
        case .monthStreak:
            return "Submitted reports for 30 days in a row"

        // Venue-Specific Badges
        case .libraryLover:
            return "Submitted 5 reports at libraries"
        case .cafeCritic:
            return "Submitted 5 reports at cafes or restaurants"
        case .parkPioneer:
            return "Submitted 5 reports at parks or outdoor spaces"

        // Profile & Special Badges
        case .profileBuilder:
            return "Built a sensory profile with 10+ reports"
        case .earlyBird:
            return "Submitted a report between 6am-9am"
        case .nightOwl:
            return "Submitted a report between 9pm-12am"
        }
    }

    var iconName: String {
        switch self {
        // Basic Achievement Badges
        case .firstReport:
            return "1.circle.fill"
        case .threeReportsWeek:
            return "3.circle.fill"
        case .threeUniqueLocations:
            return "map.fill"

        // Sensory Discovery Badges
        case .lowNoiseReport:
            return "ear.fill"
        case .lowCrowdReport:
            return "person.fill"
        case .perfectLighting:
            return "lightbulb.fill"
        case .perfectComfort:
            return "heart.fill"

        // Milestone Badges
        case .tenReports:
            return "10.circle.fill"
        case .twentyFiveReports:
            return "25.circle.fill"
        case .fiftyReports:
            return "50.circle.fill"
        case .hundredReports:
            return "100.circle.fill"

        // Streak Badges
        case .threeDayStreak:
            return "flame.fill"
        case .weekStreak:
            return "flame.circle.fill"
        case .monthStreak:
            return "crown.fill"

        // Venue-Specific Badges
        case .libraryLover:
            return "books.vertical.fill"
        case .cafeCritic:
            return "cup.and.saucer.fill"
        case .parkPioneer:
            return "tree.fill"

        // Profile & Special Badges
        case .profileBuilder:
            return "brain.head.profile"
        case .earlyBird:
            return "sunrise.fill"
        case .nightOwl:
            return "moon.stars.fill"
        }
    }

    /// Bonus points awarded when this badge is earned
    var bonusPoints: Int {
        switch self {
        // Basic Achievement Badges - Small bonuses
        case .firstReport:
            return 25
        case .threeReportsWeek:
            return 30
        case .threeUniqueLocations:
            return 35

        // Sensory Discovery Badges - Medium bonuses
        case .lowNoiseReport:
            return 40
        case .lowCrowdReport:
            return 40
        case .perfectLighting:
            return 40
        case .perfectComfort:
            return 50

        // Milestone Badges - Large bonuses (scales with difficulty)
        case .tenReports:
            return 100
        case .twentyFiveReports:
            return 250
        case .fiftyReports:
            return 500
        case .hundredReports:
            return 1000

        // Streak Badges - Growing bonuses
        case .threeDayStreak:
            return 75
        case .weekStreak:
            return 150
        case .monthStreak:
            return 500

        // Venue-Specific Badges - Medium bonuses
        case .libraryLover:
            return 60
        case .cafeCritic:
            return 60
        case .parkPioneer:
            return 60

        // Profile & Special Badges - Small to medium
        case .profileBuilder:
            return 100
        case .earlyBird:
            return 30
        case .nightOwl:
            return 30
        }
    }
}