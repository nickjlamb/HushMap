import SwiftUI

struct SensoryPredictionView: View {
    // Service for generating predictions
    let predictionService = PredictionService()
    
    // Environment values
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    
    // For tab navigation
    @State private var selectedTab: Int = 0
    @State private var navigateToHome: Bool = false
    
    // Form state
    @State private var venueName: String = ""
    @State private var selectedVenueType: String = VenueType.cafe.rawValue
    @State private var location: String = ""
    @State private var selectedDay: String = DayOfWeek.saturday.rawValue
    @State private var timeOfDay: String = "4:00 PM"
    @State private var selectedWeather: String = WeatherCondition.rainy.rawValue
    @State private var userReportsSummary: String = ""
    
    // Result state
    @State private var prediction: VenuePredictionResponse?
    @State private var showPrediction: Bool = false
    @State private var isLoading: Bool = false
    @State private var showingTestView: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Venue Information") {
                    TextField("Venue Name", text: $venueName)
                    
                    Picker("Venue Type", selection: $selectedVenueType) {
                        ForEach(VenueType.allCases.map { $0.rawValue }, id: \.self) { type in
                            Text(type)
                        }
                    }
                    
                    TextField("Location", text: $location)
                }
                
                Section("Visit Details") {
                    Picker("Day of Week", selection: $selectedDay) {
                        ForEach(DayOfWeek.allCases.map { $0.rawValue }, id: \.self) { day in
                            Text(day)
                        }
                    }
                    
                    TextField("Time of Day (e.g., 4:00 PM)", text: $timeOfDay)
                    
                    Picker("Weather", selection: $selectedWeather) {
                        ForEach(WeatherCondition.allCases.map { $0.rawValue }, id: \.self) { weather in
                            Text(weather)
                        }
                    }
                }
                
                Section("Previous Reports") {
                    TextEditor(text: $userReportsSummary)
                        .frame(minHeight: 100)
                        .placeholder(when: userReportsSummary.isEmpty) {
                            Text("Enter any user reports or notes about this venue (optional)")
                                .foregroundColor(.gray)
                                .padding(.leading, 5)
                        }
                }
                
                Section {
                    Button(action: generatePrediction) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Generate Prediction")
                                .frame(maxWidth: .infinity)
                                .bold()
                        }
                    }
                    .disabled(venueName.isEmpty || location.isEmpty || isLoading)
                    .listRowBackground(Color.hushBackground)
                    .foregroundColor(.white)
                }
                
                Section {
                    // Add a back button that goes to Map view
                    Button(action: {
                        // Navigate to the map tab (index 0)
                        NotificationCenter.default.post(
                            name: Notification.Name("SwitchToTab"),
                            object: nil,
                            userInfo: ["tabIndex": 0]
                        )
                    }) {
                        Label("Back to Map", systemImage: "map")
                            .frame(maxWidth: .infinity)
                    }
                    .foregroundColor(.blue)
                    
                    // A simple button to clear the form
                    Button(action: {
                        // Reset form
                        venueName = ""
                        location = ""
                        userReportsSummary = ""
                        prediction = nil
                    }) {
                        Label("Clear Form", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .foregroundColor(.gray)
                }
                
                if let prediction = prediction {
                    Section(header: Text("Sensory Prediction"), 
                            footer: Button(action: {
                                self.prediction = nil  // Clear the prediction
                            }) {
                                Text("Dismiss Prediction")
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }) {
                        VStack(alignment: .leading, spacing: 16) {
                            // Summary
                            Text(prediction.summary)
                                .padding(.bottom, 5)
                            
                            // Confidence level
                            HStack {
                                Label {
                                    Text("Confidence: \(prediction.confidence.rawValue)")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                } icon: {
                                    Image(systemName: 
                                        prediction.confidence == .high ? "checkmark.seal.fill" :
                                        prediction.confidence == .medium ? "checkmark.seal" : "questionmark.circle"
                                    )
                                    .foregroundColor(
                                        prediction.confidence == .high ? .green :
                                        prediction.confidence == .medium ? .blue : .gray
                                    )
                                }
                                
                                Spacer()
                                
                                Text(prediction.confidence.description)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                            
                            // Sensory levels
                            SensoryLevelRow(title: "Noise", level: prediction.noiseLevel, iconName: "speaker.wave.3")
                            SensoryLevelRow(title: "Crowd", level: prediction.crowdLevel, iconName: "person.2")
                            SensoryLevelRow(title: "Lighting", level: prediction.lightingLevel, iconName: "lightbulb")
                            
                            Divider()
                            
                            // New actions
                            HStack {
                                Button(action: {
                                    // Make a new prediction with same data
                                    generatePrediction()
                                }) {
                                    Label("Generate New", systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                
                                Spacer()
                                
                                Button(action: {
                                    // Clear this prediction
                                    self.prediction = nil
                                }) {
                                    Label("Dismiss", systemImage: "xmark.circle")
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                            .padding(.top, 8)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Sensory Prediction")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Show test view with sample data
                        showingTestView = true
                    }) {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
            .sheet(isPresented: $showingTestView) {
                NavigationView {
                    PredictionTestView()
                        .navigationBarItems(trailing: Button("Close") {
                            showingTestView = false
                        })
                }
            }
        }
    }
    
    private func generatePrediction() {
        // Simple validation
        guard !venueName.isEmpty && !location.isEmpty else { return }
        
        // Show loading state
        isLoading = true
        
        // Create request object
        let request = VenuePredictionRequest(
            venueName: venueName,
            venueType: selectedVenueType,
            location: location,
            dayOfWeek: selectedDay,
            timeOfDay: timeOfDay,
            weather: selectedWeather,
            userReportsSummary: userReportsSummary
        )
        
        // In a real app, this might be an async network call
        // For demo, we'll use a slight delay to simulate processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.prediction = self.predictionService.generatePrediction(for: request)
            self.showPrediction = true
            self.isLoading = false
        }
    }
}

// We're now using the imported SensoryLevelRow component from Components/SensoryLevelRow.swift

// TextEditor placeholder
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// Preview
struct SensoryPredictionView_Previews: PreviewProvider {
    static var previews: some View {
        SensoryPredictionView()
    }
}