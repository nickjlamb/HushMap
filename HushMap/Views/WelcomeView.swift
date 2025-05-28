import SwiftUI
import CoreLocation

struct WelcomeView: View {
    @Binding var hasSeenWelcome: Bool
    @State private var allowLocation: Bool = true
    @StateObject private var locationManager = HushLocationManager()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [.white, .hushBackground.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: dynamicTypeSize >= .accessibility1 ? 32 : 24) {
                Spacer()

                Image("HushMapIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .hushBackground.opacity(0.3), radius: 10, x: 0, y: 5)

                Text("Welcome to HushMap")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.hushBackground)
                    .multilineTextAlignment(.center)

                Text("Find and share quieter, more comfortable spaces for people sensitive to noise, crowds, and lighting.")
                    .font(.body)
                    .foregroundColor(.primary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)

                Toggle("Allow Location Access", isOn: $allowLocation)
                    .padding(.horizontal)
                    .toggleStyle(SwitchToggleStyle(tint: .hushBackground))
                    .accessibilityLabel("Toggle location permission")

                // Optional sign-in section
                VStack(spacing: 12) {
                    Text("Optional: Sign in to sync your data across devices")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    CompactSignInView()
                        .padding(.horizontal)
                    
                    Text("You can always sign in later or use the app without an account")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                Button("Get Started") {
                    if allowLocation {
                        locationManager.requestLocationPermission()
                    }
                    hasSeenWelcome = true
                }
                .bold()
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.hushBackground)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: .hushBackground.opacity(0.3), radius: 5, x: 0, y: 3)
                .padding()
            }
            .padding()
        }
    }
}

class HushLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestLocationPermission() {
        manager.requestWhenInUseAuthorization()
    }
}
