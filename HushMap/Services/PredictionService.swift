import Foundation
import CoreLocation
import SwiftData

class PredictionService {
    private let modelContext: ModelContext?
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }
    
    // Method to generate prediction from Place Details (for integration with map search)
    func generateSensoryPrediction(for place: PlaceDetails, time: Date, weather: String, userReportsSummary: String) -> VenuePredictionResponse {
        // Extract day of week and time of day
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE" // Full day name
        let dayOfWeek = dateFormatter.string(from: time)
        
        dateFormatter.dateFormat = "h:mm a"
        let timeOfDay = dateFormatter.string(from: time)
        
        // Create prediction request
        let request = VenuePredictionRequest(
            venueName: place.name,
            venueType: inferVenueType(from: place.name),
            location: place.address,
            dayOfWeek: dayOfWeek,
            timeOfDay: timeOfDay,
            weather: weather,
            userReportsSummary: userReportsSummary
        )
        
        // Generate prediction using existing method with coordinate
        var prediction = generatePrediction(for: request, coordinate: place.coordinate, targetTime: time)
        
        // Add the coordinate information
        prediction.coordinate = place.coordinate
        
        return prediction
    }
    
    // Infer venue type from name (would be replaced with actual data from the Places API)
    private func inferVenueType(from name: String) -> String {
        let lowercaseName = name.lowercased()
        
        // Transport hubs - highest priority as they're most impactful
        if lowercaseName.contains("station") || lowercaseName.contains("terminal") || 
           lowercaseName.contains("airport") || lowercaseName.contains("tube") || 
           lowercaseName.contains("underground") || lowercaseName.contains("metro") ||
           lowercaseName.contains("king's cross") || lowercaseName.contains("kings cross") ||
           lowercaseName.contains("paddington") || lowercaseName.contains("victoria") ||
           lowercaseName.contains("waterloo") || lowercaseName.contains("liverpool street") {
            return "Transport Hub"
        } else if lowercaseName.contains("café") || lowercaseName.contains("cafe") || lowercaseName.contains("coffee") {
            return "Café"
        } else if lowercaseName.contains("library") || lowercaseName.contains("bookstore") {
            return "Library"
        } else if lowercaseName.contains("park") || lowercaseName.contains("garden") {
            return "Park"
        } else if lowercaseName.contains("museum") || lowercaseName.contains("gallery") {
            return "Museum"
        } else if lowercaseName.contains("restaurant") || lowercaseName.contains("diner") {
            return "Restaurant"
        } else if lowercaseName.contains("shop") || lowercaseName.contains("store") || lowercaseName.contains("mall") {
            return "Shopping Mall"
        } else if lowercaseName.contains("cinema") || lowercaseName.contains("theater") || lowercaseName.contains("theatre") {
            return "Cinema"
        } else if lowercaseName.contains("gym") || lowercaseName.contains("fitness") {
            return "Gym"
        } else if lowercaseName.contains("bar") || lowercaseName.contains("pub") {
            return "Bar"
        }
        
        return "Other"
    }
    
    // Generate a sensory prediction for a venue
    func generatePrediction(for request: VenuePredictionRequest, coordinate: CLLocationCoordinate2D? = nil, targetTime: Date? = nil) -> VenuePredictionResponse {
        // In a real implementation, this would call an API
        // For now, we'll use rule-based logic to mimic AI predictions
        
        // Create normalized factors
        let (noiseFactor, crowdFactor, lightingFactor) = analyzeVenueType(request.venueType)
        let (timeNoiseFactor, timeCrowdFactor) = analyzeTimeFactors(request.dayOfWeek, request.timeOfDay)
        let (weatherNoiseFactor, weatherCrowdFactor) = analyzeWeatherFactors(request.weather)
        
        // Get real user reports from database (highest priority)
        let realReportData: (noise: Double, crowd: Double, lighting: Double, confidence: ConfidenceLevel)
        if let coordinate = coordinate, let targetTime = targetTime {
            realReportData = analyzeRealUserReports(for: coordinate, time: targetTime)
        } else {
            realReportData = (0.0, 0.0, 0.0, .low) // No coordinate provided
        }
        
        // Process user reports for more specific information (text-based)
        let textReportFactors = analyzeUserReports(request.userReportsSummary)
        
        // Combine real database reports with text reports (real reports take priority)
        let combinedUserReports = combineUserReportData(realReportData, textReportFactors)
        
        // Combined analysis with venue-specific time adjustments
        let (adjustedTimeNoiseFactor, adjustedTimeCrowdFactor) = adjustTimeFactorsForVenue(request.venueType, timeNoiseFactor, timeCrowdFactor)
        let noiseLevelValue = calculateFinalFactor(noiseFactor, adjustedTimeNoiseFactor, weatherNoiseFactor, combinedUserReports.noise)
        let crowdLevelValue = calculateFinalFactor(crowdFactor, adjustedTimeCrowdFactor, weatherCrowdFactor, combinedUserReports.crowd)
        let lightingLevelValue = combinedUserReports.lighting != 0 ? combinedUserReports.lighting : lightingFactor
        
        // Convert to sensory levels
        let noiseLevel = convertToSensoryLevel(noiseLevelValue)
        let crowdLevel = convertToSensoryLevel(crowdLevelValue)
        let lightingLevel = convertToLightingLevel(lightingLevelValue)
        
        // Generate a natural language summary
        let summary = generateSummary(request, noiseLevel, crowdLevel, lightingLevel)
        
        // Determine confidence level based on the quality of input data and real reports
        let confidence = determineConfidenceLevel(request, realDataConfidence: realReportData.confidence)
        
        return VenuePredictionResponse.create(
            summary: summary,
            noiseLevel: noiseLevel,
            crowdLevel: crowdLevel,
            lightingLevel: lightingLevel,
            confidence: confidence
        )
    }
    
    // Query nearby user reports from the database
    private func getNearbyReports(for coordinate: CLLocationCoordinate2D, radius: Double = 500.0) -> [Report] {
        guard let modelContext = modelContext else { return [] }
        
        do {
            // Fetch all reports (we'll filter by distance in memory for simplicity)
            let descriptor = FetchDescriptor<Report>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)] // Most recent first
            )
            let allReports = try modelContext.fetch(descriptor)
            
            // Filter by distance
            let nearbyReports = allReports.filter { report in
                let distance = distanceBetween(coordinate, report.coordinate)
                return distance <= radius
            }
            
            return nearbyReports
        } catch {
            print("Error fetching reports: \(error)")
            return []
        }
    }
    
    // Calculate distance between two coordinates in meters
    private func distanceBetween(_ coord1: CLLocationCoordinate2D, _ coord2: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return location1.distance(from: location2)
    }
    
    // Analyze real user reports for this location and time
    private func analyzeRealUserReports(for coordinate: CLLocationCoordinate2D, time: Date) -> (noise: Double, crowd: Double, lighting: Double, confidence: ConfidenceLevel) {
        let nearbyReports = getNearbyReports(for: coordinate)
        
        if nearbyReports.isEmpty {
            return (0.0, 0.0, 0.0, .low) // No data available
        }
        
        // Filter reports by relevance
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        
        // Recent reports (last 7 days) - highest weight
        let recentReports = nearbyReports.filter { $0.timestamp >= sevenDaysAgo }
        // Medium-term reports (last 30 days) - medium weight  
        let mediumTermReports = nearbyReports.filter { $0.timestamp >= thirtyDaysAgo && $0.timestamp < sevenDaysAgo }
        // Older reports - lower weight but still useful for patterns
        let olderReports = nearbyReports.filter { $0.timestamp < thirtyDaysAgo }
        
        // Time-based filtering - same day of week and similar time
        let targetDayOfWeek = Calendar.current.component(.weekday, from: time)
        let targetHour = Calendar.current.component(.hour, from: time)
        
        let relevantReports = nearbyReports.filter { report in
            let reportDayOfWeek = Calendar.current.component(.weekday, from: report.timestamp)
            let reportHour = Calendar.current.component(.hour, from: report.timestamp)
            
            // Same day of week or within 2 hours of target time
            return reportDayOfWeek == targetDayOfWeek || abs(reportHour - targetHour) <= 2
        }
        
        // Calculate weighted averages
        var totalNoise = 0.0
        var totalCrowd = 0.0
        var totalLighting = 0.0
        var totalWeight = 0.0
        
        // Process recent reports (weight: 1.0)
        for report in recentReports {
            let weight = relevantReports.contains(where: { $0.id == report.id }) ? 1.5 : 1.0 // Bonus for time relevance
            totalNoise += report.noise * weight
            totalCrowd += report.crowds * weight
            totalLighting += report.lighting * weight
            totalWeight += weight
        }
        
        // Process medium-term reports (weight: 0.7)
        for report in mediumTermReports {
            let weight = relevantReports.contains(where: { $0.id == report.id }) ? 1.0 : 0.7
            totalNoise += report.noise * weight
            totalCrowd += report.crowds * weight
            totalLighting += report.lighting * weight
            totalWeight += weight
        }
        
        // Process older reports (weight: 0.3)
        for report in olderReports.prefix(10) { // Limit older reports to prevent over-weighting
            let weight = relevantReports.contains(where: { $0.id == report.id }) ? 0.5 : 0.3
            totalNoise += report.noise * weight
            totalCrowd += report.crowds * weight
            totalLighting += report.lighting * weight
            totalWeight += weight
        }
        
        // Calculate averages if we have data
        guard totalWeight > 0 else {
            return (0.0, 0.0, 0.0, .low)
        }
        
        let avgNoise = totalNoise / totalWeight
        let avgCrowd = totalCrowd / totalWeight
        let avgLighting = totalLighting / totalWeight
        
        // Determine confidence based on data quality
        let confidence: ConfidenceLevel
        if recentReports.count >= 5 {
            confidence = .high
        } else if nearbyReports.count >= 3 {
            confidence = .medium
        } else {
            confidence = .low
        }
        
        return (avgNoise, avgCrowd, avgLighting, confidence)
    }
    
    // Combine real database reports with text-based reports
    private func combineUserReportData(
        _ realData: (noise: Double, crowd: Double, lighting: Double, confidence: ConfidenceLevel),
        _ textData: (noise: Double, crowd: Double, lighting: Double)
    ) -> (noise: Double, crowd: Double, lighting: Double) {
        
        // If we have real data, prioritize it heavily
        if realData.noise > 0 || realData.crowd > 0 || realData.lighting > 0 {
            // Weight real data based on confidence level
            let realWeight: Double
            switch realData.confidence {
            case .high: realWeight = 0.9    // 90% real data, 10% text
            case .medium: realWeight = 0.7  // 70% real data, 30% text  
            case .low: realWeight = 0.5     // 50% real data, 50% text
            }
            
            let textWeight = 1.0 - realWeight
            
            let combinedNoise = realData.noise * realWeight + textData.noise * textWeight
            let combinedCrowd = realData.crowd * realWeight + textData.crowd * textWeight
            let combinedLighting = realData.lighting * realWeight + textData.lighting * textWeight
            
            return (combinedNoise, combinedCrowd, combinedLighting)
        } else {
            // No real data, use text data only
            return textData
        }
    }
    
    // Analyze venue type to determine baseline factors
    private func analyzeVenueType(_ venueType: String) -> (noise: Double, crowd: Double, lighting: Double) {
        switch venueType.lowercased() {
        case "transport hub":
            return (0.8, 0.8, 0.7) // Very loud announcements/trains, very crowded, bright lighting
        case "café", "cafe":
            return (0.5, 0.5, 0.4) // Moderate noise, moderate crowd, soft lighting
        case "library":
            return (0.1, 0.3, 0.5) // Very quiet, low crowd, moderate lighting
        case "restaurant":
            return (0.7, 0.7, 0.5) // Louder, crowded, moderate lighting
        case "park":
            return (0.4, 0.5, 0.0) // Moderate noise, moderate crowd, natural lighting
        case "shopping mall":
            return (0.8, 0.8, 0.7) // Loud, crowded, bright lighting
        case "museum":
            return (0.2, 0.6, 0.6) // Quiet, moderately crowded, controlled lighting
        case "cinema", "movie theater":
            return (0.3, 0.7, 0.1) // Quiet (during movie), crowded, dark
        case "gym":
            return (0.7, 0.6, 0.8) // Loud, moderately crowded, bright lighting
        case "bar", "pub":
            return (0.9, 0.8, 0.3) // Very loud, crowded, dim lighting
        case "office":
            return (0.4, 0.5, 0.7) // Moderate noise, moderate crowd, bright lighting
        case "hospital":
            return (0.5, 0.6, 0.9) // Moderate noise, moderately crowded, very bright
        default:
            return (0.5, 0.5, 0.5) // Default to moderate for all
        }
    }
    
    // Analyze day of week and time of day - returns multipliers to apply to base levels
    private func analyzeTimeFactors(_ dayOfWeek: String, _ timeOfDay: String) -> (noise: Double, crowd: Double) {
        let isWeekend = dayOfWeek.lowercased() == "saturday" || dayOfWeek.lowercased() == "sunday"
        
        // Parse time
        let timeComponents = timeOfDay.split(separator: ":")
        guard let hour = Int(timeComponents[0]) else {
            return (1.0, 1.0) // no adjustment
        }
        
        let isPM = timeOfDay.lowercased().contains("pm")
        let hour24 = isPM && hour != 12 ? hour + 12 : (hour == 12 && !isPM ? 0 : hour)
        
        // Early morning (5-7am) - quiet time
        if hour24 >= 5 && hour24 <= 7 {
            return isWeekend ? (0.3, 0.2) : (0.5, 0.4) // Weekday commuters starting
        }
        // Morning rush hour (8-10am) - PEAK TIME for transport
        else if hour24 >= 8 && hour24 <= 10 {
            return isWeekend ? (0.6, 0.5) : (1.8, 1.9) // MASSIVE weekday rush hour multiplier
        }
        // Late morning (11am-12pm) - still busy
        else if hour24 >= 11 && hour24 <= 11 {
            return isWeekend ? (0.8, 0.7) : (1.2, 1.3) // Still elevated from rush hour
        }
        // Lunch (12-2pm) - moderate activity
        else if hour24 >= 12 && hour24 <= 14 {
            return isWeekend ? (1.0, 1.1) : (1.3, 1.4) // Lunch crowd
        }
        // Afternoon (3-4pm) - building to evening rush
        else if hour24 >= 15 && hour24 <= 16 {
            return isWeekend ? (1.1, 1.2) : (1.4, 1.5) // Pre-evening rush
        }
        // Evening rush hour (5-7pm) - PEAK TIME
        else if hour24 >= 17 && hour24 <= 19 {
            return isWeekend ? (1.2, 1.3) : (1.7, 1.8) // Evening rush hour
        }
        // Evening (8-10pm) - social time
        else if hour24 >= 20 && hour24 <= 22 {
            return isWeekend ? (1.4, 1.5) : (1.0, 1.1) // Weekend social peak
        }
        // Night (11pm-4am) - quiet time
        else {
            return isWeekend ? (0.8, 0.6) : (0.2, 0.1) // Very quiet, especially weekdays
        }
    }
    
    // Adjust time factors based on venue type - some venues are less affected by rush hour
    private func adjustTimeFactorsForVenue(_ venueType: String, _ timeFactor: Double, _ crowdFactor: Double) -> (noise: Double, crowd: Double) {
        switch venueType.lowercased() {
        case "transport hub":
            // Transport hubs are MOST affected by rush hour - use full multipliers
            return (timeFactor, crowdFactor)
            
        case "library":
            // Libraries have minimal rush hour impact - people don't rush to libraries!
            // Cap the multipliers to prevent extreme values
            let dampedTimeFactor = min(1.3, 0.5 + timeFactor * 0.3)
            let dampedCrowdFactor = min(1.2, 0.6 + crowdFactor * 0.2)
            return (dampedTimeFactor, dampedCrowdFactor)
            
        case "museum":
            // Museums have moderate time sensitivity - busier on weekends
            let dampedTimeFactor = min(1.4, 0.7 + timeFactor * 0.4)
            let dampedCrowdFactor = min(1.5, 0.7 + crowdFactor * 0.4)
            return (dampedTimeFactor, dampedCrowdFactor)
            
        case "park":
            // Parks affected by weather more than time, but still some rush impact
            let dampedTimeFactor = min(1.6, 0.6 + timeFactor * 0.5)
            let dampedCrowdFactor = min(1.7, 0.6 + crowdFactor * 0.6)
            return (dampedTimeFactor, dampedCrowdFactor)
            
        case "café", "cafe":
            // Cafes have moderate rush hour impact (morning coffee rush)
            let dampedTimeFactor = min(1.5, 0.8 + timeFactor * 0.4)
            let dampedCrowdFactor = min(1.6, 0.8 + crowdFactor * 0.5)
            return (dampedTimeFactor, dampedCrowdFactor)
            
        case "restaurant":
            // Restaurants have meal-time specific patterns
            let dampedTimeFactor = min(1.6, 0.7 + timeFactor * 0.5)
            let dampedCrowdFactor = min(1.7, 0.7 + crowdFactor * 0.6)
            return (dampedTimeFactor, dampedCrowdFactor)
            
        case "shopping mall":
            // Shopping malls affected by rush hour but in reverse (people avoid commute times)
            let inverseFactor = 2.0 - timeFactor // Invert high rush hour values
            let dampedTimeFactor = min(1.4, 0.8 + inverseFactor * 0.3)
            let dampedCrowdFactor = min(1.5, 0.8 + inverseFactor * 0.4)
            return (dampedTimeFactor, dampedCrowdFactor)
            
        case "office":
            // Offices highly affected by rush hour
            return (timeFactor, crowdFactor)
            
        case "hospital":
            // Hospitals have consistent activity - less time variation
            let dampedTimeFactor = min(1.3, 0.8 + timeFactor * 0.2)
            let dampedCrowdFactor = min(1.4, 0.8 + crowdFactor * 0.3)
            return (dampedTimeFactor, dampedCrowdFactor)
            
        default:
            // Default: moderate time sensitivity
            let dampedTimeFactor = min(1.5, 0.7 + timeFactor * 0.4)
            let dampedCrowdFactor = min(1.6, 0.7 + crowdFactor * 0.5)
            return (dampedTimeFactor, dampedCrowdFactor)
        }
    }
    
    // Analyze weather conditions
    private func analyzeWeatherFactors(_ weather: String) -> (noise: Double, crowd: Double) {
        switch weather.lowercased() {
        case "sunny", "clear":
            return (0.2, 0.3) // More people outside, slightly noisier
        case "rainy", "raining":
            return (-0.2, -0.1) // Fewer people outside, slightly quieter
        case "snowy", "snowing":
            return (-0.3, -0.3) // Significantly fewer people, quieter
        case "stormy", "thunderstorm":
            return (-0.4, -0.4) // Very few people, much quieter outside
        case "windy":
            return (0.1, -0.1) // Windier can be noisier, slightly fewer people
        case "foggy":
            return (-0.1, -0.2) // Slightly fewer people, slightly quieter
        case "heatwave", "hot":
            return (0.1, -0.2) // More people seeking shelter, can be quieter outside
        case "cold", "freezing":
            return (-0.2, -0.3) // Fewer people outside, quieter
        default:
            return (0.0, 0.0) // No adjustment
        }
    }
    
    // Analyze user reports to extract specific information
    private func analyzeUserReports(_ reports: String) -> (noise: Double, crowd: Double, lighting: Double) {
        let lowercaseReports = reports.lowercased()
        
        // Initialize with no specific data
        var noiseValue: Double = 0.0
        var crowdValue: Double = 0.0
        var lightingValue: Double = 0.0
        
        // Check for noise indicators
        if lowercaseReports.contains("very quiet") || lowercaseReports.contains("silent") {
            noiseValue = 0.1
        } else if lowercaseReports.contains("quiet") {
            noiseValue = 0.3
        } else if lowercaseReports.contains("moderate noise") || lowercaseReports.contains("moderate sound") {
            noiseValue = 0.5
        } else if lowercaseReports.contains("noisy") || lowercaseReports.contains("loud") {
            noiseValue = 0.7
        } else if lowercaseReports.contains("very noisy") || lowercaseReports.contains("very loud") {
            noiseValue = 0.9
        }
        
        // Check for crowd indicators
        if lowercaseReports.contains("empty") || lowercaseReports.contains("deserted") {
            crowdValue = 0.1
        } else if lowercaseReports.contains("not crowded") || lowercaseReports.contains("few people") {
            crowdValue = 0.3
        } else if lowercaseReports.contains("moderately crowded") || lowercaseReports.contains("some people") {
            crowdValue = 0.5
        } else if lowercaseReports.contains("crowded") || lowercaseReports.contains("busy") {
            crowdValue = 0.7
        } else if lowercaseReports.contains("very crowded") || lowercaseReports.contains("packed") {
            crowdValue = 0.9
        }
        
        // Check for lighting indicators
        if lowercaseReports.contains("dark") || lowercaseReports.contains("dim lighting") {
            lightingValue = 0.2
        } else if lowercaseReports.contains("soft lighting") || lowercaseReports.contains("warm lighting") {
            lightingValue = 0.4
        } else if lowercaseReports.contains("moderate lighting") || lowercaseReports.contains("balanced lighting") {
            lightingValue = 0.5
        } else if lowercaseReports.contains("bright") || lowercaseReports.contains("well lit") {
            lightingValue = 0.7
        } else if lowercaseReports.contains("very bright") || lowercaseReports.contains("harsh lighting") {
            lightingValue = 0.9
        }
        
        // Check for time-specific patterns
        if lowercaseReports.contains("busier after") || lowercaseReports.contains("crowded in") {
            // Handle time-specific information here
            crowdValue = 0.7 // Default to busy if time pattern detected
        }
        
        return (noiseValue, crowdValue, lightingValue)
    }
    
    // Calculate final sensory factors
    private func calculateFinalFactor(_ baseFactor: Double, _ timeFactor: Double, _ weatherFactor: Double, _ userFactor: Double) -> Double {
        // User reports have highest priority if available
        if userFactor != 0.0 {
            // Apply time and weather adjustments to user report data
            let adjustedUserFactor = userFactor * timeFactor + weatherFactor
            return min(1.0, max(0.0, adjustedUserFactor))
        } else {
            // Time factors are multipliers applied to base venue characteristics
            // Weather factors are additive adjustments
            let timeAdjustedBase = baseFactor * timeFactor
            let finalValue = timeAdjustedBase + weatherFactor
            return min(1.0, max(0.0, finalValue))
        }
    }
    
    // Convert numerical value to sensory level
    private func convertToSensoryLevel(_ value: Double) -> SensoryLevel {
        switch value {
        case 0.0..<0.2: return .veryLow
        case 0.2..<0.4: return .low
        case 0.4..<0.6: return .moderate
        case 0.6..<0.8: return .high
        case 0.8...1.0: return .veryHigh
        default: return .varies
        }
    }
    
    // Special conversion for lighting
    private func convertToLightingLevel(_ value: Double) -> SensoryLevel {
        switch value {
        case 0.0..<0.3: return .veryLow // Very dim
        case 0.3..<0.45: return .low // Soft lighting
        case 0.45..<0.6: return .moderate // Moderate lighting
        case 0.6..<0.8: return .high // Bright
        case 0.8...1.0: return .veryHigh // Very bright
        default: return .varies
        }
    }
    
    // Generate a natural language summary
    private func generateSummary(_ request: VenuePredictionRequest, _ noise: SensoryLevel, _ crowd: SensoryLevel, _ lighting: SensoryLevel) -> String {
        
        // If we have user reports, prioritize that information
        if !request.userReportsSummary.isEmpty {
            return request.userReportsSummary
        }
        
        // Time-specific description
        let timeDescription = request.timeOfDay.contains("AM") || (request.timeOfDay.contains(":") && Int(request.timeOfDay.split(separator: ":")[0]) ?? 12 < 12) 
            ? "morning" 
            : (Int(request.timeOfDay.split(separator: ":")[0]) ?? 12 < 17 ? "afternoon" : "evening")
        
        // Venue-specific description
        var summary = "This \(request.venueType.lowercased()) may "
        
        // Noise description
        switch noise {
        case .veryLow: summary += "be very quiet"
        case .low: summary += "be relatively quiet"
        case .moderate: summary += "have moderate noise levels"
        case .high: summary += "be quite noisy"
        case .veryHigh: summary += "be very loud"
        case .varies: summary += "have varying noise levels"
        }
        
        summary += " and "
        
        // Crowd description
        switch crowd {
        case .veryLow: summary += "nearly empty"
        case .low: summary += "not very crowded"
        case .moderate: summary += "moderately busy"
        case .high: summary += "fairly crowded"
        case .veryHigh: summary += "very crowded"
        case .varies: summary += "have varying crowd levels"
        }
        
        // Weather impact
        if ["rainy", "snowy", "stormy"].contains(request.weather.lowercased()) {
            summary += " due to the \(request.weather.lowercased()) weather"
        }
        
        // Time impact
        summary += " during \(request.dayOfWeek) \(timeDescription)."
        
        // Add lighting information
        summary += " The lighting is likely to be "
        
        switch lighting {
        case .veryLow: summary += "very dim."
        case .low: summary += "soft and warm."
        case .moderate: summary += "moderate and comfortable."
        case .high: summary += "bright and well-lit."
        case .veryHigh: summary += "very bright."
        case .varies: summary += "variable depending on the area."
        }
        
        return summary
    }
    
    // Determine confidence level based on available data
    private func determineConfidenceLevel(_ request: VenuePredictionRequest, realDataConfidence: ConfidenceLevel = .low) -> ConfidenceLevel {
        // Validate inputs first to prevent unexpected values
        guard !request.venueName.isEmpty,
              !request.venueType.isEmpty,
              !request.location.isEmpty,
              !request.dayOfWeek.isEmpty,
              !request.timeOfDay.isEmpty,
              !request.weather.isEmpty else {
            return .low
        }
        
        // Real data confidence takes priority
        if realDataConfidence == .high {
            return .high
        } else if realDataConfidence == .medium {
            return .medium
        }
        
        // Fall back to text-based user reports if no real data
        if request.userReportsSummary.count > 50 {
            return realDataConfidence == .low ? .medium : .high // Boost if we have some real data
        } else if request.userReportsSummary.count > 20 {
            return realDataConfidence == .low ? .low : .medium
        } else {
            return realDataConfidence // Use real data confidence or .low if none
        }
    }
}