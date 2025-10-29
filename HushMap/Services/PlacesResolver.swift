/*
 PlacesResolver.swift
 
 Google Places-first POI resolution for privacy-aware location labeling
 
 TTL POLICY:
 • Place names are cached for 29 days (Google's policy limit for Place details)
 • Place IDs are cached longer-term for future enrichment
 • Street/area labels cached for 180 days (more stable geographic data)
 
 DENYLIST LOGIC:
 • Priority 1: Google Place types (hospital, school, place_of_worship, police, etc.)
 • Priority 2: Word-boundary regex on names for edge cases
 • Sensitive places → force .area tier regardless of proximity
 
 CONFIDENCE HEURISTICS:
 • Distance penalty: closer POI = higher confidence
 • Density penalty: multiple POIs nearby = lower confidence  
 • Type specificity: "restaurant" > "establishment" > "point_of_interest"
 • Confidence < 0.8 → hedged copy ("near {POI}")
 */

import Foundation
import CoreLocation

// MARK: - Data Structures

struct PlacesResult {
    let name: String
    let placeID: String?
    let confidence: Double
    let openNow: Bool?
}

struct PlacesCandidate {
    let name: String
    let placeID: String
    let coordinate: CLLocationCoordinate2D
    let types: [String]
    let rating: Double?
    let userRatingsTotal: Int?
    let businessStatus: String?
    let distanceMeters: Double
    let openNow: Bool?
}

extension PlacesCandidate {
    var isComplex: Bool {
        let complexTypes: Set<String> = ["shopping_mall", "airport", "train_station", "subway_station", "university", "hospital"]
        return !types.filter { complexTypes.contains($0) }.isEmpty
    }
}

struct PlacesSession {
    let sessionToken: String = UUID().uuidString
}

// MARK: - Protocol

protocol PlacesResolving {
    func nearestPOI(for coordinate: CLLocationCoordinate2D, session: PlacesSession?) async throws -> PlacesResult?
    func nearbyCandidates(for coordinate: CLLocationCoordinate2D, session: PlacesSession?) async throws -> [PlacesCandidate]
}

// MARK: - Implementation

final class PlacesResolver: PlacesResolving {
    
    private let apiKey: String
    private let poiMaxRadiusMeters: Double
    private let rateLimiter: RateLimiter
    
    // Google Place types that should force .area tier
    private static let sensitivePlaceTypes: Set<String> = [
        "hospital", "doctor", "dentist", "pharmacy", "physiotherapist",
        "school", "primary_school", "secondary_school", "university", "childcare",
        "church", "mosque", "synagogue", "hindu_temple", "place_of_worship",
        "police", "courthouse", "fire_station", "local_government_office",
        "homeless_shelter", "care_home", "funeral_home"
    ]
    
    // Word-boundary regex for name fallback (case/locale-insensitive)
    private static let sensitiveNamePattern = "\\b(hospital|clinic|court|mosque|church|temple|synagogue|primary school|gp|surgery|police|shelter|care home|childcare)\\b"
    private static let sensitiveNameRegex: NSRegularExpression? = {
        return try? NSRegularExpression(pattern: sensitiveNamePattern, options: [.caseInsensitive, .anchorsMatchLines])
    }()
    
    @MainActor
    init(apiKey: String, poiMaxRadiusMeters: Double = 25.0, rateLimiter: RateLimiter? = nil) {
        self.apiKey = apiKey
        self.poiMaxRadiusMeters = poiMaxRadiusMeters
        self.rateLimiter = rateLimiter ?? RateLimiter()
    }
    
    func nearestPOI(for coordinate: CLLocationCoordinate2D, session: PlacesSession?) async throws -> PlacesResult? {
        return try await rateLimiter.executeWithLimit {
            return try await self.performNearbySearch(coordinate: coordinate, session: session)
        }
    }
    
    func nearbyCandidates(for coordinate: CLLocationCoordinate2D, session: PlacesSession?) async throws -> [PlacesCandidate] {
        return try await rateLimiter.executeWithLimit {
            return try await self.performNearbyCandidatesSearch(coordinate: coordinate, session: session)
        }
    }
    
