import SwiftUI
import MapKit
import CoreLocation
import SwiftData
import GoogleMaps
import Combine
import Foundation

enum HomeMapSheet: Identifiable, Equatable {
    case about
    case placeSearch
    case placePrediction(PlaceDetails)
    case mapTapPrediction(PlaceDetails)
    case pinDetail(ReportPin)
    case addReport(CLLocationCoordinate2D?, String?)

    var id: String {
        switch self {
        case .about: return "about"
        case .placeSearch: return "placeSearch"
        case .placePrediction(let place): return "placePrediction-\(place.name)-\(place.coordinate.latitude)-\(place.coordinate.longitude)"
        case .mapTapPrediction(let place): return "mapTapPrediction-\(place.name)-\(place.coordinate.latitude)-\(place.coordinate.longitude)"
        case .pinDetail(let pin): return "pinDetail-\(pin.id)"
        case .addReport(let coord, _):
            if let coord = coord {
                return "addReport-\(coord.latitude)-\(coord.longitude)"
            }
            return "addReport"
        }
    }

    static func == (lhs: HomeMapSheet, rhs: HomeMapSheet) -> Bool {
        switch (lhs, rhs) {
        case (.about, .about), (.placeSearch, .placeSearch):
            return true
        case (.placePrediction(let place1), .placePrediction(let place2)):
            return place1.name == place2.name && place1.coordinate.latitude == place2.coordinate.latitude && place1.coordinate.longitude == place2.coordinate.longitude
        case (.mapTapPrediction(let place1), .mapTapPrediction(let place2)):
            return place1.name == place2.name && place1.coordinate.latitude == place2.coordinate.latitude && place1.coordinate.longitude == place2.coordinate.longitude
        case (.pinDetail(let pin1), (.pinDetail(let pin2))):
            return pin1.id == pin2.id
        case (.addReport(let coord1, let name1), .addReport(let coord2, let name2)):
            return coord1?.latitude == coord2?.latitude && coord1?.longitude == coord2?.longitude && name1 == name2
        default:
            return false
        }
    }
}

