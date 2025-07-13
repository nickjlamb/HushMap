import SwiftUI
import SwiftData
import CoreLocation
import GoogleMaps
import GoogleSignIn

@main
struct HushMapApp: App {
    // Add the location usage description to Info.plist
    init() {
        if Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") == nil {
            // Log the warning but don't try to modify Info.plist at runtime
            #if DEBUG
            // Warning: NSLocationWhenInUseUsageDescription not found in Info.plist
            #endif
        }
        
        // Initialize Google Maps
        GoogleMapsService.shared.configure()
        
        // Configure Google Sign In
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            #if DEBUG
            print("Warning: GoogleService-Info.plist not found or CLIENT_ID missing")
            #endif
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
    }
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome: Bool = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            Report.self,
            User.self,
            Badge.self,
            SensoryProfile.self
        ])
        
        // First try with default migration
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            #if DEBUG
            print("Error creating model container with migration: \(error)")
            #endif
            
            // If that fails, try to delete the existing store and start fresh
            // This is only appropriate for development or new apps
            do {
                #if DEBUG
                print("Attempting to recreate database...")
                #endif
                // Try to remove the existing store - this is a drastic measure
                let fileManager = FileManager.default
                let appSupportDirectory = try? fileManager.url(for: .applicationSupportDirectory, 
                                                              in: .userDomainMask, 
                                                              appropriateFor: nil, 
                                                              create: true)
                
                if let storeURL = appSupportDirectory?.appendingPathComponent("default.store") {
                    // Try to delete the old database
                    try? fileManager.removeItem(at: storeURL)
                }
                
                // Create a new configuration
                let destructiveConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                return try ModelContainer(for: schema, configurations: [destructiveConfig])
            } catch {
                #if DEBUG
                print("Destructive migration failed: \(error)")
                #endif
                
                // If that still fails, try in-memory only as a last resort
                do {
                    #if DEBUG
                    print("Falling back to in-memory store...")
                    #endif
                    let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                    return try ModelContainer(for: schema, configurations: [fallbackConfig])
                } catch {
                    #if DEBUG
                    print("⚠️ Critical: Could not create ModelContainer even with in-memory fallback: \(error)")
                    #endif
                    // Create a minimal container with no persistence as absolute last resort
                    let minimalSchema = Schema([Report.self])
                    let minimalConfig = ModelConfiguration(schema: minimalSchema, isStoredInMemoryOnly: true)
                    return try! ModelContainer(for: minimalSchema, configurations: [minimalConfig])
                }
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            if hasSeenWelcome {
                ContentView()
                    .tint(.hushBackground)
                    .sheet(isPresented: .constant(!hasCompletedOnboarding && hasSeenWelcome)) {
                        OnboardingView(isPresented: .constant(!hasCompletedOnboarding))
                    }
                    .onAppear {
                        // Import sample data if needed
                        let modelContext = sharedModelContainer.mainContext
                        CSVLoader.importSampleDataIfNeeded(into: modelContext)
                        
                        // Listen for reset welcome notification
                        NotificationCenter.default.addObserver(
                            forName: Notification.Name("ShowWelcomeScreen"),
                            object: nil,
                            queue: .main
                        ) { _ in
                            hasSeenWelcome = false
                        }
                    }
                    .onOpenURL { url in
                        GIDSignIn.sharedInstance.handle(url)
                    }
            } else {
                WelcomeView(hasSeenWelcome: $hasSeenWelcome)
                    .tint(.hushBackground)
                    .onOpenURL { url in
                        GIDSignIn.sharedInstance.handle(url)
                    }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
