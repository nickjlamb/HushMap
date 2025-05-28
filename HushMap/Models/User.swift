import Foundation
import SwiftData

@Model
final class User {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var points: Int = 0
    var lastReportDate: Date?
    
    // Google Sign In integration
    var googleID: String?
    var email: String?
    var profileImageURL: String?
    var isAnonymous: Bool = true
    
    // Relationships
    @Relationship(deleteRule: .cascade) var badges: [Badge] = []
    @Relationship(deleteRule: .cascade) var reports: [Report] = []
    @Relationship(deleteRule: .cascade) var sensoryProfile: SensoryProfile?
    
    init(name: String, points: Int = 0) {
        self.id = UUID()
        self.name = name
        self.points = points
        self.isAnonymous = true
    }
    
    // Initialize with authenticated user data
    init(from authenticatedUser: AuthenticatedUser) {
        self.id = UUID()
        self.name = authenticatedUser.name
        self.email = authenticatedUser.email
        
        switch authenticatedUser.signInMethod {
        case .google:
            self.googleID = authenticatedUser.id
        case .apple:
            // Store Apple ID in a separate field if needed
            self.googleID = nil
        case .none:
            self.googleID = nil
        }
        
        self.profileImageURL = authenticatedUser.profileImageURL?.absoluteString
        self.points = 0
        self.isAnonymous = false
    }
    
    // Helper method to check if a badge type has been earned
    func hasBadge(ofType type: BadgeType) -> Bool {
        return badges.contains { $0.title == type.rawValue }
    }
    
    // Add points to the user
    func addPoints(_ pointsToAdd: Int) {
        self.points += pointsToAdd
    }
    
    // Award a badge if not already earned
    func awardBadge(ofType type: BadgeType) -> Badge? {
        // Check if badge already awarded
        if !hasBadge(ofType: type) {
            let badge = Badge(
                title: type.rawValue,
                description: type.description,
                iconName: type.iconName
            )
            badges.append(badge)
            return badge
        }
        return nil
    }
    
    // Calculate points for a report
    func calculatePointsForReport(_ report: Report) -> Int {
        var totalPoints = 10 // Base points for submission
        
        // Bonus for low average sensory levels (quieter, less crowded, better lighting)
        let averageSensoryLevel = (report.noise + report.crowds + report.lighting) / 3.0
        if averageSensoryLevel < 0.3 {
            totalPoints += 5
        }
        
        return totalPoints
    }
    
    // Ensure user has a sensory profile, create if needed
    func ensureSensoryProfile() -> SensoryProfile {
        if let profile = sensoryProfile {
            return profile
        } else {
            let newProfile = SensoryProfile()
            sensoryProfile = newProfile
            return newProfile
        }
    }
    
    // Update sensory profile when user submits a report
    func updateSensoryProfile(with report: Report) {
        let profile = ensureSensoryProfile()
        profile.updateFromReport(report)
    }
}