import Foundation

// API key moved to Config-Local.xcconfig for security
// Replace with: Bundle.main.object(forInfoDictionaryKey: "GOOGLE_PLACES_API_KEY") as? String ?? ""
let apiKey = "YOUR_API_KEY_HERE"
let urlString = "https://places.googleapis.com/v1/places:autocomplete"

guard let url = URL(string: urlString) else {
    print("❌ Invalid URL")
    exit(1)
}

var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")

let requestBody: [String: Any] = [
    "input": "pizza restaurant",
    "languageCode": "en"
]

do {
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
} catch {
    print("❌ Error creating request body: \(error)")
    exit(1)
}

let task = URLSession.shared.dataTask(with: request) { data, response, error in
    if let error = error {
        print("❌ Network error: \(error)")
        return
    }
    
    guard let data = data else {
        print("❌ No data received")
        return
    }
    
    if let jsonString = String(data: data, encoding: .utf8) {
        print("✅ Response: \(jsonString)")
    }
    
    exit(0)
}

task.resume()
RunLoop.main.run()