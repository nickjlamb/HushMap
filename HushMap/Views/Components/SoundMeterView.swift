import SwiftUI

struct SoundMeterView: View {
    @ObservedObject var audioService: AudioAnalysisService
    @State private var animationOffset: CGFloat = 0
    @State private var isAnimating: Bool = false
    
    let height: CGFloat = 60
    let cornerRadius: CGFloat = 8
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with microphone icon and title
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(audioService.isListening ? .green : .gray)
                    .font(.title2)
                
                Text("AI Sound Meter")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if audioService.isListening {
                    Text("\(Int(audioService.currentDecibels))dB")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .monospacedDigit()
                }
            }
            
            // Sound level visualization
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: height)
                
                // Animated background pattern
                if audioService.isListening {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: height)
                        .offset(x: animationOffset)
                        .clipped()
                }
                
                // Sound level indicator
                GeometryReader { geometry in
                    let level = max(0, min(1, audioService.getNoiseLevel()))
                    let width = geometry.size.width * CGFloat(level)
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.green,
                                    Color.yellow,
                                    Color.orange,
                                    Color.red
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width, height: height)
                        .animation(.easeInOut(duration: 0.3), value: level)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                
                // Sound wave animation overlay
                if audioService.isListening {
                    HStack(spacing: 2) {
                        ForEach(0..<20, id: \.self) { index in
                            SoundWaveBar(
                                height: height,
                                animationDelay: Double(index) * 0.1,
                                isActive: audioService.isListening
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                // Decibel scale markers
                HStack {
                    ForEach([30, 45, 60, 75, 90], id: \.self) { db in
                        VStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.6))
                                .frame(width: 1, height: height * 0.3)
                            
                            Text("\(db)")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        if db != 90 { Spacer() }
                    }
                }
                .padding(.horizontal, 8)
            }
            
            // AI description and controls
            VStack(spacing: 8) {
                if audioService.isListening {
                    Text(audioService.getNoiseDescription())
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    if let alert = audioService.getSensoryAlert() {
                        Text(alert)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                
                // Control buttons
                HStack(spacing: 16) {
                    if !audioService.hasPermission {
                        Button("Enable Microphone") {
                            Task {
                                await audioService.requestMicrophonePermission()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.hushBackground)
                    } else {
                        Button(audioService.isListening ? "Stop" : "Start Listening") {
                            if audioService.isListening {
                                audioService.stopListening()
                            } else {
                                audioService.startListening()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(audioService.isListening ? .red : .green)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .onAppear {
            audioService.checkMicrophonePermission()
            startAnimation()
        }
        .onChange(of: audioService.isListening) { _, isListening in
            if isListening {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }
    
    private func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            animationOffset = 100
        }
    }
    
    private func stopAnimation() {
        isAnimating = false
        withAnimation(.easeOut(duration: 0.3)) {
            animationOffset = 0
        }
    }
}

struct SoundWaveBar: View {
    let height: CGFloat
    let animationDelay: Double
    let isActive: Bool
    
    @State private var barHeight: CGFloat = 2
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.white.opacity(0.6))
            .frame(width: 2, height: barHeight)
            .animation(
                isActive ? 
                    .easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true)
                    .delay(animationDelay) : 
                    .easeOut(duration: 0.2),
                value: barHeight
            )
            .onAppear {
                if isActive {
                    barHeight = CGFloat.random(in: 2...(height * 0.8))
                }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    barHeight = CGFloat.random(in: 2...(height * 0.8))
                } else {
                    barHeight = 2
                }
            }
    }
}

// Compact version for inline use
struct CompactSoundMeter: View {
    @ObservedObject var audioService: AudioAnalysisService
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "mic.fill")
                .foregroundColor(audioService.isListening ? .green : .gray)
                .font(.caption)
            
            if audioService.isListening {
                // Mini sound level bar
                GeometryReader { geometry in
                    let level = max(0, min(1, audioService.getNoiseLevel()))
                    let width = geometry.size.width * CGFloat(level)
                    
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.green)
                            .frame(width: width)
                            .animation(.easeInOut(duration: 0.3), value: level)
                    }
                }
                .frame(height: 6)
                
                Text("\(Int(audioService.currentDecibels))dB")
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()
            } else {
                Text("Tap to measure")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.1))
        )
        .onTapGesture {
            if audioService.hasPermission {
                if audioService.isListening {
                    audioService.stopListening()
                } else {
                    audioService.startListening()
                }
            } else {
                Task {
                    await audioService.requestMicrophonePermission()
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SoundMeterView(audioService: AudioAnalysisService())
        CompactSoundMeter(audioService: AudioAnalysisService())
    }
    .padding()
}