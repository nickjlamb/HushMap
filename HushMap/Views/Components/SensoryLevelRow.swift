import SwiftUI

struct SensoryLevelRow: View {
    let title: String
    let level: SensoryLevel
    let iconName: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconName)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            // Title and level
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                // Progress bar
                SensoryLevelIndicator(level: level)
            }
            
            Spacer()
            
            // Level indicator badge
            Text(level.rawValue)
                .font(.footnote)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(level.color.opacity(0.2))
                .foregroundColor(level.color)
                .cornerRadius(6)
        }
    }
}

struct SensoryLevelIndicator: View {
    let level: SensoryLevel
    
    // Get progress value based on sensory level
    private var progressValue: Double {
        switch level {
        case .veryLow: return 0.1
        case .low: return 0.3
        case .moderate: return 0.5
        case .high: return 0.7
        case .veryHigh: return 0.9
        case .varies: return 0.5 // Default for varies
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let safeWidth = max(geometry.size.width, 1) // Ensure width is never zero
            
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .frame(width: safeWidth, height: 8)
                    .opacity(0.2)
                    .foregroundColor(.gray)
                    .cornerRadius(4)
                
                // Foreground
                if level == .varies {
                    // Special striped pattern for "varies"
                    HStack(spacing: 4) {
                        ForEach(0..<5) { i in
                            // Ensure width calculation is safe from NaN
                            let segmentWidth = max(safeWidth / 10, 1)
                            let safeSegmentWidth = segmentWidth.isNaN ? 1 : segmentWidth
                            Rectangle()
                                .frame(width: safeSegmentWidth, height: 8)
                                .foregroundColor(level.color)
                                .cornerRadius(4)
                        }
                    }
                } else {
                    // Standard progress bar
                    // Safely calculate width to prevent NaN values
                    let barWidth = safeWidth * progressValue
                    let safeBarWidth = barWidth.isNaN ? 1 : max(barWidth, 0)
                    Rectangle()
                        .frame(width: safeBarWidth, height: 8)
                        .foregroundColor(level.color)
                        .cornerRadius(4)
                }
            }
        }
        .frame(height: 8)
    }
}

// Preview
struct SensoryLevelRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            SensoryLevelRow(title: "Noise", level: .veryLow, iconName: "speaker.wave.3")
            SensoryLevelRow(title: "Crowds", level: .low, iconName: "person.2")
            SensoryLevelRow(title: "Lighting", level: .moderate, iconName: "lightbulb")
            SensoryLevelRow(title: "Activity", level: .high, iconName: "figure.walk")
            SensoryLevelRow(title: "Intensity", level: .veryHigh, iconName: "bolt.fill")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}