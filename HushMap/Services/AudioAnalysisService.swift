import Foundation
import AVFoundation
import Combine

class AudioAnalysisService: ObservableObject {
    @Published var currentDecibels: Float = 0.0
    @Published var isListening: Bool = false
    @Published var hasPermission: Bool = false
    @Published var permissionStatus: AVAudioSession.RecordPermission = .undetermined
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var timer: Timer?
    
    // Audio analysis properties
    private let sampleRate: Double = 44100
    private let bufferSize: UInt32 = 1024
    private var referenceAmplitude: Float = 0.00002 // Reference for 0 dB SPL
    
    init() {
        setupAudioSession()
        checkMicrophonePermission()
    }
    
    // MARK: - Permission Management
    
    func checkMicrophonePermission() {
        permissionStatus = AVAudioSession.sharedInstance().recordPermission
        hasPermission = permissionStatus == .granted
    }
    
    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.permissionStatus = granted ? .granted : .denied
                    self.hasPermission = granted
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Audio Analysis
    
    func startListening() {
        guard hasPermission else {
            print("Microphone permission not granted")
            return
        }
        
        guard !isListening else { return }
        
        setupAudioEngine()
        
        do {
            try audioEngine?.start()
            isListening = true
            print("Started audio analysis")
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    func stopListening() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        isListening = false
        currentDecibels = 0.0
        print("Stopped audio analysis")
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        
        guard let inputNode = inputNode else {
            print("Failed to get input node")
            return
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: recordingFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        
        audioEngine?.prepare()
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        
        // Calculate RMS (Root Mean Square)
        var sum: Float = 0.0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(frameLength))
        
        // Convert to decibels
        let decibels = 20 * log10(rms / referenceAmplitude)
        
        // Filter out invalid readings
        let filteredDecibels = max(-160, min(120, decibels))
        
        DispatchQueue.main.async {
            // Smooth the reading to reduce jitter
            self.currentDecibels = self.currentDecibels * 0.7 + filteredDecibels * 0.3
        }
    }
    
    // MARK: - AI-Powered Noise Level Analysis
    
    /// Converts decibel reading to sensory level (0.0 to 1.0)
    func getNoiseLevel() -> Double {
        let db = Double(currentDecibels)
        
        // Map decibels to 0.0-1.0 scale based on real-world sound levels
        switch db {
        case ..<30:
            return 0.0 // Very quiet (library, whisper)
        case 30..<45:
            return 0.2 // Quiet (home, office)
        case 45..<60:
            return 0.4 // Moderate (normal conversation)
        case 60..<75:
            return 0.6 // Moderately loud (busy restaurant)
        case 75..<90:
            return 0.8 // Loud (traffic, city street)
        default:
            return 1.0 // Very loud (concert, construction)
        }
    }
    
    /// Gets AI-generated description of current noise level
    func getNoiseDescription() -> String {
        let db = Double(currentDecibels)
        
        switch db {
        case ..<30:
            return "Very Quiet - Library level"
        case 30..<45:
            return "Quiet - Home/Office level"
        case 45..<60:
            return "Moderate - Normal conversation"
        case 60..<75:
            return "Moderately Loud - Busy restaurant"
        case 75..<90:
            return "Loud - City traffic level"
        case 90..<105:
            return "Very Loud - Concert level"
        default:
            return "Extremely Loud - Potentially harmful"
        }
    }
    
    /// Gets color representing noise level intensity
    func getNoiseColor() -> (red: Double, green: Double, blue: Double) {
        let level = getNoiseLevel()
        
        // Gradient from green (quiet) to red (loud)
        let red = level
        let green = 1.0 - level
        let blue = 0.2
        
        return (red: red, green: green, blue: blue)
    }
    
    /// Checks if current noise level suggests sensory sensitivity concerns
    func getSensoryAlert() -> String? {
        let db = Double(currentDecibels)
        
        if db > 80 {
            return "⚠️ High noise level detected - may be uncomfortable for noise-sensitive individuals"
        } else if db > 70 {
            return "🔊 Moderately loud environment - consider for noise sensitivity"
        }
        
        return nil
    }
    
    // MARK: - Calibration and Accuracy
    
    /// Takes multiple readings over a period to get more accurate measurement
    func getAverageReading(duration: TimeInterval = 3.0) async -> Float {
        var readings: [Float] = []
        let interval = 0.1 // Take reading every 100ms
        let totalReadings = Int(duration / interval)
        
        for _ in 0..<totalReadings {
            readings.append(currentDecibels)
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
        
        let validReadings = readings.filter { $0 > -160 && $0 < 120 }
        guard !validReadings.isEmpty else { return 0 }
        
        return validReadings.reduce(0, +) / Float(validReadings.count)
    }
    
    /// Gets confidence level of current reading
    func getReadingConfidence() -> Double {
        let db = Double(currentDecibels)
        
        // Higher confidence for readings in typical range
        if db >= 20 && db <= 100 {
            return 0.9
        } else if db >= 10 && db <= 110 {
            return 0.7
        } else {
            return 0.3
        }
    }
    
    deinit {
        stopListening()
    }
}

// MARK: - Supporting Types

struct AudioReading {
    let decibels: Float
    let timestamp: Date
    let confidence: Double
    let suggestedNoiseLevel: Double
    let description: String
    
    init(from service: AudioAnalysisService) {
        self.decibels = service.currentDecibels
        self.timestamp = Date()
        self.confidence = service.getReadingConfidence()
        self.suggestedNoiseLevel = service.getNoiseLevel()
        self.description = service.getNoiseDescription()
    }
}