import SwiftUI
import CoreLocation

struct PlacePredictionView: View {
    let place: PlaceDetails
    @Binding var isPresented: Bool
    @State private var prediction: VenuePredictionResponse?
    @State private var isLoading = false
    @State private var showVisitDetails = false
    
    // Visit details state
    @State private var selectedDay: String = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }()
    @State private var selectedTime: Date = Date()
    @State private var selectedWeather: String = "Clear"
    @State private var userReportsSummary: String = ""
    
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
                                    HStack {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                        Text("Analyzing...")
                                    }
                                } else {
                                    Label("Get Sensory Prediction", systemImage: "sparkles")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.hushBackground)
                            .frame(maxWidth: .infinity)
                            .disabled(isLoading)
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
                                Text("Prediction for:")
                                    .font(.headline)
                                
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
                            
                            Divider()
                            
                            // Sensory levels
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
                            
                            // Confidence indicator
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Prediction Confidence")
                                    .font(.headline)
                                
                                HStack {
                                    Image(systemName: "checkmark.seal")
                                        .foregroundColor(.hushBackground)
                                    Text(prediction.confidence.rawValue)
                                        .fontWeight(.medium)
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
                                    Label("Add Your Own Report", systemImage: "square.and.pencil")
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(.hushBackground)
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
        
        // Generate prediction with a brief delay for UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.prediction = self.predictionService.generateSensoryPrediction(
                for: self.place,
                time: visitDate,
                weather: self.selectedWeather,
                userReportsSummary: self.userReportsSummary
            )
            
            self.isLoading = false
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