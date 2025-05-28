import Foundation
import SwiftData

class SensoryProfileService: ObservableObject {
    @Published var currentProfile: SensoryProfile?
    @Published var isLearning: Bool = false
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Profile Management
    
    /// Loads the current user's sensory profile
    func loadCurrentProfile(for user: User) {
        currentProfile = user.sensoryProfile
    }
    
    /// Creates a new sensory profile for a user
    func createProfile(for user: User) -> SensoryProfile {
        let profile = SensoryProfile()
        user.sensoryProfile = profile
        
        // Save to database
        modelContext.insert(profile)
        do {
            try modelContext.save()
            currentProfile = profile
        } catch {
            print("Error creating sensory profile: \(error)")
        }
        
        return profile
    }
    
    /// Updates profile when user submits a new report
    func updateProfile(with report: Report, for user: User) {
        isLearning = true
        
        // Ensure user has a profile
        let profile = user.ensureSensoryProfile()
        
        // Update the profile with new data using simple counting method
        profile.updateFromReport(report)
        
        // Now perform the intelligent comfort-based analysis
        updatePreferencesBasedOnComfort(for: user, profile: profile)
        
        // Save changes
        do {
            try modelContext.save()
            currentProfile = profile
            print("🧠 Updated sensory profile with comfort-based learning: confidence \(profile.confidenceScore)")
        } catch {
            print("Error updating sensory profile: \(error)")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isLearning = false
        }
    }
    
    /// SMART LEARNING: Analyze comfort correlations to learn true preferences
    private func updatePreferencesBasedOnComfort(for user: User, profile: SensoryProfile) {
        // Get all reports for this user
        let allReports = user.reports
        
        guard allReports.count >= 2 else {
            print("🧠 Not enough reports for comfort-based learning (need 2+, have \(allReports.count))")
            return
        }
        
        // Separate comfortable vs uncomfortable experiences
        let comfortableReports = allReports.filter { $0.comfort >= 0.6 } // Comfortable experiences
        let uncomfortableReports = allReports.filter { $0.comfort <= 0.4 } // Uncomfortable experiences
        
        print("🧠 Analyzing \(comfortableReports.count) comfortable vs \(uncomfortableReports.count) uncomfortable reports")
        
        // If we have comfortable experiences, learn from them
        if comfortableReports.count >= 1 {
            let avgNoiseComfortable = comfortableReports.map { $0.noise }.reduce(0, +) / Double(comfortableReports.count)
            let avgCrowdsComfortable = comfortableReports.map { $0.crowds }.reduce(0, +) / Double(comfortableReports.count)
            let avgLightingComfortable = comfortableReports.map { $0.lighting }.reduce(0, +) / Double(comfortableReports.count)
            
            // These averages from comfortable experiences ARE the user's preferences
            profile.noisePreference = min(1.0, max(0.0, avgNoiseComfortable))
            profile.crowdsPreference = min(1.0, max(0.0, avgCrowdsComfortable))
            profile.lightingPreference = min(1.0, max(0.0, avgLightingComfortable))
            
            print("🧠 Learned preferences from comfort: noise=\(String(format: "%.2f", profile.noisePreference)), crowds=\(String(format: "%.2f", profile.crowdsPreference)), lighting=\(String(format: "%.2f", profile.lightingPreference))")
        }
        
        // Increase confidence if we have good data distribution
        if comfortableReports.count >= 2 && allReports.count >= 3 {
            // Boost confidence for having diverse comfort data
            let comfortVariance = allReports.map { $0.comfort }.reduce(0) { sum, comfort in
                sum + abs(comfort - 0.5)
            } / Double(allReports.count)
            
            // More variance in comfort ratings = more reliable learning
            let varianceBonus = min(0.3, comfortVariance * 0.6)
            profile.confidenceScore = min(1.0, profile.confidenceScore + varianceBonus)
            
            print("🧠 Boosted confidence by \(String(format: "%.2f", varianceBonus)) due to comfort variance")
        }
    }
    
    // MARK: - Recommendation Logic
    
