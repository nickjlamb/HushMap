import Foundation
import SwiftData
import CoreLocation

// MARK: - Placeholders

enum Placeholders {
    static let nearbyArea = NSLocalizedString("Nearby area", comment: "Fallback location label when specific location cannot be determined")
}

enum DisplayTier: String, Codable, CaseIterable {
    case poi = "poi"
    case street = "street" 
    case area = "area"
}

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
    
    // Location display fields for privacy-aware labeling
    var displayName: String?
    var displayTierRaw: String?
    var locationResolvedAt: Date?
    var locationResolutionVersion: Int?
    var privacyFlagUserRequestedAreaOnly: Bool? // default false
    var confidence: Double? // Location resolution confidence (0.0-1.0)
    var openNow: Bool? // Business hours status from Google Places API

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
    
    // Display tier computed property
    var displayTier: DisplayTier? {
        get { displayTierRaw.flatMap(DisplayTier.init(rawValue:)) }
        set { displayTierRaw = newValue?.rawValue }
    }
    
    // Friendly display name with tier-appropriate formatting and hedged copy
    var friendlyDisplayName: String {
        // If not resolved yet, show deterministic offline placeholder
        guard let displayName = displayName,
              let displayTier = displayTier else {
            return placeholderAreaLabel(for: coordinate)
        }
        
        switch displayTier {
        case .poi:
            // Apply hedged copy for low confidence POIs using config threshold
            let hedgeThreshold = PrivacyLocationConfig.shared.confidenceHedgeThreshold
            if let confidence = confidence, confidence < hedgeThreshold {
                return "near \(displayName)"
            }
            return displayName
        case .street:
            return displayName  
        case .area:
            return sanitizeAreaName(displayName)
        }
    }
    
    // Sanitize area names to prevent redundant suffixes and replace synthetic patterns
    private func sanitizeAreaName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Replace synthetic patterns with "Nearby area"
        let syntheticPattern = "^(Area|Cell|Grid|Zone)\\s*\\d+$"
        if let regex = try? NSRegularExpression(pattern: syntheticPattern, options: [.caseInsensitive]),
           regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)) != nil {
            return Placeholders.nearbyArea
        }
        
        // Avoid appending " area" if it already ends with it
        if trimmed.hasSuffix(" area") {
            return trimmed
        }
        
        return "\(trimmed) area"
    }
    
    // Generate deterministic, offline-safe placeholder for unresolved reports
    private func placeholderAreaLabel(for coordinate: CLLocationCoordinate2D) -> String {
        // Return a stable, deterministic label without network calls
        // This ensures the UI is consistent until backfill completes
        return Placeholders.nearbyArea
    }
    
    // Accessibility-friendly display name with additional context
    var accessibleDisplayName: String {
        let baseName = friendlyDisplayName
        
        // Handle unresolved state
        guard let displayTier = displayTier else {
            return "Area label: \(baseName)"
        }
        
        switch displayTier {
        case .area:
            return "Area label: \(baseName)"
        case .poi:
            if let confidence = confidence, confidence < 0.8 {
                return "Approximate location: \(baseName)"
            }
            return baseName
        case .street:
            return baseName
        }
    }
    
    // Quiet score (0-100) computed from sensory levels for display
    var quietScore: Int {
        // Invert and normalize sensory levels to 0-100 scale
        // Lower sensory levels = higher quiet score
        let invertedAverage = 1.0 - averageSensoryLevel
        return Int((invertedAverage * 100).rounded())
    }
    
    // Location identifier (for finding unique locations)
    var locationIdentifier: String {
        // Round to 3 decimal places (~100m precision)
        let roundedLat = (latitude * 1000).rounded() / 1000
        let roundedLon = (longitude * 1000).rounded() / 1000
        return "\(roundedLat),\(roundedLon)"
    }
}
