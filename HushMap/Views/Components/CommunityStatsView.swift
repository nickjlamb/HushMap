import SwiftUI

/// Statistics about the community dataset
/// Designed to build trust without gamification or competition
struct CommunityStats {
    let totalReports: Int
    let reportsLast30Days: Int
    let regionBreakdown: RegionBreakdown
    let lastUpdated: Date

    struct RegionBreakdown {
        let europe: Int
        let northAmerica: Int
        let asiaPacific: Int
        let other: Int

        var hasMultipleRegions: Bool {
            [europe, northAmerica, asiaPacific, other].filter { $0 > 0 }.count > 1
        }
    }

    /// Compute stats from a collection of Firestore reports
    static func from(reports: [FirestoreReport]) -> CommunityStats {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        let reportsLast30Days = reports.filter { $0.timestamp >= thirtyDaysAgo }.count

        // Classify reports by region based on coordinates
        var europe = 0
        var northAmerica = 0
        var asiaPacific = 0
        var other = 0

        for report in reports {
            let region = classifyRegion(latitude: report.latitude, longitude: report.longitude)
            switch region {
            case .europe: europe += 1
            case .northAmerica: northAmerica += 1
            case .asiaPacific: asiaPacific += 1
            case .other: other += 1
            }
        }

        return CommunityStats(
            totalReports: reports.count,
            reportsLast30Days: reportsLast30Days,
            regionBreakdown: RegionBreakdown(
                europe: europe,
                northAmerica: northAmerica,
                asiaPacific: asiaPacific,
                other: other
            ),
            lastUpdated: Date()
        )
    }

    private enum Region {
        case europe, northAmerica, asiaPacific, other
    }

    /// Simple region classification based on coordinate ranges
    private static func classifyRegion(latitude: Double, longitude: Double) -> Region {
        // Europe: roughly lat 35-72, lon -25 to 65
        if latitude >= 35 && latitude <= 72 && longitude >= -25 && longitude <= 65 {
            return .europe
        }
        // North America: roughly lat 15-72, lon -170 to -50
        if latitude >= 15 && latitude <= 72 && longitude >= -170 && longitude <= -50 {
            return .northAmerica
        }
        // Asia Pacific: roughly lat -50 to 72, lon 60 to 180 (or -180 to -100 for Pacific islands)
        if (latitude >= -50 && latitude <= 72 && longitude >= 60 && longitude <= 180) ||
           (latitude >= -50 && latitude <= 30 && longitude >= -180 && longitude <= -100) {
            return .asiaPacific
        }
        return .other
    }
}

// MARK: - Community Stats View

struct CommunityStatsView: View {
    let stats: CommunityStats

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("highContrastMode") private var highContrastMode = false

    private var backgroundColor: Color {
        highContrastMode ? .hushOffWhite : .hushCream
    }

