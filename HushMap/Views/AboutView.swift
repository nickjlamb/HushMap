import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    
    // Control for high contrast mode
    @AppStorage("highContrastMode") private var highContrastMode = false
    
    // Color scheme adaptation for accessibility
    var backgroundColor: Color {
        if highContrastMode {
            return .hushOffWhite // Warm off-white in high contrast mode
        } else {
            return colorScheme == .dark ? Color(UIColor.systemBackground) : Color.hushCream
        }
    }
    
    var textColor: Color {
        if highContrastMode {
            return .black // Always black text in high contrast mode
        } else {
            return colorScheme == .dark ? Color.hushOffWhite : Color.black
        }
    }
    
    var accentColor: Color {
        highContrastMode ? .hushWaterRoad : .hushBackground
    }
    
    var cardBackgroundColor: Color {
        if highContrastMode {
            return .hushSoftWhite
        } else {
            return colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.hushSoftWhite
        }
    }
    
    var buttonBackgroundColor: Color {
        if highContrastMode {
            return Color.hushMapLines.opacity(0.3)
        } else {
            return colorScheme == .dark ? Color(UIColor.tertiarySystemBackground) : Color.hushMapLines.opacity(0.2)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: dynamicTypeSize > .large ? 32 : 24) {
                // Header with close button
                HStack {
                    Text("About HushMap")
                        .font(.largeTitle.weight(.bold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .foregroundColor(textColor)
                        .accessibilityAddTraits(.isHeader)
                    
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(accentColor)
                    }
                    .accessibilityLabel("Close About screen")
                }
                .padding(.bottom, 8)
                
                // App description
                VStack(alignment: .leading, spacing: 16) {
                    Image("HushMapIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .cornerRadius(16)
                        .accessibilityHidden(true)
                    
                    Text("HushMap helps you find and report quiet, sensory-friendly places in your area.")
                        .font(.title3.weight(.medium))
                        .foregroundColor(textColor)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Designed with the neurodiverse community in mind, it promotes comfort, safety, and accessibility for everyone sensitive to noise, lighting, and crowds.")
                        .foregroundColor(textColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardBackgroundColor)
                )
                
                // Accessibility Options
                VStack(alignment: .leading, spacing: 12) {
                    Text("Accessibility Options")
                        .font(.title2.weight(.bold))
                        .foregroundColor(textColor)
                        .accessibilityAddTraits(.isHeader)
                    
                    Toggle(isOn: $highContrastMode) {
                        Label("High contrast mode", systemImage: "circle.lefthalf.filled")
                    }
                    .toggleStyle(SwitchToggleStyle(tint: accentColor))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(buttonBackgroundColor)
                    )
                    
                    Text("Tip: You can also use your device's built-in accessibility settings for larger text, reduced motion, and VoiceOver.")
                        .font(.subheadline)
                        .foregroundColor(textColor.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Privacy & Contact
                VStack(alignment: .leading, spacing: 12) {
                    Text("Privacy & Contact")
                        .font(.title2.weight(.bold))
                        .foregroundColor(textColor)
                        .accessibilityAddTraits(.isHeader)
                    
                    Button {
                        if let url = URL(string: "https://www.pharmatools.ai/privacy-policy") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                                .font(.title3)
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(buttonBackgroundColor)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open privacy policy")
                    
                    Button {
                        if let url = URL(string: "https://www.pharmatools.ai/terms") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "doc.plaintext")
                                .font(.title3)
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(buttonBackgroundColor)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open terms of service")
                    
                    Button {
                        if let url = URL(string: "mailto:support@pharmatools.ai") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "envelope")
                                .font(.title3)
                            Text("Contact Support")
                            Spacer()
                            Text("support@pharmatools.ai")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(buttonBackgroundColor)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Email support")
                    
                    Button {
                        // Open App Store page for rating
                        if let url = URL(string: "https://apps.apple.com/app/id6748575846?action=write-review") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "star.fill")
                                .font(.title3)
                                .foregroundColor(.yellow)
                            Text("Rate This App")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(buttonBackgroundColor)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Rate HushMap on the App Store")
                }
                
                // Try our other app
                VStack(alignment: .leading, spacing: 12) {
                    Text("Try Our Other App")
                        .font(.title2.weight(.bold))
                        .foregroundColor(textColor)
                        .accessibilityAddTraits(.isHeader)
                    
                    Button {
                        if let url = URL(string: "https://apps.apple.com/us/app/patiently-ai-simplify-notes/id6739538685") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 16) {
                            AsyncImage(url: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/15/13/92/1513923b-0847-ffc6-0cc4-147f8d91b133/AppIcon-0-0-1x_U007epad-0-1-85-220.png/460x0w.webp")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        ProgressView()
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Patiently AI")
                                    .font(.headline)
                                    .foregroundColor(textColor)
                                
                                Text("Turn complex medical notes into patient-friendly explanations")
                                    .font(.subheadline)
                                    .foregroundColor(textColor.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                HStack {
                                    Image(systemName: "apple.logo")
                                    Text("View on App Store")
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(accentColor)
                                .font(.footnote)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(buttonBackgroundColor)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open Patiently AI on App Store")
                }
                
                // Version info
                HStack {
                    Spacer()
                    VStack {
                        Text("HushMap v1.5.2 (12)")
                            .font(.caption)
                            .foregroundColor(textColor.opacity(0.6))
                        Text("© 2025 PharmaTools.AI")
                            .font(.caption2)
                            .foregroundColor(textColor.opacity(0.5))
                    }
                    Spacer()
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .background(backgroundColor.ignoresSafeArea())
        .environment(\.colorScheme, highContrastMode ? .light : colorScheme)
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
            .preferredColorScheme(.light)
        
        AboutView()
            .preferredColorScheme(.dark)
    }
}
