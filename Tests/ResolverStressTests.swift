import XCTest
@testable import HushMap
import Foundation
import CoreLocation

/// Stress test for ReportLocationResolver with 1,000 synthetic reports
/// Tests cache efficiency and performance without network calls.
final class ResolverStressTests: XCTestCase {
    
    var tempCacheDirectory: URL!
    var cacheStore: DiskLocationLabelCacheStore!
    var fakeGeocodingService: FakeGeocodingService!
    var resolver: ReportLocationResolver!
    var syntheticReports: [Report] = []
    
    // Performance tracking
    var geocodeCallCount = 0
    var cacheHitCount = 0
    var resolutionTimes: [TimeInterval] = []
    
    override func setUp() throws {
        try super.setUp()
        
        // Setup temporary cache directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ResolverStressTests")
            .appendingPathComponent(UUID().uuidString)
        
        tempCacheDirectory = tempDir
        try FileManager.default.createDirectory(
            at: tempCacheDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Setup fake services
        fakeGeocodingService = FakeGeocodingService()
        cacheStore = try DiskLocationLabelCacheStore(cacheDirectory: tempCacheDirectory)
        
        // Create resolver with fake service
        resolver = ReportLocationResolver(
            geocodingService: fakeGeocodingService,
            diskCacheStore: cacheStore,
            rateLimiter: RateLimiter()
        )
        
        // Reset counters
        geocodeCallCount = 0
        cacheHitCount = 0
        resolutionTimes.removeAll()
        
        // Generate 1,000 synthetic reports over a 300m grid
        generateSyntheticReports()
        
        // Pre-populate fake service responses
        setupFakeGeocodingResponses()
    }
    
    override func tearDown() {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempCacheDirectory)
        super.tearDown()
    }
    
