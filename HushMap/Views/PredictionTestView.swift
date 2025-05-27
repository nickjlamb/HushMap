import SwiftUI

struct PredictionTestView: View {
    // Prediction service
    private let predictionService = PredictionService()
    
    // Test input data (as provided in the requirements)
    private let sampleRequestData = VenuePredictionRequest(
        venueName: "The Roastery Café",
        venueType: "Café",
        location: "London, UK",
        dayOfWeek: "Saturday",
        timeOfDay: "4:00 PM",
        weather: "Rainy",
        userReportsSummary: "Typically quiet in the mornings, busier after 3 PM on weekends. Lighting is soft and warm."
    )
    
    // Store the prediction result
    @State private var prediction: VenuePredictionResponse?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                Text("AI Sensory Risk Predictor")
                    .font(.title)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // Input data card
                GroupBox(label: Label("Input Data", systemImage: "arrow.down.doc.fill")) {
                    VStack(alignment: .leading, spacing: 8) {
                        InputRow(title: "Venue", value: sampleRequestData.venueName)
                        InputRow(title: "Type", value: sampleRequestData.venueType)
                        InputRow(title: "Location", value: sampleRequestData.location)
                        InputRow(title: "Day", value: sampleRequestData.dayOfWeek)
                        InputRow(title: "Time", value: sampleRequestData.timeOfDay)
                        InputRow(title: "Weather", value: sampleRequestData.weather)
                        
                        Divider()
                        
                        Text("User Reports:")
                            .font(.headline)
                            .padding(.top, 4)
                        
                        Text(sampleRequestData.userReportsSummary)
                            .font(.body)
                            .padding(.top, 1)
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                // Generate prediction button
                Button(action: {
                    // Generate prediction from the provided data
                    prediction = predictionService.generatePrediction(for: sampleRequestData)
                }) {
                    Label("Generate Prediction", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.hushBackground)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Show prediction result if available
                if let prediction = prediction {
                    GroupBox(label: Label("Prediction Result", systemImage: "wand.and.stars")) {
                        VStack(alignment: .leading, spacing: 16) {
                            // Summary
                            Text(prediction.summary)
                                .font(.body)
                                .padding(.bottom, 8)
                            
                            Divider()
                            
                            // Structured output (as in the requirements)
                            Text("Structured Output Format:")
                                .font(.headline)
                            
                            CodeBlock(content: """
                            {
                              "summary": "\(prediction.summary)",
                              "noiseLevel": "\(prediction.noiseLevel.rawValue)",
                              "crowdLevel": "\(prediction.crowdLevel.rawValue)",
                              "lightingLevel": "\(prediction.lightingLevel.rawValue)",
                              "confidence": "\(prediction.confidence.rawValue)"
                            }
                            """)
                            
                            // Visual indicators
                            SensoryLevelRow(title: "Noise", level: prediction.noiseLevel, iconName: "speaker.wave.3")
                                .padding(.top, 8)
                            SensoryLevelRow(title: "Crowd", level: prediction.crowdLevel, iconName: "person.2")
                            SensoryLevelRow(title: "Lighting", level: prediction.lightingLevel, iconName: "lightbulb")
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.top)
        }
        .navigationTitle("Sample Test")
    }
}

// Helper components
struct InputRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title + ":")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

struct CodeBlock: View {
    let content: String
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(content)
                .font(.system(.body, design: .monospaced))
                .padding()
        }
        .background(Color(UIColor.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    PredictionTestView()
}