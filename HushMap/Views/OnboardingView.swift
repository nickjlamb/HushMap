import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0
    @State private var showInteractiveDemo = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    private let steps = OnboardingData.steps
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Progress indicator
                    ProgressView(value: Double(currentStep + 1), total: Double(steps.count))
                        .progressViewStyle(LinearProgressViewStyle(tint: .hushBackground))
                        .frame(height: 4)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    
                    // Main content
                    TabView(selection: $currentStep) {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            OnboardingStepView(
                                step: step,
                                isLastStep: index == steps.count - 1,
                                onNext: nextStep,
                                onSkip: skipOnboarding,
                                onComplete: completeOnboarding
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
                    
                    // Navigation controls
                    HStack {
                        // Skip button
                        if currentStep < steps.count - 1 {
                            Button("Skip") {
                                skipOnboarding()
                            }
                            .foregroundColor(.secondary)
                            .font(.body)
                        }
                        
                        Spacer()
                        
                        // Page indicators
                        HStack(spacing: 8) {
                            ForEach(0..<steps.count, id: \.self) { index in
                                Circle()
                                    .fill(index == currentStep ? Color.hushBackground : Color.gray.opacity(0.3))
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(index == currentStep ? 1.2 : 1.0)
                                    .animation(.easeInOut(duration: 0.3), value: currentStep)
                            }
                        }
                        
                        Spacer()
                        
                        // Next/Done button
                        Button(currentStep == steps.count - 1 ? "Get Started" : "Next") {
                            if currentStep == steps.count - 1 {
                                completeOnboarding()
                            } else {
                                nextStep()
                            }
                        }
                        .foregroundColor(.hushBackground)
                        .font(.body)
                        .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
                }
            }
            .navigationBarHidden(true)
        }
        .interactiveDismissDisabled()
    }
    
    private func nextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentStep < steps.count - 1 {
                currentStep += 1
            }
        }
    }
    
    private func skipOnboarding() {
        hasCompletedOnboarding = true
        isPresented = false
    }
    
    private func completeOnboarding() {
        hasCompletedOnboarding = true
        isPresented = false
    }
}

// MARK: - Individual Step View
struct OnboardingStepView: View {
    let step: OnboardingStep
    let isLastStep: Bool
    let onNext: () -> Void
    let onSkip: () -> Void
    let onComplete: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Icon and title
                VStack(spacing: 20) {
                    // Icon
                    Image(systemName: step.iconName)
                        .font(.system(size: 60))
                        .foregroundColor(step.iconColor)
                        .frame(width: 80, height: 80)
                        .background(
                            Circle()
                                .fill(step.iconColor.opacity(0.1))
                        )
                    
                    // Title and subtitle
                    VStack(spacing: 8) {
                        Text(step.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text(step.subtitle)
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Description
                Text(step.description)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
                
                // Examples (if provided)
                if let examples = step.examples {
                    SensoryExamplesView(examples: examples)
                }
                
                // Tips (if provided)
                if let tips = step.tips {
                    TipsView(tips: tips)
                }
                
                // Interactive demo (if enabled)
                if step.interactiveDemo {
                    InteractiveDemoView()
                }
                
                Spacer(minLength: 60) // Space for navigation controls
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
}

// MARK: - Sensory Examples View
struct SensoryExamplesView: View {
    let examples: [SensoryExample]
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(examples) { example in
                HStack {
                    // Emoji
                    Text(example.emoji)
                        .font(.title2)
                        .frame(width: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(example.description)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if !example.venues.isEmpty {
                            Text(example.venues.joined(separator: " • "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Level indicator
                    SensoryLevelIndicator(level: example.level)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.hushMapLines.opacity(0.1))
                )
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Tips View
struct TipsView: View {
    let tips: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(.orange)
                Text("Tips")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                HStack(alignment: .top, spacing: 12) {
                    Text("•")
                        .foregroundColor(.hushBackground)
                        .fontWeight(.bold)
                    
                    Text(tip)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Interactive Demo View
struct InteractiveDemoView: View {
    @State private var selectedExample: String = "noise"
    @State private var selectedLevel: SensoryLevel = .moderate
    
    private let demoOptions = ["noise", "crowd", "lighting"]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Try It Out!")
                .font(.headline)
                .foregroundColor(.hushBackground)
            
            // Category selector
            HStack {
                ForEach(demoOptions, id: \.self) { option in
                    Button(action: {
                        selectedExample = option
                        selectedLevel = .moderate
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: iconName(for: option))
                                .font(.title2)
                            Text(option.capitalized)
                                .font(.caption)
                        }
                        .foregroundColor(selectedExample == option ? .white : .hushBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedExample == option ? Color.hushBackground : Color.hushBackground.opacity(0.1))
                        )
                    }
                }
            }
            
            // Level examples
            if let examples = OnboardingData.sensoryExamples[selectedExample] {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(examples) { example in
                        Button(action: {
                            selectedLevel = example.level
                        }) {
                            VStack(spacing: 8) {
                                Text(example.emoji)
                                    .font(.title)
                                Text(example.description)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                SensoryLevelIndicator(level: example.level)
                            }
                            .foregroundColor(selectedLevel == example.level ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedLevel == example.level ? Color.hushBackground : Color.gray.opacity(0.1))
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.hushMapLines.opacity(0.05))
        )
        .padding(.horizontal, 20)
    }
    
    private func iconName(for category: String) -> String {
        switch category {
        case "noise": return "speaker.wave.3"
        case "crowd": return "person.2"
        case "lighting": return "lightbulb"
        default: return "questionmark.circle"
        }
    }
}

// MARK: - Sensory Level Indicator
struct SensoryLevelIndicator: View {
    let level: SensoryLevel
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Circle()
                    .fill(index <= level.numericValue ? level.color : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}