import Foundation
import SwiftUI
import CoreLocation

// Sensory level classification for predictions
enum SensoryLevel: String, Codable, CaseIterable {
    case veryLow = "Very Low"
    case low = "Low" 
    case moderate = "Moderate"
    case high = "High"
    case veryHigh = "Very High"
    case varies = "Varies"
    
    // User-facing description
    var description: String {
        switch self {
        case .veryLow:
            return "Minimal impact expected"
        case .low:
            return "Minor impact possible"
        case .moderate:
            return "Moderate impact likely"
        case .high:
            return "Significant impact expected"
        case .veryHigh:
            return "Extreme impact likely"
        case .varies:
            return "Impact varies throughout the day"
        }
    }
    
    // SF Symbol icon name
    var iconName: String {
        switch self {
        case .veryLow:
            return "1.circle.fill"
        case .low:
            return "2.circle.fill"
        case .moderate:
            return "3.circle.fill"
        case .high:
            return "4.circle.fill"
        case .veryHigh:
            return "5.circle.fill"
        case .varies:
            return "questionmark.circle.fill"
        }
    }
    
    // Color representation
    var color: Color {
        switch self {
        case .veryLow: return .green
        case .low: return .mint
        case .moderate: return .yellow
        case .high: return .orange
        case .veryHigh: return .red
        case .varies: return .purple
        }
    }
}

// Confidence level for predictions
enum ConfidenceLevel: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium" 
    case high = "High"
    
    // User-facing description
    var description: String {
        switch self {
        case .low:
            return "Limited data available"
        case .medium:
            return "Based on moderate evidence"
        case .high:
            return "Based on substantial evidence"
        }
    }
}

// Request model for venue prediction
struct VenuePredictionRequest: Codable {
    let venueName: String
    let venueType: String
    let location: String
    let dayOfWeek: String
    let timeOfDay: String
    let weather: String
    let userReportsSummary: String
}

// Response model for venue prediction
struct VenuePredictionResponse: Identifiable {
    var id: UUID
    let summary: String
    let noiseLevel: SensoryLevel
    let crowdLevel: SensoryLevel
    let lightingLevel: SensoryLevel
    let confidence: ConfidenceLevel
    let timestamp: Date
    
    // For use without storing the prediction (transient)
    // Not included in Codable conformance
    var coordinate: CLLocationCoordinate2D?
}

// Extension to handle Codable conformance
extension VenuePredictionResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case id, summary, noiseLevel, crowdLevel, lightingLevel, confidence, timestamp
        // coordinate is intentionally excluded as CLLocationCoordinate2D is not Codable
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        summary = try container.decode(String.self, forKey: .summary)
        noiseLevel = try container.decode(SensoryLevel.self, forKey: .noiseLevel)
        crowdLevel = try container.decode(SensoryLevel.self, forKey: .crowdLevel)
        lightingLevel = try container.decode(SensoryLevel.self, forKey: .lightingLevel)
        confidence = try container.decode(ConfidenceLevel.self, forKey: .confidence)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        coordinate = nil // Not included in Codable
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(summary, forKey: .summary)
        try container.encode(noiseLevel, forKey: .noiseLevel)
        try container.encode(crowdLevel, forKey: .crowdLevel)
        try container.encode(lightingLevel, forKey: .lightingLevel)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(timestamp, forKey: .timestamp)
        // coordinate is intentionally excluded as CLLocationCoordinate2D is not Codable
    }
    
    // Custom initializer moved to extension to avoid conflict with memberwise initializer
}

// Convenience initializer in extension
extension VenuePredictionResponse {
    // This initializer allows setting default values and coordinate in a type-safe way
    static func create(
        id: UUID = UUID(),
        summary: String,
        noiseLevel: SensoryLevel,
        crowdLevel: SensoryLevel,
        lightingLevel: SensoryLevel,
        confidence: ConfidenceLevel,
        timestamp: Date = Date(),
        coordinate: CLLocationCoordinate2D? = nil
    ) -> VenuePredictionResponse {
        var response = VenuePredictionResponse(
            id: id,
            summary: summary,
            noiseLevel: noiseLevel,
            crowdLevel: crowdLevel,
            lightingLevel: lightingLevel,
            confidence: confidence,
            timestamp: timestamp
        )
        response.coordinate = coordinate
        return response
    }
}

// Sample venue types for prediction
enum VenueType: String, CaseIterable {
    case cafe = "Café"
    case restaurant = "Restaurant"
    case library = "Library"
    case park = "Park"
    case shoppingMall = "Shopping Mall"
    case museum = "Museum"
    case cinema = "Cinema"
    case gym = "Gym"
    case bar = "Bar"
    case office = "Office"
    case publicTransport = "Public Transport"
    case hospital = "Hospital"
    case school = "School"
    case university = "University"
    case beach = "Beach"
    case concert = "Concert Venue"
}

// Sample weather conditions
enum WeatherCondition: String, CaseIterable {
    case sunny = "Sunny"
    case cloudy = "Cloudy"
    case rainy = "Rainy"
    case snowy = "Snowy"
    case windy = "Windy"
    case stormy = "Stormy"
    case foggy = "Foggy"
    case heatwave = "Heatwave"
    case cold = "Cold"
}

// Sample days of the week
enum DayOfWeek: String, CaseIterable {
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"
    case sunday = "Sunday"
}