import Foundation
import CoreLocation

// MARK: - Result Structure

struct LocationLabelResult {
    let name: String
    let tier: DisplayTier
    let confidence: Double
    let placeID: String?
    let openNow: Bool?
}

// MARK: - Placeholders (using shared definition from Report.swift)

// MARK: - Provider Implementation

// MARK: - POI Candidate Scoring

struct POIScore {
    let confidence: Double
    let snap: Bool
}

struct ScoringContext {
    let horizontalAccuracy: CLLocationAccuracy?
}

struct ResolverTelemetry {
    var directPOI = 0
    var hedgedPOI = 0
    var street = 0
    var area = 0
    var denylistHits = 0
    var snaps = 0
    var total = 0
    
    mutating func reset() {
        directPOI = 0
        hedgedPOI = 0
        street = 0
        area = 0
        denylistHits = 0
        snaps = 0
        total = 0
    }
    
    func print() {
        #if DEBUG
        Swift.print("[Telemetry] total=\(total) direct=\(directPOI) hedged=\(hedgedPOI) street=\(street) area=\(area) snaps=\(snaps) denylist=\(denylistHits)")
        #endif
    }
}

final class LocationLabelProvider {
    
    private let placesResolver: PlacesResolving
    private let geocoderAdapter: GoogleGeocoderAdapting
    private let config: PrivacyLocationConfig
    private var telemetry = ResolverTelemetry()
    
    init(
        placesResolver: PlacesResolving,
        geocoderAdapter: GoogleGeocoderAdapting,
        config: PrivacyLocationConfig = .shared
    ) {
        self.placesResolver = placesResolver
        self.geocoderAdapter = geocoderAdapter
        self.config = config
    }
    
