import SwiftUI
import GoogleMaps
import SwiftData
import CoreLocation

enum SingleScreenMapSheet: Identifiable, Equatable {
    case addReport(CLLocationCoordinate2D?, String?)
    case nearby
    case locationReport(ReportPin)
    case profile
    case mapStylePicker
    case communityStats
    case placePrediction(PlaceDetails)

    var id: String {
        switch self {
        case .addReport: return "addReport"
        case .nearby: return "nearby"
        case .locationReport(let pin): return "locationReport-\(pin.id)"
        case .profile: return "profile"
        case .mapStylePicker: return "mapStylePicker"
        case .communityStats: return "communityStats"
        case .placePrediction(let place): return "placePrediction-\(place.name)"
        }
    }

    static func == (lhs: SingleScreenMapSheet, rhs: SingleScreenMapSheet) -> Bool {
        switch (lhs, rhs) {
        case (.nearby, .nearby), (.profile, .profile), (.mapStylePicker, .mapStylePicker), (.communityStats, .communityStats):
            return true
        case (.addReport(let coord1, let name1), .addReport(let coord2, let name2)):
            return coord1?.latitude == coord2?.latitude &&
                   coord1?.longitude == coord2?.longitude &&
                   name1 == name2
        case (.locationReport(let pin1), .locationReport(let pin2)):
            return pin1.id == pin2.id
        case (.placePrediction(let p1), .placePrediction(let p2)):
            return p1.name == p2.name &&
                   p1.coordinate.latitude == p2.coordinate.latitude &&
                   p1.coordinate.longitude == p2.coordinate.longitude
        default:
            return false
        }
    }
}

struct SingleScreenMapView: View {
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var shouldFocusSearch = false
    @State private var showBottomSheet = true
    @State private var bottomSheetDetent: PresentationDetent = .height(150)

    // Map-related state
    @State private var currentMapStyle: GMSMapViewType = .normal
    
    // Consolidated sheet state
    @State private var activeSheet: SingleScreenMapSheet?
    
