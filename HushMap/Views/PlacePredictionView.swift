import SwiftUI
import CoreLocation

struct PlacePredictionView: View {
    let place: PlaceDetails
    @Binding var isPresented: Bool
    var onPredictionRequested: (() -> Void)? = nil
    @State private var prediction: VenuePredictionResponse?
    @State private var isLoading = false
    @State private var showVisitDetails = false
    @State private var predictionError: AppError?
    @StateObject private var errorState = ErrorStateViewModel()
    
    // Visit details state
    @State private var selectedDay: String = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }()
    @State private var selectedTime: Date = Date()
    @State private var selectedWeather: String = "Clear"
    @State private var userReportsSummary: String = ""
    
    // Sample certifications - shows for demo purposes (in real app, this would come from venue database)
    private var sampleCertifications: [SensoryCertification] {
        // Show certifications for popular venues as examples
        let venueName = place.name.lowercased()
        
        if venueName.contains("library") || venueName.contains("museum") || venueName.contains("café") || venueName.contains("coffee") {
            return [
                SensoryCertification(
                    type: .autismFriendly,
                    certifyingBody: "National Autistic Society",
                    details: "Staff trained in autism awareness, quiet spaces available during peak hours"
                ),
                SensoryCertification(
                    type: .quietHours,
                    certifyingBody: "Sensory Inclusive Venues",
                    details: "Designated quiet hours 9-11am daily with reduced lighting and no background music"
                )
            ]
        } else if venueName.contains("station") || venueName.contains("tube") || venueName.contains("underground") {
            return [
                SensoryCertification(
                    type: .sensoryInclusive,
                    certifyingBody: "Transport for London",
                    details: "Sensory maps available, quiet zones designated, step-free access certified"
                )
            ]
        } else {
            // Show at least one certification for other venues to demonstrate the feature
            return [
                SensoryCertification(
                    type: .neurodivergentWelcome,
                    certifyingBody: "Inclusive Business Network",
                    details: "Staff receive neurodiversity awareness training and venue welcomes all visitors"
                )
            ]
        }
    }
    
    @Environment(\.modelContext) private var modelContext
    private var predictionService: PredictionService {
        PredictionService(modelContext: modelContext)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Header with place name
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(place.address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                if prediction == nil {
                    // Visit details form
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("When are you planning to visit?")
                                .font(.headline)
                                .padding(.bottom, 4)
                            
                            // Day picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Day of Week")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Picker("Day", selection: $selectedDay) {
                                    ForEach(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], id: \.self) { day in
                                        Text(abbreviatedDay(day)).tag(day)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            // Time picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Time of Visit")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.wheel)
                                    .frame(height: 100)
                            }
                            .padding(.bottom, 16)
                            
                            // Weather picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Weather Conditions")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Picker("Weather", selection: $selectedWeather) {
                                    ForEach(["Clear", "Cloudy", "Rainy", "Sunny"], id: \.self) { weather in
                                        Text(weather).tag(weather)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            // Optional user reports
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Previous Experience (Optional)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                TextField("Any notes from previous visits...", text: $userReportsSummary, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3...6)
                            }
                            
                            // Get prediction button
                            Button(action: {
                                generatePrediction()
                            }) {
                                if isLoading {
                                    HStack(spacing: 12) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(1.2)
                                        Text("AI is analyzing...")
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.purple)
                                    )
                                } else {
                                    Label("Get Sensory Prediction", systemImage: "sparkles")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.hushBackground)
                                        )
                                }
                            }
                            .disabled(isLoading)
                            .animation(.easeInOut(duration: 0.3), value: isLoading)
                            .padding(.top, 8)
                        }
                        .padding()
                    }
                } else if let prediction = prediction {
                    // Enhanced prediction results
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Visit details summary
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Prediction for:")
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    // AI indicator
                                    HStack(spacing: 4) {
                                        Image(systemName: "brain.head.profile")
                                            .foregroundColor(.purple)
                                            .font(.caption)
                                        Text("AI Powered")
                                            .font(.caption)
                                            .foregroundColor(.purple)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.hushBackground)
                                    Text("\(selectedDay), \(selectedTime, style: .time)")
                                    
                                    Spacer()
                                    
                                    Image(systemName: weatherIcon)
                                        .foregroundColor(.hushBackground)
                                    Text(selectedWeather)
                                }
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            
                            Divider()
                            
                            
                            // Sensory certifications (if any)
                            if !sampleCertifications.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Sensory Certifications")
                                        .font(.headline)
                                    
                                    LazyVGrid(columns: [
                                        GridItem(.flexible()),
                                        GridItem(.flexible())
                                    ], spacing: 8) {
                                        ForEach(sampleCertifications) { certification in
                                            SensoryCertificationBadge(certification: certification)
                                        }
                                    }
                                }
                                
                                Divider()
                            }
                            
                            // Sensory levels (moved up for instant visual feedback)
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Sensory Environment")
                                    .font(.headline)
                                
                                VStack(spacing: 12) {
                                    SensoryLevelRow(title: "Noise", level: prediction.noiseLevel, iconName: "speaker.wave.3")
                                    SensoryLevelRow(title: "Crowd", level: prediction.crowdLevel, iconName: "person.2")
                                    SensoryLevelRow(title: "Lighting", level: prediction.lightingLevel, iconName: "lightbulb")
                                }
                            }
                            
                            Divider()
                            
                            // Prediction summary
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Overall Assessment")
                                    .font(.headline)
                                
                                Text(prediction.summary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            
                            // Interesting fact (if available)
                            if !prediction.interestingFact.isEmpty {
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "lightbulb.fill")
                                            .foregroundColor(.orange)
                                        Text("Interesting Fact")
                                            .font(.headline)
                                    }
                                    
                                    Text(prediction.interestingFact)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color.orange.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                            Divider()
                            
                            // Confidence indicator
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Prediction Confidence")
                                        .font(.headline)
                                    
                                    Button(action: {}) {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help(confidenceTooltipText(for: prediction.confidence))
                                }
                                
                                HStack {
                                    Image(systemName: "checkmark.seal")
                                        .foregroundColor(.hushBackground)
                                    Text(prediction.confidence.rawValue)
                                        .fontWeight(.medium)
                                    Text("• \(prediction.confidence.description)")
                                        .foregroundColor(.secondary)
                                        .font(.subheadline)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            
                            // Action buttons
                            VStack(spacing: 16) {
                                Button(action: {
                                    // Reset to try different visit details
                                    self.prediction = nil
                                    self.selectedTime = Date()
                                    self.selectedWeather = "Clear"
                                    self.userReportsSummary = ""
                                }) {
                                    Label("Try Different Visit Details", systemImage: "arrow.clockwise")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.hushBackground)
                                
                                Button(action: {
                                    // Navigate to add report (tab 2)
                                    NotificationCenter.default.post(
                                        name: Notification.Name("SwitchToTab"),
                                        object: nil,
                                        userInfo: ["tabIndex": 2]
                                    )
                                    isPresented = false
                                }) {
                                    Label("Log My Visit", systemImage: "square.and.pencil")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.hushBackground)
                            }
                            .padding(.top, 16)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Sensory Prediction")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                HStack {
                    Spacer()
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(.hushBackground)
                    .padding(.trailing)
                    .padding(.top, 8)
                }
            }
        }
    }
    
    private var weatherIcon: String {
        switch selectedWeather {
        case "Clear": return "sun.max"
        case "Cloudy": return "cloud"
        case "Rainy": return "cloud.rain"
        case "Sunny": return "sun.max"
        default: return "sun.max"
        }
    }
    
    private func abbreviatedDay(_ day: String) -> String {
        switch day {
        case "Monday": return "Mon"
        case "Tuesday": return "Tue"
        case "Wednesday": return "Wed"
        case "Thursday": return "Thu"
        case "Friday": return "Fri"
        case "Saturday": return "Sat"
        case "Sunday": return "Sun"
        default: return day
        }
    }
    
    private func generatePrediction() {
        isLoading = true

        // Notify parent that prediction was requested (e.g., to show purple pin)
        onPredictionRequested?()

        // Create combined date from selected day and time
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
        
        // For simplicity, use current week's date for the selected day
        var visitDate = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        
        // Find the date for the selected day in the current week
        if let weekday = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"].firstIndex(of: selectedDay) {
            let today = calendar.component(.weekday, from: Date()) - 1 // Sunday = 0
            let daysToAdd = (weekday - today + 7) % 7
            visitDate = calendar.date(byAdding: .day, value: daysToAdd, to: Date()) ?? Date()
        }
        
        // Set the time
        if let hour = timeComponents.hour, let minute = timeComponents.minute {
            visitDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: visitDate) ?? visitDate
        }
        
        // Generate AI-powered prediction
        Task {
            do {
                // Add a brief delay for UX
                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                
                let generatedPrediction = await self.predictionService.generateSensoryPrediction(
                    for: self.place,
                    time: visitDate,
                    weather: self.selectedWeather,
                    userReportsSummary: self.userReportsSummary
                )
                
                await MainActor.run {
                    self.prediction = generatedPrediction
                    self.predictionError = nil
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    // Show error but don't block the UI - prediction service has fallbacks
                    self.predictionError = error as? AppError ?? AppError.general(.unexpectedError)
                    self.isLoading = false
                    
                    // Still try to show a basic prediction if AI failed
                    if self.prediction == nil {
                        // Create a basic fallback prediction
                        self.prediction = VenuePredictionResponse(
                            id: UUID(),
                            venueName: place.name,
                            venueType: "Unknown",
                            summary: "Unable to generate detailed prediction. Please check your connection and try again.",
                            interestingFact: "",
                            noiseLevel: .moderate,
                            crowdLevel: .moderate,
                            lightingLevel: .moderate,
                            confidence: .low,
                            timestamp: Date(),
                            coordinate: place.coordinate
                        )
                    }
                }
            }
        }
    }
    
    // Helper function for confidence tooltip
    private func confidenceTooltipText(for confidence: ConfidenceLevel) -> String {
        switch confidence {
        case .high:
            return "High confidence predictions are based on 5+ recent user reports from this venue, or AI analysis of comprehensive data patterns."
        case .medium:
            return "Medium confidence predictions are based on 3+ user reports from nearby venues, or substantial community feedback."
        case .low:
            return "Low confidence predictions rely mainly on venue type patterns and limited user data. Consider contributing a report to help others!"
        }
    }
}

// Preview
#Preview {
    PlacePredictionView(
        place: PlaceDetails(
            name: "The Quiet Café",
            address: "123 Serenity St, London",
            coordinate: CLLocationCoordinate2D(latitude: 51.509865, longitude: -0.118092)
        ),
        isPresented: .constant(true)
    )
}