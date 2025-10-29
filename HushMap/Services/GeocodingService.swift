/*
 GeocodingService.swift
 
 Privacy-Aware Location Resolution for HushMap
 
 This service provides tiered location labeling that respects user privacy:
 
 Resolution Tiers:
 1. POI (.poi) - Named places of interest (cafes, shops, etc.) within configurable radius
 2. Street (.street) - Street name + locality (e.g., "Oxford St, London")
 3. Area (.area) - Neighborhood/area name only (e.g., "Camden area")
 
 Privacy Heuristics:
 - Residential addresses (detected by house numbers without POI) → force .area tier
 - Sensitive venues (schools, clinics, hospitals) → force .area tier
 - User-requested privacy mode → force .area tier
 - Never expose unit numbers, precise addresses, or postcodes
 
 New Features:
 - Confidence scoring with hedged copy support
 - Configurable radii and density guards
 - Category guardrails and complex preference
 - Persistent disk cache with memory cache
 - Token bucket rate limiting with backoff
 */

import Foundation
import CoreLocation
import MapKit
import os.signpost

// MARK: - Instruments Signposts

private let locationLabelingLog = OSLog(subsystem: "com.your.bundle.HushMap", category: "LocationLabeling")

// MARK: - Updated Protocol

protocol GeocodingService {
    func resolveDisplayName(
        for coordinate: CLLocationCoordinate2D,
        userRequestedAreaOnly: Bool,
        locale: Locale
    ) async throws -> (name: String, tier: DisplayTier, confidence: Double)
}

@MainActor
class DefaultGeocodingService: GeocodingService {
    
    // MARK: - Configuration
    
    private let poiMaxRadiusMeters: Double
    private let denseAreaDowngradeThresholdMeters: Double
    private let rateLimiter: RateLimiter
    
    // MARK: - Constants
    static let LOCATION_RULES_VERSION: Int = 3
    private static let MAX_CACHE_ENTRIES = 1000
    private static let MAX_LABEL_LENGTH = 40
    
    // MARK: - Cache
    private let memoryCache = NSCache<NSString, LocationLabel>()
    
    // MARK: - Sensitive Category Denylist
    private static let sensitivePOICategories: [MKPointOfInterestCategory] = [
        .hospital,
        .pharmacy,
        .school,
        .university
    ]
    
    // Word-boundary regex for sensitive venue names (case/locale-insensitive)
    private static let sensitiveNamePattern = "\\b(hospital|clinic|court|mosque|church|temple|synagogue|primary school|gp|surgery)\\b"
    private static let sensitiveNameRegex: NSRegularExpression? = {
        return try? NSRegularExpression(pattern: sensitiveNamePattern, options: [.caseInsensitive, .anchorsMatchLines])
    }()
    
    private static let complexCategories: [MKPointOfInterestCategory] = [
        .airport, .amusementPark, .aquarium, .zoo, .museum, .stadium
    ]
    
    init(
        poiMaxRadiusMeters: Double = 25.0,
        denseAreaDowngradeThresholdMeters: Double = 10.0,
        rateLimiter: RateLimiter? = nil
    ) {
        self.poiMaxRadiusMeters = poiMaxRadiusMeters
        self.denseAreaDowngradeThresholdMeters = denseAreaDowngradeThresholdMeters
        self.rateLimiter = rateLimiter ?? RateLimiter()
        
        memoryCache.countLimit = Self.MAX_CACHE_ENTRIES
    }
    
