import SwiftUI
import SwiftData
import CoreLocation

struct NearbyView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var reports: [Report]
    @StateObject private var locationManager = LocationManager()
    
    @State private var searchRadius: Double = 2.0 // km
    @State private var maxSensoryLevel: Double = 0.6 // Only show places with average sensory level <= 0.6
    @State private var sortByDistance = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Filters
                filtersSection
                
                // Content
                if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                    locationPermissionView
                } else if !locationManager.isLocationReady {
                    loadingView
                } else {
                    nearbyLocationsList
                }
            }
            .navigationTitle("Nearby")
            .navigationBarTitleDisplayMode(.large)
            .ignoresSafeArea(.all, edges: [.horizontal])
            .onAppear {
                locationManager.requestLocationPermission()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "location.magnifyingglass")
                    .foregroundColor(.hushBackground)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("Sensory-Friendly Places")
                        .font(.headline)
                    Text("Find quiet, comfortable spots nearby")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.hushMapShape.opacity(0.3))
        }
    }
    
    private var filtersSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Search Radius: \(String(format: "%.1f", searchRadius)) km")
                        .font(.subheadline)
                    Slider(value: $searchRadius, in: 0.5...10.0, step: 0.5)
                        .accentColor(.hushBackground)
                }
                
                Spacer()
                
                Toggle("Sort by Distance", isOn: $sortByDistance)
                    .toggleStyle(SwitchToggleStyle(tint: .hushBackground))
            }
            
            VStack(alignment: .leading) {
                Text("Max Sensory Level: \(String(format: "%.1f", maxSensoryLevel * 10))/10")
                    .font(.subheadline)
                Slider(value: $maxSensoryLevel, in: 0.1...1.0, step: 0.1)
                    .accentColor(.hushBackground)
            }
        }
        .padding()
        .background(Color.hushWaterRoad.opacity(0.3))
    }
    
    private var locationPermissionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(.title, design: .default, weight: .regular))
                .foregroundColor(.secondary)
            
            Text("Location Access Required")
                .font(.headline)
            
            Text("To show nearby sensory-friendly places, please enable location access in Settings.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.hushBackground)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Getting your location...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var nearbyLocationsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if nearbyLocations.isEmpty {
                    emptyStateView
                } else {
                    ForEach(nearbyLocations, id: \.id) { location in
                        NearbyLocationCard(location: location)
                    }
                }
            }
            .padding()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(.title, design: .default, weight: .regular))
                .foregroundColor(.secondary)
            
            Text("No Nearby Places Found")
                .font(.headline)
            
            Text("Try increasing your search radius or adjusting the sensory level filter. You can also add reports to help build the database!")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private var nearbyLocations: [NearbyLocation] {
        guard let userLocation = locationManager.lastLocation else { return [] }
        
        // Group reports by location and calculate averages
        let locationGroups = Dictionary(grouping: reports) { $0.locationIdentifier }
        
        var locations: [NearbyLocation] = []
        
        for (locationId, reportsAtLocation) in locationGroups {
            // Calculate average sensory levels
            let avgNoise = reportsAtLocation.map { $0.noise }.reduce(0, +) / Double(reportsAtLocation.count)
            let avgCrowds = reportsAtLocation.map { $0.crowds }.reduce(0, +) / Double(reportsAtLocation.count)
            let avgLighting = reportsAtLocation.map { $0.lighting }.reduce(0, +) / Double(reportsAtLocation.count)
            let avgSensoryLevel = (avgNoise + avgCrowds + avgLighting) / 3.0
            
            // Filter by sensory level
            guard avgSensoryLevel <= maxSensoryLevel else { continue }
            
            // Use the most recent report for location data
            guard let latestReport = reportsAtLocation.max(by: { $0.timestamp < $1.timestamp }) else { continue }
            
            let reportLocation = CLLocation(latitude: latestReport.latitude, longitude: latestReport.longitude)
            let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
            let distance = reportLocation.distance(from: userCLLocation) / 1000.0 // Convert to km
            
            // Filter by distance
            guard distance <= searchRadius else { continue }
            
            let location = NearbyLocation(
                id: locationId,
                coordinate: latestReport.coordinate,
                distance: distance,
                averageNoise: avgNoise,
                averageCrowds: avgCrowds,
                averageLighting: avgLighting,
                reportCount: reportsAtLocation.count,
                lastReportDate: latestReport.timestamp,
                averageSensoryLevel: avgSensoryLevel
            )
            
            locations.append(location)
        }
        
        // Sort by distance or sensory level
        if sortByDistance {
            return locations.sorted { $0.distance < $1.distance }
        } else {
            return locations.sorted { $0.averageSensoryLevel < $1.averageSensoryLevel }
        }
    }
}

