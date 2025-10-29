import XCTest
@testable import HushMap
import Foundation
import CoreLocation
import UIKit

/// Quick validation tests for the acceptance criteria
final class AcceptanceCriteriaTests: XCTestCase {
    
    func testAcceptanceCriteria() async throws {
        print("🧪 Testing acceptance criteria...")
        
        // 1. testAreaSanitization_noDoubleSuffix(): "Camden area" → remains "Camden area", no extra " area"
        let report1 = Report(noise: 0.5, crowds: 0.5, lighting: 0.5, comfort: 0.5, comments: "Test", latitude: 51.5074, longitude: -0.1278)
        report1.displayName = "Camden area"
        report1.displayTierRaw = DisplayTier.area.rawValue
        
        XCTAssertEqual(report1.friendlyDisplayName, "Camden area")
        print("✅ No double suffix: 'Camden area' → '\(report1.friendlyDisplayName)'")
        
        // 2. testSyntheticArea_replacedWithNearbyArea(): "Area 5135251" → "Nearby area"
        let report2 = Report(noise: 0.5, crowds: 0.5, lighting: 0.5, comfort: 0.5, comments: "Test", latitude: 51.5074, longitude: -0.1278)
        report2.displayName = "Area 5135251"
        report2.displayTierRaw = DisplayTier.area.rawValue
        
        XCTAssertEqual(report2.friendlyDisplayName, "Nearby area")
        print("✅ Synthetic replacement: 'Area 5135251' → '\(report2.friendlyDisplayName)'")
        
        // 3. testPlaceholdersNotPersisted(): resolver returning .area + "Nearby area" does not save
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let fakeService = FakeGeocodingService()
        let cacheStore = try DiskLocationLabelCacheStore(cacheDirectory: tempDir)
        let resolver = ReportLocationResolver(geocodingService: fakeService, diskCacheStore: cacheStore, rateLimiter: RateLimiter())
        
        let coord = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        fakeService.setResponse(for: coord, name: "Nearby area", tier: .area, confidence: 1.0)
        
        let report3 = Report(noise: 0.5, crowds: 0.5, lighting: 0.5, comfort: 0.5, comments: "Test", latitude: coord.latitude, longitude: coord.longitude)
        await resolver.resolveLocationForReport(report3)
        
        XCTAssertNil(report3.displayName, "Placeholder should not persist to report")
        print("✅ Placeholders not persisted: displayName = \(report3.displayName?.description ?? "nil")")
        
        // 4. testCachePurge_removesSyntheticEntries(): seeded cache with "Area 12345" is removed
        let syntheticLabel = LocationLabel(name: "Area 12345", tier: .area, confidence: 1.0, updatedAt: Date())
        let syntheticKey = LocationKey(coordinate: coord, locale: .current, rulesVersion: 2)
        cacheStore.set(syntheticLabel, for: syntheticKey)
        
        XCTAssertNotNil(cacheStore.get(for: syntheticKey), "Should be cached before purge")
        
        try cacheStore.purge { label in
            let syntheticPattern = "^(Area|Cell|Grid|Zone)\\s*\\d+$"
            if let regex = try? NSRegularExpression(pattern: syntheticPattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: label.name.utf16.count)
                return regex.firstMatch(in: label.name, options: [], range: range) != nil
            }
            return false
        }
        
        XCTAssertNil(cacheStore.get(for: syntheticKey), "Should be removed after purge")
        print("✅ Cache purge works: synthetic entry removed")
        
        print("🎉 All acceptance criteria passed!")
    }
    
    func testDonutPinCenterIsTransparent() {
        print("🧪 Testing donut pin hole transparency...")
        
        let img = MarkerIconFactory.shared.image(
            for: .quiet, 
            size: .normal, 
            selected: false, 
            scale: UIScreen.main.scale,
            zoomMultiplier: 1.0,
            interfaceStyle: .light
        )
        
        guard let cgImage = img.cgImage else { 
            return XCTFail("No CGImage available")
        }
        
        // Check center of the hole (around bulb center at y = S * 0.44)
        let centerX = Int(cgImage.width / 2)
        let centerY = Int(Double(cgImage.height) * 0.5)  // Approximate hole center
        
        let alpha = alphaAtPixel(cgImage: cgImage, x: centerX, y: centerY)
        XCTAssertLessThanOrEqual(alpha, 5, "Hole should be transparent (alpha ≈ 0), got \(alpha)")
        
        print("✅ Hole transparency verified: alpha = \(alpha)")
    }
    
    // Helper to extract alpha value at specific pixel
    private func alphaAtPixel(cgImage: CGImage, x: Int, y: Int) -> UInt8 {
        guard x >= 0 && y >= 0 && x < cgImage.width && y < cgImage.height else {
            return 255  // Return opaque for out-of-bounds
        }
        
        let bytesPerPixel = 4
        let bytesPerRow = cgImage.bytesPerRow
        let bitsPerComponent = 8
        
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return 255
        }
        
        let offset = (y * bytesPerRow) + (x * bytesPerPixel)
        return bytes[offset + 3]  // Alpha is the 4th component (RGBA)
    }
}