    // Filter state
    @State private var selectedFilters = FilterOptions()
    @State private var startDate = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1)) ?? Date()
    @State private var endDate = Date()
    
    // Bottom sheet related state
    @State private var showLegend = false
    @State private var showAbout = false
    @State private var selectedPin: ReportPin?
    @State private var prefilledReportLocation: CLLocationCoordinate2D?
    @State private var prefilledReportLocationName: String?
    @State private var useClustering = false
    @State private var sortByRecent = false
    @State private var maxNoiseThreshold = 1.0
    @State private var maxCrowdThreshold = 1.0
    @State private var maxLightingThreshold = 1.0
    
    // Map navigation state
    @State private var cameraPosition: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    @State private var shouldUpdateCamera = false
    @State private var hasSetInitialLocation = false
    
    // Data queries
    @Query private var allReports: [Report]
    @Query private var users: [User]
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("highContrastMode") private var highContrastMode = false
    
    // Authentication service
    @StateObject private var authService = AuthenticationService.shared
    
    // Location service for proximity filtering
    @StateObject private var locationManager = LocationManager()

    // Location resolver for populating displayName on reports
    @StateObject private var locationResolver = ReportLocationResolver()

    // Community stats
    @State private var worldwideReportCount: Int?
    @State private var communityStats: CommunityStats?

    // Temporary pins for AI predictions (purple markers on map)
    @State private var tempPins: [PlaceDetails] = []

    // Find current user in SwiftData based on authentication
    private var currentSwiftDataUser: User? {
        guard let authenticatedUser = authService.currentUser else { return nil }
        
        // Find user by provider-specific ID
        return users.first { user in
            switch authenticatedUser.signInMethod {
            case .google:
                return user.googleID == authenticatedUser.id
            case .apple:
                return user.appleID == authenticatedUser.id
            case .none:
                return false
            }
        }
    }
    
    // Computed filtered reports based on current filters and date range
    private var filteredReports: [Report] {
        allReports.filter { report in
            // Date filter
            if report.timestamp < startDate || report.timestamp > endDate {
                return false
            }
            
            // Sensory level filters
            if !selectedFilters.noiseLevel.contains(report.noise) ||
               !selectedFilters.crowdLevel.contains(report.crowds) ||
               !selectedFilters.lightingLevel.contains(report.lighting) ||
               !selectedFilters.comfortLevel.contains(report.comfort) {
                return false
            }
            
            // My reports filter
            if selectedFilters.showOnlyMyReports {
                // Only show reports from authenticated user
                if let currentUser = currentSwiftDataUser {
                    return report.user?.id == currentUser.id
                } else {
                    // If not authenticated or no user found, show no reports
                    return false
                }
            }
            
            // Recent filter
            if selectedFilters.showOnlyRecent && !report.isFromThisWeek {
                return false
            }
            
            // Proximity filter
            if let proximityRadius = selectedFilters.proximityRadius,
               let userLocation = locationManager.lastLocation {
                let reportLocation = CLLocation(latitude: report.latitude, longitude: report.longitude)
                let userLocationCL = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                let distance = userLocationCL.distance(from: reportLocation)
                
                if distance > proximityRadius {
                    return false
                }
            }
            
            // Open now filter - check actual business hours
            if selectedFilters.showOnlyOpenNow {
                // Check if openNow is available and true
                if let openNow = report.openNow {
                    if !openNow {
                        return false // Place is closed
                    }
                } else {
                    // If no business hours data available, exclude from open now filter
                    return false
                }
            }
            
            return true
        }
    }
    
    // Convert filtered reports to ReportPins for map display
    private var reportPins: [ReportPin] {
        // Group reports by location (using locationIdentifier)
        let groupedReports = Dictionary(grouping: filteredReports) { $0.locationIdentifier }
        
        return groupedReports.compactMap { (locationId, reports) in
            guard let firstReport = reports.first else { return nil }

            // Calculate aggregated values
            let averageNoise = reports.map(\.noise).reduce(0, +) / Double(reports.count)
            let averageCrowds = reports.map(\.crowds).reduce(0, +) / Double(reports.count)
            let averageLighting = reports.map(\.lighting).reduce(0, +) / Double(reports.count)
            let averageQuietScore = reports.map(\.quietScore).reduce(0, +) / reports.count
            let latestTimestamp = reports.map(\.timestamp).max() ?? Date()

            // For clustered reports, show the most recent contributor
            let mostRecentReport = reports.max(by: { $0.timestamp < $1.timestamp }) ?? firstReport
            let contributorName: String?
            if reports.count > 1 {
                contributorName = "Multiple Contributors"
            } else {
                contributorName = mostRecentReport.submittedByUserName ?? "You"
            }

            return ReportPin(
                coordinate: firstReport.coordinate,
                displayName: firstReport.displayName,
                displayTier: firstReport.displayTier,
                confidence: firstReport.confidence,
                reportCount: reports.count,
                averageNoise: averageNoise,
                averageCrowds: averageCrowds,
                averageLighting: averageLighting,
                averageQuietScore: averageQuietScore,
                latestTimestamp: latestTimestamp,
                submittedByUserName: contributorName,
                submittedByUserProfileImageURL: reports.count == 1 ? mostRecentReport.submittedByUserProfileImageURL : nil
            )
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full-screen map background
                MapView(
                    mapStyle: currentMapStyle,
                    onMapStyleChanged: { newStyle in
                        currentMapStyle = newStyle
                    },
                    selectedFilters: selectedFilters,
                    startDate: startDate,
                    endDate: endDate,
                    pins: reportPins,
                    targetCameraPosition: shouldUpdateCamera ? cameraPosition : nil,
                    shouldUpdateCamera: shouldUpdateCamera,
                    onCameraUpdated: {
                        // Reset the update flag after camera has been updated
                        DispatchQueue.main.async {
                            shouldUpdateCamera = false
                        }
                    },
                    onPinTapped: { pin in
                        selectedPin = pin
                        activeSheet = .locationReport(pin)
                    },
                    onPOITap: { placeID, name, location in
                        // When user taps a Google Maps POI, show prediction view (purple pin appears later)
                        let place = PlaceDetails(name: name, address: "", coordinate: location)
                        activeSheet = .placePrediction(place)
                    },
                    tempPins: tempPins
                )
                .ignoresSafeArea(.all)
                .onTapGesture {
                    // Dismiss search when tapping map
                    dismissSearch()
                }
                
                // Floating search bar - hide when bottom sheet is fully expanded
                if bottomSheetDetent != .large {
                    VStack {
                        HStack {
                            FloatingSearchBar(
                                searchText: $searchText,
                                isSearching: $isSearching,
                                onPlaceSelected: { coordinate, placeName in
                                    // Update camera position to selected place
                                    withAnimation(.easeInOut(duration: 0.8)) {
                                        cameraPosition = coordinate
                                        shouldUpdateCamera = true
                                    }
                                },
                                shouldFocus: $shouldFocusSearch
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, geometry.safeAreaInsets.top + 80)
                            
                            Spacer()
                        }
                        
                        Spacer()
                    }
                    .zIndex(2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Community Stats Badge - Bottom Left (tappable)
                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        if let count = worldwideReportCount {
                            communityStatsBadge(count: count)
                                .onTapGesture {
                                    // Only show stats if we have computed them
                                    if communityStats != nil {
                                        activeSheet = .communityStats
                                    }
                                }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 200) // Above bottom sheet
                }
                .zIndex(1)

                // Native bottom sheet will be presented via .sheet() modifier below
            }
        }
        .task {
            // Fetch worldwide count when view appears
            await fetchWorldwideReportCount()

            // Resolve locations for reports that don't have displayName
            // This runs in background and updates SwiftData, triggering UI refresh
            let reportsNeedingResolution = allReports.filter { $0.displayName == nil }
            if !reportsNeedingResolution.isEmpty {
                print("📍 Resolving locations for \(reportsNeedingResolution.count) reports without displayName")
                await locationResolver.resolveLocationsForReports(reportsNeedingResolution)
            }

            // Refresh count every 2 minutes to catch new reports
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(120))
                await fetchWorldwideReportCount()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Refresh when app comes back to foreground
            Task {
                await fetchWorldwideReportCount()
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addReport(let location, let locationName):
                if let location = location {
                    AddReportView(location: location, locationName: locationName)
                } else {
                    AddReportView()
                }
            case .nearby:
                NearbyView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            case .locationReport(let pin):
                LocationReportView(
                    pin: pin,
                    onAddReport: { location, locationName in
                        activeSheet = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showAddReportWith(location: location, locationName: locationName)
                        }
                    }
                )
            case .profile:
                NavigationView {
                    ProfileView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    activeSheet = nil
                                }
                                .fontWeight(.medium)
                            }
                        }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(false) // Allow swipe despite having Done button
            case .mapStylePicker:
                MapStylePickerView(
                    currentMapStyle: .init(
                        get: { currentMapStyle },
                        set: { currentMapStyle = $0 }
                    ),
                    onMapStyleSelected: { style in
                        currentMapStyle = style
                        activeSheet = nil
                    },
                    isPresented: .init(
                        get: { activeSheet != nil },
                        set: { _ in activeSheet = nil }
                    )
                )
            case .communityStats:
                if let stats = communityStats {
                    CommunityStatsView(stats: stats)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            case .placePrediction(let place):
                PlacePredictionView(
                    place: place,
                    isPresented: .init(
                        get: { activeSheet != nil },
                        set: { if !$0 { activeSheet = nil } }
                    ),
                    onPredictionRequested: {
                        // Add purple AI prediction pin when user requests prediction
                        // Only add if not already present at this location
                        if !tempPins.contains(where: {
                            abs($0.coordinate.latitude - place.coordinate.latitude) < 0.00001 &&
                            abs($0.coordinate.longitude - place.coordinate.longitude) < 0.00001
                        }) {
                            tempPins.append(place)
                        }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showBottomSheet) {
            NativeBottomSheetContent(
                showAddReport: .init(
                    get: {
                        if case .addReport = activeSheet {
                            return true
                        }
                        return false
                    },
                    set: { shouldShow in
                        if shouldShow {
                            activeSheet = .addReport(nil, nil)
                        } else {
                            activeSheet = nil
                        }
                    }
                ),
                showNearby: .init(
                    get: { activeSheet == .nearby },
                    set: { shouldShow in
                        if shouldShow {
                            activeSheet = .nearby
                        } else {
                            activeSheet = nil
                        }
                    }
                ),
                showProfile: .init(
                    get: { activeSheet == .profile },
                    set: { shouldShow in
                        if shouldShow {
                            activeSheet = .profile
                        } else {
                            activeSheet = nil
                        }
                    }
                ),
                showLegend: $showLegend,
                showAbout: $showAbout,
                currentMapStyle: $currentMapStyle,
                detent: $bottomSheetDetent,
                onMapStyleSelected: { _ in
                    activeSheet = .mapStylePicker
                }
            )
            .presentationDetents([.height(150), .medium, .large], selection: $bottomSheetDetent)
            .presentationDragIndicator(.hidden)
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
            .interactiveDismissDisabled()
        }
        .onChange(of: activeSheet) { _, sheet in
            if sheet == nil {
                // Clear prefilled data when sheet is dismissed
                prefilledReportLocation = nil
                prefilledReportLocationName = nil
            }
        }
        .environment(\.colorScheme, highContrastMode ? .light : colorScheme)
        .onAppear {
            setInitialMapLocation()
            
            // Listen for tab switch notifications from NearbyView
            NotificationCenter.default.addObserver(
                forName: Notification.Name("SwitchToTab"),
                object: nil,
                queue: .main
            ) { notification in
                // Close the sheet when switching to map tab
                if let tabIndex = notification.userInfo?["tabIndex"] as? Int, tabIndex == 0 {
                    activeSheet = nil
                }
            }
            
            // Listen for coordinate centering notifications from NearbyView
            NotificationCenter.default.addObserver(
                forName: Notification.Name("CenterMapOnCoordinate"),
                object: nil,
                queue: .main
            ) { notification in
                if let coordinate = notification.userInfo?["coordinate"] as? CLLocationCoordinate2D {
                    cameraPosition = coordinate
                    shouldUpdateCamera = true
                    // Dismiss the sheet after setting the coordinate
                    activeSheet = nil
                }
            }
        }
        .onDisappear {
            // Clean up notification observers
            NotificationCenter.default.removeObserver(self, name: Notification.Name("SwitchToTab"), object: nil)
            NotificationCenter.default.removeObserver(self, name: Notification.Name("CenterMapOnCoordinate"), object: nil)
        }
    }
    
    // MARK: - Private Methods
    
    private func dismissSearch() {
        if isSearching {
            withAnimation(.easeInOut(duration: 0.2)) {
                isSearching = false
                searchText = ""
            }
            
            // Dismiss keyboard
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder), 
                to: nil, 
                from: nil, 
                for: nil
            )
        }
    }
    
    
    // MARK: - AddReportView Navigation
    
    private func showAddReportWith(location: CLLocationCoordinate2D, locationName: String?) {
        prefilledReportLocation = location
        prefilledReportLocationName = locationName
        activeSheet = .addReport(location, locationName)
    }
    
    private func setInitialMapLocation() {
        guard !hasSetInitialLocation else { return }
        
        if let userLocation = locationManager.lastLocation {
            // Use user's current location if available
            withAnimation(.easeInOut(duration: 0.8)) {
                cameraPosition = userLocation
                shouldUpdateCamera = true
                hasSetInitialLocation = true
            }
        } else {
            // Request location permission and update when available
            locationManager.requestLocationPermission()
            
            // Set a timer to check for location updates
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if let userLocation = locationManager.lastLocation, !hasSetInitialLocation {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        cameraPosition = userLocation
                        shouldUpdateCamera = true
                        hasSetInitialLocation = true
                    }
                } else if !hasSetInitialLocation {
                    // If still no location after 2 seconds, keep San Francisco as default
                    hasSetInitialLocation = true
                }
            }
        }
    }

    // MARK: - Community Stats Badge

    @ViewBuilder
    private func communityStatsBadge(count: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 20))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(count.formatted())")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                // Chevron as subtle disclosure indicator
                HStack(spacing: 3) {
                    Text("shared experiences")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                }
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16))
        // Accessibility: indicate this is a tappable element
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count.formatted()) shared experiences")
        .accessibilityHint("Shows community overview and statistics")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Fetch Worldwide Count

    private func fetchWorldwideReportCount() async {
        print("🌍 Fetching worldwide report count...")
        do {
            let firestoreReports = try await FirestoreService.shared.downloadAllReports()
            await MainActor.run {
                worldwideReportCount = firestoreReports.count
                // Compute community stats for the expanded view
                communityStats = CommunityStats.from(reports: firestoreReports)
                print("🌍 ✅ Fetched \(firestoreReports.count) reports worldwide")
            }
        } catch {
            print("🌍 ❌ Failed to fetch worldwide report count: \(error)")
        }
    }
}

