import XCTest
@testable import HushMap
import Foundation
import CoreLocation

/// Tests that DiskLocationLabelCacheStore handles corrupted JSON gracefully
/// without crashing and properly cleans up invalid files.
final class CacheCorruptionTests: XCTestCase {
    
    var tempCacheDirectory: URL!
    var cacheStore: DiskLocationLabelCacheStore!
    
    override func setUp() throws {
        try super.setUp()
        
        // Create temporary directory for testing
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CacheCorruptionTests")
            .appendingPathComponent(UUID().uuidString)
        
        tempCacheDirectory = tempDir
        
        try FileManager.default.createDirectory(
            at: tempCacheDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        cacheStore = try DiskLocationLabelCacheStore(cacheDirectory: tempCacheDirectory)
    }
    
    override func tearDown() {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempCacheDirectory)
        super.tearDown()
    }
    
    func testCorruptedJSONReturnsNilWithoutCrash() throws {
        // Given: A location key
        let coordinate = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        let locationKey = LocationKey(
            coordinate: coordinate,
            locale: .current,
            rulesVersion: 1
        )
        
        // When: We write invalid JSON to the cache file
        let cacheFilePath = tempCacheDirectory.appendingPathComponent("\(locationKey.base64URLKey).json")
        let invalidJSON = "{ invalid json content }"
        try invalidJSON.write(to: cacheFilePath, atomically: true, encoding: .utf8)
        
        // Verify file exists before test
        XCTAssertTrue(FileManager.default.fileExists(atPath: cacheFilePath.path))
        
        // Then: get() should return nil without crashing and delete the corrupted file
        let result = cacheStore.get(for: locationKey)
        XCTAssertNil(result, "Corrupted cache should return nil")
        
        // Verify corrupted file was deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheFilePath.path),
                      "Corrupted cache file should be deleted")
    }
    
    func testTruncatedJSONReturnsNilWithoutCrash() throws {
        // Given: A location key
        let coordinate = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        let locationKey = LocationKey(
            coordinate: coordinate,
            locale: .current,
            rulesVersion: 1
        )
        
        // When: We write truncated JSON to the cache file
        let cacheFilePath = tempCacheDirectory.appendingPathComponent("\(locationKey.base64URLKey).json")
        let truncatedJSON = "{ \"name\": \"Test\", \"tier\": \"poi\", \"confidence\": 0.9, \"updatedAt\":"
        try truncatedJSON.write(to: cacheFilePath, atomically: true, encoding: .utf8)
        
        // Then: get() should return nil without crashing and delete the corrupted file
        let result = cacheStore.get(for: locationKey)
        XCTAssertNil(result, "Truncated cache should return nil")
        
        // Verify corrupted file was deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheFilePath.path),
                      "Truncated cache file should be deleted")
    }
    
    func testEmptyFileReturnsNilWithoutCrash() throws {
        // Given: A location key
        let coordinate = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        let locationKey = LocationKey(
            coordinate: coordinate,
            locale: .current,
            rulesVersion: 1
        )
        
        // When: We create an empty cache file
        let cacheFilePath = tempCacheDirectory.appendingPathComponent("\(locationKey.base64URLKey).json")
        FileManager.default.createFile(atPath: cacheFilePath.path, contents: Data(), attributes: nil)
        
        // Then: get() should return nil without crashing and delete the empty file
        let result = cacheStore.get(for: locationKey)
        XCTAssertNil(result, "Empty cache file should return nil")
        
        // Verify empty file was deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheFilePath.path),
                      "Empty cache file should be deleted")
    }
    
    func testValidCacheWorksAfterCorruption() throws {
        // Given: A location key
        let coordinate = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        let locationKey = LocationKey(
            coordinate: coordinate,
            locale: .current,
            rulesVersion: 1
        )
        
        // When: We first have corrupted data, then store valid data
        let cacheFilePath = tempCacheDirectory.appendingPathComponent("\(locationKey.base64URLKey).json")
        try "invalid".write(to: cacheFilePath, atomically: true, encoding: .utf8)
        
        // Corrupted read should return nil and clean up
        let corruptedResult = cacheStore.get(for: locationKey)
        XCTAssertNil(corruptedResult)
        
        // Now store valid data
        let validLabel = LocationLabel(name: "Test Cafe", tier: .poi, confidence: 0.95, updatedAt: Date())
        cacheStore.set(validLabel, for: locationKey)
        
        // Then: Valid data should be retrievable
        let validResult = cacheStore.get(for: locationKey)
        XCTAssertNotNil(validResult)
        XCTAssertEqual(validResult?.name, "Test Cafe")
        XCTAssertEqual(validResult?.tier, .poi)
        XCTAssertEqual(validResult?.confidence, 0.95, accuracy: 0.01)
    }
}