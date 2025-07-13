import Foundation

// MARK: - OpenAI Models
struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let maxTokens: Int
    let temperature: Double
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}

// MARK: - OpenAI Service
class OpenAIService {
    private let apiKey: String = {
        // Try to read from Info.plist first
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String, !key.isEmpty && !key.contains("$") {
            // API key loaded successfully
            return key
        }
        
        // Fallback: Read directly from Config-Local.xcconfig
        if let path = Bundle.main.path(forResource: "Config-Local", ofType: "xcconfig"),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                if line.hasPrefix("OPENAI_API_KEY =") {
                    let key = line.replacingOccurrences(of: "OPENAI_API_KEY =", with: "").trimmingCharacters(in: .whitespaces)
                    // API key loaded from config
                    return key
                }
            }
        }
        
        print("❌ OpenAI API key not found - check Config-Local.xcconfig")
        return ""
    }()
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    func generateSensoryPrediction(
        venueName: String,
        venueType: String,
        dayOfWeek: String,
        timeOfDay: String,
        weather: String,
        placesData: String? = nil
    ) async throws -> String {
        
        let prompt = """
        You are an AI assistant specialized in predicting sensory environments for neurodivergent individuals, particularly those with autism and sensory processing differences.
        
        Analyze this venue and provide a comprehensive sensory prediction:
        
        VENUE: \(venueName)
        TYPE: \(venueType)
        TIME: \(dayOfWeek) at \(timeOfDay)
        WEATHER: \(weather)
        \(placesData.map { "ADDITIONAL DATA: \($0)" } ?? "")
        
        IMPORTANT: Start your response with structured data, then provide natural language explanation.
        
        Format your response EXACTLY like this:
        
        NOISE_LEVEL: [very quiet/quiet/moderate/noisy/very loud]
        CROWD_LEVEL: [empty/light/moderate/busy/very crowded]  
        LIGHTING_LEVEL: [dim/soft/moderate/bright/very bright]
        
        [Then provide your natural language assessment explaining WHY these levels exist, specific sensory considerations, and practical advice for visitors with sensory sensitivities. Be supportive and informative, not clinical.]
        """
        
        let request = OpenAIRequest(
            model: "gpt-3.5-turbo",
            messages: [
                OpenAIMessage(role: "system", content: "You are a specialized AI assistant helping neurodivergent individuals navigate sensory environments safely and comfortably."),
                OpenAIMessage(role: "user", content: prompt)
            ],
            maxTokens: 300,
            temperature: 0.3
        )
        
        return try await performRequest(request)
    }
    
    func generateInterestingFact(venueName: String) async throws -> String {
        let prompt = """
        Provide one fascinating, specific fact about \(venueName) that would interest someone who enjoys detailed information and trivia.
        
        Include precise numbers, historical details, architectural features, surprising statistics, hidden secrets, or unusual design elements. Make it genuinely fascinating!
        
        Examples of good facts:
        - "Buckingham Palace has 775 rooms including 188 staff bedrooms and 78 bathrooms"
        - "The London Eye moves so slowly you could walk faster - just 0.6 mph"
        - "Big Ben's clock face is so large that the minute hand travels 118 miles per year"
        
        Format: "Did you know? [Your fact]"
        
        Keep it under 60 words and make it genuinely surprising, not generic tourism information.
        """
        
        let request = OpenAIRequest(
            model: "gpt-3.5-turbo",
            messages: [
                OpenAIMessage(role: "user", content: prompt)
            ],
            maxTokens: 80,
            temperature: 0.7
        )
        
        return try await performRequest(request)
    }
    
    private func performRequest(_ request: OpenAIRequest, retryCount: Int = 0) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw AppError.api(.openAIError)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 15 // Reduced to 15 seconds for faster fallback
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw AppError.api(.openAIError)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.network(.invalidResponse)
            }
            
            // Handle specific HTTP status codes
            switch httpResponse.statusCode {
            case 200:
                break // Success
            case 401:
                throw AppError.api(.invalidAPIKey)
            case 429:
                throw AppError.api(.quotaExceeded)
            case 500...599:
                throw AppError.network(.serverUnavailable)
            default:
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("🤖 OpenAI API Error (\(httpResponse.statusCode)): \(errorString)")
                throw AppError.api(.openAIError)
            }
            
            do {
                let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                return openAIResponse.choices.first?.message.content ?? "No response generated"
            } catch {
                print("🤖 OpenAI JSON Decode Error: \(error)")
                throw AppError.api(.openAIError)
            }
            
        } catch let urlError as URLError {
            // Handle network-specific errors with retry logic
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw AppError.network(.noConnection)
            case .timedOut:
                // Retry timeout errors once
                if retryCount < 1 {
                    print("🔄 OpenAI request timed out, retrying... (attempt \(retryCount + 1))")
                    return try await performRequest(request, retryCount: retryCount + 1)
                } else {
                    throw AppError.network(.timeout)
                }
            default:
                throw AppError.network(.invalidResponse)
            }
        } catch let appError as AppError {
            // Re-throw app errors as-is
            throw appError
        } catch {
            // Retry unexpected errors once
            if retryCount < 1 {
                print("🔄 Unexpected OpenAI error, retrying... (attempt \(retryCount + 1)): \(error)")
                return try await performRequest(request, retryCount: retryCount + 1)
            } else {
                throw AppError.api(.openAIError)
            }
        }
    }
}

// MARK: - Error Types
enum OpenAIError: Error, LocalizedError {
    case invalidURL
    case encodingError(Error)
    case invalidResponse
    case apiError(Int, String)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid OpenAI API URL"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from OpenAI"
        case .apiError(let code, let message):
            return "OpenAI API error (\(code)): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}