// MARK: - Supporting Types

// BottomSheetState is defined in BottomSheetView as BottomSheetView.SheetState

struct FilterOptions {
    var noiseLevel: ClosedRange<Double> = 0.0...1.0
    var crowdLevel: ClosedRange<Double> = 0.0...1.0
    var lightingLevel: ClosedRange<Double> = 0.0...1.0
    var comfortLevel: ClosedRange<Double> = 0.0...1.0
    var venueTypes: Set<String> = []
    var showOnlyMyReports = false
    var showOnlyRecent = false
    var showOnlyOpenNow = false
    var proximityRadius: Double? = nil // in meters, nil = no proximity filter
    
    var isFiltered: Bool {
        noiseLevel != 0.0...1.0 ||
        crowdLevel != 0.0...1.0 ||
        lightingLevel != 0.0...1.0 ||
        comfortLevel != 0.0...1.0 ||
        !venueTypes.isEmpty ||
        showOnlyMyReports ||
        showOnlyRecent ||
        showOnlyOpenNow ||
        proximityRadius != nil
    }
    
    mutating func reset() {
        noiseLevel = 0.0...1.0
        crowdLevel = 0.0...1.0
        lightingLevel = 0.0...1.0
        comfortLevel = 0.0...1.0
        venueTypes.removeAll()
        showOnlyMyReports = false
        showOnlyRecent = false
        showOnlyOpenNow = false
        proximityRadius = nil
    }
}

#Preview {
    SingleScreenMapView()
}