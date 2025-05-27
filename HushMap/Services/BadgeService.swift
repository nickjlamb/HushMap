import Foundation
import SwiftData

class BadgeService {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // Check user's achievements after a new report is submitted
    func checkAchievements(for user: User, with newReport: Report) -> [Badge] {
        var newlyEarnedBadges: [Badge] = []
        
        // First Report badge
        if user.reports.count == 1 {
            if let badge = user.awardBadge(ofType: .firstReport) {
                newlyEarnedBadges.append(badge)
            }
        }
        
        // 3 Reports in a Week badge
        let reportsThisWeek = user.reports.filter { $0.isFromThisWeek }
        if reportsThisWeek.count >= 3 && !user.hasBadge(ofType: .threeReportsWeek) {
            if let badge = user.awardBadge(ofType: .threeReportsWeek) {
                newlyEarnedBadges.append(badge)
            }
        }
        
        // 3 Unique Locations badge
        let uniqueLocations = Set(user.reports.map { $0.locationIdentifier })
        if uniqueLocations.count >= 3 && !user.hasBadge(ofType: .threeUniqueLocations) {
            if let badge = user.awardBadge(ofType: .threeUniqueLocations) {
                newlyEarnedBadges.append(badge)
            }
        }
        
        // Low Noise Report badge
        if newReport.noise < 0.2 && !user.hasBadge(ofType: .lowNoiseReport) {
            if let badge = user.awardBadge(ofType: .lowNoiseReport) {
                newlyEarnedBadges.append(badge)
            }
        }
        
        // Low Crowd Report badge
        if newReport.crowds < 0.2 && !user.hasBadge(ofType: .lowCrowdReport) {
            if let badge = user.awardBadge(ofType: .lowCrowdReport) {
                newlyEarnedBadges.append(badge)
            }
        }
        
        // Perfect Lighting Report badge
        if newReport.lighting >= 0.4 && newReport.lighting <= 0.6 && !user.hasBadge(ofType: .perfectLighting) {
            if let badge = user.awardBadge(ofType: .perfectLighting) {
                newlyEarnedBadges.append(badge)
            }
        }
        
        return newlyEarnedBadges
    }
    
    // Handle points for a new report
    func awardPointsForReport(_ report: Report, to user: User) -> Int {
        let points = user.calculatePointsForReport(report)
        user.addPoints(points)
        report.points = points
        
        // Save the user's last report date
        user.lastReportDate = report.timestamp
        
        return points
    }
    
    // Process a new report - award points and badges
    func processNewReport(_ report: Report, for user: User) -> (points: Int, badges: [Badge]) {
        // Add the report to the user
        report.user = user
        user.reports.append(report)
        
        // Award points
        let points = awardPointsForReport(report, to: user)
        
        // Check for newly earned badges
        let badges = checkAchievements(for: user, with: report)
        
        // Save changes
        try? modelContext.save()
        
        return (points, badges)
    }
}