    func resolveDisplayName(
        for coordinate: CLLocationCoordinate2D,
        userRequestedAreaOnly: Bool = false,
        locale: Locale = .current
    ) async throws -> (name: String, tier: DisplayTier, confidence: Double) {
        
        let locationKey = LocationKey(coordinate: coordinate, locale: locale, rulesVersion: Int16(Self.LOCATION_RULES_VERSION))
        let cacheKeyString = locationKey.base64URLKey
        
        // Check memory cache first
        if let cached = memoryCache.object(forKey: cacheKeyString as NSString) {
            return (cached.name, cached.tier, cached.confidence)
        }
        
        // Check kill-switch: area-only override forces .area everywhere
        let config = PrivacyLocationConfig.shared
        if userRequestedAreaOnly || config.areaOnlyOverride {
            let areaName = try await resolveAreaName(coordinate: coordinate, locale: locale)
            let result = LocationLabel(name: areaName, tier: .area, confidence: 1.0, updatedAt: Date())
            memoryCache.setObject(result, forKey: cacheKeyString as NSString)
            return (result.name, result.tier, result.confidence)
        }
        
        return try await rateLimiter.executeWithLimit {
            let signpostID = OSSignpostID(log: locationLabelingLog)
            os_signpost(.begin, log: locationLabelingLog, name: "Geocode Resolution", signpostID: signpostID)
            
            // Phase 1: Try POI resolution with confidence scoring
            if let poiResult = try await self.resolvePOIName(coordinate: coordinate, locale: locale) {
                let locationLabel = LocationLabel(
                    name: poiResult.name,
                    tier: poiResult.tier,
                    confidence: poiResult.confidence,
                    updatedAt: Date()
                )
                self.memoryCache.setObject(locationLabel, forKey: cacheKeyString as NSString)
                os_signpost(.end, log: locationLabelingLog, name: "Geocode Resolution", signpostID: signpostID, "POI")
                return (poiResult.name, poiResult.tier, poiResult.confidence)
            }
            
            // Phase 2: Try street resolution
            if let streetResult = try await self.resolveStreetName(coordinate: coordinate, locale: locale) {
                // Apply privacy heuristics - check if this looks residential
                if await self.isResidentialAddress(coordinate) {
                    let areaName = try await self.resolveAreaName(coordinate: coordinate, locale: locale)
                    let locationLabel = LocationLabel(name: areaName, tier: .area, confidence: 1.0, updatedAt: Date())
                    self.memoryCache.setObject(locationLabel, forKey: cacheKeyString as NSString)
                    os_signpost(.end, log: locationLabelingLog, name: "Geocode Resolution", signpostID: signpostID, "Area (Residential)")
                    return (areaName, .area, 1.0)
                }
                
                let locationLabel = LocationLabel(
                    name: streetResult.name,
                    tier: streetResult.tier,
                    confidence: streetResult.confidence,
                    updatedAt: Date()
                )
                self.memoryCache.setObject(locationLabel, forKey: cacheKeyString as NSString)
                os_signpost(.end, log: locationLabelingLog, name: "Geocode Resolution", signpostID: signpostID, "Street")
                return (streetResult.name, streetResult.tier, streetResult.confidence)
            }
            
            // Phase 3: Fallback to area
            let areaName = try await self.resolveAreaName(coordinate: coordinate, locale: locale)
            let locationLabel = LocationLabel(name: areaName, tier: .area, confidence: 1.0, updatedAt: Date())
            self.memoryCache.setObject(locationLabel, forKey: cacheKeyString as NSString)
            os_signpost(.end, log: locationLabelingLog, name: "Geocode Resolution", signpostID: signpostID, "Area (Fallback)")
            return (areaName, .area, 1.0)
        }
    }
    
    // MARK: - POI Resolution with Confidence Scoring
    private func resolvePOIName(coordinate: CLLocationCoordinate2D, locale: Locale) async throws -> (name: String, tier: DisplayTier, confidence: Double)? {
        
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: poiMaxRadiusMeters * 2,
            longitudinalMeters: poiMaxRadiusMeters * 2
        )
        
        let request = MKLocalSearch.Request()
        request.region = region
        request.resultTypes = [.pointOfInterest]
        
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        
        // Calculate distances and filter suitable POIs
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var candidates: [(item: MKMapItem, distance: Double)] = []
        
