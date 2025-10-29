import XCTest
@testable import HushMap
import Foundation
import CoreLocation

/// Tests for area name sanitization and synthetic placeholder handling
final class AreaSanitizationTests: XCTestCase {
    
    func testAreaSanitization_noDoubleSuffix() {
        // Given: A report with area display name that already has " area" suffix
        let report = Report(
            noise: 0.5,
            crowds: 0.5,
            lighting: 0.5,
            comfort: 0.5,
            comments: "Test",
            latitude: 51.5074,
            longitude: -0.1278
        )
        
        // When: We set an area name that already ends with " area"
        report.displayName = "Camden area"
        report.displayTierRaw = DisplayTier.area.rawValue
        
        // Then: friendlyDisplayName should not add another " area" suffix
        XCTAssertEqual(report.friendlyDisplayName, "Camden area", 
                      "Area name should not have double ' area' suffix")
    }
    
    func testSyntheticArea_replacedWithNearbyArea() {
        // Given: A report with synthetic area patterns
        let report = Report(
            noise: 0.5,
            crowds: 0.5,
            lighting: 0.5,
            comfort: 0.5,
            comments: "Test",
            latitude: 51.5074,
            longitude: -0.1278
        )
        
        let syntheticNames = ["Area 5135251", "Grid 123", "Zone 999", "Cell 42"]
        
        for syntheticName in syntheticNames {
            // When: We set a synthetic area name
            report.displayName = syntheticName
            report.displayTierRaw = DisplayTier.area.rawValue
            
            // Then: friendlyDisplayName should replace it with "Nearby area"
            XCTAssertEqual(report.friendlyDisplayName, "Nearby area",
                          "Synthetic name '\(syntheticName)' should be replaced with 'Nearby area'")
        }
    }
    
