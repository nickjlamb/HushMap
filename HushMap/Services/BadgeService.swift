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

        // MARK: - Basic Achievement Badges

        // First Report badge
        if user.reports.count == 1 && !user.hasBadge(ofType: .firstReport) {
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

        // MARK: - Sensory Discovery Badges

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

        // Perfect Comfort badge
        if newReport.comfort > 0.8 && !user.hasBadge(ofType: .perfectComfort) {
            if let badge = user.awardBadge(ofType: .perfectComfort) {
                newlyEarnedBadges.append(badge)
            }
        }

        // MARK: - Milestone Badges

        let reportCount = user.reports.count

        if reportCount >= 10 && !user.hasBadge(ofType: .tenReports) {
            if let badge = user.awardBadge(ofType: .tenReports) {
                newlyEarnedBadges.append(badge)
            }
        }

        if reportCount >= 25 && !user.hasBadge(ofType: .twentyFiveReports) {
            if let badge = user.awardBadge(ofType: .twentyFiveReports) {
                newlyEarnedBadges.append(badge)
            }
        }

        if reportCount >= 50 && !user.hasBadge(ofType: .fiftyReports) {
            if let badge = user.awardBadge(ofType: .fiftyReports) {
                newlyEarnedBadges.append(badge)
            }
        }

        if reportCount >= 100 && !user.hasBadge(ofType: .hundredReports) {
            if let badge = user.awardBadge(ofType: .hundredReports) {
                newlyEarnedBadges.append(badge)
            }
        }

        // MARK: - Streak Badges

        let currentStreak = calculateCurrentStreak(for: user)

        if currentStreak >= 3 && !user.hasBadge(ofType: .threeDayStreak) {
            if let badge = user.awardBadge(ofType: .threeDayStreak) {
                newlyEarnedBadges.append(badge)
            }
        }

        if currentStreak >= 7 && !user.hasBadge(ofType: .weekStreak) {
            if let badge = user.awardBadge(ofType: .weekStreak) {
                newlyEarnedBadges.append(badge)
            }
        }

        if currentStreak >= 30 && !user.hasBadge(ofType: .monthStreak) {
            if let badge = user.awardBadge(ofType: .monthStreak) {
                newlyEarnedBadges.append(badge)
            }
        }

        // MARK: - Venue-Specific Badges

        // Library Lover badge
        let libraryReports = user.reports.filter { isLibrary($0) }
        if libraryReports.count >= 5 && !user.hasBadge(ofType: .libraryLover) {
            if let badge = user.awardBadge(ofType: .libraryLover) {
                newlyEarnedBadges.append(badge)
            }
        }

        // Cafe Critic badge
        let cafeReports = user.reports.filter { isCafeOrRestaurant($0) }
        if cafeReports.count >= 5 && !user.hasBadge(ofType: .cafeCritic) {
            if let badge = user.awardBadge(ofType: .cafeCritic) {
                newlyEarnedBadges.append(badge)
            }
        }

        // Park Pioneer badge
        let parkReports = user.reports.filter { isPark($0) }
        if parkReports.count >= 5 && !user.hasBadge(ofType: .parkPioneer) {
            if let badge = user.awardBadge(ofType: .parkPioneer) {
                newlyEarnedBadges.append(badge)
            }
        }

        // MARK: - Profile & Special Badges

        // Profile Builder badge
        if reportCount >= 10 && user.sensoryProfile != nil && !user.hasBadge(ofType: .profileBuilder) {
            if let badge = user.awardBadge(ofType: .profileBuilder) {
                newlyEarnedBadges.append(badge)
            }
        }

        // Time-based badges
        let hour = Calendar.current.component(.hour, from: newReport.timestamp)

        // Early Bird badge (6am-9am)
        if hour >= 6 && hour < 9 && !user.hasBadge(ofType: .earlyBird) {
            if let badge = user.awardBadge(ofType: .earlyBird) {
                newlyEarnedBadges.append(badge)
            }
        }

        // Night Owl badge (9pm-12am)
        if hour >= 21 && hour < 24 && !user.hasBadge(ofType: .nightOwl) {
            if let badge = user.awardBadge(ofType: .nightOwl) {
                newlyEarnedBadges.append(badge)
            }
        }

        return newlyEarnedBadges
    }

    // MARK: - Helper Methods

    /// Calculate the current consecutive day streak for a user
    private func calculateCurrentStreak(for user: User) -> Int {
        let calendar = Calendar.current
        let sortedReports = user.reports.sorted { $0.timestamp > $1.timestamp }

        guard let mostRecentReport = sortedReports.first else { return 0 }

        // Check if the most recent report was today or yesterday
        let today = calendar.startOfDay(for: Date())
        let mostRecentDay = calendar.startOfDay(for: mostRecentReport.timestamp)
        let daysDifference = calendar.dateComponents([.day], from: mostRecentDay, to: today).day ?? 0

        // Streak is broken if last report was more than 1 day ago
        if daysDifference > 1 { return 0 }

        var streak = 0
        var currentDay = today

        for report in sortedReports {
            let reportDay = calendar.startOfDay(for: report.timestamp)

            // Check if this report is from the current streak day
            if reportDay == currentDay {
                continue // Same day, keep looking
            } else if reportDay == calendar.date(byAdding: .day, value: -1, to: currentDay) {
                // Previous day - continue streak
                streak += 1
                currentDay = reportDay
            } else {
                // Gap in streak - stop counting
                break
            }
        }

        // Add 1 for today if there's a report today
        if calendar.isDateInToday(mostRecentReport.timestamp) {
            streak += 1
        }

        return streak
    }

    /// Check if a report is from a library
    private func isLibrary(_ report: Report) -> Bool {
        guard let displayName = report.displayName?.lowercased() else { return false }
        return displayName.contains("library") || displayName.contains("библиотека")
    }

    /// Check if a report is from a cafe or restaurant
    private func isCafeOrRestaurant(_ report: Report) -> Bool {
        guard let displayName = report.displayName?.lowercased() else { return false }
        let keywords = ["cafe", "café", "coffee", "restaurant", "bistro", "eatery", "diner", "bakery"]
        return keywords.contains { displayName.contains($0) }
    }

    /// Check if a report is from a park or outdoor space
    private func isPark(_ report: Report) -> Bool {
        guard let displayName = report.displayName?.lowercased() else { return false }
        let keywords = ["park", "garden", "trail", "plaza", "square", "green", "outdoor"]
        return keywords.contains { displayName.contains($0) }
    }

    // MARK: - Badge Progress Tracking

    /// Get progress toward badges the user hasn't earned yet
    func getBadgeProgress(for user: User) -> [BadgeProgress] {
        var progressList: [BadgeProgress] = []

        for badgeType in BadgeType.allCases {
            // Skip badges already earned
            if user.hasBadge(ofType: badgeType) {
                continue
            }

            if let progress = calculateProgress(for: badgeType, user: user) {
                progressList.append(progress)
            }
        }

        // Sort by completion percentage (closest to completion first)
        return progressList.sorted { $0.percentage > $1.percentage }
    }

    /// Calculate progress for a specific badge type
    private func calculateProgress(for badgeType: BadgeType, user: User) -> BadgeProgress? {
        let reportCount = user.reports.count

        switch badgeType {
        // Basic Achievement Badges
        case .firstReport:
            return BadgeProgress(
                badgeType: badgeType,
                current: reportCount,
                goal: 1,
                description: "Submit your first report"
            )

        case .threeReportsWeek:
            let reportsThisWeek = user.reports.filter { $0.isFromThisWeek }.count
            return BadgeProgress(
                badgeType: badgeType,
                current: reportsThisWeek,
                goal: 3,
                description: "Submit 3 reports this week"
            )

        case .threeUniqueLocations:
            let uniqueLocations = Set(user.reports.map { $0.locationIdentifier }).count
            return BadgeProgress(
                badgeType: badgeType,
                current: uniqueLocations,
                goal: 3,
                description: "Visit 3 different locations"
            )

        // Sensory Discovery Badges
        case .lowNoiseReport:
            return BadgeProgress(
                badgeType: badgeType,
                current: 0,
                goal: 1,
                description: "Find a place with low noise (< 0.2)"
            )

        case .lowCrowdReport:
            return BadgeProgress(
                badgeType: badgeType,
                current: 0,
                goal: 1,
                description: "Find a place with few crowds (< 0.2)"
            )

        case .perfectLighting:
            return BadgeProgress(
                badgeType: badgeType,
                current: 0,
                goal: 1,
                description: "Find a place with perfect lighting (0.4-0.6)"
            )

        case .perfectComfort:
            return BadgeProgress(
                badgeType: badgeType,
                current: 0,
                goal: 1,
                description: "Find a highly comfortable place (> 0.8)"
            )

        // Milestone Badges
        case .tenReports:
            return BadgeProgress(
                badgeType: badgeType,
                current: reportCount,
                goal: 10,
                description: "Submit 10 reports"
            )

        case .twentyFiveReports:
            return BadgeProgress(
                badgeType: badgeType,
                current: reportCount,
                goal: 25,
                description: "Submit 25 reports"
            )

        case .fiftyReports:
            return BadgeProgress(
                badgeType: badgeType,
                current: reportCount,
                goal: 50,
                description: "Submit 50 reports"
            )

        case .hundredReports:
            return BadgeProgress(
                badgeType: badgeType,
                current: reportCount,
                goal: 100,
                description: "Submit 100 reports"
            )

        // Streak Badges
        case .threeDayStreak:
            let currentStreak = calculateCurrentStreak(for: user)
            return BadgeProgress(
                badgeType: badgeType,
                current: currentStreak,
                goal: 3,
                description: "Submit reports for 3 days in a row"
            )

        case .weekStreak:
            let currentStreak = calculateCurrentStreak(for: user)
            return BadgeProgress(
                badgeType: badgeType,
                current: currentStreak,
                goal: 7,
                description: "Submit reports for 7 days in a row"
            )

        case .monthStreak:
            let currentStreak = calculateCurrentStreak(for: user)
            return BadgeProgress(
                badgeType: badgeType,
                current: currentStreak,
                goal: 30,
                description: "Submit reports for 30 days in a row"
            )

        // Venue-Specific Badges
        case .libraryLover:
            let libraryCount = user.reports.filter { isLibrary($0) }.count
            return BadgeProgress(
                badgeType: badgeType,
                current: libraryCount,
                goal: 5,
                description: "Submit 5 reports at libraries"
            )

        case .cafeCritic:
            let cafeCount = user.reports.filter { isCafeOrRestaurant($0) }.count
            return BadgeProgress(
                badgeType: badgeType,
                current: cafeCount,
                goal: 5,
                description: "Submit 5 reports at cafes"
            )

        case .parkPioneer:
            let parkCount = user.reports.filter { isPark($0) }.count
            return BadgeProgress(
                badgeType: badgeType,
                current: parkCount,
                goal: 5,
                description: "Submit 5 reports at parks"
            )

        // Profile & Special Badges
        case .profileBuilder:
            return BadgeProgress(
                badgeType: badgeType,
                current: user.sensoryProfile != nil ? reportCount : 0,
                goal: 10,
                description: "Build your sensory profile (10 reports)"
            )

        case .earlyBird:
            return BadgeProgress(
                badgeType: badgeType,
                current: 0,
                goal: 1,
                description: "Submit a report between 6am-9am"
            )

        case .nightOwl:
            return BadgeProgress(
                badgeType: badgeType,
                current: 0,
                goal: 1,
                description: "Submit a report between 9pm-12am"
            )
        }
    }

    // MARK: - Points and Report Processing

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
        // Note: report.user and user.reports relationship should already be set by caller
        // SwiftData handles the inverse relationship automatically

        // Award points
        let points = awardPointsForReport(report, to: user)

        // Check for newly earned badges
        let badges = checkAchievements(for: user, with: report)

        // Save changes
        try? modelContext.save()

        return (points, badges)
    }
}

// MARK: - Badge Progress Model

struct BadgeProgress: Identifiable {
    let id = UUID()
    let badgeType: BadgeType
    let current: Int
    let goal: Int
    let description: String

    var percentage: Double {
        guard goal > 0 else { return 0 }
        return min(Double(current) / Double(goal), 1.0)
    }

    var progressText: String {
        return "\(current)/\(goal)"
    }

    var isComplete: Bool {
        return current >= goal
    }
}