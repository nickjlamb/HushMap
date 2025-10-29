import SwiftUI
import WatchKit

struct LogView: View {
    @StateObject private var sessionManager = WCSessionManager.shared
    @StateObject private var soundMonitor = EnvironmentalSoundMonitor.shared
    @State private var showQuietFeedback = false
    @State private var showNoisyFeedback = false
    @State private var hapticFeedback = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Compact title
                Text("LOG NOISE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                    .padding(.top, 2)
                    .padding(.bottom, 8)

                // Show current sound level if available
                if let soundLevel = soundMonitor.currentSoundLevel {
                    HStack(spacing: 5) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(soundMonitor.getSoundLevelColor() == "green" ? Color(red: 0.2, green: 0.8, blue: 0.4) :
                                           soundMonitor.getSoundLevelColor() == "yellow" ? Color(red: 1.0, green: 0.8, blue: 0.0) :
                                           soundMonitor.getSoundLevelColor() == "orange" ? Color(red: 1.0, green: 0.6, blue: 0.0) :
                                           Color(red: 1.0, green: 0.3, blue: 0.3))

                        Text("\(Int(soundLevel)) dB")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(soundMonitor.getSoundLevelEmoji())
                            .font(.system(size: 16))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.bottom, 16)
                }

                // Action Buttons
                VStack(spacing: 12) {
                    // Quiet Button
                    Button(action: logQuiet) {
                        HStack(spacing: 0) {
                            // Icon section
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(red: 0.2, green: 0.8, blue: 0.4).opacity(0.15))
                                    .frame(width: 50, height: 50)

                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.4))
                            }
                            .scaleEffect(showQuietFeedback ? 1.15 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: showQuietFeedback)
                            .padding(.trailing, 12)

                            // Text section
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Quiet")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)

                                Text("It's peaceful here")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("👍")
                                .font(.system(size: 24))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    Color(red: 0.2, green: 0.8, blue: 0.4).opacity(0.3),
                                    lineWidth: 1.5
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Noisy Button
                    Button(action: logNoisy) {
                        HStack(spacing: 0) {
                            // Icon section
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.15))
                                    .frame(width: 50, height: 50)

                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(Color(red: 1.0, green: 0.3, blue: 0.3))
                            }
                            .scaleEffect(showNoisyFeedback ? 1.15 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: showNoisyFeedback)
                            .padding(.trailing, 12)

                            // Text section
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Noisy")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)

                                Text("Too loud for comfort")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("👎")
                                .font(.system(size: 24))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.3),
                                    lineWidth: 1.5
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 12)
                
                // Connection Warning
                if !sessionManager.isConnected {
                    HStack(spacing: 5) {
                        Image(systemName: "iphone.slash")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(red: 1.0, green: 0.6, blue: 0.0))

                        Text("Offline - will sync later")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(red: 1.0, green: 0.6, blue: 0.0).opacity(0.1))
                    )
                    .padding(.top, 12)
                }

                // Location Context
                if let place = sessionManager.nearestPlace {
                    VStack(spacing: 4) {
                        Text("LOCATION")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .tracking(0.8)

                        HStack(spacing: 6) {
                            Text(place.emoji)
                                .font(.system(size: 16))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(place.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                    .foregroundStyle(.white)

                                HStack(spacing: 3) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.green)
                                    Text(place.formattedDistance)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.05))
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                }

                Spacer().frame(height: 12)
            }
            .padding(.horizontal, 4)
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle("Log")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func logQuiet() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showQuietFeedback = true
        }
        
        WKInterfaceDevice.current().play(.success)
        
        sessionManager.sendLogEntry(isQuiet: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showQuietFeedback = false
            }
        }
    }
    
    private func logNoisy() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showNoisyFeedback = true
        }
        
        WKInterfaceDevice.current().play(.notification)
        
        sessionManager.sendLogEntry(isQuiet: false)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showNoisyFeedback = false
            }
        }
    }
}

struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LogView()
        }
        .onAppear {
            WCSessionManager.shared.nearestPlace = Place.preview
        }
    }
}