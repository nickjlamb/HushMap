import SwiftUI

struct PlaceSearchViewWrapper: View {
    var onPlaceSelected: (PlaceDetails) -> Void
    
    @State private var searchText = ""
    @State private var suggestions: [PlaceSuggestion] = []
    @State private var selectedPlace: PlaceDetails?
    @State private var isLoading = false
    @FocusState private var isSearchFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    private let placeService = PlaceService()
    
    var body: some View {
        NavigationView {
            VStack {
                // Search field
                TextField("Search for a place...", text: $searchText)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .onChange(of: searchText) { oldValue, newValue in
                        if newValue.count >= 2 { // Start search after 2+ characters
                            fetchSuggestions(for: newValue)
                        } else if newValue.isEmpty {
                            suggestions = [] // Clear suggestions if text is cleared
                        }
                    }
                    .onSubmit {
                        // Also search when submit/return is pressed
                        if !searchText.isEmpty {
                            fetchSuggestions(for: searchText)
                        }
                    }
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($isSearchFieldFocused)
                    .accessibilityLabel("Search for places")
                
                if isLoading {
                    ProgressView("Loading...")
                        .padding()
                }
                
                // Suggestions list
                if suggestions.isEmpty && !searchText.isEmpty && !isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        
                        Text("Type more characters to start searching")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(10)
                    .padding()
                } else {
                    List(suggestions) { suggestion in
                        Button(action: {
                            fetchDetails(for: suggestion.id)
                        }) {
                            HStack {
                                Image(systemName: "mappin")
                                    .foregroundColor(.hushBackground)
                                    .frame(width: 24)
                                
                                Text(suggestion.description)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.white)
                }
                
                // Selected place card
                if let place = selectedPlace {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Selected Place")
                            .font(.headline)
                            .padding(.bottom, 2)
                        
                        Text(place.name)
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text(place.address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Button(action: {
                                onPlaceSelected(place)
                            }) {
                                Text("Select this Place")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.hushBackground)
                            
                            Button(action: {
                                selectedPlace = nil
                            }) {
                                Text("Clear")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.hushBackground)
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Find a Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Auto-focus the search field when the view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isSearchFieldFocused = true
                }
            }
        }
    }
    
    private func fetchSuggestions(for input: String) {
        guard !input.isEmpty else {
            suggestions = []
            return
        }
        
        isLoading = true
        placeService.fetchAutocomplete(for: input) { results in
            self.suggestions = results
            self.isLoading = false
        }
    }
    
    private func fetchDetails(for placeID: String) {
        isLoading = true
        placeService.fetchPlaceDetails(for: placeID) { details in
            self.selectedPlace = details
            self.isLoading = false
        }
    }
}

#Preview {
    PlaceSearchViewWrapper { place in
        print("Selected place: \(place.name)")
    }
}