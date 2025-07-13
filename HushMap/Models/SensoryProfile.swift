import Foundation
import SwiftData

@Model
class SensoryProfile {
    @Attribute(.unique) var id: UUID = UUID()
    
    // User preferences for each sensory dimension (0.0 = very sensitive, 1.0 = not sensitive)
    var noisePreference: Double // User's tolerance for noise
    var crowdsPreference: Double // User's tolerance for crowds
    var lightingPreference: Double // User's tolerance for bright lighting
    
    // Learning metrics - track user behavior patterns
    var totalReports: Int = 0 // Number of reports user has submitted
    var averageNoiseRating: Double = 0.0 // Average noise level user reports
    var averageCrowdsRating: Double = 0.0 // Average crowds level user reports
    var averageLightingRating: Double = 0.0 // Average lighting level user reports
    
    // Comfort-based learning metrics
    var comfortableNoiseSum: Double = 0.0 // Sum of noise levels when comfortable
    var comfortableCrowdsSum: Double = 0.0 // Sum of crowds levels when comfortable
    var comfortableLightingSum: Double = 0.0 // Sum of lighting levels when comfortable
    var comfortableReportsCount: Int = 0 // Count of comfortable reports
    
    // Preference confidence (0.0 = uncertain, 1.0 = very confident)
    var confidenceScore: Double = 0.0
    
    // Timestamps
    var createdAt: Date
    var lastUpdated: Date
    
    // Relationship to user
    @Relationship(inverse: \User.sensoryProfile) var user: User?
    
    init(noisePreference: Double = 0.5, crowdsPreference: Double = 0.5, lightingPreference: Double = 0.5) {
        self.id = UUID()
        self.noisePreference = noisePreference
        self.crowdsPreference = crowdsPreference
        self.lightingPreference = lightingPreference
        self.createdAt = Date()
        self.lastUpdated = Date()
    }
    
    // MARK: - Learning Algorithm
    
    /// Updates the sensory profile based on a new report
    func updateFromReport(_ report: Report) {
        totalReports += 1
        lastUpdated = Date()
        
        // Update running averages
        let weight = 1.0 / Double(totalReports)
        let oldWeight = 1.0 - weight
        
        averageNoiseRating = (averageNoiseRating * oldWeight) + (report.noise * weight)
        averageCrowdsRating = (averageCrowdsRating * oldWeight) + (report.crowds * weight)
        averageLightingRating = (averageLightingRating * oldWeight) + (report.lighting * weight)
        
        // Track comfortable experiences (comfort > 0.6)
        if report.comfort > 0.6 {
            comfortableNoiseSum += report.noise
            comfortableCrowdsSum += report.crowds
            comfortableLightingSum += report.lighting
            comfortableReportsCount += 1
        }
        
        // Learn preferences based on comfort correlation
        updatePreferences()
        updateConfidence()
    }
    
    private func updatePreferences() {
        // Use comfort-based learning: preferences are the average sensory levels
        // from reports where the user felt comfortable (comfort > 0.6)
        
        if comfortableReportsCount > 0 {
            // Calculate average sensory levels from comfortable experiences
            let avgComfortableNoise = comfortableNoiseSum / Double(comfortableReportsCount)
            let avgComfortableCrowds = comfortableCrowdsSum / Double(comfortableReportsCount)
            let avgComfortableLighting = comfortableLightingSum / Double(comfortableReportsCount)
            
            // Blend with existing preferences using exponential moving average
            // This prevents wild swings and allows gradual learning
            let learningRate = 0.3 // How quickly to adapt (0.0 = no change, 1.0 = instant change)
            
            noisePreference = (noisePreference * (1.0 - learningRate)) + (avgComfortableNoise * learningRate)
            crowdsPreference = (crowdsPreference * (1.0 - learningRate)) + (avgComfortableCrowds * learningRate)
            lightingPreference = (lightingPreference * (1.0 - learningRate)) + (avgComfortableLighting * learningRate)
        } else if totalReports > 0 {
            // If no comfortable reports yet, use inverse correlation
            // High reported levels with assumed discomfort = low preference
            noisePreference = min(1.0, max(0.0, 1.0 - averageNoiseRating))
            crowdsPreference = min(1.0, max(0.0, 1.0 - averageCrowdsRating))
            lightingPreference = min(1.0, max(0.0, 1.0 - averageLightingRating))
        }
        
        // Ensure preferences stay within valid range
        noisePreference = min(1.0, max(0.0, noisePreference))
        crowdsPreference = min(1.0, max(0.0, crowdsPreference))
        lightingPreference = min(1.0, max(0.0, lightingPreference))
    }
    
    private func updateConfidence() {
        // Confidence increases with more reports, but plateaus
        // Uses logarithmic function to prevent infinite growth
        if totalReports > 0 {
            confidenceScore = min(1.0, log(Double(totalReports) + 1) / log(11)) // Reaches ~0.9 at 10 reports
        }
    }
    
    // MARK: - Recommendation Logic
    
    /// Calculates compatibility score for a place (0.0 = incompatible, 1.0 = perfect match)
    func compatibilityScore(for averageNoise: Double, crowds: Double, lighting: Double) -> Double {
        let noiseScore = 1.0 - abs(noisePreference - averageNoise)
        let crowdsScore = 1.0 - abs(crowdsPreference - crowds)
        let lightingScore = 1.0 - abs(lightingPreference - lighting)
        
        // Weight by confidence - if we're not confident about preferences, be more lenient
        let weightedScore = (noiseScore + crowdsScore + lightingScore) / 3.0
        return (weightedScore * confidenceScore) + (0.5 * (1.0 - confidenceScore))
    }
    
    /// Determines if a place should trigger a warning notification
    func shouldWarnFor(noise: Double, crowds: Double, lighting: Double, threshold: Double = 0.3) -> (shouldWarn: Bool, reasons: [String]) {
        var reasons: [String] = []
        
        // Only warn if we're confident about preferences
        guard confidenceScore > 0.3 else { return (false, []) }
        
        // Check each dimension for potential issues
        if noise > noisePreference + threshold {
            reasons.append("louder than your preference")
        }
        
        if crowds > crowdsPreference + threshold {
            reasons.append("more crowded than your preference")
        }
        
        if lighting > lightingPreference + threshold {
            reasons.append("brighter than your preference")
        }
        
        return (reasons.count > 0, reasons)
    }
    
    // MARK: - User-friendly descriptions
    
    var noiseToleranceDescription: String {
        switch noisePreference {
        case 0.0..<0.3: return "Prefers quiet environments"
        case 0.3..<0.7: return "Moderate noise tolerance"
        default: return "Comfortable with loud environments"
        }
    }
    
    var crowdsToleranceDescription: String {
        switch crowdsPreference {
        case 0.0..<0.3: return "Prefers uncrowded spaces"
        case 0.3..<0.7: return "Moderate crowd tolerance"
        default: return "Comfortable with busy spaces"
        }
    }
    
    var lightingToleranceDescription: String {
        switch lightingPreference {
        case 0.0..<0.3: return "Prefers dim lighting"
        case 0.3..<0.7: return "Moderate lighting preference"
        default: return "Comfortable with bright lighting"
        }
    }
    
    var overallProfileDescription: String {
        if confidenceScore < 0.2 {
            return "Still learning your preferences..."
        } else if confidenceScore < 0.5 {
            return "Building your sensory profile..."
        } else {
            return "Well-established sensory profile"
        }
    }
}