    /// Gets personalized place recommendations based on user's sensory profile
    func getPersonalizedRecommendations(from places: [PlaceRecommendation], user: User) -> [PlaceRecommendation] {
        guard let profile = user.sensoryProfile, profile.confidenceScore > 0.2 else {
            // Not enough data for personalization, return original list
            return places
        }
        
        return places.map { place in
            let compatibilityScore = profile.compatibilityScore(
                for: place.averageNoise,
                crowds: place.averageCrowds,
                lighting: place.averageLighting
            )
            
            var personalizedPlace = place
            personalizedPlace.personalizedScore = compatibilityScore
            return personalizedPlace
        }.sorted { $0.personalizedScore > $1.personalizedScore }
    }
    
    /// Checks if a place should trigger a warning notification
    func shouldWarnUser(about place: PlaceRecommendation, user: User) -> (shouldWarn: Bool, reason: String?) {
        guard let profile = user.sensoryProfile else { return (false, nil) }
        
        let result = profile.shouldWarnFor(
            noise: place.averageNoise,
            crowds: place.averageCrowds,
            lighting: place.averageLighting
        )
        
        if result.shouldWarn {
            let reasonText = result.reasons.joined(separator: ", ")
            return (true, "This place may be \(reasonText)")
        }
        
        return (false, nil)
    }
    
    // MARK: - Profile Analysis
    
    /// Gets insights about the user's sensory preferences
    func getProfileInsights(for user: User) -> SensoryProfileInsights? {
        guard let profile = user.sensoryProfile, profile.totalReports > 0 else { return nil }
        
        return SensoryProfileInsights(
            totalReports: profile.totalReports,
            confidenceLevel: profile.confidenceScore,
            noisePreference: profile.noiseToleranceDescription,
            crowdsPreference: profile.crowdsToleranceDescription,
            lightingPreference: profile.lightingToleranceDescription,
            overallDescription: profile.overallProfileDescription,
            lastUpdated: profile.lastUpdated
        )
    }
    
    /// Manually adjusts profile preferences (for user settings)
    func adjustPreferences(
        for user: User,
        noise: Double? = nil,
        crowds: Double? = nil,
        lighting: Double? = nil
    ) {
        let profile = user.ensureSensoryProfile()
        
        if let noise = noise {
            profile.noisePreference = max(0.0, min(1.0, noise))
        }
        if let crowds = crowds {
            profile.crowdsPreference = max(0.0, min(1.0, crowds))
        }
        if let lighting = lighting {
            profile.lightingPreference = max(0.0, min(1.0, lighting))
        }
        
        profile.lastUpdated = Date()
        
        do {
            try modelContext.save()
            currentProfile = profile
        } catch {
            print("Error adjusting profile preferences: \(error)")
        }
    }
    
    // MARK: - Learning Progress
    
    /// Returns the number of reports needed to reach next confidence level
    func reportsNeededForNextLevel(user: User) -> Int? {
        guard let profile = user.sensoryProfile else { return nil }
        
        let currentReports = profile.totalReports
        let nextMilestone: Int
        
        switch currentReports {
        case 0..<3: nextMilestone = 3
        case 3..<5: nextMilestone = 5
        case 5..<10: nextMilestone = 10
        case 10..<20: nextMilestone = 20
        default: return nil // Profile is well-established
        }
        
        return nextMilestone - currentReports
    }
}

// MARK: - Supporting Types

struct SensoryProfileInsights {
    let totalReports: Int
    let confidenceLevel: Double
    let noisePreference: String
    let crowdsPreference: String
    let lightingPreference: String
    let overallDescription: String
    let lastUpdated: Date
    
    var confidenceLevelDescription: String {
        switch confidenceLevel {
        case 0.0..<0.2: return "Just getting started"
        case 0.2..<0.4: return "Learning your preferences"
        case 0.4..<0.6: return "Building confidence"
        case 0.6..<0.8: return "Well-established"
        default: return "Highly confident"
        }
    }
}

// Temporary placeholder for PlaceRecommendation if it doesn't exist
struct PlaceRecommendation {
    let name: String
    let averageNoise: Double
    let averageCrowds: Double
    let averageLighting: Double
    var personalizedScore: Double = 0.5
}