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
    private let apiKey = APIKeys.googlePlaces

    func fetchAutocomplete(for input: String, completion: @escaping ([PlaceSuggestion]) -> Void) {
        // Don't search for empty or very short inputs
        guard input.count >= 2 else {
            completion([])
            return
        }
        
        // Debug: Check if API key is loaded
        if apiKey.isEmpty {
            print("❌ Places API key is empty! Check Config-Local.xcconfig")
            completion([])
            return
        }
        print("🔑 Using Places API key: \(String(apiKey.prefix(10)))...")
        
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
        request.setValue("https://hushmap.app", forHTTPHeaderField: "Referer")
        
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
                    print("❌ Places API Network error: \(error)")
                    completion([])
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 Places API Response status: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        print("❌ Places API HTTP Error: \(httpResponse.statusCode)")
                        if let data = data, let errorString = String(data: data, encoding: .utf8) {
                            print("❌ Error response: \(errorString)")
                        }
                        completion([])
                        return
                    }
                }
                
                guard let data = data else {
                    print("❌ No data received from Places API")
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
        request.setValue("displayName,formattedAddress,location", forHTTPHeaderField: "X-Goog-FieldMask")
        request.setValue("https://hushmap.app", forHTTPHeaderField: "Referer")
        
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
                                print("❌ Could not parse latitude/longitude")
                                completion(nil)
                                return
                            }
                            
                            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                            let placeDetails = PlaceDetails(name: name, address: address, coordinate: coordinate)
                            completion(placeDetails)
                        } else {
                            print("❌ Unexpected JSON structure for place details")
                            print("Available keys: \(json.keys)")
                            completion(nil)
                        }
                    } else {
                        print("❌ Could not parse JSON as dictionary")
                        completion(nil)
                    }
                } catch {
                    print("❌ JSON parsing error: \(error)")
                    completion(nil)
                }
            }
        }.resume()
    }
    
    func findPlace(at coordinate: CLLocationCoordinate2D, completion: @escaping (PlaceDetails?) -> Void) {
        // Use Places API nearbySearch to find places at the given coordinate
        let urlString = "https://places.googleapis.com/v1/places:searchNearby"
        
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("https://hushmap.app", forHTTPHeaderField: "Referer")
        request.setValue("places.displayName,places.formattedAddress,places.location", forHTTPHeaderField: "X-Goog-FieldMask")
        
        let requestBody: [String: Any] = [
            "locationRestriction": [
                "circle": [
                    "center": [
                        "latitude": coordinate.latitude,
                        "longitude": coordinate.longitude
                    ],
                    "radius": 50.0 // 50 meters radius
                ]
            ],
            "maxResultCount": 1
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("Error creating request body: \(error)")
            completion(nil)
            return
        }
        
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
                       let places = json["places"] as? [[String: Any]],
                       let firstPlace = places.first,
                       let displayName = firstPlace["displayName"] as? [String: Any],
                       let name = displayName["text"] as? String,
                       let address = firstPlace["formattedAddress"] as? String,
                       let location = firstPlace["location"] as? [String: Any],
                       let latitude = location["latitude"] as? Double,
                       let longitude = location["longitude"] as? Double {
                        
                        let placeCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                        let placeDetails = PlaceDetails(name: name, address: address, coordinate: placeCoordinate)
                        completion(placeDetails)
                    } else {
                        // No place found at this location
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