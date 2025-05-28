import SwiftUI

// MARK: - Error Alert View
struct ErrorAlert: ViewModifier {
    @ObservedObject var errorState: ErrorStateViewModel
    let retryAction: (() -> Void)?
    let settingsAction: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .alert(
                errorState.currentError?.title ?? "Error",
                isPresented: $errorState.isShowingError,
                presenting: errorState.currentError
            ) { error in
                Button(error.actionButtonTitle) {
                    switch error {
                    case .network, .api, .general:
                        retryAction?()
                    case .location:
                        settingsAction?()
                    }
                    errorState.clearError()
                }
                
                if case .location = error {
                    Button("Not Now") {
                        errorState.clearError()
                    }
                }
            } message: { error in
                Text(error.errorDescription ?? "An error occurred")
            }
    }
}

// MARK: - Error State View
struct ErrorStateView: View {
    let error: AppError
    let retryAction: (() -> Void)?
    let settingsAction: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: iconName)
                .font(.system(.title, design: .default, weight: .regular))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text(error.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(error.errorDescription ?? "An error occurred")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(spacing: 12) {
                Button(action: primaryAction) {
                    Text(error.actionButtonTitle)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.hushBackground)
                        )
                }
                
                if case .location = error {
                    Button("Continue Without Location") {
                        // Allow user to continue without location
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
    }
    
    private var iconName: String {
        switch error {
        case .network:
            return "wifi.exclamationmark"
        case .location:
            return "location.slash"
        case .api:
            return "server.rack"
        case .general:
            return "exclamationmark.triangle"
        }
    }
    
    private func primaryAction() {
        switch error {
        case .network, .api, .general:
            retryAction?()
        case .location:
            settingsAction?()
        }
    }
}

// MARK: - Loading with Error Fallback
struct LoadingWithErrorView<Content: View>: View {
    let isLoading: Bool
    let error: AppError?
    let content: Content
    let retryAction: (() -> Void)?
    let settingsAction: (() -> Void)?
    
    init(
        isLoading: Bool,
        error: AppError?,
        retryAction: (() -> Void)? = nil,
        settingsAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.isLoading = isLoading
        self.error = error
        self.retryAction = retryAction
        self.settingsAction = settingsAction
        self.content = content()
    }
    
    var body: some View {
        Group {
            if let error = error {
                ErrorStateView(
                    error: error,
                    retryAction: retryAction,
                    settingsAction: settingsAction
                )
            } else if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
    }
}

// MARK: - View Extensions
extension View {
    func errorAlert(
        errorState: ErrorStateViewModel,
        retryAction: (() -> Void)? = nil,
        settingsAction: (() -> Void)? = nil
    ) -> some View {
        modifier(ErrorAlert(
            errorState: errorState,
            retryAction: retryAction,
            settingsAction: settingsAction
        ))
    }
    
    func openAppSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}