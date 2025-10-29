import SwiftUI
import Combine
import CoreLocation
import Speech
import AVFoundation

struct FloatingSearchBar: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    @State private var showAutoComplete = false
    @State private var autoCompleteResults: [PlaceSuggestion] = []
    @State private var isListening = false
    @State private var isLoading = false
    @FocusState private var isSearchFieldFocused: Bool
    
    // Speech recognition properties
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var speechAuthorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    // Map integration
    var onPlaceSelected: ((CLLocationCoordinate2D, String) -> Void)?
    
    // External focus trigger
    @Binding var shouldFocus: Bool
    
    // Services
    private let placeService = PlaceService()
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("highContrastMode") private var highContrastMode = false
    
    var backgroundColor: Color {
        if highContrastMode {
            return .hushOffWhite
        } else {
            return colorScheme == .dark ? Color(UIColor.systemBackground) : Color.hushOffWhite
        }
    }
    
    var textColor: Color {
        if highContrastMode {
            return .hushPrimaryText
        } else {
            return colorScheme == .dark ? Color.hushOffWhite : Color.hushPrimaryText
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main search bar
            HStack(spacing: 12) {
                // Search icon
                Image(systemName: "magnifyingglass")
                    .font(.hushHeadline)
                    .foregroundColor(textColor.opacity(0.6))
                
                // Search text field
                TextField("Search places...", text: $searchText)
                    .font(.hushBody)
                    .foregroundColor(textColor)
                    .textFieldStyle(.plain)
                    .focused($isSearchFieldFocused)
                    .onTapGesture {
                        isSearching = true
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAutoComplete = !searchText.isEmpty
                        }
                    }
                    .onChange(of: searchText) { _, newValue in
                        handleSearchTextChange(newValue)
                    }
                    .onChange(of: shouldFocus) { _, newValue in
                        if newValue {
                            isSearchFieldFocused = true
                            isSearching = true
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showAutoComplete = !searchText.isEmpty
                            }
                            // Reset the trigger
                            DispatchQueue.main.async {
                                shouldFocus = false
                            }
                        }
                    }
                
                // Voice input button
                Button(action: {
                    toggleVoiceInput()
                }) {
                    Image(systemName: isListening ? "mic.fill" : "mic")
                        .font(.hushHeadline)
                        .foregroundColor(isListening ? .hushBackground : textColor.opacity(0.6))
                        .scaleEffect(isListening ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isListening)
                }
                .accessibilityLabel(isListening ? "Stop voice input" : "Start voice input")
                
                // Clear button (when there's text)
                if !searchText.isEmpty {
                    Button(action: {
                        clearSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.hushHeadline)
                            .foregroundColor(textColor.opacity(0.6))
                    }
                    .accessibilityLabel("Clear search")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 44) // Accessibility touch target
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
            )
            
            // Auto-complete dropdown
            if showAutoComplete && (!autoCompleteResults.isEmpty || isLoading) {
                VStack(spacing: 0) {
                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Searching...")
                                .font(.hushBody)
                                .foregroundColor(textColor.opacity(0.6))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(minHeight: 44)
                    } else {
                        ForEach(autoCompleteResults) { suggestion in
                            AutoCompleteRow(
                                text: suggestion.description,
                                backgroundColor: backgroundColor,
                                textColor: textColor
                            ) {
                                selectAutoCompleteResult(suggestion)
                            }
                            
                            if suggestion.id != autoCompleteResults.last?.id {
                                Divider()
                                    .padding(.leading, 48)
                            }
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(backgroundColor)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                )
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showAutoComplete)
        .onAppear {
            requestSpeechAuthorization()
        }
    }
    
    // MARK: - Private Methods
    
    private func handleSearchTextChange(_ text: String) {
        if text.isEmpty {
            withAnimation(.easeInOut(duration: 0.2)) {
                showAutoComplete = false
                autoCompleteResults = []
                isLoading = false
            }
        } else if text.count >= 2 {
            // Show loading state and fetch real autocomplete results
            withAnimation(.easeInOut(duration: 0.2)) {
                showAutoComplete = true
                isLoading = true
            }
            
            fetchAutoCompleteResults(for: text)
        }
    }
    
    private func fetchAutoCompleteResults(for query: String) {
        placeService.fetchAutocomplete(for: query) { suggestions in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.autoCompleteResults = suggestions
                    self.isLoading = false
                }
            }
        }
    }
    
    private func selectAutoCompleteResult(_ suggestion: PlaceSuggestion) {
        searchText = suggestion.description
        withAnimation(.easeInOut(duration: 0.2)) {
            showAutoComplete = false
            isLoading = false
        }
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Fetch place details and navigate to location
        fetchPlaceDetailsAndNavigate(suggestion)
    }
    
    private func fetchPlaceDetailsAndNavigate(_ suggestion: PlaceSuggestion) {
        placeService.fetchPlaceDetails(placeId: suggestion.id) { placeDetails in
            DispatchQueue.main.async {
                if let details = placeDetails {
                    // Navigate map to the selected location
                    self.onPlaceSelected?(details.coordinate, details.name)
                    
                    // Dismiss keyboard and search
                    self.dismissSearch()
                } else {
                    // Handle error - could show an alert or retry
                    print("Failed to fetch place details for: \(suggestion.description)")
                }
            }
        }
    }
    
    private func dismissSearch() {
        withAnimation(.easeInOut(duration: 0.2)) {
            searchText = ""
            showAutoComplete = false
            isSearching = false
            autoCompleteResults = []
            isLoading = false
        }
        
        // Dismiss keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func clearSearch() {
        dismissSearch()
    }
    
    private func toggleVoiceInput() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isListening.toggle()
        }
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        if isListening {
            startVoiceRecognition()
        } else {
            stopVoiceRecognition()
        }
    }
    
    private func startVoiceRecognition() {
        // Check authorization
        guard speechAuthorizationStatus == .authorized else {
            print("Speech recognition not authorized")
            stopListening()
            return
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognizer not available")
            stopListening()
            return
        }
        
        // Cancel previous task if running
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to configure audio session: \(error)")
            stopListening()
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            stopListening()
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            recognitionRequest.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
            stopListening()
            return
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            DispatchQueue.main.async {
                if let result = result {
                    let recognizedText = result.bestTranscription.formattedString
                    searchText = recognizedText
                    
                    if result.isFinal {
                        stopVoiceRecognition()
                        handleSearchTextChange(recognizedText)
                    }
                }
                
                if let error = error {
                    print("Speech recognition error: \(error)")
                    stopVoiceRecognition()
                }
            }
        }
    }
    
    private func stopVoiceRecognition() {
        // Stop audio engine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // Cancel recognition request and task
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Reset audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
        
        stopListening()
    }
    
    private func stopListening() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isListening = false
        }
    }
    
    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                speechAuthorizationStatus = authStatus
            }
        }
    }
    
}

struct AutoCompleteRow: View {
    let text: String
    let backgroundColor: Color
    let textColor: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle")
                    .font(.hushHeadline)
                    .foregroundColor(.hushBackground)
                    .frame(width: 24, height: 24)
                
                Text(text)
                    .font(.hushBody)
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "arrow.up.left")
                    .font(.caption)
                    .foregroundColor(textColor.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 44) // Accessibility touch target
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select \(text)")
    }
}

#Preview {
    VStack {
        FloatingSearchBar(
            searchText: .constant(""),
            isSearching: .constant(false),
            shouldFocus: .constant(false)
        )
        .padding()
        
        Spacer()
    }
    .background(Color.hushCream)
}