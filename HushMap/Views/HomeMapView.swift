import SwiftUI
import MapKit
import CoreLocation
import SwiftData
import GoogleMaps
import Combine

struct HomeMapView: View {
    @StateObject private var locationManager = LocationManager()
    @Query private var reports: [Report]
    // Note: Removed Apple Maps position state - using currentCoordinate for Google Maps
    @State private var useClustering = true
    @State private var sortByRecent = false
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var maxNoiseThreshold: Double = 1.0
    @State private var maxCrowdThreshold: Double = 1.0
    @State private var maxLightingThreshold: Double = 1.0
    @State private var showAbout = false
    
    // States for place search
    @State private var showingPlaceSearch = false
    @State private var selectedPlace: PlaceDetails?
    @State private var showingPlacePrediction = false
    @State private var tempPin: PlaceDetails?
    
    // States for map tap predictions
    @State private var isLookingUpLocation = false
    @State private var showingMapTapPrediction = false
    
    // States for temp pin display and report interaction
    @State private var showingTempPin = false
    @State private var tempPinLocation: CLLocationCoordinate2D?
    @State private var selectedReport: Report?
    
    // States for pin interaction
    @State private var selectedPin: ReportPin?
    @State private var showingPinDetail = false
    
    // State for legend
    @State private var showLegend = false
    
    // State for expandable header
    @State private var headerExpanded = false
    
    // State for map style (Google Maps)
    @State private var currentMapStyle: Int = 0 // 0 = standard, 1 = satellite, 2 = hybrid, 3 = terrain
    @State private var currentCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // Default fallback
    @State private var googleMapType: GMSMapViewType = .normal
    @State private var hasInitializedLocation = false // Track if we've set initial location

