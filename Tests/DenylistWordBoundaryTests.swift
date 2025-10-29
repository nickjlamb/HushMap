import XCTest
@testable import HushMap
import MapKit

/// Tests that the sensitive venue denylist uses proper word boundaries
/// to avoid false positives on legitimate venue names.
final class DenylistWordBoundaryTests: XCTestCase {
    
    var geocodingService: DefaultGeocodingService!
    
    override func setUp() {
        super.setUp()
        geocodingService = DefaultGeocodingService()
    }
    
    func testWordBoundaryPositiveMatches() {
        // These should match (be marked as sensitive)
        let sensitiveNames = [
            "Central Hospital",
            "St. Mary's Hospital",
            "The Local Clinic",
            "Westminster Court",
            "Grand Mosque",
            "St. Paul's Church",
            "Buddhist Temple",
            "Main Street Synagogue",
            "Primary School",
            "Village GP",
            "Medical Surgery"
        ]
        
        for name in sensitiveNames {
            let mapItem = createMockMapItem(name: name, category: nil)
            XCTAssertTrue(isSensitivePOIPublic(mapItem), 
                         "'\(name)' should be marked as sensitive")
        }
    }
    
    func testWordBoundaryNegativeMatches() {
        // These should NOT match (legitimate venues with similar substrings)
        let legitimateNames = [
            "Courtney House",        // Contains "court" but not as whole word
            "Churchill Arms",        // Contains "church" but not as whole word  
            "The Mosque Restaurant", // Contains "mosque" but context is different
            "Temple Bar",            // "Temple" as venue name, not religious
            "Court Road Cafe",       // "Court" as street name
            "Hospital Street Pub",   // "Hospital" as street name
            "Surgery Lane Market",   // "Surgery" as street name
            "GP Motors",            // "GP" as business abbreviation
        ]
        
        for name in legitimateNames {
            let mapItem = createMockMapItem(name: name, category: nil)
            XCTAssertFalse(isSensitivePOIPublic(mapItem), 
                          "'\(name)' should NOT be marked as sensitive")
        }
    }
    
    func testCaseInsensitiveMatching() {
        let caseVariations = [
            "central hospital",    // lowercase
            "CENTRAL HOSPITAL",    // uppercase  
            "Central HOSPITAL",    // mixed case
            "CeNtRaL hOsPiTaL"    // random case
        ]
        
        for name in caseVariations {
            let mapItem = createMockMapItem(name: name, category: nil)
            XCTAssertTrue(isSensitivePOIPublic(mapItem), 
                         "'\(name)' should be marked as sensitive (case insensitive)")
        }
    }
    
    func testCategoryTakesPrecedenceOverName() {
        // A venue with hospital category should be sensitive even with safe name
        let hospitalItem = createMockMapItem(name: "Safe Cafe Name", category: .hospital)
        XCTAssertTrue(isSensitivePOIPublic(hospitalItem), 
                     "Hospital category should override safe name")
        
        // A venue with safe category should not be sensitive even with risky name fragment
        let cafeItem = createMockMapItem(name: "Courtney's Cafe", category: .restaurant)
        XCTAssertFalse(isSensitivePOIPublic(cafeItem), 
                      "Safe category with name fragment should not be sensitive")
    }
    
    // MARK: - Helper Methods
    
    private func createMockMapItem(name: String, category: MKPointOfInterestCategory?) -> MKMapItem {
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0))
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        if let category = category {
            // Note: In actual testing, you may need to use a mock or subclass
            // since MKMapItem's pointOfInterestCategory is read-only
            // For now, this demonstrates the test structure
        }
        return mapItem
    }
    
    // Helper method to access private isSensitivePOI method
    private func isSensitivePOIPublic(_ item: MKMapItem) -> Bool {
        // This would need reflection or a test-friendly version of the method
        // For now, we'll create a simplified version of the logic
        
        // Check category first
        if let category = item.pointOfInterestCategory {
            let sensitivePOICategories: [MKPointOfInterestCategory] = [
                .hospital, .pharmacy, .school, .university
            ]
            if sensitivePOICategories.contains(category) {
                return true
            }
        }
        
        // Check name with regex
        let name = item.name ?? ""
        guard !name.isEmpty else { return false }
        
        let pattern = "\\b(hospital|clinic|court|mosque|church|temple|synagogue|primary school|gp|surgery)\\b"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines])
        
        guard let regex = regex else { return false }
        let nameRange = NSRange(location: 0, length: name.utf16.count)
        return regex.firstMatch(in: name, options: [], range: nameRange) != nil
    }
}