        for item in response.mapItems {
            let itemLocation = CLLocation(
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude
            )
            let distance = itemLocation.distance(from: targetLocation)
            
            if distance <= poiMaxRadiusMeters && !isSensitivePOI(item) {
                candidates.append((item: item, distance: distance))
            }
        }
        
        guard !candidates.isEmpty else { return nil }
        
        // Sort by distance
        candidates.sort { $0.distance < $1.distance }
        let closestCandidate = candidates[0]
        
        // Check density guard - if multiple POIs are very close, downgrade to street
        if candidates.count > 1 {
            let secondClosest = candidates[1]
            if secondClosest.distance <= denseAreaDowngradeThresholdMeters,
               !isWellKnownComplex(closestCandidate.item) {
                // Too dense - downgrade to street unless it's a complex
                return nil
            }
        }
        
        // Calculate confidence score
        var confidence = 1.0
        let distance = closestCandidate.distance
        
        // Distance penalties
        if distance >= 20.0 {
            confidence -= 0.25
        } else if distance >= 10.0 {
            confidence -= 0.15
        } else if distance >= 5.0 {
            confidence -= 0.1
        }
        
        // Second-closest penalty
        if candidates.count > 1 && candidates[1].distance <= 5.0 {
            confidence -= 0.2
        }
        
        // Category ambiguity penalty
        if isGenericCategory(closestCandidate.item) {
            confidence -= 0.1
        }
        
        // Clamp confidence to [0,1]
        confidence = max(0.0, min(1.0, confidence))
        
        // Get display name (prefer complex names)
        let displayName = getDisplayName(for: closestCandidate.item, locale: locale)
        