    var body: some View {
        ZStack {
            // Background matching bottom nav bar
            Color.hushMapShape.opacity(0.95)
                .ignoresSafeArea(.all, edges: .all)
            
            GoogleMapView(
                mapType: $googleMapType,
                cameraPosition: $currentCoordinate,
                pins: filteredPins,
                onPinTap: { pin in
                    selectedPin = pin
                    showingPinDetail = true
                },
                tempPin: tempPin,
                onMapTap: { coordinate in
                    handleMapTap(at: coordinate)
                },
                onPOITap: { placeID, name, location in
                    print("User tapped POI: \(name)")
                    let place = PlaceDetails(name: name, address: "", coordinate: location)
                    selectedPlace = place
                    tempPin = place
                    showingMapTapPrediction = true
                }
            )
            .ignoresSafeArea(.all, edges: .all)
            .onAppear {
                // Request location permission when view appears
                locationManager.requestLocationPermission()
                
                // Listen for coordinate centering notifications from Nearby view
                NotificationCenter.default.addObserver(
                    forName: Notification.Name("CenterMapOnCoordinate"),
                    object: nil,
                    queue: .main
                ) { notification in
                    if let coordinate = notification.userInfo?["coordinate"] as? CLLocationCoordinate2D {
                        currentCoordinate = coordinate
                    }
                }
            }
            .onReceive(locationManager.$lastLocation) { newLocation in
                // Only update map position ONCE when user location first becomes available
                if let newLocation = newLocation, !hasInitializedLocation {
                    currentCoordinate = newLocation
                    hasInitializedLocation = true
                }
            }

            // Map Legend
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    MapLegendView(isVisible: $showLegend)
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 120) // Account for tab bar

            VStack {
                expandableHeader
                    .padding(.top, 8) // Reduced padding to move nav bar up
                Spacer()
            }
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingPlaceSearch) {
            PlaceSearchViewWrapper(
                onPlaceSelected: { place in
                    handlePlaceSelection(place)
                    showingPlaceSearch = false
                }
            )
        }
        .sheet(isPresented: $showingPlacePrediction) {
            if let place = selectedPlace {
                PlacePredictionView(
                    place: place, 
                    isPresented: $showingPlacePrediction
                )
            }
        }
        .sheet(isPresented: $showingMapTapPrediction) {
            if let place = selectedPlace {
                PlacePredictionView(
                    place: place, 
                    isPresented: $showingMapTapPrediction
                )
            }
        }
        .sheet(isPresented: $showingPinDetail) {
            if let pin = selectedPin {
                PinDetailView(pin: pin)
            }
        }
    }
    
    private func handlePlaceSelection(_ place: PlaceDetails) {
        // Set the temporary pin
        tempPin = place
        selectedPlace = place
        
        // Center the Google Maps on the selected place
        currentCoordinate = place.coordinate
        
        // Show the prediction sheet after a brief delay to allow the map to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showingPlacePrediction = true
        }
    }
    
    private func handleMapTap(at coordinate: CLLocationCoordinate2D) {
        // Don't interfere if already looking up a location
        guard !isLookingUpLocation else { return }
        
        isLookingUpLocation = true
        
        // Use Places API to find business details at this location
        let placeService = PlaceService()
        placeService.findPlace(at: coordinate) { [self] (place: PlaceDetails?) in
            DispatchQueue.main.async {
                self.isLookingUpLocation = false
                
                guard let place = place else {
                    print("No place found at this location")
                    return
                }
                
                // Set the place and show prediction
                self.selectedPlace = place
                self.tempPin = place
                self.showingMapTapPrediction = true
            }
        }
    }
    
    // Google Maps style helper properties
    private var mapStyleIcon: String {
        return GoogleMapsService.shared.mapStyleIcon(for: googleMapType)
    }
    
    private var mapStyleLabel: String {
        return GoogleMapsService.shared.mapStyleName(for: googleMapType)
    }
    
    private func cycleMapStyle() {
        switch googleMapType {
        case .normal:
            googleMapType = .satellite
        case .satellite:
            googleMapType = .hybrid
        case .hybrid:
            googleMapType = .terrain
        case .terrain:
            googleMapType = .normal
        default:
            googleMapType = .normal
        }
    }
    
    var expandableHeader: some View {
        VStack(spacing: 0) {
            // Main header bar - always visible
            HStack(spacing: 0) {
                // Expand/Collapse indicator
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        headerExpanded.toggle()
                    }
                }) {
                    Image(systemName: headerExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.hushBackground)
                        .frame(width: 20)
                }
                .accessibilityLabel(headerExpanded ? "Collapse header" : "Expand header")
                
                Spacer()
                
                // Control buttons
                HStack(spacing: 24) {
                    // Legend button
                    VStack(spacing: 4) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showLegend.toggle()
                            }
                        }) {
                            Image(systemName: "list.bullet.rectangle.fill")
                                .font(.title2)
                                .foregroundColor(.hushBackground)
                        }
                        .accessibilityLabel("Show pin legend")
                        
                        if headerExpanded {
                            Text("Legend")
                                .font(.caption2)
                                .foregroundColor(.hushBackground.opacity(0.8))
                        }
                    }
                    
                    // Map Style button
                    VStack(spacing: 4) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                cycleMapStyle()
                            }
                        }) {
                            Image(systemName: mapStyleIcon)
                                .font(.title2)
                                .foregroundColor(.hushBackground)
                        }
                        .accessibilityLabel("Change map style")
                        
                        if headerExpanded {
                            Text(mapStyleLabel)
                                .font(.caption2)
                                .foregroundColor(.hushBackground.opacity(0.8))
                        }
                    }
                    
                    // Filters button
                    VStack(spacing: 4) {
                        Button(action: {
                            // This will expand the header to show filters
                            withAnimation(.easeInOut(duration: 0.3)) {
                                headerExpanded.toggle()
                            }
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.title2)
                                .foregroundColor(.hushBackground)
                        }
                        .accessibilityLabel("Show filters")
                        
                        if headerExpanded {
                            Text("Filters")
                                .font(.caption2)
                                .foregroundColor(.hushBackground.opacity(0.8))
                        }
                    }
                    
                    // Search button
                    VStack(spacing: 4) {
                        Button(action: {
                            showingPlaceSearch = true
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                                .foregroundColor(.hushBackground)
                        }
                        .accessibilityLabel("Search for places")
                        
                        if headerExpanded {
                            Text("Search")
                                .font(.caption2)
                                .foregroundColor(.hushBackground.opacity(0.8))
                        }
                    }
                    
                    // About button
                    VStack(spacing: 4) {
                        Button(action: {
                            showAbout = true
                        }) {
                            Image(systemName: "info.circle.fill")
                                .font(.title2)
                                .foregroundColor(.hushBackground)
                        }
                        .accessibilityLabel("About HushMap")
                        
                        if headerExpanded {
                            Text("About")
                                .font(.caption2)
                                .foregroundColor(.hushBackground.opacity(0.8))
                        }
                    }
                }
                
                Spacer()
                
                // Spacer to balance the chevron
                Spacer()
                    .frame(width: 20)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.hushMapShape.opacity(0.9))
            .cornerRadius(headerExpanded ? 12 : 16)
            
            // Expanded content - filters
            if headerExpanded {
                VStack(spacing: 12) {
                    Divider()
                        .background(Color.hushBackground.opacity(0.3))
                    
                    // Filter controls
                    VStack(spacing: 12) {
                        HStack {
                            Text("Filter Options")
                                .font(.headline)
                                .foregroundColor(.hushBackground)
                            Spacer()
                        }
                        
                        VStack(spacing: 8) {
                            Toggle("Group Pins by Location", isOn: $useClustering)
                                .foregroundColor(.hushBackground)
                            Toggle("Sort by Most Recent", isOn: $sortByRecent)
                                .foregroundColor(.hushBackground)
                        }
                        .padding()
                        .background(Color.hushMapLines.opacity(0.8))
                        .cornerRadius(12)

                        DateFilterView(startDate: $startDate, endDate: $endDate)

                        ThresholdSliderView(
                            noiseThreshold: $maxNoiseThreshold,
                            crowdThreshold: $maxCrowdThreshold,
                            lightingThreshold: $maxLightingThreshold
                        )

                        Button("Reset Filters") {
                            maxNoiseThreshold = 1.0
                            maxCrowdThreshold = 1.0
                            maxLightingThreshold = 1.0
                            startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                            endDate = Date()
                            useClustering = true
                            sortByRecent = false
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.hushBackground)
                        .accessibilityLabel("Reset all filters and sorting options")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .background(Color.hushMapShape.opacity(0.9))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    var filteredPins: [ReportPin] {
        // Filter reports based on user criteria
        let filtered = reports.filter { report in
            // Date filter
            let isInDateRange = report.timestamp >= startDate && report.timestamp <= endDate
            
            // Sensory level filters (reports with levels <= threshold)
            let meetsNoiseThreshold = report.noise <= maxNoiseThreshold
            let meetsCrowdThreshold = report.crowds <= maxCrowdThreshold
            let meetsLightingThreshold = report.lighting <= maxLightingThreshold
            
            return isInDateRange && meetsNoiseThreshold && meetsCrowdThreshold && meetsLightingThreshold
        }
        
        // Convert to pins
        var pins: [ReportPin] = []
        
        if useClustering {
            // Group by location identifier and create one pin per location
            let groupedReports = Dictionary(grouping: filtered) { $0.locationIdentifier }
            
            for (_, reportsAtLocation) in groupedReports {
                if let representativeReport = reportsAtLocation.first {
                    // Calculate average sensory levels
                    let avgNoise = reportsAtLocation.map { $0.noise }.reduce(0, +) / Double(reportsAtLocation.count)
                    let avgCrowds = reportsAtLocation.map { $0.crowds }.reduce(0, +) / Double(reportsAtLocation.count)
                    let avgLighting = reportsAtLocation.map { $0.lighting }.reduce(0, +) / Double(reportsAtLocation.count)
                    
                    let pin = ReportPin(
                        coordinate: representativeReport.coordinate,
                        reportCount: reportsAtLocation.count,
                        averageNoise: avgNoise,
                        averageCrowds: avgCrowds,
                        averageLighting: avgLighting,
                        latestTimestamp: reportsAtLocation.max(by: { $0.timestamp < $1.timestamp })?.timestamp ?? representativeReport.timestamp
                    )
                    pins.append(pin)
                }
            }
        } else {
            // Create individual pins for each report
            pins = filtered.map { report in
                ReportPin(
                    coordinate: report.coordinate,
                    reportCount: 1,
                    averageNoise: report.noise,
                    averageCrowds: report.crowds,
                    averageLighting: report.lighting,
                    latestTimestamp: report.timestamp
                )
            }
        }
        
        // Sort if requested
        if sortByRecent {
            return pins.sorted { $0.latestTimestamp > $1.latestTimestamp }
        } else {
            return pins
        }
    }

}

struct ReportPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let reportCount: Int
    let averageNoise: Double
    let averageCrowds: Double
    let averageLighting: Double
    let latestTimestamp: Date
    
    var averageSensoryLevel: Double {
        (averageNoise + averageCrowds + averageLighting) / 3.0
    }
    
    var qualityColor: Color {
        switch averageSensoryLevel {
        case 0.0..<0.3: return Color(red: 0.2, green: 0.8, blue: 0.3) // Vibrant green
        case 0.3..<0.5: return Color(red: 0.4, green: 0.7, blue: 0.9) // Bright blue  
        case 0.5..<0.7: return Color(red: 1.0, green: 0.8, blue: 0.0) // Bright yellow
        case 0.7..<0.9: return Color(red: 1.0, green: 0.5, blue: 0.0) // Orange
        default: return Color(red: 0.9, green: 0.2, blue: 0.2) // Bright red
        }
    }
    
    var qualityRating: String {
        switch averageSensoryLevel {
        case 0.0..<0.3: return "Excellent"
        case 0.3..<0.5: return "Good"
        case 0.5..<0.7: return "Fair"
        case 0.7..<0.9: return "Poor"
        default: return "Very Poor"
        }
    }
}

struct ReportPinView: View {
    let pin: ReportPin

    var body: some View {
        ZStack {
            // Drop shadow circle
            Circle()
                .fill(Color.black.opacity(0.3))
                .frame(width: 34, height: 34)
                .offset(x: 1, y: 2)
            
            // Main pin body
            Circle()
                .fill(pin.qualityColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                )
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.2), lineWidth: 1)
                )
            
            // Inner content
            if pin.reportCount > 1 {
                Text("\(pin.reportCount)")
                    .font(.caption)
                    .fontWeight(.black)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.7), radius: 1, x: 0, y: 1)
            } else {
                // Single dot for individual reports
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            }
        }
        .scaleEffect(pin.reportCount > 1 ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: pin.reportCount)
    }
}