    func testStressWithColdCache() async throws {
        // Test with empty cache - should hit geocoding service frequently
        let startTime = Date()
        
        for report in syntheticReports {
            let resolutionStart = Date()
            await resolver.resolveLocationForReport(report)
            let resolutionEnd = Date()
            
            resolutionTimes.append(resolutionEnd.timeIntervalSince(resolutionStart))
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        print("📊 Cold Cache Results:")
        print("• Total reports: \(syntheticReports.count)")
        print("• Total time: \(String(format: "%.2f", totalTime))s")
        print("• Average resolution time: \(String(format: "%.0f", resolutionTimes.reduce(0, +) / Double(resolutionTimes.count) * 1000))ms")
        print("• Geocode calls: \(fakeGeocodingService.callCount)")
        print("• Cache hit rate: 0% (expected for cold cache)")
        
        // Assertions for cold cache
        XCTAssertTrue(totalTime < 30.0, "Total resolution time should be under 30s")
        XCTAssertTrue(fakeGeocodingService.callCount > 800, "Should make many geocode calls with cold cache")
    }
    
    func testStressWithWarmCache() async throws {
        // First, warm up the cache
        for report in syntheticReports {
            await resolver.resolveLocationForReport(report)
        }
        
        // Reset tracking
        fakeGeocodingService.resetCallCount()
        resolutionTimes.removeAll()
        
        // Now test with warm cache
        let startTime = Date()
        
        for report in syntheticReports {
            let resolutionStart = Date()
            await resolver.resolveLocationForReport(report)
            let resolutionEnd = Date()
            
            resolutionTimes.append(resolutionEnd.timeIntervalSince(resolutionStart))
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        let averageResolutionTime = resolutionTimes.reduce(0, +) / Double(resolutionTimes.count)
        let p99ResolutionTime = calculateP99(resolutionTimes)
        let geocodeCalls = fakeGeocodingService.callCount
        let cacheHitRate = Double(syntheticReports.count - geocodeCalls) / Double(syntheticReports.count) * 100
        
        print("📊 Warm Cache Results:")
        print("• Total reports: \(syntheticReports.count)")
        print("• Total time: \(String(format: "%.2f", totalTime))s")
        print("• Average resolution time: \(String(format: "%.0f", averageResolutionTime * 1000))ms")
        print("• P99 resolution time: \(String(format: "%.0f", p99ResolutionTime * 1000))ms")
        print("• Geocode calls: \(geocodeCalls)")
        print("• Cache hit rate: \(String(format: "%.1f", cacheHitRate))%")
        
        // Key assertions from the requirements
        XCTAssertTrue(cacheHitRate >= 95.0, "≥ 95% cache hit rate required (got \(String(format: "%.1f", cacheHitRate))%)")
        XCTAssertTrue(geocodeCalls <= Int(Double(syntheticReports.count) * 0.05), "≤ 5% calls should hit geocoder after warm cache")
        XCTAssertTrue(p99ResolutionTime < 0.150, "P99 resolution time should be <150ms from cache (got \(String(format: "%.0f", p99ResolutionTime * 1000))ms)")
        XCTAssertTrue(totalTime < 10.0, "Total warm cache resolution time should be under 10s")
    }
    
    func testCacheEfficiencyWithOverlappingReports() async throws {
        // Create additional reports that overlap with existing ones (should hit cache)
        let overlappingReports = generateOverlappingReports(count: 200)
        
        // Warm cache with original reports
        for report in syntheticReports {
            await resolver.resolveLocationForReport(report)
        }
        
        // Reset tracking
        fakeGeocodingService.resetCallCount()
        resolutionTimes.removeAll()
        
        // Test overlapping reports (should mostly hit cache)
        for report in overlappingReports {
            let resolutionStart = Date()
            await resolver.resolveLocationForReport(report)
            let resolutionEnd = Date()
            
            resolutionTimes.append(resolutionEnd.timeIntervalSince(resolutionStart))
        }
        
        let geocodeCalls = fakeGeocodingService.callCount
        let cacheHitRate = Double(overlappingReports.count - geocodeCalls) / Double(overlappingReports.count) * 100
        
        print("📊 Overlapping Reports Results:")
        print("• Overlapping reports: \(overlappingReports.count)")
        print("• Geocode calls: \(geocodeCalls)")
        print("• Cache hit rate: \(String(format: "%.1f", cacheHitRate))%")
        
        // Should have very high cache hit rate for overlapping locations
        XCTAssertTrue(cacheHitRate >= 90.0, "Cache hit rate should be ≥90% for overlapping locations")
        XCTAssertTrue(geocodeCalls <= 20, "Very few geocode calls expected for overlapping reports")
    }
    
    // MARK: - Helper Methods
    
    private func generateSyntheticReports() {
        // Central London coordinates as base
        let baseLat = 51.5074
        let baseLon = -0.1278
        
        // 300m grid: approximately 0.0027° per 300m at London's latitude
        let gridSpacing = 0.0027
        let gridSize = 32 // 32x32 grid ≈ 1024 points
        
        var reportId = 0
        
        for i in 0..<gridSize {
            for j in 0..<gridSize {
                guard reportId < 1000 else { break }
                
                let lat = baseLat + (Double(i) - Double(gridSize)/2) * gridSpacing
                let lon = baseLon + (Double(j) - Double(gridSize)/2) * gridSpacing
                
                let report = Report(
                    noise: Double.random(in: 0.1...0.9),
                    crowds: Double.random(in: 0.1...0.9),
                    lighting: Double.random(in: 0.1...0.9),
                    comfort: Double.random(in: 0.1...0.9),
                    comments: "Synthetic report #\(reportId)",
                    latitude: lat,
                    longitude: lon
                )
                
                syntheticReports.append(report)
                reportId += 1
            }
            
            if reportId >= 1000 { break }
        }
        
        print("📍 Generated \(syntheticReports.count) synthetic reports over 300m grid")
    }
    
    private func generateOverlappingReports(count: Int) -> [Report] {
        var overlappingReports: [Report] = []
        
        // Create reports that are very close to existing ones (within cache quantization)
        for i in 0..<min(count, syntheticReports.count) {
            let original = syntheticReports[i]
            
            // Add small random offset (within 25m quantization grid)
            let latOffset = Double.random(in: -0.0001...0.0001)
            let lonOffset = Double.random(in: -0.0001...0.0001)
            
            let overlappingReport = Report(
                noise: Double.random(in: 0.1...0.9),
                crowds: Double.random(in: 0.1...0.9),
                lighting: Double.random(in: 0.1...0.9),
                comfort: Double.random(in: 0.1...0.9),
                comments: "Overlapping report #\(i)",
                latitude: original.latitude + latOffset,
                longitude: original.longitude + lonOffset
            )
            
            overlappingReports.append(overlappingReport)
        }
        
        return overlappingReports
    }
    
    private func setupFakeGeocodingResponses() {
        // Setup diverse fake responses for our synthetic reports
        for (index, report) in syntheticReports.enumerated() {
            let coordinate = CLLocationCoordinate2D(latitude: report.latitude, longitude: report.longitude)
            
            // Vary the response types for realistic testing
            switch index % 5 {
            case 0:
                fakeGeocodingService.setResponse(
                    for: coordinate,
                    name: "Test Cafe \(index)",
                    tier: .poi,
                    confidence: 0.95
                )
            case 1:
                fakeGeocodingService.setResponse(
                    for: coordinate,
                    name: "Test Street, London",
                    tier: .street,
                    confidence: 0.90
                )
            case 2:
                fakeGeocodingService.setResponse(
                    for: coordinate,
                    name: "Camden area",
                    tier: .area,
                    confidence: 1.0
                )
            case 3:
                fakeGeocodingService.setResponse(
                    for: coordinate,
                    name: "Local Shop \(index)",
                    tier: .poi,
                    confidence: 0.75  // Lower confidence to test hedging
                )
            case 4:
                fakeGeocodingService.setResponse(
                    for: coordinate,
                    name: "Westminster area",
                    tier: .area,
                    confidence: 1.0
                )
            default:
                break
            }
        }
    }
    
    private func calculateP99(_ times: [TimeInterval]) -> TimeInterval {
        let sortedTimes = times.sorted()
        let p99Index = min(Int(Double(sortedTimes.count) * 0.99), sortedTimes.count - 1)
        return sortedTimes[p99Index]
    }
}