    func resolve(
        for coordinate: CLLocationCoordinate2D,
        userAreaOnly: Bool = false,
        locale: Locale = .current,
        horizontalAccuracy: CLLocationAccuracy? = nil
    ) async -> LocationLabelResult {
        
        // Step 1: Check kill-switch - if userAreaOnly or areaOnlyOverride, skip POI/street
        if userAreaOnly || config.areaOnlyOverride {
            let areaName = await resolveAreaName(coordinate: coordinate, locale: locale)
            telemetry.area += 1
            telemetry.total += 1
            checkTelemetry()
            return LocationLabelResult(
                name: areaName,
                tier: .area,
                confidence: 1.0,
                placeID: nil,
                openNow: nil
            )
        }
        
        // Step 2: Try Places API with new candidate-based approach
        if config.usePlacesEnrichment {
            do {
                let session = PlacesSession()
                let candidates = try await placesResolver.nearbyCandidates(for: coordinate, session: session)
                
                if !candidates.isEmpty {
                    let cfg = config.placesTuning
                    let ctx = ScoringContext(horizontalAccuracy: horizontalAccuracy)
                    
                    // Score top 3 candidates
                    var scoredCandidates: [(candidate: PlacesCandidate, score: POIScore)] = []
                    for candidate in candidates.prefix(3) {
                        let score = scorePOI(candidate, neighbors: Array(candidates), cfg: cfg, ctx: ctx)
                        scoredCandidates.append((candidate, score))
                    }
                    
                    // Tie-breaking: snap > confidence > complex preference > rating > userRatingsTotal > distance
                    scoredCandidates.sort { first, second in
                        if first.score.snap != second.score.snap {
                            return first.score.snap
                        }
                        
                        // Complex preference tie-breaker
                        let confDelta = abs(first.score.confidence - second.score.confidence)
                        let bothNearby = abs(first.candidate.distanceMeters - second.candidate.distanceMeters) <= cfg.denseCompetitionMeters
                        if bothNearby && confDelta < 0.08 {
                            // Prefer complex venues in ambiguous clusters
                            if first.candidate.isComplex != second.candidate.isComplex {
                                return first.candidate.isComplex
                            }
                        }
                        
                        if confDelta > 0.01 {
                            return first.score.confidence > second.score.confidence
                        }
                        if let r1 = first.candidate.rating, let r2 = second.candidate.rating, abs(r1 - r2) > 0.1 {
                            return r1 > r2
                        }
                        if let u1 = first.candidate.userRatingsTotal, let u2 = second.candidate.userRatingsTotal, abs(u1 - u2) > 10 {
                            return u1 > u2
                        }
                        return first.candidate.distanceMeters < second.candidate.distanceMeters
                    }
                    
                    // Find best non-denylisted candidate
                    for (candidate, score) in scoredCandidates {
                        if isSensitivePlace(candidate) {
                            telemetry.denylistHits += 1
                            continue // Skip denylisted places
                        }
                        
                        // Decision logic
                        if score.snap && !isSensitivePlace(candidate) {
                            // Snap window: use POI directly
                            telemetry.directPOI += 1
                            telemetry.snaps += 1
                            telemetry.total += 1
                            checkTelemetry()
                            return LocationLabelResult(
                                name: candidate.name,
                                tier: .poi,
                                confidence: score.confidence,
                                placeID: candidate.placeID,
                                openNow: candidate.openNow
                            )
                        } else if score.confidence >= cfg.minConfidenceForDirectPOI {
                            // High confidence: use POI directly  
                            telemetry.directPOI += 1
                            telemetry.total += 1
                            checkTelemetry()
                            return LocationLabelResult(
                                name: candidate.name,
                                tier: .poi,
                                confidence: score.confidence,
                                placeID: candidate.placeID,
                                openNow: candidate.openNow
                            )
                        } else if score.confidence >= cfg.minConfidenceForHedgedPOI {
                            // Moderate confidence: use hedged copy
                            let hedgedName = "near \(candidate.name)"
                            telemetry.hedgedPOI += 1
                            telemetry.total += 1
                            checkTelemetry()
                            return LocationLabelResult(
                                name: hedgedName,
                                tier: .poi,
                                confidence: score.confidence,
                                placeID: candidate.placeID,
                                openNow: candidate.openNow
                            )
                        }
                        // If confidence too low, continue to next candidate
                    }
                    
                    // All candidates were either denylisted or low confidence, fall through to geocoder
                }
            } catch {
                print("⚠️ Places API failed, falling back to geocoder: \(error)")
            }
        }
        
        // Step 3: Try street geocoding
        do {
            if let geocodingResult = try await geocoderAdapter.reverseGeocode(coordinate: coordinate) {
                telemetry.street += 1
                telemetry.total += 1
                checkTelemetry()
                return LocationLabelResult(
                    name: geocodingResult.shortAddress,
                    tier: .street,
                    confidence: geocodingResult.confidence,
                    placeID: nil,
                    openNow: nil
                )
            }
        } catch {
            print("⚠️ Geocoding failed, falling back to area: \(error)")
        }
        
        // Step 4: Fallback to area
        let areaName = await resolveAreaName(coordinate: coordinate, locale: locale)
        telemetry.area += 1
        telemetry.total += 1
        checkTelemetry()
        return LocationLabelResult(
            name: areaName,
            tier: .area,
            confidence: 1.0,
            placeID: nil,
            openNow: nil
        )
    }
    
    // MARK: - POI Scoring
    
    func scorePOI(_ candidate: PlacesCandidate, neighbors: [PlacesCandidate], cfg: PlacesTuning, ctx: ScoringContext) -> POIScore {
        // Base by distance
        var conf = max(0, 1.0 - (candidate.distanceMeters / max(cfg.poiMaxRadiusMeters, 1)))
        
        // Snap if very close
        let snap = (candidate.distanceMeters <= cfg.snapWindowMeters)
        
        // Type priority boost
        if let idx = cfg.poiTypePriority.firstIndex(where: { candidate.types.contains($0) }) {
            conf += 0.12 - Double(idx) * 0.01 // higher priority → slightly larger boost
        }
        
        // Rating & popularity
        if let r = candidate.rating, r >= 4.3 { conf += 0.06 }
        if let n = candidate.userRatingsTotal, n >= 200 { conf += 0.05 } else if let n = candidate.userRatingsTotal, n >= 50 { conf += 0.02 }
        
        // Competition penalty (dense ambiguity)
        let competing = neighbors.dropFirst().prefix(3).filter { abs($0.distanceMeters - candidate.distanceMeters) <= cfg.denseCompetitionMeters }
        if !competing.isEmpty { conf -= 0.12 }
        
        // Horizontal accuracy penalty
        if let accuracy = ctx.horizontalAccuracy {
            if accuracy > 15 {
                conf -= 0.08  // First penalty
                if accuracy > 30 {
                    conf -= 0.07  // Additional penalty (total -0.15)
                }
            }
        }
        
        // Open-hours penalty (if available)
        if let openNow = candidate.openNow, !openNow {
            conf -= 0.03
        }
        
        // Clamp
        conf = min(max(conf, 0), 1)
        return POIScore(confidence: conf, snap: snap)
    }
    
