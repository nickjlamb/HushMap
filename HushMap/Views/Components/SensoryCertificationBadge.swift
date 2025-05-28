import SwiftUI

struct SensoryCertificationBadge: View {
    let certification: SensoryCertification
    @State private var showDetails = false
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: certification.type.icon)
                .foregroundColor(colorForType(certification.type))
                .font(.caption)
            
            Text(certification.type.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorForType(certification.type).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(colorForType(certification.type).opacity(0.3), lineWidth: 1)
                )
        )
        .onTapGesture {
            withAnimation {
                showDetails = true
            }
        }
        .fullScreenCover(isPresented: $showDetails) {
            SensoryCertificationDetailView(certification: certification, isPresented: $showDetails)
        }
    }
    
    private func colorForType(_ type: SensoryCertificationType) -> Color {
        switch type.color {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "indigo": return .indigo
        case "teal": return .teal
        case "orange": return .orange
        default: return .blue
        }
    }
}

struct SensoryCertificationDetailView: View {
    let certification: SensoryCertification
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom header
            HStack {
                Text("Certification Details")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Done") {
                    isPresented = false
                }
                .font(.headline)
                .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.systemGray6))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: certification.type.icon)
                                .foregroundColor(colorForType(certification.type))
                                .font(.title2)
                            
                            VStack(alignment: .leading) {
                                Text(certification.type.rawValue)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Certified by \(certification.certifyingBody)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if certification.isValid {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                            }
                        }
                        
                        Text(certification.type.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Certification Details")
                            .font(.headline)
                        
                        Text(certification.details)
                            .font(.body)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Issued")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(certification.dateIssued, style: .date)
                                    .font(.subheadline)
                            }
                            
                            Spacer()
                            
                            if let timeRemaining = certification.timeRemaining {
                                VStack(alignment: .trailing) {
                                    Text("Status")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(timeRemaining)
                                        .font(.subheadline)
                                        .foregroundColor(certification.isValid ? .green : .red)
                                }
                            }
                        }
                        
                        if let verificationURL = certification.verificationURL {
                            Link("Verify Certification", destination: URL(string: verificationURL)!)
                                .font(.footnote)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    private func colorForType(_ type: SensoryCertificationType) -> Color {
        switch type.color {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "indigo": return .indigo
        case "teal": return .teal
        case "orange": return .orange
        default: return .blue
        }
    }
}

#Preview {
    SensoryCertificationBadge(certification: SensoryCertification.sampleCertifications[0])
}