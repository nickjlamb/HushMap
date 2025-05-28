import Foundation

// MARK: - App Error Framework
enum AppError: LocalizedError, Identifiable {
    case network(NetworkError)
    case location(LocationError)
    case api(APIError)
    case general(GeneralError)
    
    var id: String {
        switch self {
        case .network(let error): return "network_\(error.rawValue)"
        case .location(let error): return "location_\(error.rawValue)"
        case .api(let error): return "api_\(error.rawValue)"
        case .general(let error): return "general_\(error.rawValue)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .network(let error): return error.userMessage
        case .location(let error): return error.userMessage
        case .api(let error): return error.userMessage
        case .general(let error): return error.userMessage
        }
    }
    
    var title: String {
        switch self {
        case .network: return "Connection Issue"
        case .location: return "Location Access"
        case .api: return "Service Unavailable"
        case .general: return "Something Went Wrong"
        }
    }
    
    var actionButtonTitle: String {
        switch self {
        case .network: return "Try Again"
        case .location: return "Open Settings"
        case .api: return "Retry"
        case .general: return "OK"
        }
    }
}

// MARK: - Network Errors
enum NetworkError: String, CaseIterable {
    case noConnection = "no_connection"
    case timeout = "timeout"
    case serverUnavailable = "server_unavailable"
    case invalidResponse = "invalid_response"
    
    var userMessage: String {
        switch self {
        case .noConnection:
            return "Please check your internet connection and try again."
        case .timeout:
            return "The request took too long. Please check your connection and try again."
        case .serverUnavailable:
            return "Our servers are temporarily unavailable. Please try again in a few moments."
        case .invalidResponse:
            return "We received an unexpected response. Please try again."
        }
    }
}

// MARK: - Location Errors
enum LocationError: String, CaseIterable {
    case permissionDenied = "permission_denied"
    case permissionRestricted = "permission_restricted"
    case locationUnavailable = "location_unavailable"
    case serviceDisabled = "service_disabled"
    
    var userMessage: String {
        switch self {
        case .permissionDenied:
            return "HushMap needs location access to show nearby venues and provide sensory predictions."
        case .permissionRestricted:
            return "Location access is restricted on this device. Please check your device restrictions."
        case .locationUnavailable:
            return "Unable to determine your current location. Please try again."
        case .serviceDisabled:
            return "Location services are disabled. Please enable them in Settings."
        }
    }
}

// MARK: - API Errors
enum APIError: String, CaseIterable {
    case invalidAPIKey = "invalid_api_key"
    case quotaExceeded = "quota_exceeded"
    case googleMapsError = "google_maps_error"
    case googlePlacesError = "google_places_error"
    case openAIError = "openai_error"
    case authenticationFailed = "auth_failed"
    
    var userMessage: String {
        switch self {
        case .invalidAPIKey:
            return "There's a configuration issue with the app. Please try again later."
        case .quotaExceeded:
            return "We've reached our service limit for today. Please try again tomorrow."
        case .googleMapsError:
            return "Map services are temporarily unavailable. Please try again."
        case .googlePlacesError:
            return "Place search is temporarily unavailable. Please try again."
        case .openAIError:
            return "AI predictions are temporarily unavailable. You can still browse venues and reports."
        case .authenticationFailed:
            return "Please sign in again to continue using HushMap."
        }
    }
}

// MARK: - General Errors
enum GeneralError: String, CaseIterable {
    case dataCorruption = "data_corruption"
    case insufficientStorage = "insufficient_storage"
    case unexpectedError = "unexpected_error"
    
    var userMessage: String {
        switch self {
        case .dataCorruption:
            return "Some data may be corrupted. Please restart the app."
        case .insufficientStorage:
            return "Your device is running low on storage space."
        case .unexpectedError:
            return "An unexpected error occurred. Please try again."
        }
    }
}

// MARK: - Error State View Model
@MainActor
class ErrorStateViewModel: ObservableObject {
    @Published var currentError: AppError?
    @Published var isShowingError = false
    
    func showError(_ error: AppError) {
        currentError = error
        isShowingError = true
    }
    
    func clearError() {
        currentError = nil
        isShowingError = false
    }
}