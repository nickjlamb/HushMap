import Foundation

// MARK: - Sensory Certification Models

enum SensoryCertificationType: String, Codable, CaseIterable {
    case autismFriendly = "Autism Friendly"
    case sensoryInclusive = "Sensory Inclusive"
    case quietHours = "Quiet Hours"
    case lowStimulation = "Low Stimulation"
    case sensoryFriendly = "Sensory Friendly"
    case neurodivergentWelcome = "Neurodivergent Welcome"
    
    var icon: String {
        switch self {
        case .autismFriendly:
            return "heart.circle.fill"
        case .sensoryInclusive:
            return "accessibility.circle.fill"
        case .quietHours:
            return "speaker.slash.circle.fill"
        case .lowStimulation:
            return "moon.circle.fill"
        case .sensoryFriendly:
            return "brain.head.profile.circle.fill"
        case .neurodivergentWelcome:
            return "person.2.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .autismFriendly:
            return "blue"
        case .sensoryInclusive:
            return "green"
        case .quietHours:
            return "purple"
        case .lowStimulation:
            return "indigo"
        case .sensoryFriendly:
            return "teal"
        case .neurodivergentWelcome:
            return "orange"
        }
    }
    
    var description: String {
        switch self {
        case .autismFriendly:
            return "Certified autism-friendly environment with trained staff and sensory accommodations"
        case .sensoryInclusive:
            return "Designed to be inclusive for all sensory needs with multiple accommodation options"
        case .quietHours:
            return "Designated quiet hours with reduced noise, music, and crowd levels"
        case .lowStimulation:
            return "Maintained as a low-stimulation environment with soft lighting and minimal noise"
        case .sensoryFriendly:
            return "Sensory-friendly features including retreat spaces and sensory tools"
        case .neurodivergentWelcome:
            return "Actively welcoming to neurodivergent individuals with understanding staff"
        }
    }
}

struct SensoryCertification: Codable, Identifiable {
    let id: UUID
    let type: SensoryCertificationType
    let certifyingBody: String
    let dateIssued: Date
    let expiryDate: Date?
    let details: String
    let verificationURL: String?
    
    var isValid: Bool {
        guard let expiryDate = expiryDate else { return true }
        return Date() < expiryDate
    }
    
    var timeRemaining: String? {
        guard let expiryDate = expiryDate else { return nil }
        let timeInterval = expiryDate.timeIntervalSince(Date())
        let days = Int(timeInterval / 86400)
        
        if days > 30 {
            return "Expires in \(days) days"
        } else if days > 0 {
            return "Expires in \(days) days"
        } else {
            return "Expired"
        }
    }
    
    init(type: SensoryCertificationType, certifyingBody: String, details: String, verificationURL: String? = nil) {
        self.id = UUID()
        self.type = type
        self.certifyingBody = certifyingBody
        self.dateIssued = Date()
        self.expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())
        self.details = details
        self.verificationURL = verificationURL
    }
}

// MARK: - Example Certifications

extension SensoryCertification {
    static let sampleCertifications: [SensoryCertification] = [
        SensoryCertification(
            type: .autismFriendly,
            certifyingBody: "National Autistic Society",
            details: "Staff trained in autism awareness, quiet spaces available, sensory breaks encouraged"
        ),
        SensoryCertification(
            type: .quietHours,
            certifyingBody: "Sensory Spaces Initiative",
            details: "Daily quiet hours 9-11am and 2-4pm with reduced music and lighting"
        ),
        SensoryCertification(
            type: .sensoryInclusive,
            certifyingBody: "Inclusive Design Council",
            details: "Comprehensive sensory accommodations including noise-canceling zones and adjustable lighting"
        )
    ]
}