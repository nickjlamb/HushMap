import Foundation
import UIKit

// Simple standalone test for PlaceService
class TestApp {
    private let placeService = PlaceService()
    
    func testSearch() {
        print("🧪 Starting PlaceService test...")
        
        placeService.fetchAutocomplete(for: "Preston") { suggestions in
            print("🧪 Test completed. Received \(suggestions.count) suggestions:")
            for (index, suggestion) in suggestions.enumerated() {
                print("  \(index + 1). \(suggestion.description) (ID: \(suggestion.id))")
            }
            
            if let firstSuggestion = suggestions.first {
                print("🧪 Testing place details for: \(firstSuggestion.description)")
                self.placeService.fetchPlaceDetails(for: firstSuggestion.id) { details in
                    if let details = details {
                        print("🧪 Place details: \(details.name) at \(details.coordinate)")
                    } else {
                        print("🧪 Failed to get place details")
                    }
                    
                    // Exit after test
                    exit(0)
                }
            } else {
                print("🧪 No suggestions received, exiting")
                exit(1)
            }
        }
    }
}

// Run the test
let testApp = TestApp()
testApp.testSearch()

// Keep the app running
RunLoop.main.run()