    func testPlaceholdersNotPersisted() async {
        // Given: A resolver with fake geocoding service that returns synthetic placeholders
        let tempCacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlaceholderTests")
            .appendingPathComponent(UUID().uuidString)
        
        try! FileManager.default.createDirectory(
            at: tempCacheDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        defer { try? FileManager.default.removeItem(at: tempCacheDirectory) }
        
        let fakeGeocodingService = FakeGeocodingService()
        let cacheStore = try DiskLocationLabelCacheStore(cacheDirectory: tempCacheDirectory)
        let resolver = ReportLocationResolver(
            geocodingService: fakeGeocodingService,
            diskCacheStore: cacheStore,
            rateLimiter: RateLimiter()
        )
        
        // Setup fake service to return synthetic placeholder
        let coordinate = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        fakeGeocodingService.setResponse(
            for: coordinate,
            name: "Nearby area",
            tier: .area,
            confidence: 1.0
        )
        
        let report = Report(
            noise: 0.5,
            crowds: 0.5,
            lighting: 0.5,
            comfort: 0.5,
            comments: "Test",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        
        // When: We resolve location for the report
        await resolver.resolveLocationForReport(report)
        
        // Then: Synthetic placeholders should not be persisted to report
        XCTAssertNil(report.displayName, "Synthetic placeholder should not be persisted to report.displayName")
        XCTAssertNil(report.displayTierRaw, "Synthetic placeholder should not be persisted to report.displayTier")
        XCTAssertNil(report.confidence, "Synthetic placeholder should not be persisted to report.confidence")
        
        // And: Should not be persisted to disk cache
        let locationKey = LocationKey(
            coordinate: coordinate,
            locale: .current,
            rulesVersion: 2
        )
        let cachedLabel = cacheStore.get(for: locationKey)
        XCTAssertNil(cachedLabel, "Synthetic placeholder should not be cached to disk")
        
        // But: UI should still show the placeholder via friendlyDisplayName
        XCTAssertEqual(report.friendlyDisplayName, "Nearby area", 
                      "UI should show placeholder even when not persisted")
    }
    
    func testCachePurge_removesSyntheticEntries() throws {
        // Given: A cache with synthetic entries seeded
        let tempCacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PurgeTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(
            at: tempCacheDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        defer { try? FileManager.default.removeItem(at: tempCacheDirectory) }
        
        let cacheStore = try DiskLocationLabelCacheStore(cacheDirectory: tempCacheDirectory)
        
        // Seed cache with both legitimate and synthetic entries
        let legitimateKey = LocationKey(
            coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
            locale: .current,
            rulesVersion: 2
        )
        let syntheticKey = LocationKey(
            coordinate: CLLocationCoordinate2D(latitude: 51.5080, longitude: -0.1280),
            locale: .current,
            rulesVersion: 2
        )
        
        let legitimateLabel = LocationLabel(
            name: "Camden area",
            tier: .area,
            confidence: 1.0,
            updatedAt: Date()
        )
        let syntheticLabel = LocationLabel(
            name: "Area 12345",
            tier: .area,
            confidence: 1.0,
            updatedAt: Date()
        )
        
        cacheStore.set(legitimateLabel, for: legitimateKey)
        cacheStore.set(syntheticLabel, for: syntheticKey)
        
        // Verify both are cached before purge
        XCTAssertNotNil(cacheStore.get(for: legitimateKey), "Legitimate entry should be cached")
        XCTAssertNotNil(cacheStore.get(for: syntheticKey), "Synthetic entry should be cached before purge")
        
        // When: We purge synthetic entries
        try cacheStore.purge { label in
            let syntheticPattern = "^(Area|Cell|Grid|Zone)\\s*\\d+$"
            if let regex = try? NSRegularExpression(pattern: syntheticPattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: label.name.utf16.count)
                return regex.firstMatch(in: label.name, options: [], range: range) != nil
            }
            return false
        }
        
        // Then: Synthetic entry should be removed, legitimate entry should remain
        XCTAssertNotNil(cacheStore.get(for: legitimateKey), "Legitimate entry should remain after purge")
        XCTAssertNil(cacheStore.get(for: syntheticKey), "Synthetic entry should be removed by purge")
    }
    
    func testLegitimateAreaNames_notAffectedBySanitization() {
        // Given: A report with legitimate area names
        let report = Report(
            noise: 0.5,
            crowds: 0.5,
            lighting: 0.5,
            comfort: 0.5,
            comments: "Test",
            latitude: 51.5074,
            longitude: -0.1278
        )
        
        let legitimateNames = [
            "Camden",           // Should become "Camden area"
            "Westminster",      // Should become "Westminster area"
            "South London",     // Should become "South London area"
            "King's Cross"      // Should become "King's Cross area"
        ]
        
        for baseName in legitimateNames {
            // When: We set a legitimate area name (without " area" suffix)
            report.displayName = baseName
            report.displayTierRaw = DisplayTier.area.rawValue
            
            // Then: friendlyDisplayName should add " area" suffix
            XCTAssertEqual(report.friendlyDisplayName, "\(baseName) area",
                          "Legitimate name '\(baseName)' should get ' area' suffix")
        }
    }
    
    func testSyntheticPatternMatching_caseInsensitive() {
        let report = Report(
            noise: 0.5,
            crowds: 0.5,
            lighting: 0.5,
            comfort: 0.5,
            comments: "Test",
            latitude: 51.5074,
            longitude: -0.1278
        )
        
        let syntheticVariations = [
            "area 123",         // lowercase
            "GRID 456",         // uppercase
            "Zone 789",         // title case
            "CELL 999"          // mixed case
        ]
        
        for syntheticName in syntheticVariations {
            report.displayName = syntheticName
            report.displayTierRaw = DisplayTier.area.rawValue
            
            XCTAssertEqual(report.friendlyDisplayName, "Nearby area",
                          "Case variation '\(syntheticName)' should be replaced with 'Nearby area'")
        }
    }
}