struct DateFilterView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date

    var body: some View {
        VStack {
            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
            DatePicker("End Date", selection: $endDate, displayedComponents: .date)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct ThresholdSliderView: View {
    @Binding var noiseThreshold: Double
    @Binding var crowdThreshold: Double
    @Binding var lightingThreshold: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "speaker.wave.3")
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text("Noise: \(Int(noiseThreshold * 10))/10")
                        .font(.subheadline)
                    Slider(value: $noiseThreshold, in: 0...1)
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "person.2")
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text("Crowd: \(Int(crowdThreshold * 10))/10")
                        .font(.subheadline)
                    Slider(value: $crowdThreshold, in: 0...1)
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "lightbulb")
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text("Lighting: \(Int(lightingThreshold * 10))/10")
                        .font(.subheadline)
                    Slider(value: $lightingThreshold, in: 0...1)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct PinDetailView: View {
    let pin: ReportPin
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "location.circle.fill")
                                .foregroundColor(.hushBackground)
                                .font(.title2)
                            
                            VStack(alignment: .leading) {
                                Text("Location Report")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("\(String(format: "%.4f", pin.coordinate.latitude)), \(String(format: "%.4f", pin.coordinate.longitude))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // Quality indicator
                        HStack {
                            Text("Overall Quality:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(pin.qualityRating)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(pin.qualityColor)
                            
                            Spacer()
                            
                            if pin.reportCount > 1 {
                                Text("\(pin.reportCount) reports")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.hushMapShape.opacity(0.3))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color.hushMapShape.opacity(0.3))
                    .cornerRadius(12)
                    
                    // Sensory levels
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Sensory Environment")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            SensoryDetailRow(
                                title: "Noise Level",
                                level: pin.averageNoise,
                                icon: "speaker.wave.3",
                                description: getSensoryDescription(level: pin.averageNoise, type: "noise")
                            )
                            
                            SensoryDetailRow(
                                title: "Crowd Level", 
                                level: pin.averageCrowds,
                                icon: "person.2",
                                description: getSensoryDescription(level: pin.averageCrowds, type: "crowd")
                            )
                            
                            SensoryDetailRow(
                                title: "Lighting",
                                level: pin.averageLighting,
                                icon: "lightbulb",
                                description: getSensoryDescription(level: pin.averageLighting, type: "lighting")
                            )
                        }
                    }
                    .padding()
                    .background(Color.hushWaterRoad.opacity(0.3))
                    .cornerRadius(12)
                    
                    // Timing info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Report Information")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                            Text("Last updated:")
                                .foregroundColor(.secondary)
                            Text(pin.latestTimestamp, style: .relative)
                                .fontWeight(.medium)
                            Text("ago")
                                .foregroundColor(.secondary)
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(Color.hushWaterRoad.opacity(0.3))
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Location Details")
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
    }
    
    private func getSensoryDescription(level: Double, type: String) -> String {
        switch type {
        case "noise":
            switch level {
            case 0.0..<0.2: return "Very quiet - whisper levels"
            case 0.2..<0.4: return "Quiet - soft conversations"
            case 0.4..<0.6: return "Moderate - normal conversation"
            case 0.6..<0.8: return "Loud - raised voices needed"
            default: return "Very loud - uncomfortable"
            }
        case "crowd":
            switch level {
            case 0.0..<0.2: return "Nearly empty - plenty of space"
            case 0.2..<0.4: return "Few people - comfortable spacing"
            case 0.4..<0.6: return "Moderate crowds - some activity"
            case 0.6..<0.8: return "Busy - limited space"
            default: return "Very crowded - minimal space"
            }
        case "lighting":
            switch level {
            case 0.0..<0.3: return "Dim - cozy atmosphere"
            case 0.3..<0.45: return "Soft - warm lighting"
            case 0.45..<0.6: return "Moderate - comfortable brightness"
            case 0.6..<0.8: return "Bright - well illuminated"
            default: return "Very bright - intense lighting"
            }
        default:
            return "Unknown"
        }
    }
}

