import SwiftUI

#if DEBUG
/// Developer settings for privacy location configuration (DEBUG builds only)
struct DevSettingsView: View {
    @State private var config = PrivacyLocationConfig.shared
    @State private var areaOnlyOverride: Bool
    @State private var confidenceHedgeThreshold: Double
    @State private var usePlacesEnrichment: Bool
    @State private var poiMaxRadiusMeters: Double
    @State private var snapWindowMeters: Double
    @State private var minConfidenceForDirectPOI: Double
    @State private var minConfidenceForHedgedPOI: Double
    @State private var showCandidateLogging = false
    
    init() {
        self._areaOnlyOverride = State(initialValue: PrivacyLocationConfig.shared.areaOnlyOverride)
        self._confidenceHedgeThreshold = State(initialValue: PrivacyLocationConfig.shared.confidenceHedgeThreshold)
        self._usePlacesEnrichment = State(initialValue: PrivacyLocationConfig.shared.usePlacesEnrichment)
        self._poiMaxRadiusMeters = State(initialValue: PrivacyLocationConfig.shared.poiMaxRadiusMeters)
        self._snapWindowMeters = State(initialValue: PrivacyLocationConfig.shared.snapWindowMeters)
        self._minConfidenceForDirectPOI = State(initialValue: PrivacyLocationConfig.shared.minConfidenceForDirectPOI)
        self._minConfidenceForHedgedPOI = State(initialValue: PrivacyLocationConfig.shared.minConfidenceForHedgedPOI)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Privacy Controls") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Force Area-Only Mode", isOn: $areaOnlyOverride)
                            .onChange(of: areaOnlyOverride) { _, newValue in
                                config.areaOnlyOverride = newValue
                            }
                        
                        Text("Kill-switch: Forces .area tier everywhere, bypassing POI/street resolution")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Enable Places Enrichment", isOn: $usePlacesEnrichment)
                            .onChange(of: usePlacesEnrichment) { _, newValue in
                                config.usePlacesEnrichment = newValue
                            }
                        
                        Text("Uses Google Places API for POI names; disable to use legacy geocoding only")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Confidence Hedge Threshold")
                            Spacer()
                            Text("\(String(format: "%.2f", confidenceHedgeThreshold))")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $confidenceHedgeThreshold, in: 0.6...0.9, step: 0.05) {
                            Text("Threshold")
                        } minimumValueLabel: {
                            Text("0.6")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } maximumValueLabel: {
                            Text("0.9")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .onChange(of: confidenceHedgeThreshold) { _, newValue in
                            config.confidenceHedgeThreshold = newValue
                        }
                        
                        Text("POI confidence below this threshold shows as 'near {POI}' instead of '{POI}'")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("POI Snapping Tuning") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("POI Max Radius")
                            Spacer()
                            Text("\(String(format: "%.0f", poiMaxRadiusMeters))m")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $poiMaxRadiusMeters, in: 25...50, step: 1) {
                            Text("POI Max Radius")
                        } minimumValueLabel: {
                            Text("25m")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } maximumValueLabel: {
                            Text("50m")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .onChange(of: poiMaxRadiusMeters) { _, newValue in
                            config.poiMaxRadiusMeters = newValue
                        }
                        
                        Text("Maximum distance to search for POIs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Snap Window")
                            Spacer()
                            Text("\(String(format: "%.0f", snapWindowMeters))m")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $snapWindowMeters, in: 8...25, step: 1) {
                            Text("Snap Window")
                        } minimumValueLabel: {
                            Text("8m")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } maximumValueLabel: {
                            Text("25m")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .onChange(of: snapWindowMeters) { _, newValue in
                            config.snapWindowMeters = newValue
                        }
                        
                        Text("Hard snap window - POIs within this distance are preferred")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Direct POI Confidence")
                            Spacer()
                            Text("\(String(format: "%.2f", minConfidenceForDirectPOI))")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $minConfidenceForDirectPOI, in: 0.70...0.90, step: 0.05) {
                            Text("Direct POI Confidence")
                        } minimumValueLabel: {
                            Text("0.70")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } maximumValueLabel: {
                            Text("0.90")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .onChange(of: minConfidenceForDirectPOI) { _, newValue in
                            config.minConfidenceForDirectPOI = newValue
                        }
                        
                        Text("Minimum confidence to show POI name directly (no hedging)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Hedged POI Confidence") 
                            Spacer()
                            Text("\(String(format: "%.2f", minConfidenceForHedgedPOI))")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $minConfidenceForHedgedPOI, in: 0.50...0.80, step: 0.05) {
                            Text("Hedged POI Confidence")
                        } minimumValueLabel: {
                            Text("0.50")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } maximumValueLabel: {
                            Text("0.80")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .onChange(of: minConfidenceForHedgedPOI) { _, newValue in
                            config.minConfidenceForHedgedPOI = newValue
                        }
                        
                        Text("Minimum confidence to show 'near {POI}' (below this falls back to street)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Enable Candidate Logging", isOn: $showCandidateLogging)
                        
                        Text("Logs top 3 candidates with scores and final decision to console")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Current Settings") {
                    HStack {
                        Text("Area-Only Override")
                        Spacer()
                        Text(areaOnlyOverride ? "ON" : "OFF")
                            .foregroundColor(areaOnlyOverride ? .red : .green)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Places Enrichment")
                        Spacer()
                        Text(usePlacesEnrichment ? "ON" : "OFF")
                            .foregroundColor(usePlacesEnrichment ? .green : .orange)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Hedge Threshold")
                        Spacer()
                        Text(String(format: "%.2f", confidenceHedgeThreshold))
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Instructions") {
                    Text("These settings affect how location labels are displayed throughout the app:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Area-Only Override: All locations show as '{Area} area'")
                        Text("• Hedge Threshold: Controls when POIs show as 'near {POI}'")
                        Text("• Settings persist between app launches")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Dev Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    DevSettingsView()
}
#endif