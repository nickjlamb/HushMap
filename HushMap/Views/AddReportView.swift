import SwiftUI
import SwiftData
import CoreLocation

struct AddReportView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var locationManager = LocationManager()
    @StateObject private var audioService = AudioAnalysisService()
    @Query private var users: [User]
    
    @State private var noiseLevel: Double = 0.5
    @State private var crowdLevel: Double = 0.5
    @State private var lightingLevel: Double = 0.5
    @State private var comments: String = ""
    @State private var showToast: Bool = false
    @State private var showAudioMeter = false
    
    // Gamification states
    @State private var showBadgeNotification: Bool = false
    @State private var showPointsNotification: Bool = false
    @State private var earnedBadge: Badge?
    @State private var earnedPoints: Int = 0

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Form content
                    Form {
                        Section(header: Text("Rate the Sensory Environment")) {
                            // AI-Enhanced Noise Measurement
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "speaker.wave.3")
                                        .foregroundColor(.hushBackground)
                                        .frame(width: 20)
                                    
                                    Text("Noise: \(Int(noiseLevel * 10))/10")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        showAudioMeter.toggle()
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "brain.head.profile")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                            Text("AI Assist")
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            LinearGradient(
                                                colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                        .shadow(color: .purple.opacity(0.3), radius: 4, x: 0, y: 2)
                                    }
                                }
                                
                                Slider(value: $noiseLevel, in: 0...1)
                                    .tint(.hushBackground)
                                
                                // Show compact audio meter if enabled
                                if showAudioMeter {
                                    VStack(spacing: 8) {
                                        CompactSoundMeter(audioService: audioService)
                                        
                                        if audioService.isListening {
                                            HStack {
                                                Button("Use AI Reading") {
                                                    withAnimation(.easeInOut(duration: 0.3)) {
                                                        noiseLevel = audioService.getNoiseLevel()
                                                    }
                                                }
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.green.opacity(0.2))
                                                .foregroundColor(.green)
                                                .cornerRadius(6)
                                                
                                                Spacer()
                                                
                                                Text(audioService.getNoiseDescription())
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            
                            SliderWithLabel(title: "Crowds", value: $crowdLevel)
                            SliderWithLabel(title: "Lighting", value: $lightingLevel)
                        }

                        Section(header: Text("Optional Comments")) {
                            TextEditor(text: $comments)
                                .frame(minHeight: 100)
                        }
                    }
                    
                    // AI Sound Analysis Section
                    if showAudioMeter {
                        VStack(spacing: 0) {
                            SoundMeterView(audioService: audioService)
                                .padding(.horizontal)
                                .padding(.top)
                        }
                        .background(Color(.systemGroupedBackground))
                    }
                    
                    // Prominent Submit Button
                    VStack(spacing: 0) {
                        Button(action: submitReport) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.subheadline)
                                Text("Submit Report")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .minimumScaleFactor(0.8)
                                    .lineLimit(1)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.hushBackground)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.hushMapShape.opacity(0.95))
                                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: -4)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .ignoresSafeArea(.container, edges: .bottom)
                    }
                }
                .ignoresSafeArea(.all, edges: [.horizontal])

                // Success Toast
                if showToast {
                    VStack {
                        Spacer()
                        Text("Report saved successfully")
                            .padding()
                            .background(Color.hushBackground.opacity(0.9))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .transition(.move(edge: .bottom))
                            .padding(.bottom, 40)
                            .accessibilityAddTraits(.isStaticText)
                    }
                    .animation(.easeInOut, value: showToast)
                }
                
                // Points notification
                if showPointsNotification {
                    VStack {
                        PointsNotificationView(points: earnedPoints, isPresented: $showPointsNotification)
                            .padding(.top)
                        Spacer()
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: showPointsNotification)
                }
                
                // Badge notification dialog
                if showBadgeNotification, let badge = earnedBadge {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            BadgeNotificationView(badge: badge, isPresented: $showBadgeNotification)
                        )
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: showBadgeNotification)
                }
            }
            .navigationTitle("Add Report")
            .onAppear {
                // Ensure user exists
                if users.isEmpty {
                    let userService = UserService(modelContext: modelContext)
                    _ = userService.getCurrentUser()
                }
            }
        }
    }

    func submitReport() {
        // Initialize location for San Francisco if user location isn't available
        let defaultLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let location = locationManager.lastLocation ?? defaultLocation

        let newReport = Report(
            noise: noiseLevel,
            crowds: crowdLevel,
            lighting: lightingLevel,
            comments: comments,
            latitude: location.latitude,
            longitude: location.longitude
        )
        
        // Get the current user (or create one if needed)
        let userService = UserService(modelContext: modelContext)
        let currentUser = userService.getCurrentUser()
        
        // Insert and process the report for gamification
        modelContext.insert(newReport)
        
        // Process the report for points and badges
        let badgeService = BadgeService(modelContext: modelContext)
        let result = badgeService.processNewReport(newReport, for: currentUser)
        
        // Update sensory profile with new report data
        let profileService = SensoryProfileService(modelContext: modelContext)
        profileService.updateProfile(with: newReport, for: currentUser)
        
        // Save earned badges and points for notifications
        earnedPoints = result.points
        
        // Show badges if earned
        if let firstBadge = result.badges.first {
            earnedBadge = firstBadge
            
            // Show badge notification after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    showBadgeNotification = true
                }
            }
        } else {
            // If no badge, just show points notification
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    showPointsNotification = true
                }
                
                // Auto-dismiss points after a few seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        showPointsNotification = false
                    }
                }
            }
        }

        // Reset form
        noiseLevel = 0.5
        crowdLevel = 0.5
        lightingLevel = 0.5
        comments = ""
        
        // Stop audio analysis
        audioService.stopListening()
        showAudioMeter = false

        // Show toast
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showToast = false
        }

        print("✅ Report saved to SwiftData with location")
    }
}

struct SliderWithLabel: View {
    let title: String
    @Binding var value: Double
    
    var iconName: String {
        switch title {
        case "Noise":
            return "speaker.wave.3"
        case "Crowds":
            return "person.2"
        case "Lighting":
            return "lightbulb"
        default:
            return "slider.horizontal.3"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(.hushBackground)
                    .frame(width: 20)
                
                Text("\(title): \(Int(value * 10))/10")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            Slider(value: $value, in: 0...1)
                .tint(.hushBackground)
        }
        .padding(.vertical, 4)
    }
}

