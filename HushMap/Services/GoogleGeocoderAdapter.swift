import Foundation
import CoreLocation
import GoogleMaps

// MARK: - Geocoding Result

struct GeocodingResult {
    let shortAddress: String
    let confidence: Double
}

// MARK: - Protocol

protocol GoogleGeocoderAdapting {
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> GeocodingResult?
}

// MARK: - Implementation

final class GoogleGeocoderAdapter: GoogleGeocoderAdapting, @unchecked Sendable {
    
    private let geocoder: GMSGeocoder
    private let rateLimiter: RateLimiter
    
    @MainActor
    init(rateLimiter: RateLimiter? = nil) {
        self.geocoder = GMSGeocoder()
        self.rateLimiter = rateLimiter ?? RateLimiter()
    }
    
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> GeocodingResult? {
        return try await rateLimiter.executeWithLimit {
            return try await self.performReverseGeocode(coordinate: coordinate)
        }
    }
    
    // MARK: - Private Methods
    
    private func performReverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> GeocodingResult? {
        return try await withCheckedThrowingContinuation { continuation in
            geocoder.reverseGeocodeCoordinate(coordinate) { response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let response = response,
                      let firstResult = response.firstResult() else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let shortAddress = self.formatShortAddress(from: firstResult)
                let confidence = self.calculateGeocodeConfidence(from: firstResult)
                
                let result = GeocodingResult(
                    shortAddress: shortAddress,
                    confidence: confidence
                )
                
                continuation.resume(returning: result)
            }
        }
    }
    
    private func formatShortAddress(from address: GMSAddress) -> String {
        var components: [String] = []
        
        // Add thoroughfare (street name)
        if let thoroughfare = address.thoroughfare {
            components.append(thoroughfare)
        }
        
        // Add locality (city/town)
        if let locality = address.locality {
            components.append(locality)
        }
        
        // If no components, try subLocality or administrativeArea
        if components.isEmpty {
            if let subLocality = address.subLocality {
                components.append(subLocality)
            } else if let administrativeArea = address.administrativeArea {
                components.append(administrativeArea)
            }
        }
        
        return components.joined(separator: ", ")
    }
    
    private func calculateGeocodeConfidence(from address: GMSAddress) -> Double {
        var confidence = 1.0
        
        // Higher confidence if we have both street and locality
        if address.thoroughfare != nil && address.locality != nil {
            confidence = 0.95
        } else if address.thoroughfare != nil || address.locality != nil {
            confidence = 0.85
        } else {
            // Only has subLocality or administrativeArea
            confidence = 0.75
        }
        
        return confidence
    }
}

// MARK: - Fake Implementation for Testing

final class FakeGoogleGeocoderAdapter: GoogleGeocoderAdapting {
    private var mockResults: [String: GeocodingResult?] = [:]
    private var callCount = 0
    
    var totalCalls: Int { return callCount }
    
    func setMockResult(for coordinate: CLLocationCoordinate2D, result: GeocodingResult?) {
        let key = "\(coordinate.latitude),\(coordinate.longitude)"
        mockResults[key] = result
    }
    
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> GeocodingResult? {
        callCount += 1
        
        let key = "\(coordinate.latitude),\(coordinate.longitude)"
        return mockResults[key] ?? nil
    }
    
    func reset() {
        mockResults.removeAll()
        callCount = 0
    }
}