    // MARK: - Private Methods
    
    private func performNearbySearch(coordinate: CLLocationCoordinate2D, session: PlacesSession?) async throws -> PlacesResult? {
        let baseURL = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "location", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "radius", value: String(Int(poiMaxRadiusMeters))),
            URLQueryItem(name: "rankby", value: "distance"),
            URLQueryItem(name: "fields", value: "name,types,place_id,geometry,rating,user_ratings_total,business_status,opening_hours"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        if let session = session {
            components.queryItems?.append(URLQueryItem(name: "sessiontoken", value: session.sessionToken))
        }
        
        guard let url = components.url else {
            throw LocationResolutionError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LocationResolutionError.networkError
        }
        
        let placesResponse = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)
        
        guard placesResponse.status == "OK",
              let results = placesResponse.results,
              !results.isEmpty else {
            return nil
        }
        
        // Filter and rank candidates
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var candidates: [(place: GooglePlace, distance: Double)] = []
        
        for place in results {
            guard let geometry = place.geometry,
                  let location = geometry.location else { continue }
            
            let placeLocation = CLLocation(latitude: location.lat, longitude: location.lng)
            let distance = placeLocation.distance(from: targetLocation)
            
            // Skip if too far
            if distance > poiMaxRadiusMeters { continue }
            
            // Skip if sensitive (denylist check)
            if isSensitivePlace(place) { continue }
            
            candidates.append((place: place, distance: distance))
        }
        
        guard !candidates.isEmpty else { return nil }
        
        // Sort by distance (rankby=distance should already do this, but ensure)
        candidates.sort { $0.distance < $1.distance }
        let closest = candidates[0]
        
        // Calculate confidence based on distance, density, and type specificity
        let confidence = calculateConfidence(
            place: closest.place,
            distance: closest.distance,
            competitors: Array(candidates.dropFirst())
        )
        
        return PlacesResult(
            name: closest.place.name,
            placeID: closest.place.placeId,
            confidence: confidence,
            openNow: nil
        )
    }
    
    private func performNearbyCandidatesSearch(coordinate: CLLocationCoordinate2D, session: PlacesSession?) async throws -> [PlacesCandidate] {
        let baseURL = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
        
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "location", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "radius", value: String(Int(poiMaxRadiusMeters))),
            URLQueryItem(name: "rankby", value: "distance"),
            URLQueryItem(name: "fields", value: "name,types,place_id,geometry,rating,user_ratings_total,business_status,opening_hours"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        if let session = session {
            components.queryItems?.append(URLQueryItem(name: "sessiontoken", value: session.sessionToken))
        }
        
        guard let url = components.url else {
            throw LocationResolutionError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LocationResolutionError.networkError
        }
        
        let placesResponse = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)
        
        guard placesResponse.status == "OK",
              let results = placesResponse.results,
              !results.isEmpty else {
            return []
        }
        
        // Convert all valid places to candidates
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var candidates: [PlacesCandidate] = []
        
        for place in results {
            guard let geometry = place.geometry,
                  let location = geometry.location,
                  let placeId = place.placeId else { continue }
            
            let placeLocation = CLLocation(latitude: location.lat, longitude: location.lng)
            let distance = placeLocation.distance(from: targetLocation)
            
            // Skip if too far
            if distance > poiMaxRadiusMeters { continue }
            
            let candidate = PlacesCandidate(
                name: place.name,
                placeID: placeId,
                coordinate: CLLocationCoordinate2D(latitude: location.lat, longitude: location.lng),
                types: place.types ?? [],
                rating: place.rating,
                userRatingsTotal: place.userRatingsTotal,
                businessStatus: place.businessStatus,
                distanceMeters: distance,
                openNow: place.openingHours?.openNow
            )
            
            candidates.append(candidate)
        }
        
        // Sort by distance (closest first)
        candidates.sort { $0.distanceMeters < $1.distanceMeters }
        
        return candidates
    }
    
    private func isSensitivePlace(_ place: GooglePlace) -> Bool {
        // Check types first (most reliable)
        if let types = place.types {
            for type in types {
                if Self.sensitivePlaceTypes.contains(type) {
                    return true
                }
            }
        }
        
        // Fallback to name regex
        guard !place.name.isEmpty, let regex = Self.sensitiveNameRegex else { return false }
        let nameRange = NSRange(location: 0, length: place.name.utf16.count)
        return regex.firstMatch(in: place.name, options: [], range: nameRange) != nil
    }
    
    private func calculateConfidence(place: GooglePlace, distance: Double, competitors: [(place: GooglePlace, distance: Double)]) -> Double {
        var confidence = 1.0
        
        // Distance penalty (exponential dropoff)
        let distanceRatio = distance / poiMaxRadiusMeters
        confidence *= (1.0 - (distanceRatio * distanceRatio * 0.4))
        
        // Density penalty (nearby competitors reduce confidence)
        let nearbyCompetitors = competitors.filter { $0.distance <= 15.0 }
        if !nearbyCompetitors.isEmpty {
            let densityPenalty = min(0.3, Double(nearbyCompetitors.count) * 0.1)
            confidence -= densityPenalty
        }
        
        // Type specificity bonus
        if let types = place.types {
            if types.contains("restaurant") || types.contains("store") || types.contains("cafe") {
                confidence += 0.1 // Specific business types get bonus
            } else if types.contains("establishment") || types.contains("point_of_interest") {
                confidence -= 0.1 // Generic types get penalty
            }
        }
        
        return max(0.1, min(1.0, confidence))
    }
}

