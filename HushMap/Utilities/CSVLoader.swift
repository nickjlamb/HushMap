import Foundation
import SwiftData
import CoreLocation

// CSV Data Loader utility for importing sample data
class CSVLoader {
    /// Load reports from a CSV file in the app bundle
    /// - Parameter filename: Name of the CSV file (without extension)
    /// - Returns: Array of Report objects
    static func loadReports(from filename: String = "default") -> [Report] {
        // Get the URL to the CSV resource
        guard let url = Bundle.main.url(forResource: filename, withExtension: "csv") else {
            print("⚠️ Could not find \(filename).csv in the app bundle")
            // Debug info
            print("📁 App bundle path: \(Bundle.main.bundlePath)")
            let csvFiles = Bundle.main.paths(forResourcesOfType: "csv", inDirectory: nil)
            print("📄 CSV files in bundle: \(csvFiles)")
            
            return createSampleReports() // Return hardcoded samples instead
        }
        
        print("✅ Found CSV file: \(url.path)")
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let rows = content.components(separatedBy: .newlines)
            
            // Skip header row
            let dataRows = rows.dropFirst()
            
            var reports: [Report] = []
            
            for row in dataRows where !row.isEmpty {
                let columns = row.components(separatedBy: ",")
                
                // Ensure we have all required fields
                guard columns.count >= 8,
                      let latitude = Double(columns[2]),
                      let longitude = Double(columns[3]),
                      let noise = Double(columns[4]),
                      let crowds = Double(columns[5]),
                      let lighting = Double(columns[6]) else {
                    continue
                }
                
                // Parse timestamp or use current date
                let dateFormatter = ISO8601DateFormatter()
                let timestamp = dateFormatter.date(from: columns[7]) ?? Date()
                
                // Get comments (handling quoted text with commas)
                let comments: String
                if columns.count > 8 {
                    // Handle quoted comments that might contain commas
                    if columns[8].hasPrefix("\"") {
                        // Find the closing quote
                        let joinedRemainder = columns[8...].joined(separator: ",")
                        if let endQuoteIndex = joinedRemainder.lastIndex(of: "\"") {
                            comments = String(joinedRemainder[joinedRemainder.index(after: joinedRemainder.startIndex)..<endQuoteIndex])
                        } else {
                            comments = columns[8].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                        }
                    } else {
                        comments = columns[8]
                    }
                } else {
                    comments = ""
                }
                
                // Create report
                let report = Report(
                    noise: noise,
                    crowds: crowds,
                    lighting: lighting,
                    comfort: 0.7, // Default comfort for sample data
                    comments: comments,
                    latitude: latitude,
                    longitude: longitude,
                    timestamp: timestamp
                )
                
                reports.append(report)
            }
            
            return reports
        } catch {
            print("⚠️ Error loading CSV data: \(error.localizedDescription)")
            return createSampleReports()
        }
    }
    
    /// Create hardcoded sample reports in case CSV loading fails
    private static func createSampleReports() -> [Report] {
        print("📊 Creating hardcoded sample reports")
        return [
            Report(
                noise: 0.2,
                crowds: 0.3,
                lighting: 0.5,
                comfort: 0.9, // High comfort for quiet study environment
                comments: "Very quiet environment, perfect for studying",
                latitude: 37.7749,
                longitude: -122.4194,
                timestamp: Date().addingTimeInterval(-86400 * 7) // One week ago
            ),
            Report(
                noise: 0.5,
                crowds: 0.6,
                lighting: 0.9,
                comfort: 0.6, // Moderate comfort for busy but nice space
                comments: "Nice open space, moderate crowd on weekends",
                latitude: 37.7694,
                longitude: -122.4862,
                timestamp: Date().addingTimeInterval(-86400 * 3) // Three days ago
            ),
            Report(
                noise: 0.3,
                crowds: 0.5,
                lighting: 0.4,
                comfort: 0.8, // High comfort for good morning spot
                comments: "Good morning spot, gets busier after lunch",
                latitude: 37.7849,
                longitude: -122.4094,
                timestamp: Date().addingTimeInterval(-86400) // Yesterday
            )
        ]
    }
    
    /// Import sample data into the model context if needed
    /// - Parameter modelContext: The SwiftData model context
    static func importSampleDataIfNeeded(into modelContext: ModelContext) {
        // Check if we already have data
        let descriptor = FetchDescriptor<Report>()
        let existingReportCount: Int
        
        do {
            existingReportCount = try modelContext.fetchCount(descriptor)
        } catch {
            print("Error fetching report count: \(error)")
            existingReportCount = 0
        }
        
        // If no existing data, import sample data
        if existingReportCount == 0 {
            print("Importing sample data...")
            let sampleReports = loadReports()
            
            // Create a default user if needed
            let userDescriptor = FetchDescriptor<User>()
            let userExists: Bool
            
            do {
                userExists = try modelContext.fetchCount(userDescriptor) > 0
            } catch {
                userExists = false
            }
            
            var currentUser: User
            
            if !userExists {
                currentUser = User(name: "Default User")
                modelContext.insert(currentUser)
            } else {
                do {
                    currentUser = try modelContext.fetch(userDescriptor).first!
                } catch {
                    // Fallback
                    currentUser = User(name: "Default User")
                    modelContext.insert(currentUser)
                }
            }
            
            // Add sample reports to the user
            for report in sampleReports {
                report.user = currentUser
                currentUser.reports.append(report)
                modelContext.insert(report)
            }
            
            // Save changes
            do {
                try modelContext.save()
                print("Successfully imported \(sampleReports.count) sample reports")
            } catch {
                print("Error saving sample data: \(error)")
            }
        }
    }
}