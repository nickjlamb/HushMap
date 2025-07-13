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
        
        // Debug: Check if API key is loaded
        if apiKey.isEmpty {
            #if DEBUG
            print("❌ Places API key is empty! Check Config-Local.xcconfig")
            #endif
            completion([])
            return
        }
        #if DEBUG
        // Using Places API key
        #endif
        
        // New Places API endpoint
        let urlString = "https://places.googleapis.com/v1/places:autocomplete"
        
        guard let url = URL(string: urlString) else {
            #if DEBUG
            print("Invalid URL")
            #endif
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("https://hushmap.app", forHTTPHeaderField: "Referer")
        
        let requestBody: [String: Any] = [
            "input": input,
            "languageCode": "en"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            #if DEBUG
            print("Error creating request body: \(error)")
            #endif
            completion([])
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    #if DEBUG
                    print("❌ Places API Network error: \(error)")
                    // Check for specific network errors
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .notConnectedToInternet, .networkConnectionLost:
                            print("❌ No internet connection")
                        case .timedOut:
                            print("❌ Request timed out")
                        default:
                            print("❌ Network error: \(urlError.localizedDescription)")
                        }
                    }
                    #endif
                    completion([])
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    #if DEBUG
                    print("📡 Places API Response status: \(httpResponse.statusCode)")
                    #endif
                    if httpResponse.statusCode != 200 {
                        #if DEBUG
                        print("❌ Places API HTTP Error: \(httpResponse.statusCode)")
                        if let data = data, let errorString = String(data: data, encoding: .utf8) {
                            print("❌ Error response: \(errorString)")
                        }
                        #endif
                        completion([])
                        return
                    }
                }
                
                guard let data = data else {
                    #if DEBUG
                    print("❌ No data received from Places API")
                    #endif
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
                        #if DEBUG
                        print("Unexpected JSON structure")
                        #endif
                        completion([])
                    }
                } catch {
                    #if DEBUG
                    print("JSON parsing error: \(error)")
                    #endif
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
        request.setValue("displayName,formattedAddress,location", forHTTPHeaderField: "X-Goog-FieldMask")
        request.setValue("https://hushmap.app", forHTTPHeaderField: "Referer")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    #if DEBUG
                    print("Network error: \(error)")
                    #endif
                    completion(nil)
                    return
                }
                
                guard let data = data else {
                    completion(nil)
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {                        
                        if let displayName = json["displayName"] as? [String: Any],
                           let name = displayName["text"] as? String,
                           let address = json["formattedAddress"] as? String,
                           let location = json["location"] as? [String: Any] {
                            
                            // Handle latitude/longitude as either String or Double
                            let latitude: Double
                            let longitude: Double
                            
                            if let latString = location["latitude"] as? String,
                               let lonString = location["longitude"] as? String,
                               let lat = Double(latString),
                               let lon = Double(lonString) {
                                latitude = lat
                                longitude = lon
                            } else if let lat = location["latitude"] as? Double,
                                      let lon = location["longitude"] as? Double {
                                latitude = lat
                                longitude = lon
                            } else {
                                #if DEBUG
                                print("❌ Could not parse latitude/longitude")
                                #endif
                                completion(nil)
                                return
                            }
                            
                            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                            
                            let placeDetails = PlaceDetails(
                                name: name,
                                address: address,
                                coordinate: coordinate
                            )
                            
                            completion(placeDetails)
                        } else {
                            #if DEBUG
                            print("❌ Unexpected JSON structure for place details")
                            print("Available keys: \(json.keys)")
                            #endif
                            completion(nil)
                        }
                    } else {
                        #if DEBUG
                        print("❌ Could not parse JSON as dictionary")
                        #endif
                        completion(nil)
                    }
                } catch {
                    #if DEBUG
                    print("❌ JSON parsing error: \(error)")
                    #endif
                    completion(nil)
                }
            }
        }.resume()
    }
    
    func findPlace(at coordinate: CLLocationCoordinate2D, completion: @escaping (PlaceDetails?) -> Void) {
        // Simple version that just creates a generic place with coordinates
        let place = PlaceDetails(
            name: "Location",
            address: "Coordinates: \(coordinate.latitude), \(coordinate.longitude)",
            coordinate: coordinate
        )
        completion(place)
    }
}