import Foundation
import SwiftUI

// MARK: - Onboarding Step Model
struct OnboardingStep: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let description: String
    let iconName: String
    let iconColor: Color
    let examples: [SensoryExample]?
    let tips: [String]?
    let interactiveDemo: Bool
    
    init(
        title: String,
        subtitle: String,
        description: String,
        iconName: String,
        iconColor: Color,
        examples: [SensoryExample]? = nil,
        tips: [String]? = nil,
        interactiveDemo: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.iconName = iconName
        self.iconColor = iconColor
        self.examples = examples
        self.tips = tips
        self.interactiveDemo = interactiveDemo
    }
}

// MARK: - Sensory Example Model
struct SensoryExample: Identifiable, Hashable {
    let id = UUID()
    let level: SensoryLevel
    let description: String
    let emoji: String
    let venues: [String]
}

// MARK: - Onboarding Data
struct OnboardingData {
    static let steps: [OnboardingStep] = [
        // Welcome & Introduction
        OnboardingStep(
            title: "Welcome to HushMap",
            subtitle: "Your guide to sensory-friendly spaces",
            description: "HushMap helps you find venues that match your sensory preferences. Whether you need quiet spaces, avoid crowds, or prefer certain lighting, we've got you covered.",
            iconName: "brain.head.profile",
            iconColor: .purple
        ),
        
        // Understanding Sensory Levels
        OnboardingStep(
            title: "Understanding Sensory Levels",
            subtitle: "We measure three key factors",
            description: "Every venue is rated on noise, crowd levels, and lighting. These help you predict if a space will be comfortable for you.",
            iconName: "slider.horizontal.3",
            iconColor: .hushBackground,
            examples: [
                SensoryExample(
                    level: .veryLow,
                    description: "Very Quiet",
                    emoji: "🤫",
                    venues: ["Libraries", "Museums", "Quiet cafés"]
                ),
                SensoryExample(
                    level: .moderate,
                    description: "Moderate",
                    emoji: "😌",
                    venues: ["Restaurants", "Bookstores", "Coffee shops"]
                ),
                SensoryExample(
                    level: .veryHigh,
                    description: "Very Loud",
                    emoji: "🎵",
                    venues: ["Concerts", "Sports bars", "Nightclubs"]
                )
            ]
        ),
        
        // Noise Levels Deep Dive
        OnboardingStep(
            title: "Noise Levels",
            subtitle: "From whisper quiet to concert loud",
            description: "Noise levels help you find spaces that match your hearing comfort and sensory needs.",
            iconName: "speaker.wave.3",
            iconColor: .blue,
            examples: [
                SensoryExample(
                    level: .veryLow,
                    description: "Very Quiet - Whisper level",
                    emoji: "📚",
                    venues: ["Libraries", "Study areas", "Meditation spaces"]
                ),
                SensoryExample(
                    level: .low,
                    description: "Quiet - Soft conversation",
                    emoji: "☕️",
                    venues: ["Quiet cafés", "Museums", "Bookstores"]
                ),
                SensoryExample(
                    level: .moderate,
                    description: "Moderate - Normal talking",
                    emoji: "🍽️",
                    venues: ["Restaurants", "Offices", "Shops"]
                ),
                SensoryExample(
                    level: .high,
                    description: "Loud - Energetic atmosphere",
                    emoji: "🍻",
                    venues: ["Busy restaurants", "Markets", "Gyms"]
                ),
                SensoryExample(
                    level: .veryHigh,
                    description: "Very Loud - Music/entertainment",
                    emoji: "🎵",
                    venues: ["Concerts", "Clubs", "Sports venues"]
                )
            ]
        ),
        
        // Crowd Levels
        OnboardingStep(
            title: "Crowd Levels",
            subtitle: "From empty to packed",
            description: "Crowd levels indicate how busy a space feels and how much personal space you'll have.",
            iconName: "person.2",
            iconColor: .orange,
            examples: [
                SensoryExample(
                    level: .veryLow,
                    description: "Empty - Just you",
                    emoji: "🧘",
                    venues: ["Off-peak libraries", "Early morning cafés"]
                ),
                SensoryExample(
                    level: .low,
                    description: "Light - Few people around",
                    emoji: "🚶",
                    venues: ["Quiet bookstores", "Small galleries"]
                ),
                SensoryExample(
                    level: .moderate,
                    description: "Moderate - Comfortably busy",
                    emoji: "👥",
                    venues: ["Popular cafés", "Shopping centers"]
                ),
                SensoryExample(
                    level: .high,
                    description: "Busy - Lots of activity",
                    emoji: "🏃",
                    venues: ["Rush hour transit", "Busy restaurants"]
                ),
                SensoryExample(
                    level: .veryHigh,
                    description: "Very Crowded - Packed",
                    emoji: "🌊",
                    venues: ["Concerts", "Rush hour", "Popular events"]
                )
            ]
        ),
        
        // Lighting Levels
        OnboardingStep(
            title: "Lighting",
            subtitle: "From dim to bright",
            description: "Lighting affects comfort for those sensitive to brightness or who prefer certain ambiances.",
            iconName: "lightbulb",
            iconColor: .yellow,
            examples: [
                SensoryExample(
                    level: .veryLow,
                    description: "Dim - Cozy and subdued",
                    emoji: "🕯️",
                    venues: ["Wine bars", "Intimate restaurants", "Lounges"]
                ),
                SensoryExample(
                    level: .low,
                    description: "Soft - Warm and gentle",
                    emoji: "🏮",
                    venues: ["Cafés", "Reading areas", "Boutiques"]
                ),
                SensoryExample(
                    level: .moderate,
                    description: "Moderate - Well-lit",
                    emoji: "💡",
                    venues: ["Offices", "Shops", "Restaurants"]
                ),
                SensoryExample(
                    level: .high,
                    description: "Bright - Clear and vibrant",
                    emoji: "☀️",
                    venues: ["Retail stores", "Hospitals", "Gyms"]
                ),
                SensoryExample(
                    level: .veryHigh,
                    description: "Very Bright - Intense lighting",
                    emoji: "💫",
                    venues: ["Electronics stores", "Some offices", "Stadiums"]
                )
            ]
        ),
        
        // AI Predictions
        OnboardingStep(
            title: "AI-Powered Predictions",
            subtitle: "Smart insights for better planning",
            description: "Our AI analyzes venue types, times, user reports, and other factors to predict what you'll experience before you visit.",
            iconName: "brain",
            iconColor: .purple,
            tips: [
                "Predictions consider time of day and day of week",
                "Weather and local events can affect conditions",
                "User reports help improve accuracy over time",
                "Always check current conditions when possible"
            ]
        ),
        
        // How to Use
        OnboardingStep(
            title: "How to Use HushMap",
            subtitle: "Finding your perfect space",
            description: "Search for venues, view predictions, and contribute your own experiences to help the community.",
            iconName: "map",
            iconColor: .hushBackground,
            tips: [
                "Browse the map to discover nearby venues",
                "Tap venues to see detailed sensory predictions",
                "Use the search to find specific places",
                "Submit reports to help others",
                "Filter by your sensory preferences"
            ],
            interactiveDemo: true
        ),
        
        // Community & Contribution
        OnboardingStep(
            title: "Join the Community",
            subtitle: "Your experiences help everyone",
            description: "Share your sensory experiences to build a more inclusive world. Every report makes HushMap better for the community.",
            iconName: "heart.circle",
            iconColor: .pink,
            tips: [
                "Submit honest, helpful reports",
                "Focus on sensory factors, not personal opinions",
                "Help make spaces more accessible for everyone",
                "Your data stays private and secure"
            ]
        )
    ]
    