struct NearbyLocation {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let distance: Double
    let averageNoise: Double
    let averageCrowds: Double
    let averageLighting: Double
    let reportCount: Int
    let lastReportDate: Date
    let averageSensoryLevel: Double
    
    var qualityRating: String {
        switch averageSensoryLevel {
        case 0.0..<0.3: return "Excellent"
        case 0.3..<0.5: return "Good"
        case 0.5..<0.7: return "Fair"
        default: return "Poor"
        }
    }
    
    var qualityColor: Color {
        switch averageSensoryLevel {
        case 0.0..<0.3: return .hushLowRisk
        case 0.3..<0.5: return .hushMediumRisk
        case 0.5..<0.7: return .hushHighRisk
        default: return .red
        }
    }
}

struct NearbyLocationCard: View {
    let location: NearbyLocation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Location")
                        .font(.headline)
                    Text("\(String(format: "%.2f", location.distance)) km away")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(location.qualityRating)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(location.qualityColor)
                    
                    Text("\(location.reportCount) report\(location.reportCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Sensory levels
            VStack(spacing: 8) {
                SensoryLevelBar(
                    title: "Noise",
                    level: location.averageNoise,
                    icon: "speaker.wave.3"
                )
                
                SensoryLevelBar(
                    title: "Crowds",
                    level: location.averageCrowds,
                    icon: "person.2"
                )
                
                SensoryLevelBar(
                    title: "Lighting",
                    level: location.averageLighting,
                    icon: "lightbulb"
                )
            }
            
            // Last updated
            HStack {
                Text("Last updated:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(location.lastReportDate, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            // Primary CTA Button
            Button(action: {
                // Switch to map tab and center on this location
                NotificationCenter.default.post(
                    name: Notification.Name("SwitchToTab"),
                    object: nil,
                    userInfo: ["tabIndex": 0]
                )
                
                // Center map on the coordinate
                NotificationCenter.default.post(
                    name: Notification.Name("CenterMapOnCoordinate"),
                    object: nil,
                    userInfo: ["coordinate": location.coordinate]
                )
            }) {
                HStack {
                    Image(systemName: "map")
                        .font(.subheadline)
                    Text("View on Map")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.hushBackground)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.hushMapShape.opacity(0.3))
        .cornerRadius(12)
    }
}

struct SensoryLevelBar: View {
    let title: String
    let level: Double // 0.0 to 1.0
    let icon: String
    
    private var levelColor: Color {
        switch level {
        case 0.0..<0.3: return .hushLowRisk
        case 0.3..<0.6: return .hushMediumRisk
        case 0.6..<1.0: return .hushHighRisk
        default: return .red
        }
    }
    
    private var levelText: String {
        switch level {
        case 0.0..<0.2: return "Very Low"
        case 0.2..<0.4: return "Low"
        case 0.4..<0.6: return "Moderate"
        case 0.6..<0.8: return "High"
        case 0.8...1.0: return "Very High"
        default: return "Unknown"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(height: 6)
                            .opacity(0.2)
                            .foregroundColor(.gray)
                            .cornerRadius(3)
                        
                        Rectangle()
                            .frame(width: geometry.size.width * level, height: 6)
                            .foregroundColor(levelColor)
                            .cornerRadius(3)
                    }
                }
                .frame(height: 6)
            }
            
            Text(levelText)
                .font(.caption)
                .foregroundColor(levelColor)
                .fontWeight(.medium)
        }
    }
}
