import Foundation
import CoreLocation

struct PlaceSuggestion: Identifiable {
    let id: String
    let description: String
}

struct PlaceDetails {
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
}

class PlaceService {
    // Note: For Places API (New) with direct HTTP calls, you may need a separate API key
    // with "HTTP referrers" restriction instead of "iOS apps" restriction
    private let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_PLACES_API_KEY") as? String ?? ""

    func fetchAutocomplete(for input: String, completion: @escaping ([PlaceSuggestion]) -> Void) {
        // Don't search for empty or very short inputs
        guard input.count >= 2 else {
            completion([])
            return
        }
        
        // New Places API endpoint
        let urlString = "https://places.googleapis.com/v1/places:autocomplete"
        
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        
        let requestBody: [String: Any] = [
            "input": input,
            "languageCode": "en"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("Error creating request body: \(error)")
            completion([])
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Network error: \(error)")
                    completion([])
                    return
                }
                
                guard let data = data else {
                    print("No data received")
                    completion([])
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let suggestions = json["suggestions"] as? [[String: Any]] {
                        
                        let placeSuggestions = suggestions.compactMap { suggestion -> PlaceSuggestion? in
                            guard let placePrediction = suggestion["placePrediction"] as? [String: Any],
                                  let placeId = placePrediction["placeId"] as? String,
                                  let text = placePrediction["text"] as? [String: Any],
                                  let displayText = text["text"] as? String else {
                                return nil
                            }
                            
                            return PlaceSuggestion(id: placeId, description: displayText)
                        }
                        
                        completion(placeSuggestions)
                    } else {
                        print("Unexpected JSON structure")
                        completion([])
                    }
                } catch {
                    print("JSON parsing error: \(error)")
                    completion([])
                }
            }
        }.resume()
    }
    
    func fetchPlaceDetails(placeId: String, completion: @escaping (PlaceDetails?) -> Void) {
        let urlString = "https://places.googleapis.com/v1/places/\(placeId)"
        
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("places.displayName,places.formattedAddress,places.location", forHTTPHeaderField: "X-Goog-FieldMask")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Network error: \(error)")
                    completion(nil)
                    return
                }
                
                guard let data = data else {
                    completion(nil)
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let displayName = json["displayName"] as? [String: Any],
                       let name = displayName["text"] as? String,
                       let address = json["formattedAddress"] as? String,
                       let location = json["location"] as? [String: Any],
                       let latitude = location["latitude"] as? Double,
                       let longitude = location["longitude"] as? Double {
                        
                        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                        let placeDetails = PlaceDetails(name: name, address: address, coordinate: coordinate)
                        completion(placeDetails)
                    } else {
                        print("Unexpected JSON structure for place details")
                        completion(nil)
                    }
                } catch {
                    print("JSON parsing error: \(error)")
                    completion(nil)
                }
            }
        }.resume()
    }
}