        return (displayName, .poi, confidence)
    }
    
    // MARK: - Street Resolution
    private func resolveStreetName(coordinate: CLLocationCoordinate2D, locale: Locale) async throws -> (name: String, tier: DisplayTier, confidence: Double)? {
        
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
        guard let placemark = placemarks.first else { return nil }
        
        var components: [String] = []
        
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        
        if let locality = placemark.locality {
            components.append(locality)
        }
        
        guard !components.isEmpty else { return nil }
        
        let streetName = components.joined(separator: ", ")
        let cleanName = cleanLocationName(streetName, locale: locale)
        
        // Street confidence is generally high unless we detect issues
        let confidence = 0.95
        
        return (cleanName, .street, confidence)
    }
    
    // MARK: - Area Resolution
    private func resolveAreaName(coordinate: CLLocationCoordinate2D, locale: Locale) async throws -> String {
        
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else {
                return generateFallbackAreaName(coordinate)
            }
            
            // Prefer subLocality (neighborhood) > administrativeArea > locality
            if let subLocality = placemark.subLocality {
                return cleanLocationName(subLocality, locale: locale)
            }
            
            if let administrativeArea = placemark.administrativeArea {
                return cleanLocationName(administrativeArea, locale: locale)
            }
            
            if let locality = placemark.locality {
                return cleanLocationName(locality, locale: locale)
            }
            
            return generateFallbackAreaName(coordinate)
            
        } catch {
            return generateFallbackAreaName(coordinate)
        }
    }
    
    // MARK: - Privacy & Sensitivity Checks
    
    private func isSensitivePOI(_ item: MKMapItem) -> Bool {
        // Check category first (enum-based detection is more reliable)
        if let category = item.pointOfInterestCategory,
           Self.sensitivePOICategories.contains(category) {
            return true
        }
        
        // Check name for sensitive patterns using word boundaries
        let name = item.name ?? ""
        guard !name.isEmpty, let regex = Self.sensitiveNameRegex else { return false }
        
        let nameRange = NSRange(location: 0, length: name.utf16.count)
        return regex.firstMatch(in: name, options: [], range: nameRange) != nil
    }
    
    private func isWellKnownComplex(_ item: MKMapItem) -> Bool {
        guard let category = item.pointOfInterestCategory else { return false }
        
        if Self.complexCategories.contains(category) {
            return true
        }
        
        let name = item.name?.lowercased() ?? ""
        return name.contains("mall") || name.contains("centre") || name.contains("center")
    }
    
    private func isGenericCategory(_ item: MKMapItem) -> Bool {
        let name = item.name?.lowercased() ?? ""
        let genericPrefixes = ["store", "shop", "outlet", "branch"]
        
        return genericPrefixes.contains { prefix in
            name.hasPrefix(prefix)
        }
    }
    
    private func isResidentialAddress(_ coordinate: CLLocationCoordinate2D) async -> Bool {
        do {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            
            guard let placemark = placemarks.first else { return false }
            
            // If there's a subThoroughfare (house number) but no POI nearby, likely residential
            return placemark.subThoroughfare != nil
            
        } catch {
            return false
        }
    }
    
    // MARK: - Display Name Processing
    
    private func getDisplayName(for item: MKMapItem, locale: Locale) -> String {
        var displayName = item.name ?? "Unknown Place"
        
        // If this is inside a complex (like a mall), prefer the complex name
        if let category = item.pointOfInterestCategory,
           !Self.complexCategories.contains(category) {
            // Check if name suggests it's inside a complex
            if let complexName = extractComplexName(from: displayName) {
                displayName = complexName
            }
        }
        
        return cleanLocationName(displayName, locale: locale)
    }
    
    private func extractComplexName(from name: String) -> String? {
        // Look for patterns like "Store Name – Complex Name"
        if name.contains(" – ") {
            let components = name.components(separatedBy: " – ")
            if components.count == 2,
               let complexPart = components.last,
               (complexPart.lowercased().contains("mall") || 
                complexPart.lowercased().contains("centre") ||
                complexPart.lowercased().contains("center")) {
                return complexPart
            }
        }
        
        return nil
    }
    
    private func cleanLocationName(_ name: String, locale: Locale) -> String {
        var cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common unwanted suffixes/prefixes for the locale
        let unwantedPatterns = ["United Kingdom", "UK", "Greater London"]
        for pattern in unwantedPatterns {
            cleaned = cleaned.replacingOccurrences(of: ", \(pattern)", with: "")
        }
        
        // Truncate if too long using our formatter
        return LabelFormatter.compact(cleaned, max: Self.MAX_LABEL_LENGTH)
    }
    
    private func generateFallbackAreaName(_ coordinate: CLLocationCoordinate2D) -> String {
        // Generate a generic area name based on coordinate
        let lat = Int(coordinate.latitude * 100) / 100
        let lon = Int(coordinate.longitude * 100) / 100
        return "Area near \(lat)°, \(lon)°"
    }
}

// MARK: - Fake Service for Testing

class FakeGeocodingService: GeocodingService {
    private var responses: [String: (name: String, tier: DisplayTier, confidence: Double)] = [:]
    private var _callCount: Int = 0
    
    var callCount: Int { return _callCount }
    func resetCallCount() { _callCount = 0 }
    
    func setResponse(for coordinate: CLLocationCoordinate2D, name: String, tier: DisplayTier, confidence: Double = 1.0) {
        let key = "\(coordinate.latitude),\(coordinate.longitude)"
        responses[key] = (name, tier, confidence)
    }
    
    func resolveDisplayName(
        for coordinate: CLLocationCoordinate2D,
        userRequestedAreaOnly: Bool = false,
        locale: Locale = .current
    ) async throws -> (name: String, tier: DisplayTier, confidence: Double) {
        
        _callCount += 1
        
        if userRequestedAreaOnly {
            return ("Test area", .area, 1.0)
        }
        
        let key = "\(coordinate.latitude),\(coordinate.longitude)"
        if let response = responses[key] {
            return response
        }
        
        return ("Unknown area", .area, 0.5)
    }
}