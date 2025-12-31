import SwiftUI
import SwiftData
import CoreLocation

/// Lightweight UI component for fast, one-tap sensory updates.
/// Designed to be usable with one thumb in under one second.
struct QuickUpdateView: View {
    let coordinate: CLLocationCoordinate2D
    let displayName: String?
    let onLogFullVisit: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var submissionState: SubmissionState = .idle
    @State private var userPreviousState: QuietState?

    /// Tracks the current submission state for UI feedback
    private enum SubmissionState: Equatable {
        case idle
        case submitting
        case success(QuietState)
    }

    /// Location identifier for this place
    private var placeId: String {
        QuickUpdate.locationIdentifier(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            // Prompt text
            Text("How is this place right now?")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.hushSecondaryText)

            // Quick update buttons
            HStack(spacing: 12) {
                quickUpdateButton(
                    state: .quiet,
                    icon: "speaker.slash.fill",
                    baseLabel: "Quiet now",
                    stillLabel: "Still quiet"
                )

                quickUpdateButton(
                    state: .noisy,
                    icon: "speaker.wave.3.fill",
                    baseLabel: "Noisy now",
                    stillLabel: "Still noisy"
                )
            }

            // Success acknowledgement overlay
            if case .success(let state) = submissionState {
                successAcknowledgement(state: state)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            // Secondary action: Log a full visit
            Button(action: onLogFullVisit) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.caption)
                    Text("Log a full visit")
                        .font(.caption)
                }
                .foregroundColor(.hushBackground)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(Color.hushMapShape.opacity(0.15))
        .cornerRadius(12)
        .onAppear {
            checkForPreviousUpdate()
        }
        .animation(.easeInOut(duration: 0.2), value: submissionState)
    }

    // MARK: - Quick Update Button

    @ViewBuilder
    private func quickUpdateButton(
        state: QuietState,
        icon: String,
        baseLabel: String,
        stillLabel: String
    ) -> some View {
        let isSubmitting = submissionState == .submitting
        let hasSubmittedThis = if case .success(let s) = submissionState { s == state } else { false }
        let hasPreviousOfThis = userPreviousState == state

        Button(action: {
            submitQuickUpdate(state: state)
        }) {
            HStack(spacing: 8) {
                if hasSubmittedThis {
                    // Show checkmark after successful submission
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundColor(.white)
                }

                Text(hasPreviousOfThis ? stillLabel : baseLabel)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(buttonBackground(for: state, isSubmittedThis: hasSubmittedThis))
            .cornerRadius(10)
        }
        .disabled(isSubmitting)
        .opacity(isSubmitting ? 0.7 : 1.0)
    }

    /// Background color for quick update buttons
    private func buttonBackground(for state: QuietState, isSubmittedThis: Bool) -> Color {
        if isSubmittedThis {
            // Success state: show a subtle green
            return Color.hushLowRisk
        }

        switch state {
        case .quiet:
            return Color.hushBackground
        case .noisy:
            return Color.hushHighRisk
        }
    }

    // MARK: - Success Acknowledgement

    @ViewBuilder
    private func successAcknowledgement(state: QuietState) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.hushLowRisk)

            Text("Updated")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.hushSecondaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Actions

    /// Check if user has submitted a quick update for this place recently
    private func checkForPreviousUpdate() {
        let service = QuickUpdateService.shared
        if let previousUpdate = service.recentUpdate(for: placeId, modelContext: modelContext) {
            userPreviousState = previousUpdate.quietState
        }
    }

    /// Submit a quick update
    private func submitQuickUpdate(state: QuietState) {
        // Immediate haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        submissionState = .submitting

        Task {
            do {
                let service = QuickUpdateService.shared
                _ = try await service.submitQuickUpdate(
                    quietState: state,
                    coordinate: coordinate,
                    displayName: displayName,
                    modelContext: modelContext
                )

                // Success feedback
                let successGenerator = UINotificationFeedbackGenerator()
                successGenerator.notificationOccurred(.success)

                // Update state to show success
                submissionState = .success(state)
                userPreviousState = state

                // Reset after a short delay
                try? await Task.sleep(for: .seconds(2))
                if case .success = submissionState {
                    submissionState = .idle
                }
            } catch {
                // Revert on failure
                submissionState = .idle

                let errorGenerator = UINotificationFeedbackGenerator()
                errorGenerator.notificationOccurred(.error)

                #if DEBUG
                print("Quick update failed: \(error)")
                #endif
            }
        }
    }
}

// MARK: - Preview

#Preview {
    QuickUpdateView(
        coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        displayName: "Sample Coffee Shop",
        onLogFullVisit: { print("Log full visit tapped") }
    )
    .padding()
    .modelContainer(for: QuickUpdate.self, inMemory: true)
}
