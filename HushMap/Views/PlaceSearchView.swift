import SwiftUI

struct PlaceSearchView: View {
    @State private var searchText = ""
    @State private var suggestions: [PlaceSuggestion] = []
    @State private var selectedPlace: PlaceDetails?
    @State private var isLoading = false
    
    private let placeService = PlaceService()
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Search for a place...", text: $searchText)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .onChange(of: searchText) { oldValue, newValue in
                        fetchSuggestions(for: newValue)
                    }

                if isLoading {
                    ProgressView("Loading...")
                        .padding()
                }

                List(suggestions) { suggestion in
                    Button(action: {
                        fetchDetails(for: suggestion.id)
                    }) {
                        Text(suggestion.description)
                    }
                }

                if let place = selectedPlace {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("✅ Selected Place:")
                            .font(.headline)
                        Text(place.name)
                        Text(place.address)
                        Text("Lat: \(place.coordinate.latitude), Lng: \(place.coordinate.longitude)")
                    }
                    .padding()
                }
            }
            .navigationTitle("Search")
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