struct HomeMapView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var errorState = ErrorStateViewModel()
    @StateObject private var deviceCapability = DeviceCapabilityService.shared
    @StateObject private var locationResolver = ReportLocationResolver()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var modelContext

    // Replace @Query with manual state to avoid blocking UI on SwiftData updates
    @State private var reports: [Report] = []
    @State private var isLoadingReports = false

    // Note: Removed Apple Maps position state - using currentCoordinate for Google Maps
    @State private var useClustering = true
    @State private var sortByRecent = false
    @State private var startDate = DateComponents(calendar: Calendar.current, year: 2025, month: 1, day: 1).date ?? Date()
    @State private var endDate = Date()
    @State private var maxNoiseThreshold: Double = 1.0
    @State private var maxCrowdThreshold: Double = 1.0
    @State private var maxLightingThreshold: Double = 1.0

    // Cache for filteredPins to avoid recomputing on every view update
    @State private var cachedPins: [ReportPin] = []
    @State private var lastReportsHash: Int = 0
    @State private var updateTask: Task<Void, Never>?
    @State private var refreshTimer: Timer?
    
    // Consolidated sheet state
    @State private var activeSheet: HomeMapSheet?
    
    // States for place search and predictions
    @State private var selectedPlace: PlaceDetails?
    @State private var tempPin: PlaceDetails?
    
    // States for map tap predictions
    @State private var isLookingUpLocation = false
    
    // States for temp pin display and report interaction
    @State private var showingTempPin = false
    @State private var tempPinLocation: CLLocationCoordinate2D?
    @State private var selectedReport: Report?
    
    // States for pin interaction
    @State private var selectedPin: ReportPin?
    
    // State for legend
    @State private var showLegend = false
    
    // State for hamburger menu
    @State private var showHamburgerMenu = false
    
    // State for expandable header
    @State private var headerExpanded = false
    
    // State for map style (Google Maps)
    @State private var currentMapStyle: Int = 0 // 0 = standard, 1 = satellite, 2 = hybrid, 3 = terrain
    @State private var currentCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // Default fallback
    @State private var googleMapType: GMSMapViewType = .normal
    @State private var hasInitializedLocation = false // Track if we've set initial location

    // Community stats
    @State private var worldwideReportCount: Int?

    var body: some View {
        ZStack {
            // Background matching bottom nav bar
            Color.hushMapShape.opacity(0.95)
                .ignoresSafeArea(.all, edges: .all)
                .task {
                    // Fetch worldwide count when view appears
                    await fetchWorldwideReportCount()
                }
            
            // Show error state if there's a location error
            if let locationError = locationManager.locationError {
                ErrorStateView(
                    error: locationError,
                    retryAction: {
                        locationManager.requestLocationPermission()
                    },
                    settingsAction: {
                        openAppSettings()
                    }
                )
                .transition(.opacity)
            } else {
                GoogleMapView(
                mapType: $googleMapType,
                cameraPosition: $currentCoordinate,
                pins: cachedPins,
                onPinTap: { pin in
                    selectedPin = pin
                    activeSheet = .pinDetail(pin)
                },
                tempPin: tempPin,
                onMapTap: { coordinate in
                    handleMapTap(at: coordinate)
                },
                onPOITap: { placeID, name, location in
                    print("User tapped POI: \(name) with ID: \(placeID)")

                    // Create place details from the POI information
                    let place = PlaceDetails(name: name, address: "", coordinate: location)
                    tempPin = place
                    self.selectedPlace = place
                    self.activeSheet = .mapTapPrediction(place)
                }
            )
            .ignoresSafeArea(.all, edges: .all)
            .onAppear {
                // Load reports asynchronously to avoid blocking UI
                loadReportsAsync()

                // Update pins cache immediately for initial render (will be empty at first)
                updateFilteredPinsNow()

                // Request location permission (checks services asynchronously)
                locationManager.requestLocationPermission()

                // Set up periodic refresh to catch new reports from Firestore
                refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                    loadReportsAsync()
                }

                // If location is already available, use it immediately
                if let location = locationManager.lastLocation, !hasInitializedLocation {
                    currentCoordinate = location
                    hasInitializedLocation = true
                }

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
                    print("📍 Setting initial location: \(newLocation)")
                    currentCoordinate = newLocation
                    hasInitializedLocation = true

                    // Post notification to animate camera to user location with proper zoom
                    NotificationCenter.default.post(
                        name: Notification.Name("CenterMapOnCoordinate"),
                        object: nil,
                        userInfo: ["coordinate": newLocation]
                    )
                } else if newLocation != nil {
                    print("⚠️ Ignoring location update - already initialized")
                }
            }
            .onDisappear {
                // Cancel any pending pin updates
                updateTask?.cancel()

                // Stop periodic refresh timer
                refreshTimer?.invalidate()
                refreshTimer = nil

                // Clean up notification observer to prevent memory leak
                NotificationCenter.default.removeObserver(self, name: Notification.Name("CenterMapOnCoordinate"), object: nil)
            }

            // Map Legend and Community Stats - ALWAYS VISIBLE FOR TESTING
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    // Community Stats Badge (bottom left) - ALWAYS SHOW
                    communityStatsBadge(count: worldwideReportCount ?? 999)
                        .background(Color.red.opacity(0.3)) // DEBUG: Red background to make it obvious

                    Spacer()

                    // Legend (bottom right)
                    MapLegendView(isVisible: $showLegend)
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 200) // Position above the bottom sheet
            .background(Color.blue.opacity(0.2)) // DEBUG: Blue background to see the container
            
            // Hamburger Menu
            if showHamburgerMenu {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: deviceCapability.getOptimalAnimationDuration())) {
                            showHamburgerMenu = false
                        }
                    }
                    .transition(.opacity)
                
                VStack {
                    HStack {
                        HamburgerMenuView(
                            isPresented: $showHamburgerMenu,
                            showLegend: $showLegend,
                            showAbout: .init(
                                get: { activeSheet == .about },
                                set: { shouldShow in
                                    if shouldShow {
                                        activeSheet = .about
                                    } else {
                                        activeSheet = nil
                                    }
                                }
                            ),
                            currentMapStyle: $googleMapType,
                            onMapStyleSelected: { newStyle in
                                googleMapType = newStyle
                            },
                            mapStyleIcon: mapStyleIcon,
                            mapStyleLabel: mapStyleLabel
                        )
                        .frame(width: 280, height: 240)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.leading, 16)
                .padding(.top, 120)
                .animation(.easeInOut(duration: deviceCapability.getOptimalAnimationDuration()), value: showHamburgerMenu)
            }

            VStack {
                expandableHeader
                    .padding(.top, dynamicTypeSize >= .accessibility1 ? 12 : 8)
                Spacer()
            }
            }
        }
        .errorAlert(
            errorState: errorState,
            retryAction: {
                locationManager.requestLocationPermission()
            },
            settingsAction: {
                openAppSettings()
            }
        )
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .about:
                AboutView()
            case .placeSearch:
                PlaceSearchViewWrapper(
                    onPlaceSelected: { place in
                        handlePlaceSelection(place)
                        activeSheet = nil
                    }
                )
            case .placePrediction(let place):
                PlacePredictionView(
                    place: place, 
                    isPresented: .init(
                        get: { activeSheet != nil },
                        set: { _ in activeSheet = nil }
                    )
                )
            case .mapTapPrediction(let place):
                PlacePredictionView(
                    place: place, 
                    isPresented: .init(
                        get: { activeSheet != nil },
                        set: { _ in activeSheet = nil }
                    )
                )
            case .pinDetail(let pin):
                PinDetailView(
                    pin: pin,
                    onAddReport: { coordinate, displayName in
                        // Close pin detail sheet, then open AddReportView
                        activeSheet = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            activeSheet = .addReport(coordinate, displayName)
                        }
                    }
                )
            case .addReport(let location, let locationName):
                if let location = location {
                    AddReportView(location: location, locationName: locationName)
                } else {
                    AddReportView()
                }
            }
        }
        .onChange(of: [maxNoiseThreshold, maxCrowdThreshold, maxLightingThreshold]) { _, _ in
            // User filter changes - update immediately for responsiveness
            updateFilteredPinsNow()
        }
        .onChange(of: useClustering) { _, _ in
            updateFilteredPinsNow()
        }
        .onChange(of: sortByRecent) { _, _ in
            updateFilteredPinsNow()
        }
        .onChange(of: startDate) { _, _ in
            updateFilteredPinsNow()
        }
        .onChange(of: endDate) { _, _ in
            updateFilteredPinsNow()
        }
    }
    
    // Load reports asynchronously to avoid blocking main thread
    private func loadReportsAsync() {
        guard !isLoadingReports else { return }
        isLoadingReports = true

        Task { @MainActor in
            // Fetch reports on main actor (required for SwiftData)
            let descriptor = FetchDescriptor<Report>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )

            do {
                let fetchedReports = try modelContext.fetch(descriptor)

                // Only update if report count changed to avoid unnecessary updates
                if self.reports.count != fetchedReports.count {
                    self.reports = fetchedReports
                    self.scheduleUpdateFilteredPins(delay: .milliseconds(500))
                }
                self.isLoadingReports = false
            } catch {
                print("Error loading reports: \(error)")
                self.isLoadingReports = false
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
            activeSheet = .placePrediction(selectedPlace!)
        }
    }
    
    private func handleMapTap(at coordinate: CLLocationCoordinate2D) {
        // Create a generic place for the tapped location
        let place = PlaceDetails(
            name: "Selected Location",
            address: "Coordinates: \(String(format: "%.5f", coordinate.latitude)), \(String(format: "%.5f", coordinate.longitude))",
            coordinate: coordinate
        )
        
        // Set the place and show prediction
        self.selectedPlace = place
        self.tempPin = place
        self.activeSheet = .mapTapPrediction(place)
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
                    withAnimation(.easeInOut(duration: deviceCapability.getOptimalAnimationDuration())) {
                        headerExpanded.toggle()
                    }
                }) {
                    Image(systemName: headerExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.hushPrimaryText)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(headerExpanded ? "Collapse header" : "Expand header")
                
                Spacer()
                
                // Control buttons
                HStack(alignment: .bottom, spacing: 16) {
                    // Hamburger menu button
                    Button(action: {
                        withAnimation(.easeInOut(duration: deviceCapability.getOptimalAnimationDuration())) {
                            // Close filters if open, then open menu
                            if headerExpanded {
                                headerExpanded = false
                            }
                            showHamburgerMenu.toggle()
                        }
                    }) {
                        VStack(spacing: 2) {
                            Image(systemName: "line.3.horizontal")
                                .font(.title2)
                                .foregroundColor(.hushPrimaryText)
                                .frame(height: 28)
                            
                            Text("Menu")
                                .hushCaption()
                                .foregroundColor(.hushPrimaryText.opacity(0.8))
                                .minimumScaleFactor(0.8)
                                .lineLimit(1)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Open menu")
                    
                    // Filters button
                    Button(action: {
                        // Close menu if open, then toggle filters
                        withAnimation(.easeInOut(duration: deviceCapability.getOptimalAnimationDuration())) {
                            if showHamburgerMenu {
                                showHamburgerMenu = false
                            }
                            headerExpanded.toggle()
                        }
                    }) {
                        VStack(spacing: 2) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.title2)
                                .foregroundColor(.hushPrimaryText)
                                .frame(height: 28)
                            
                            Text("Filters")
                                .hushCaption()
                                .foregroundColor(.hushPrimaryText.opacity(0.8))
                                .minimumScaleFactor(0.8)
                                .lineLimit(1)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Show filters")
                    
                    // Search button
                    Button(action: {
                        // Close filters if open, then show search
                        if headerExpanded {
                            withAnimation(.easeInOut(duration: deviceCapability.getOptimalAnimationDuration())) {
                                headerExpanded = false
                            }
                        }
                        activeSheet = .placeSearch
                    }) {
                        VStack(spacing: 2) {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                                .foregroundColor(.hushPrimaryText)
                                .frame(height: 28)
                            
                            Text("Search")
                                .hushCaption()
                                .foregroundColor(.hushPrimaryText.opacity(0.8))
                                .minimumScaleFactor(0.8)
                                .lineLimit(1)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Search for places")
                }
                
                Spacer()
                
                // Spacer to balance the chevron
                Spacer()
                    .frame(width: 20)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.hushOffWhite.opacity(0.95))
            .cornerRadius(headerExpanded ? 12 : 16)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Expanded content - filters
            if headerExpanded {
                VStack(spacing: dynamicTypeSize >= .accessibility1 ? 16 : 12) {
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
                            
                            // Show performance info for debugging
                            if deviceCapability.performanceTier != .high {
                                Text("Optimized for \(deviceCapability.performanceTier.rawValue) performance")
                                    .font(.caption2)
                                    .foregroundColor(.hushBackground.opacity(0.7))
                            }
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
                            startDate = DateComponents(calendar: Calendar.current, year: 2025, month: 1, day: 1).date ?? Date()
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
                .background(Color.hushOffWhite.opacity(0.95))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // Compute hash of filter dependencies to detect changes
    private func computeFilterHash() -> Int {
        var hasher = Hasher()
        hasher.combine(reports.count)
        hasher.combine(startDate)
        hasher.combine(endDate)
        hasher.combine(maxNoiseThreshold)
        hasher.combine(maxCrowdThreshold)
        hasher.combine(maxLightingThreshold)
        hasher.combine(useClustering)
        hasher.combine(sortByRecent)
        return hasher.finalize()
    }

    // Debounced update to batch rapid changes (e.g., during migration batches)
    private func scheduleUpdateFilteredPins(delay: Duration = .milliseconds(300)) {
        // Cancel any pending update
        updateTask?.cancel()

        // Schedule new update
        updateTask = Task {
            do {
                try await Task.sleep(for: delay)
                if !Task.isCancelled {
                    updateFilteredPinsNow()
                }
            } catch {}
        }
    }

    // Immediate update without debouncing
    private func updateFilteredPinsNow() {
        let currentHash = computeFilterHash()
        guard currentHash != lastReportsHash else { return }

        lastReportsHash = currentHash

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

        // Use performance-aware clustering
        let shouldCluster = useClustering || deviceCapability.shouldUseClustering(for: filtered.count)

        if shouldCluster {
            // Group by location identifier and create one pin per location
            let groupedReports = Dictionary(grouping: filtered) { $0.locationIdentifier }

            for (_, reportsAtLocation) in groupedReports {
                if let representativeReport = reportsAtLocation.first {
                    // Calculate average sensory levels
                    let avgNoise = reportsAtLocation.map { $0.noise }.reduce(0, +) / Double(reportsAtLocation.count)
                    let avgCrowds = reportsAtLocation.map { $0.crowds }.reduce(0, +) / Double(reportsAtLocation.count)
                    let avgLighting = reportsAtLocation.map { $0.lighting }.reduce(0, +) / Double(reportsAtLocation.count)

                    let displayName = representativeReport.displayName ?? reportsAtLocation.compactMap { $0.displayName }.first
                    let displayTier = representativeReport.displayTier ?? reportsAtLocation.compactMap { $0.displayTier }.first
                    let avgQuietScore = Int((reportsAtLocation.map { $0.quietScore }.reduce(0, +)) / reportsAtLocation.count)

                    // Calculate average confidence
                    let avgConfidence = reportsAtLocation.compactMap { $0.confidence }.reduce(0, +) / Double(max(reportsAtLocation.compactMap { $0.confidence }.count, 1))

                    // For clustered reports, show the most recent contributor
                    let mostRecentReport = reportsAtLocation.max(by: { $0.timestamp < $1.timestamp }) ?? representativeReport
                    let contributorName: String?
                    if reportsAtLocation.count > 1 {
                        contributorName = "Multiple Contributors"
                    } else {
                        contributorName = mostRecentReport.submittedByUserName ?? "You"
                    }

                    let pin = ReportPin(
                        coordinate: representativeReport.coordinate,
                        displayName: displayName,
                        displayTier: displayTier,
                        confidence: avgConfidence > 0 ? avgConfidence : nil,
                        reportCount: reportsAtLocation.count,
                        averageNoise: avgNoise,
                        averageCrowds: avgCrowds,
                        averageLighting: avgLighting,
                        averageQuietScore: avgQuietScore,
                        latestTimestamp: mostRecentReport.timestamp,
                        submittedByUserName: contributorName,
                        submittedByUserProfileImageURL: reportsAtLocation.count == 1 ? mostRecentReport.submittedByUserProfileImageURL : nil
                    )
                    pins.append(pin)
                }
            }
        } else {
            // Create individual pins for each report
            pins = filtered.map { report in
                ReportPin(
                    coordinate: report.coordinate,
                    displayName: report.displayName,
                    displayTier: report.displayTier,
                    confidence: report.confidence,
                    reportCount: 1,
                    averageNoise: report.noise,
                    averageCrowds: report.crowds,
                    averageLighting: report.lighting,
                    averageQuietScore: report.quietScore,
                    latestTimestamp: report.timestamp,
                    submittedByUserName: report.submittedByUserName ?? "You",
                    submittedByUserProfileImageURL: report.submittedByUserProfileImageURL
                )
            }
        }

        // Sort if requested
        if sortByRecent {
            pins = pins.sorted { $0.latestTimestamp > $1.latestTimestamp }
        }

        // Limit pins for performance on older devices
        let maxPins = deviceCapability.mapSettings.maxPinsBeforeClustering
        if pins.count > maxPins && !shouldCluster {
            // Take the most recent pins if we're not clustering
            pins = Array(pins.prefix(maxPins))
        }

        cachedPins = pins
    }

    // MARK: - Community Stats Badge

    @ViewBuilder
    private func communityStatsBadge(count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "globe.americas.fill")
                .font(.caption)
                .foregroundColor(.hushBackground)

            VStack(alignment: .leading, spacing: 0) {
                Text("\(count.formatted())")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.hushPrimaryText)

                Text("reports worldwide")
                    .font(.caption2)
                    .foregroundColor(.hushSecondaryText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.hushMapShape.opacity(0.95))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) reports from the HushMap community worldwide")
    }

    @ViewBuilder
    private func communityStatsLoadingBadge() -> some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.7)

            Text("Loading...")
                .font(.caption2)
                .foregroundColor(.hushSecondaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.hushMapShape.opacity(0.95))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
    }

    // MARK: - Fetch Worldwide Count

    private func fetchWorldwideReportCount() async {
        print("🌍 Fetching worldwide report count...")
        do {
            let firestoreReports = try await FirestoreService.shared.downloadAllReports()
            await MainActor.run {
                worldwideReportCount = firestoreReports.count
                print("🌍 ✅ Fetched \(firestoreReports.count) reports worldwide")
            }
        } catch {
            print("🌍 ❌ Failed to fetch worldwide report count: \(error)")
        }
    }

}

struct ReportPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let displayName: String?
    let displayTier: DisplayTier?
    let confidence: Double? // Location resolution confidence
    let reportCount: Int
    let averageNoise: Double
    let averageCrowds: Double
    let averageLighting: Double
    let averageQuietScore: Int
    let latestTimestamp: Date
    let submittedByUserName: String? // Who submitted this report
    let submittedByUserProfileImageURL: String? // User profile image

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
    
    var friendlyDisplayName: String {
        guard let displayName = displayName else { return "Unknown area" }
        
        switch displayTier {
        case .poi:
            // Apply hedged copy for low confidence POIs
            if let confidence = confidence, confidence < 0.8 {
                return "near \(displayName)"
            }
            return displayName
        case .street:
            return displayName  
        case .area:
            return displayName.hasSuffix(" area") ? displayName : "\(displayName) area"
        case nil:
            return "Unknown area"
        }
    }
    
    // Accessibility-friendly display name with additional context
    var accessibleDisplayName: String {
        let baseName = friendlyDisplayName
        
        switch displayTier {
        case .area:
            return "Area label: \(baseName)"
        case .poi:
            if let confidence = confidence, confidence < 0.8 {
                return "Approximate location: \(baseName)"
            }
            return baseName
        case .street, nil:
            return baseName
        }
    }
    
    // Compact display for small surfaces
    var compactDisplay: String {
        guard let displayName = displayName else { return "Unknown" }
        return LabelFormatter.compact(displayName, max: 18)
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
    let onAddReport: ((CLLocationCoordinate2D, String?) -> Void)?
    @Environment(\.dismiss) private var dismiss

    // Default initializer for backward compatibility
    init(pin: ReportPin) {
        self.pin = pin
        self.onAddReport = nil
    }

    // Initializer with callback for Quick Update and Log Full Visit
    init(pin: ReportPin, onAddReport: @escaping (CLLocationCoordinate2D, String?) -> Void) {
        self.pin = pin
        self.onAddReport = onAddReport
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Quick Update section at the top
                    if let onAddReport = onAddReport {
                        QuickUpdateView(
                            coordinate: pin.coordinate,
                            displayName: pin.displayName,
                            onLogFullVisit: {
                                onAddReport(pin.coordinate, pin.displayName)
                            }
                        )
                    }

                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "location.circle.fill")
                                .foregroundColor(.hushBackground)
                                .font(.title2)
                            
                            VStack(alignment: .leading) {
                                // Use LabelFormatter.shortTwoLine for proper truncation
                                let (primaryLabel, _) = LabelFormatter.shortTwoLine(
                                    primary: pin.friendlyDisplayName,
                                    secondary: nil,
                                    maxPrimary: 40,
                                    maxSecondary: 40
                                )
                                
                                Text(primaryLabel)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .accessibilityLabel(pin.accessibleDisplayName)
                                
                                HStack {
                                    Text("Quiet 👍 \(pin.averageQuietScore)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Text("•")
                                        .foregroundColor(.secondary)
                                    
                                    Text(pin.latestTimestamp, style: .relative)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text("ago")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
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
                    
                    // Get Directions Button
                    Button(action: {
                        openInAppleMaps()
                    }) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.white)
                            Text("Get Directions")
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.hushBackground)
                        .cornerRadius(8)
                    }
                    
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
    
    private func openInAppleMaps() {
        let coordinate = pin.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = pin.displayName ?? pin.friendlyDisplayName
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
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

