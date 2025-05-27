import SwiftUI

struct VenuePredictionCardView: View {
    let prediction: VenuePredictionResponse
    let venue: VenuePredictionRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with venue info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(venue.venueName)
                        .font(.headline)
                    
                    Text(venue.venueType)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(venue.dayOfWeek)
                        .font(.subheadline)
                    
                    Text(venue.timeOfDay)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Prediction summary
            Text(prediction.summary)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            
            // Sensory levels
            HStack(spacing: 12) {
                SensoryLevelPill(title: "Noise", level: prediction.noiseLevel, iconName: "speaker.wave.3")
                SensoryLevelPill(title: "Crowd", level: prediction.crowdLevel, iconName: "person.2")
                SensoryLevelPill(title: "Light", level: prediction.lightingLevel, iconName: "lightbulb")
            }
            
            // Footer with confidence
            HStack {
                Spacer()
                
                Text("Based on \(prediction.confidence.rawValue.lowercased()) confidence")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct SensoryLevelPill: View {
    let title: String
    let level: SensoryLevel
    let iconName: String
    
    var body: some View {
        VStack {
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 10))
                Text(title)
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(8)
            
            Text(level.rawValue)
                .font(.caption)
                .foregroundColor(level.color)
        }
    }
}

struct VenuePredictionCardView_Previews: PreviewProvider {
    static var previews: some View {
        // Sample prediction
        let sampleRequest = VenuePredictionRequest(
            venueName: "The Roastery Café",
            venueType: "Café",
            location: "London, UK",
            dayOfWeek: "Saturday",
            timeOfDay: "4:00 PM",
            weather: "Rainy",
            userReportsSummary: "Typically quiet in the mornings, busier after 3 PM on weekends. Lighting is soft and warm."
        )
        
        let samplePrediction = VenuePredictionResponse.create(
            summary: "This café is usually quiet in the mornings but tends to get busier and louder after 3 PM on weekends. The lighting is generally soft and calming.",
            noiseLevel: .high,
            crowdLevel: .high,
            lightingLevel: .low,
            confidence: .medium
        )
        
        return VenuePredictionCardView(prediction: samplePrediction, venue: sampleRequest)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}