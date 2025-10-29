import Foundation
import CoreLocation

@MainActor
class ReportLocationResolver: ObservableObject {
    
    private let locationLabelProvider: LocationLabelProvider
    private let diskCacheStore: LocationLabelCacheStore
    
    // MARK: - Telemetry Counters
    private var labelsTotal: Int = 0
    private var poiHedged: Int = 0
    private var downgradedForDensity: Int = 0
    private var forcedAreaByDenylist: Int = 0
    
    init(
        locationLabelProvider: LocationLabelProvider? = nil,
        diskCacheStore: LocationLabelCacheStore? = nil
    ) {
        self.diskCacheStore = diskCacheStore ?? (try? DiskLocationLabelCacheStore()) ?? InMemoryLocationLabelCacheStore()
        
        // Create default LocationLabelProvider if not provided
        if let provider = locationLabelProvider {
            self.locationLabelProvider = provider
        } else {
            // Get Google Places API key from existing mechanism
            let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_PLACES_API_KEY") as? String ?? ""
            // Note: These initializers are @MainActor, which is fine since ReportLocationResolver is also @MainActor
            let placesResolver = PlacesResolver(apiKey: apiKey)
            let geocoderAdapter = GoogleGeocoderAdapter()
            self.locationLabelProvider = LocationLabelProvider(
                placesResolver: placesResolver,
                geocoderAdapter: geocoderAdapter
            )
        }
    }
    
    /// Resolve location names for reports that haven't been resolved or need updating
    func resolveLocationsForReports(_ reports: [Report]) async {
        let reportsNeedingResolution = reports.filter { report in
            needsLocationResolution(report)
        }
        
        guard !reportsNeedingResolution.isEmpty else { return }
        
        print("📍 Resolving locations for \(reportsNeedingResolution.count) reports")
        
        // Process with rate limiting (RateLimiter now handles batching and delays)
        await withTaskGroup(of: Void.self) { group in
            for report in reportsNeedingResolution {
                group.addTask { [weak self] in
                    await self?.resolveLocationForSingleReport(report)
                }
            }
        }
    }
    
    /// Resolve location for a single report
    func resolveLocationForReport(_ report: Report) async {
        await resolveLocationForSingleReport(report)
    }
    
    // MARK: - Private Methods
    
    private func needsLocationResolution(_ report: Report) -> Bool {
        // Need resolution if:
        // 1. No display name set
        // 2. No resolution timestamp
        // 3. Version is outdated
        // 4. Privacy flag changed and it affects the result
        
        if report.displayName == nil || report.locationResolvedAt == nil {
            return true
        }
        
        if let version = report.locationResolutionVersion,
           version < getCurrentLocationRulesVersion() {
            return true
        }
        
        return false
    }
    
    private func getCurrentLocationRulesVersion() -> Int {
        return DefaultGeocodingService.LOCATION_RULES_VERSION
    }
    
