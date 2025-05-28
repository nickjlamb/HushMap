import SwiftUI

struct SensoryPreferenceCard: View {
    let icon: String
    let title: String
    let description: String
    let level: Double
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.hushBackground)
                .frame(height: 24)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            // Level indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.hushBackground.opacity(0.2))
                .frame(height: 4)
                .overlay(
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.hushBackground)
                            .frame(width: max(2, 30 * level))
                        Spacer()
                    }
                )
                .frame(width: 30)
            
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.5))
        )
    }
}

struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                .frame(width: 30, height: 30)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.hushBackground, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 30, height: 30)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(.hushBackground)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 12) {
            SensoryPreferenceCard(
                icon: "speaker.wave.2",
                title: "Noise",
                description: "Prefers quiet",
                level: 0.3
            )
            
            SensoryPreferenceCard(
                icon: "person.3",
                title: "Crowds",
                description: "Moderate tolerance",
                level: 0.6
            )
            
            SensoryPreferenceCard(
                icon: "lightbulb",
                title: "Lighting",
                description: "Comfortable with bright",
                level: 0.8
            )
        }
        
        CircularProgressView(progress: 0.7)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}