import Foundation

enum MarkerStyleMode {
    case googleDefault
    case custom
}

struct MarkerStyleConfig {
    static var mode: MarkerStyleMode = .googleDefault  // Default to Google pins
    
    #if DEBUG
    // Quick debug helper to toggle between modes
    static func toggleMode() {
        mode = (mode == .googleDefault) ? .custom : .googleDefault
        print("🎯 MarkerStyleConfig switched to: \(mode)")
    }
    #endif
}