struct SensoryDetailRow: View {
    let title: String
    let level: Double
    let icon: String
    let description: String
    
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(levelText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(levelColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(levelColor.opacity(0.2))
                    .cornerRadius(4)
            }
            
            // Progress bar
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
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct MapLegendView: View {
    @Binding var isVisible: Bool
    
    // Define the quality levels and their colors (matching ReportPin)
    private let qualityLevels: [(String, Color, String)] = [
        ("Excellent", Color(red: 0.2, green: 0.8, blue: 0.3), "Very quiet, comfortable"),
        ("Good", Color(red: 0.4, green: 0.7, blue: 0.9), "Mostly pleasant"),
        ("Fair", Color(red: 1.0, green: 0.8, blue: 0.0), "Moderate levels"),
        ("Poor", Color(red: 1.0, green: 0.5, blue: 0.0), "Challenging conditions"),
        ("Very Poor", Color(red: 0.9, green: 0.2, blue: 0.2), "Avoid if sensitive")
    ]
    
    var body: some View {
        if isVisible {
            VStack(alignment: .trailing, spacing: 8) {
                // Header
                HStack {
                    Text("Sensory Quality")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isVisible = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 4)
                
                // Legend items
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(qualityLevels, id: \.0) { level in
                        HStack(spacing: 8) {
                            // Pin representation
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.2))
                                    .frame(width: 18, height: 18)
                                    .offset(x: 0.5, y: 1)
                                
                                Circle()
                                    .fill(level.1)
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black.opacity(0.2), lineWidth: 0.5)
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(level.0)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text(level.2)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.hushMapShape.opacity(0.95))
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            )
            .frame(width: 200)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity),
                removal: .scale(scale: 0.8).combined(with: .opacity)
            ))
        }
    }
}

struct HomeMapView_Previews: PreviewProvider {
    static var previews: some View {
        HomeMapView()
    }
}