// MARK: - Google Places API Models

private struct GooglePlacesResponse: Codable {
    let results: [GooglePlace]?
    let status: String
}

private struct GooglePlace: Codable {
    let name: String
    let placeId: String?
    let types: [String]?
    let geometry: GoogleGeometry?
    let rating: Double?
    let userRatingsTotal: Int?
    let businessStatus: String?
    let openingHours: GoogleOpeningHours?
    
    enum CodingKeys: String, CodingKey {
        case name
        case placeId = "place_id"
        case types
        case geometry
        case rating
        case userRatingsTotal = "user_ratings_total"
        case businessStatus = "business_status"
        case openingHours = "opening_hours"
    }
}

private struct GoogleOpeningHours: Codable {
    let openNow: Bool?
    
    enum CodingKeys: String, CodingKey {
        case openNow = "open_now"
    }
}

private struct GoogleGeometry: Codable {
    let location: GoogleLocation?
}

private struct GoogleLocation: Codable {
    let lat: Double
    let lng: Double
}

// MARK: - Errors

enum LocationResolutionError: Error {
    case invalidURL
    case networkError
    case apiKeyMissing
    case quotaExceeded
}

// MARK: - Fake Implementation for Testing

final class FakePlacesResolver: PlacesResolving {
    private var mockResults: [String: PlacesResult] = [:]
    private var mockCandidates: [String: [PlacesCandidate]] = [:]
    private var callCount = 0
    
    var totalCalls: Int { return callCount }
    
    func setMockResult(for coordinate: CLLocationCoordinate2D, result: PlacesResult?) {
        let key = "\(coordinate.latitude),\(coordinate.longitude)"
        if let result = result {
            mockResults[key] = result
        } else {
            mockResults.removeValue(forKey: key)
        }
    }
    
    func setMockCandidates(for coordinate: CLLocationCoordinate2D, candidates: [PlacesCandidate]) {
        let key = "\(coordinate.latitude),\(coordinate.longitude)"
        mockCandidates[key] = candidates
    }
    
    func nearestPOI(for coordinate: CLLocationCoordinate2D, session: PlacesSession?) async throws -> PlacesResult? {
        callCount += 1
        
        let key = "\(coordinate.latitude),\(coordinate.longitude)"
        return mockResults[key]
    }
    
    func nearbyCandidates(for coordinate: CLLocationCoordinate2D, session: PlacesSession?) async throws -> [PlacesCandidate] {
        callCount += 1
        
        let key = "\(coordinate.latitude),\(coordinate.longitude)"
        return mockCandidates[key] ?? []
    }
    
    func reset() {
        mockResults.removeAll()
        mockCandidates.removeAll()
        callCount = 0
    }
}