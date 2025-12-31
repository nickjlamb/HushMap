import SwiftUI
import CoreLocation

struct LocationReportView: View {
    let pin: ReportPin
    let onAddReport: ((CLLocationCoordinate2D, String?) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("highContrastMode") private var highContrastMode = false
    
    // Default initializer for backward compatibility
    init(pin: ReportPin) {
        self.pin = pin
        self.onAddReport = nil
    }
    
    // Initializer with callback
    init(pin: ReportPin, onAddReport: @escaping (CLLocationCoordinate2D, String?) -> Void) {
        self.pin = pin
        self.onAddReport = onAddReport
    }
    
    private var backgroundColor: Color {
        highContrastMode ? .hushOffWhite : (colorScheme == .dark ? Color(UIColor.systemBackground) : .hushCream)
    }
    
    private var cardBackgroundColor: Color {
        highContrastMode ? .hushSoftWhite : (colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : .hushSoftWhite)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Quick Update section at the top (only if callback is available)
                    if let onAddReport = onAddReport {
                        QuickUpdateView(
                            coordinate: pin.coordinate,
                            displayName: pin.displayName,
                            onLogFullVisit: {
                                onAddReport(pin.coordinate, pin.displayName)
                            }
                        )
                    }

                    // Header section
                    headerSection

                    // Quality overview
                    qualityOverviewSection

                    // Detailed metrics
                    metricsSection

                    // Report information
                    reportInfoSection

                    // Action buttons
                    actionButtonsSection
                }
                .padding()
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Location Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.hushBackground)
                }
            }
        }
        .environment(\.colorScheme, highContrastMode ? .light : colorScheme)
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Quality indicator
            Circle()
                .fill(pin.qualityColor)
                .frame(width: 60, height: 60)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                )
                .shadow(color: pin.qualityColor.opacity(0.3), radius: 8, x: 0, y: 4)
            
            VStack(spacing: 4) {
                Text(pin.friendlyDisplayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.hushPrimaryText)
                
                Text(pin.qualityRating)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(pin.qualityColor)
                
                if pin.reportCount > 1 {
                    Text("Based on \(pin.reportCount) reports")
                        .font(.caption)
                        .foregroundColor(.hushSecondaryText)
                } else {
                    Text("Based on 1 report")
                        .font(.caption)
                        .foregroundColor(.hushSecondaryText)
                }
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(16)
    }
    
    private var qualityOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sensory Environment")
                .font(.headline)
                .foregroundColor(.hushPrimaryText)
            
            VStack(spacing: 12) {
                SensoryLevelBar(
                    title: "Noise Level",
                    level: pin.averageNoise,
                    icon: "speaker.wave.3"
                )
                
                SensoryLevelBar(
                    title: "Crowd Level",
                    level: pin.averageCrowds,
                    icon: "person.2"
                )
                
                SensoryLevelBar(
                    title: "Lighting Level",
                    level: pin.averageLighting,
                    icon: "lightbulb"
                )
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(16)
    }
    
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed Metrics")
                .font(.headline)
                .foregroundColor(.hushPrimaryText)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                MetricCard(
                    title: "Quality Score",
                    value: "\(Int((1.0 - pin.averageSensoryLevel) * 100))%",
                    icon: "star.fill",
                    color: pin.qualityColor
                )
                
                MetricCard(
                    title: "Quiet Score",
                    value: "\(pin.averageQuietScore)/100",
                    icon: "ear",
                    color: .hushBackground
                )
                
                MetricCard(
                    title: "Reports",
                    value: "\(pin.reportCount)",
                    icon: "doc.text",
                    color: .hushWaterRoad
                )
                
                if let confidence = pin.confidence {
                    MetricCard(
                        title: "Confidence",
                        value: "\(Int(confidence * 100))%",
                        icon: "checkmark.circle",
                        color: .hushMapShape
                    )
                }
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(16)
    }
    
    private var reportInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Report Information")
                .font(.headline)
                .foregroundColor(.hushPrimaryText)
            
            VStack(alignment: .leading, spacing: 8) {
                // User attribution
                if let userName = pin.submittedByUserName {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.hushBackground)
                            .frame(width: 20)

                        Text("Submitted by:")
                            .font(.subheadline)
                            .foregroundColor(.hushSecondaryText)

                        Spacer()

                        Text(userName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.hushBackground)
                    }
                }

                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.hushSecondaryText)
                        .frame(width: 20)

                    Text("Last updated:")
                        .font(.subheadline)
                        .foregroundColor(.hushSecondaryText)

                    Spacer()

                    Text(pin.latestTimestamp, style: .relative)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.hushPrimaryText)
                }
                
                if let displayTier = pin.displayTier {
                    HStack {
                        Image(systemName: "location")
                            .foregroundColor(.hushSecondaryText)
                            .frame(width: 20)
                        
                        Text("Location type:")
                            .font(.subheadline)
                            .foregroundColor(.hushSecondaryText)
                        
                        Spacer()
                        
                        Text(displayTier.rawValue.capitalized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.hushPrimaryText)
                    }
                }
                
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.hushSecondaryText)
                        .frame(width: 20)
                    
                    Text("Coordinates:")
                        .font(.subheadline)
                        .foregroundColor(.hushSecondaryText)
                    
                    Spacer()
                    
                    Text("\(String(format: "%.4f", pin.coordinate.latitude)), \(String(format: "%.4f", pin.coordinate.longitude))")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.hushPrimaryText)
                }
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(16)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Primary action - Navigate to location
            Button(action: {
                openInMaps()
            }) {
                HStack {
                    Image(systemName: "location.fill")
                        .font(.subheadline)
                    Text("Open in Maps")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.hushBackground)
                .cornerRadius(12)
            }
            
            // Secondary action - Add your own report
            Button(action: {
                if let onAddReport = onAddReport {
                    onAddReport(pin.coordinate, pin.displayName)
                } else {
                    dismiss()
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                        .font(.subheadline)
                    Text("Log My Visit")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.hushBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.hushBackground, lineWidth: 2)
                )
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(16)
    }
    
    
    private func openInMaps() {
        let coordinate = pin.coordinate
        let placeName = pin.displayName ?? "Location"
        
        if let url = URL(string: "http://maps.apple.com/?ll=\(coordinate.latitude),\(coordinate.longitude)&q=\(placeName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Location")") {
            UIApplication.shared.open(url)
        }
    }
}


struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.hushPrimaryText)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.hushSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.hushSoftWhite.opacity(0.5))
        .cornerRadius(12)
    }
}

#Preview {
    LocationReportView(
        pin: ReportPin(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            displayName: "Sample Coffee Shop",
            displayTier: .poi,
            confidence: 0.85,
            reportCount: 12,
            averageNoise: 0.4,
            averageCrowds: 0.3,
            averageLighting: 0.5,
            averageQuietScore: 75,
            latestTimestamp: Date(),
            submittedByUserName: "Sarah Johnson",
            submittedByUserProfileImageURL: nil
        )
    )
}