    private var cardBackgroundColor: Color {
        highContrastMode ? .hushSoftWhite : .hushSoftWhite
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: StandardizedSheetDesign.sectionSpacing) {
                    // Explanatory header
                    explanatorySection

                    // Main statistics
                    statsSection

                    // Regional breakdown (if data spans multiple regions)
                    if stats.regionBreakdown.hasMultipleRegions {
                        regionSection
                    }

                    // Last updated
                    lastUpdatedSection
                }
                .padding(StandardizedSheetDesign.contentPadding)
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle("Community overview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.hushBackground)
                    .fontWeight(.medium)
                }
            }
        }
        .environment(\.colorScheme, highContrastMode ? .light : colorScheme)
    }

    // MARK: - Sections

    private var explanatorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("These reports are shared by people looking for quieter, calmer spaces.")
                .font(.hushBody)
                .foregroundColor(.hushSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("About this data: These reports are shared by people looking for quieter, calmer spaces.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(StandardizedSheetDesign.cardPadding)
        .background(cardBackgroundColor)
        .cornerRadius(StandardizedSheetDesign.cornerRadius)
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: StandardizedSheetDesign.itemSpacing) {
            Text("Overview")
                .font(.hushHeadline)
                .foregroundColor(.hushPrimaryText)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 12) {
                // Total reports
                StatRow(
                    label: "Total shared experiences",
                    value: stats.totalReports.formatted(),
                    accessibilityValue: "\(stats.totalReports) total shared experiences"
                )

                Divider()
                    .background(Color.hushTertiaryText.opacity(0.3))

                // Reports in past 30 days
                StatRow(
                    label: "Added in the past 30 days",
                    value: stats.reportsLast30Days.formatted(),
                    accessibilityValue: "\(stats.reportsLast30Days) reports added in the past 30 days"
                )
            }
        }
        .padding(StandardizedSheetDesign.cardPadding)
        .background(cardBackgroundColor)
        .cornerRadius(StandardizedSheetDesign.cornerRadius)
    }

    private var regionSection: some View {
        VStack(alignment: .leading, spacing: StandardizedSheetDesign.itemSpacing) {
            Text("Approximate regional breakdown")
                .font(.hushHeadline)
                .foregroundColor(.hushPrimaryText)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 12) {
                if stats.regionBreakdown.northAmerica > 0 {
                    RegionRow(
                        region: "North America",
                        count: stats.regionBreakdown.northAmerica
                    )
                }

                if stats.regionBreakdown.europe > 0 {
                    if stats.regionBreakdown.northAmerica > 0 {
                        Divider()
                            .background(Color.hushTertiaryText.opacity(0.3))
                    }
                    RegionRow(
                        region: "Europe",
                        count: stats.regionBreakdown.europe
                    )
                }

                if stats.regionBreakdown.asiaPacific > 0 {
                    if stats.regionBreakdown.northAmerica > 0 || stats.regionBreakdown.europe > 0 {
                        Divider()
                            .background(Color.hushTertiaryText.opacity(0.3))
                    }
                    RegionRow(
                        region: "Asia–Pacific",  // en dash for proper typography
                        count: stats.regionBreakdown.asiaPacific
                    )
                }

                // Only show "Other regions" if count >= 5 to avoid displaying negligible data
                if stats.regionBreakdown.other >= 5 {
                    if stats.regionBreakdown.northAmerica > 0 || stats.regionBreakdown.europe > 0 || stats.regionBreakdown.asiaPacific > 0 {
                        Divider()
                            .background(Color.hushTertiaryText.opacity(0.3))
                    }
                    RegionRow(
                        region: "Other regions (approx.)",
                        count: stats.regionBreakdown.other
                    )
                }
            }
        }
        .padding(StandardizedSheetDesign.cardPadding)
        .background(cardBackgroundColor)
        .cornerRadius(StandardizedSheetDesign.cornerRadius)
    }

    private var lastUpdatedSection: some View {
        HStack {
            Image(systemName: "clock")
                .font(.hushCaption)
                .foregroundColor(.hushTertiaryText)

            Text(lastUpdatedText)
                .font(.hushCaption)
                .foregroundColor(.hushTertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Last updated: \(lastUpdatedAccessibilityText)")
    }

    // MARK: - Helpers

    private var lastUpdatedText: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(stats.lastUpdated) {
            return "Updated today"
        } else if calendar.isDateInYesterday(stats.lastUpdated) {
            return "Updated yesterday"
        } else {
            let days = calendar.dateComponents([.day], from: stats.lastUpdated, to: now).day ?? 0
            if days == 1 {
                return "Updated 1 day ago"
            } else {
                return "Updated \(days) days ago"
            }
        }
    }

    private var lastUpdatedAccessibilityText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: stats.lastUpdated, relativeTo: Date())
    }
}

// MARK: - Supporting Views

private struct StatRow: View {
    let label: String
    let value: String
    let accessibilityValue: String

    var body: some View {
        HStack {
            Text(label)
                .font(.hushBody)
                .foregroundColor(.hushSecondaryText)

            Spacer()

            Text(value)
                .font(.hushBodyEmphasized)
                .foregroundColor(.hushPrimaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityValue)
    }
}

private struct RegionRow: View {
    let region: String
    let count: Int

    var body: some View {
        HStack {
            Text(region)
                .font(.hushBody)
                .foregroundColor(.hushSecondaryText)

            Spacer()

            Text(count.formatted())
                .font(.hushBodyEmphasized)
                .foregroundColor(.hushPrimaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(region): \(count) reports")
    }
}

// MARK: - Preview

#Preview {
    CommunityStatsView(
        stats: CommunityStats(
            totalReports: 535,
            reportsLast30Days: 47,
            regionBreakdown: CommunityStats.RegionBreakdown(
                europe: 89,
                northAmerica: 312,
                asiaPacific: 98,
                other: 36
            ),
            lastUpdated: Date()
        )
    )
}
