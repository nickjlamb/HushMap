import SwiftUI
import CoreLocation 
// TempPinView is used to show the temporary pin on the map

struct TempPinView: View {
    let place: PlaceDetails
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.hushBackground)
                .frame(width: 28, height: 28)
            
            Circle()
                .fill(Color.hushPinFace)
                .frame(width: 20, height: 20)
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.hushBackground)
        }
        .shadow(radius: 2)
        .accessibilityLabel("Selected place: \(place.name)")
    }
}

#Preview {
    TempPinView(
        place: PlaceDetails(
            name: "The Quiet Café",
            address: "123 Main St",
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        )
    )
}