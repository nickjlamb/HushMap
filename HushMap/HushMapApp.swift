import SwiftUI
import SwiftData
import CoreLocation
import GoogleMaps
import GoogleSignIn
import FirebaseCore
import FirebaseFirestore

@main
struct HushMapApp: App {
    @State private var reportsListener: ListenerRegistration?

    // Add the location usage description to Info.plist
    init() {
        if Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") == nil {
            // Log the warning but don't try to modify Info.plist at runtime
            #if DEBUG
            // Warning: NSLocationWhenInUseUsageDescription not found in Info.plist
            #endif
        }

        // Initialize Firebase
        FirebaseApp.configure()

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
            SensoryProfile.self,
            QuickUpdate.self
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
                    do {
                        return try ModelContainer(for: minimalSchema, configurations: [minimalConfig])
                    } catch {
                        // If even this fails, crash with descriptive error for debugging
                        fatalError("Failed to create minimal ModelContainer. This should never happen. Error: \(error.localizedDescription)")
                    }
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

                        // Configure Watch connectivity
                        WatchConnectivityService.shared.configure(modelContext: modelContext)

                        // Download community reports from Firestore (initial load)
                        Task {
                            do {
                                let syncService = ReportSyncService.shared
                                let downloadedCount = try await syncService.downloadReports(to: modelContext)
                                print("✅ Downloaded \(downloadedCount) community reports from Firestore")
                            } catch {
                                print("⚠️ Failed to download community reports: \(error.localizedDescription)")
                            }
                        }

                        // Set up real-time listener for new reports
                        let firestoreService = FirestoreService.shared
                        reportsListener = firestoreService.listenToReports { firestoreReports in
                            Task { @MainActor in
                                // Get existing report IDs to avoid duplicates
                                let descriptor = FetchDescriptor<Report>()
                                guard let existingReports = try? modelContext.fetch(descriptor) else { return }
                                let existingIds = Set(existingReports.map { $0.id.uuidString })

                                var newCount = 0
                                // Import new reports
                                for firestoreReport in firestoreReports {
                                    if !existingIds.contains(firestoreReport.id) {
                                        let report = firestoreReport.toReport()
                                        modelContext.insert(report)
                                        newCount += 1
                                    }
                                }

                                if newCount > 0 {
                                    try? modelContext.save()
                                    print("🔄 Real-time sync: Added \(newCount) new reports")
                                }
                            }
                        }

                        // Listen for reset welcome notification
                        NotificationCenter.default.addObserver(
                            forName: Notification.Name("ShowWelcomeScreen"),
                            object: nil,
                            queue: .main
                        ) { _ in
                            hasSeenWelcome = false
                        }
                    }
                    .task {
                        // TEMPORARILY DISABLED: Migration causes 2min UI freeze
                        // The migration runs synchronously on @MainActor and blocks SwiftData
                        // This needs to be refactored to run truly async before re-enabling

                        // Delay migration significantly to allow full map interaction first
                        // User can use app normally, then migration runs in background
                        try? await Task.sleep(for: .seconds(60))

                        // Run background migration for unresolved reports
                        let modelContext = sharedModelContainer.mainContext
                        let reportStore = SwiftDataReportStore(modelContext: modelContext)
                        let cacheStore: LocationLabelCacheStore = (try? DiskLocationLabelCacheStore()) ?? InMemoryLocationLabelCacheStore()
                        let resolver = ReportLocationResolver()

                        _ = AppStartMigrator(
                            resolver: resolver,
                            store: reportStore,
                            cacheStore: cacheStore
                        )
                        // UNCOMMENT when migration is refactored to be truly async
                        // migrator.runIfNeeded()
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
