import Foundation
import CoreLocation

// MARK: - Rate Limiter

@MainActor
class RateLimiter: ObservableObject {
    
    private let capacity: Int
    private let refillInterval: TimeInterval
    private let maxConcurrent: Int
    
    private var tokens: Int
    private var lastRefill: Date
    private var activeTasks: Int = 0
    private var backoffDelay: TimeInterval = 0.1 // Start at 100ms
    
    private let queue = DispatchQueue(label: "com.hushmap.ratelimiter", attributes: .concurrent)
    
    init(capacity: Int = 4, refillInterval: TimeInterval = 0.3, maxConcurrent: Int = 2) {
        self.capacity = capacity
        self.refillInterval = refillInterval
        self.maxConcurrent = maxConcurrent
        self.tokens = capacity
        self.lastRefill = Date()
    }
    
    func executeWithLimit<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        // Wait for available token and slot
        await waitForCapacity()
        
        activeTasks += 1
        defer { 
            Task { @MainActor in
                activeTasks -= 1
            }
        }
        
        do {
            let result = try await operation()
            
            // Success - reset backoff
            backoffDelay = 0.1
            
            return result
            
        } catch {
            // Handle network/throttling errors with exponential backoff
            if shouldApplyBackoff(for: error) {
                await applyBackoff()
            }
            throw error
        }
    }
    
    private func waitForCapacity() async {
        while true {
            await refillTokens()
            
            if tokens > 0 && activeTasks < maxConcurrent {
                tokens -= 1
                return
            }
            
            // Wait a bit before checking again
            try? await Task.sleep(nanoseconds: UInt64(refillInterval * 1_000_000_000))
        }
    }
    
    private func refillTokens() async {
        let now = Date()
        let timeSinceRefill = now.timeIntervalSince(lastRefill)
        
        if timeSinceRefill >= refillInterval {
            let tokensToAdd = Int(timeSinceRefill / refillInterval)
            tokens = min(capacity, tokens + tokensToAdd)
            lastRefill = now
        }
    }
    
    private func shouldApplyBackoff(for error: Error) -> Bool {
        // Apply backoff for network errors or when rate limited
        if let clError = error as? CLError {
            switch clError.code {
            case .network, .locationUnknown:
                return true
            default:
                return false
            }
        }
        
        // Also apply for URL session errors indicating rate limiting
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotConnectToHost, .networkConnectionLost:
                return true
            default:
                return false
            }
        }
        
        return false
    }
    
    private func applyBackoff() async {
        let jitter = Double.random(in: 0.8...1.2) // ±20% jitter
        let delayWithJitter = backoffDelay * jitter
        
        try? await Task.sleep(nanoseconds: UInt64(delayWithJitter * 1_000_000_000))
        
        // Exponential backoff with cap at 600ms
        backoffDelay = min(0.6, backoffDelay * 2)
    }
    
    // For testing - reset state
    func reset() {
        tokens = capacity
        lastRefill = Date()
        activeTasks = 0
        backoffDelay = 0.1
    }
}