    private func resolveLocationForSingleReport(_ report: Report) async {
        let locationKey = LocationKey(
            coordinate: report.coordinate,
            locale: .current,
            rulesVersion: Int16(getCurrentLocationRulesVersion())
        )
        
        let userRequestedAreaOnly = report.privacyFlagUserRequestedAreaOnly ?? false
        
        // Check disk cache first
        if let cachedLabel = diskCacheStore.get(for: locationKey) {
            await MainActor.run {
                // Don't persist synthetic placeholders - leave fields nil so UI shows placeholder
                if !isSyntheticPlaceholder(cachedLabel.name) {
                    report.displayName = cachedLabel.name
                    report.displayTierRaw = cachedLabel.tier.rawValue
                    report.confidence = cachedLabel.confidence
                    report.locationResolvedAt = Date()
                    report.locationResolutionVersion = getCurrentLocationRulesVersion()
                    // Note: openNow is not cached, it's time-sensitive
                    
                    // Update telemetry counters
                    let result = (name: cachedLabel.name, tier: cachedLabel.tier, confidence: cachedLabel.confidence)
                    updateTelemetryCounters(for: result, userRequestedAreaOnly: userRequestedAreaOnly)
                }
            }
            print("💾 Using cached location for report: \(cachedLabel.name)")
            return
        }
        
        // Resolve using LocationLabelProvider
        let resolved = await locationLabelProvider.resolve(
            for: report.coordinate,
            userAreaOnly: userRequestedAreaOnly,
            locale: .current
        )
        
        print("🔍 Resolved location for report: \(resolved.name) (\(resolved.tier.rawValue)), confidence: \(resolved.confidence)")
        
        // Write-through to disk cache (skip synthetic placeholders)
        if !isSyntheticPlaceholder(resolved.name) {
            // Calculate expiration for Places POI entries (29 days)
            let expiresAt: Date? = (resolved.tier == .poi && resolved.placeID != nil) ? 
                Date().addingTimeInterval(29 * 24 * 60 * 60) : nil
            
            let locationLabel = LocationLabel(
                name: resolved.name,
                tier: resolved.tier,
                confidence: resolved.confidence,
                updatedAt: Date(),
                placeID: resolved.placeID,
                expiresAt: expiresAt
            )
            diskCacheStore.set(locationLabel, for: locationKey)
        }
        
        // Update report and track telemetry
        await MainActor.run {
            // Don't persist synthetic placeholders - leave fields nil so UI shows placeholder
            if !isSyntheticPlaceholder(resolved.name) {
                report.displayName = resolved.name
                report.displayTierRaw = resolved.tier.rawValue
                report.confidence = resolved.confidence
                report.openNow = resolved.openNow
                report.locationResolvedAt = Date()
                report.locationResolutionVersion = getCurrentLocationRulesVersion()
            }
            
            // Update telemetry counters
            let result = (name: resolved.name, tier: resolved.tier, confidence: resolved.confidence)
            updateTelemetryCounters(for: result, userRequestedAreaOnly: userRequestedAreaOnly)
        }
    }
    
    // MARK: - Telemetry Tracking
    
    private func updateTelemetryCounters(
        for result: (name: String, tier: DisplayTier, confidence: Double),
        userRequestedAreaOnly: Bool
    ) {
        labelsTotal += 1
        
        // Track POI hedged (low confidence)
        let hedgeThreshold = PrivacyLocationConfig.shared.confidenceHedgeThreshold
        if result.tier == .poi && result.confidence < hedgeThreshold {
            poiHedged += 1
        }
        
        // Track area-only due to kill-switch
        if userRequestedAreaOnly || PrivacyLocationConfig.shared.areaOnlyOverride {
            forcedAreaByDenylist += 1
        }
        
        // Note: downgradedForDensity would need to be tracked in GeocodingService
        // since that's where density decisions are made
        
        // Print telemetry every 200 resolutions in DEBUG mode
        #if DEBUG
        if labelsTotal % 200 == 0 {
            printTelemetry()
        }
        #endif
    }
    
    private func printTelemetry() {
        let hedgedPercent = labelsTotal > 0 ? Double(poiHedged * 100) / Double(labelsTotal) : 0.0
        let forcedAreaPercent = labelsTotal > 0 ? Double(forcedAreaByDenylist * 100) / Double(labelsTotal) : 0.0
        let downgradedPercent = labelsTotal > 0 ? Double(downgradedForDensity * 100) / Double(labelsTotal) : 0.0
        
        print("""
        📊 [LocationResolver] Telemetry (last 200 resolutions):
        • Total labels: \(labelsTotal)
        • POI hedged: \(poiHedged) (\(String(format: "%.1f", hedgedPercent))%)
        • Downgraded for density: \(downgradedForDensity) (\(String(format: "%.1f", downgradedPercent))%)
        • Forced area by denylist: \(forcedAreaByDenylist) (\(String(format: "%.1f", forcedAreaPercent))%)
        """)
    }
    
    // MARK: - Synthetic Placeholder Detection
    
    private func isSyntheticPlaceholder(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for "Nearby area" placeholder
        if trimmed == Placeholders.nearbyArea {
            return true
        }
        
        // Check for synthetic numeric patterns like "Area 5135251", "Grid 123", etc.
        let syntheticPattern = "^(Area|Cell|Grid|Zone)\\s*\\d+$"
        if let regex = try? NSRegularExpression(pattern: syntheticPattern, options: [.caseInsensitive]),
           regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)) != nil {
            return true
        }
        
        return false
    }
}

// MARK: - Helper Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}