    // MARK: - Telemetry
    
    private func checkTelemetry() {
        #if DEBUG
        if telemetry.total >= 200 {
            telemetry.print()
            telemetry.reset()
        }
        #endif
    }
    
    // MARK: - Denylist Checking
    
    private func isSensitivePlace(_ candidate: PlacesCandidate) -> Bool {
        // Google Place types that should force .area tier
        let sensitivePlaceTypes: Set<String> = [
            "hospital", "doctor", "dentist", "pharmacy", "physiotherapist",
            "school", "primary_school", "secondary_school", "university", "childcare",
            "church", "mosque", "synagogue", "hindu_temple", "place_of_worship",
            "police", "courthouse", "fire_station", "local_government_office",
            "homeless_shelter", "care_home", "funeral_home"
        ]
        
        // Check types first (most reliable)
        for type in candidate.types {
            if sensitivePlaceTypes.contains(type) {
                return true
            }
        }
        
        // Fallback to name regex
        let sensitiveNamePattern = "\\b(hospital|clinic|court|mosque|church|temple|synagogue|primary school|gp|surgery|police|shelter|care home|childcare)\\b"
        guard let regex = try? NSRegularExpression(pattern: sensitiveNamePattern, options: [.caseInsensitive, .anchorsMatchLines]) else { return false }
        let nameRange = NSRange(location: 0, length: candidate.name.utf16.count)
        return regex.firstMatch(in: candidate.name, options: [], range: nameRange) != nil
    }
    
    // MARK: - Private Methods
    
    private func resolveAreaName(coordinate: CLLocationCoordinate2D, locale: Locale) async -> String {
        // Try to get neighborhood/subLocality using CLGeocoder for area fallback
        do {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            
            guard let placemark = placemarks.first else {
                return Placeholders.nearbyArea
            }
            
            // Priority: subLocality (neighborhood) > locality > administrativeArea
            if let subLocality = placemark.subLocality {
                return sanitizeAreaName(subLocality)
            }
            
            if let locality = placemark.locality {
                return sanitizeAreaName(locality)
            }
            
            if let administrativeArea = placemark.administrativeArea {
                return sanitizeAreaName(administrativeArea)
            }
            
            return Placeholders.nearbyArea
            
        } catch {
            print("⚠️ Area resolution failed: \(error)")
            return Placeholders.nearbyArea
        }
    }
    
    private func sanitizeAreaName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Replace synthetic patterns with "Nearby area"
        let syntheticPattern = "^(Area|Cell|Grid|Zone)\\s*\\d+$"
        if let regex = try? NSRegularExpression(pattern: syntheticPattern, options: [.caseInsensitive]),
           regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)) != nil {
            return Placeholders.nearbyArea
        }
        
        return trimmed
    }
}

// MARK: - Fake Implementation for Testing

final class FakeLocationLabelProvider {
    private var mockResults: [String: LocationLabelResult] = [:]
    private var callCount = 0
    
    var totalCalls: Int { return callCount }
    
    func setMockResult(for coordinate: CLLocationCoordinate2D, result: LocationLabelResult) {
        let key = "\(coordinate.latitude),\(coordinate.longitude)"
        mockResults[key] = result
    }
    
    func resolve(
        for coordinate: CLLocationCoordinate2D,
        userAreaOnly: Bool = false,
        locale: Locale = .current,
        horizontalAccuracy: CLLocationAccuracy? = nil
    ) async -> LocationLabelResult {
        callCount += 1
        
        let key = "\(coordinate.latitude),\(coordinate.longitude)"
        return mockResults[key] ?? LocationLabelResult(
            name: Placeholders.nearbyArea,
            tier: .area,
            confidence: 1.0,
            placeID: nil,
            openNow: nil
        )
    }
    
    func reset() {
        mockResults.removeAll()
        callCount = 0
    }
}