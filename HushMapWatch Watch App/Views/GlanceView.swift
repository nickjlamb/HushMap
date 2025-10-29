import SwiftUI

struct GlanceView: View {
    @StateObject private var sessionManager = WCSessionManager.shared
    @StateObject private var soundMonitor = EnvironmentalSoundMonitor.shared
    @State private var animateScore = false
    
    var scoreColor: Color {
        switch sessionManager.quietScore {
        case 80...100:
            return Color(red: 0.2, green: 0.8, blue: 0.4) // Vibrant green
        case 60..<80:
            return Color(red: 0.0, green: 0.7, blue: 1.0) // Bright blue
        case 40..<60:
            return Color(red: 1.0, green: 0.8, blue: 0.0) // Bright yellow
        case 20..<40:
            return Color(red: 1.0, green: 0.6, blue: 0.0) // Bright orange
        default:
            return Color(red: 1.0, green: 0.3, blue: 0.3) // Bright red
        }
    }

    var soundLevelColor: Color {
        let colorString = soundMonitor.getSoundLevelColor()
        switch colorString {
        case "green": return Color(red: 0.2, green: 0.8, blue: 0.4)
        case "yellow": return Color(red: 1.0, green: 0.8, blue: 0.0)
        case "orange": return Color(red: 1.0, green: 0.6, blue: 0.0)
        case "red": return Color(red: 1.0, green: 0.3, blue: 0.3)
        default: return .gray
        }
    }
    
    var comfortEmoji: String {
        switch sessionManager.quietScore {
        case 80...100:
            return "😌"
        case 60..<80:
            return "🙂"
        case 40..<60:
            return "😐"
        case 20..<40:
            return "😕"
        default:
            return "😣"
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Compact header
                HStack(spacing: 6) {
                    if sessionManager.isConnected {
                        Image(systemName: "iphone")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "iphone.slash")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 4)
                .padding(.bottom, 4)

                // Live Sound Level (compact)
                if let soundLevel = soundMonitor.currentSoundLevel,
                   let measurementDate = soundMonitor.lastMeasurementDate {
                    let measurementAge = Date().timeIntervalSince(measurementDate)
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(soundLevelColor)

                        Text("\(Int(soundLevel)) dB")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        if measurementAge > 60 {
                            Text("(\(Int(measurementAge / 60))m)")
                                .font(.system(size: 9, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(soundLevelColor.opacity(0.2))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(soundLevelColor.opacity(0.4), lineWidth: 1)
                    )
                    .padding(.bottom, 12)
                }

                // Hero Quiet Score Circle
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(
                            scoreColor.opacity(0.25),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )

                    // Animated progress ring
                    Circle()
                        .trim(from: 0, to: CGFloat(sessionManager.quietScore) / 100)
                        .stroke(
                            scoreColor,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .shadow(color: scoreColor.opacity(0.5), radius: 4, x: 0, y: 2)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: sessionManager.quietScore)

                    // Center content
                    VStack(spacing: 0) {
                        Text(comfortEmoji)
                            .font(.system(size: 32))
                            .padding(.bottom, 4)

                        Text("\(sessionManager.quietScore)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [scoreColor, scoreColor.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        Text("QUIET SCORE")
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                            .padding(.top, 2)
                    }
                }
                .frame(width: 120, height: 120)
                .padding(.vertical, 4)

                // Nearest Place Card
                if let place = sessionManager.nearestPlace {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Text(place.emoji)
                                .font(.system(size: 18))

                            Text(place.name)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                                .foregroundStyle(.white)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.green)

                            Text(place.formattedDistance)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .padding(.horizontal, 8)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 10))
                        Text("No nearby data")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                }

                // Last Update
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 8, weight: .medium))
                    Text(sessionManager.lastUpdateTime, style: .relative)
                        .font(.system(size: 9, weight: .regular))
                }
                .foregroundStyle(.tertiary)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 8)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            sessionManager.requestUpdate()

            // Start monitoring environmental sound
            soundMonitor.startMonitoring()

            withAnimation(.easeInOut(duration: 0.5).delay(0.2)) {
                animateScore = true
            }
        }
        .onDisappear {
            // Keep monitoring in background for auto-logging
            // soundMonitor.stopMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("RefreshData"))) { _ in
            sessionManager.requestUpdate()
        }
    }
}

struct GlanceView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            GlanceView()
                .previewDisplayName("With Place")
                .onAppear {
                    WCSessionManager.shared.nearestPlace = Place.preview
                    WCSessionManager.shared.quietScore = 85
                }
            
            GlanceView()
                .previewDisplayName("Noisy Place")
                .onAppear {
                    WCSessionManager.shared.nearestPlace = Place.previewNoisy
                    WCSessionManager.shared.quietScore = 35
                }
            
            GlanceView()
                .previewDisplayName("No Place")
                .onAppear {
                    WCSessionManager.shared.nearestPlace = nil
                    WCSessionManager.shared.quietScore = 50
                }
        }
    }
}