    // Sensory education examples for interactive learning
    static let sensoryExamples = [
        "noise": [
            SensoryExample(level: .veryLow, description: "Library reading room", emoji: "📚", venues: []),
            SensoryExample(level: .low, description: "Coffee shop morning", emoji: "☕️", venues: []),
            SensoryExample(level: .moderate, description: "Restaurant dinner", emoji: "🍽️", venues: []),
            SensoryExample(level: .high, description: "Busy food court", emoji: "🍕", venues: []),
            SensoryExample(level: .veryHigh, description: "Live music venue", emoji: "🎵", venues: [])
        ],
        "crowd": [
            SensoryExample(level: .veryLow, description: "Early morning park", emoji: "🌅", venues: []),
            SensoryExample(level: .low, description: "Small bookstore", emoji: "📖", venues: []),
            SensoryExample(level: .moderate, description: "Popular café", emoji: "👥", venues: []),
            SensoryExample(level: .high, description: "Shopping mall weekend", emoji: "🛍️", venues: []),
            SensoryExample(level: .veryHigh, description: "Concert venue", emoji: "🎤", venues: [])
        ],
        "lighting": [
            SensoryExample(level: .veryLow, description: "Candlelit restaurant", emoji: "🕯️", venues: []),
            SensoryExample(level: .low, description: "Cozy bookstore", emoji: "📚", venues: []),
            SensoryExample(level: .moderate, description: "Office workspace", emoji: "💼", venues: []),
            SensoryExample(level: .high, description: "Retail store", emoji: "🛒", venues: []),
            SensoryExample(level: .veryHigh, description: "Electronics showroom", emoji: "💻", venues: [])
        ]
    ]
}