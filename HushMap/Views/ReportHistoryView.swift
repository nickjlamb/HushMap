import SwiftUI
import SwiftData

struct ReportHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var allReports: [Report]

    @State private var recentlyDeletedReport: Report?
    @State private var showUndoSnackbar = false

    var sortedReports: [Report] {
        allReports.sorted {
            averageScore(for: $0) > averageScore(for: $1)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                List {
                    if sortedReports.isEmpty {
                        Text("No reports yet.")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(sortedReports) { report in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Circle()
                                        .fill(colorForRiskLevel(of: report))
                                        .frame(width: 10, height: 10)
                                    Text(report.timestamp.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                HStack {
                                    Text("Noise: \(score(report.noise))")
                                    Text("Crowds: \(score(report.crowds))")
                                    Text("Lighting: \(score(report.lighting))")
                                }
                                .font(.subheadline)

                                Text("Overall Score: \(String(format: "%.1f", averageScore(for: report))) / 1.0")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)

                                if !report.comments.isEmpty {
                                    Text("“\(report.comments)”")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .onDelete(perform: deleteReports)
                    }
                }

                if showUndoSnackbar {
                    VStack {
                        Spacer()
                        HStack {
                            Text("Report deleted")
                            Spacer()
                            Button("Undo") {
                                undoDelete()
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom))
                        .animation(.easeInOut, value: showUndoSnackbar)
                    }
                }
            }
            .navigationTitle("My Reports")
        }
    }

    func score(_ value: Double) -> String {
        return "\(Int(value * 10))/10"
    }

    func averageScore(for report: Report) -> Double {
        return (report.noise + report.crowds + report.lighting) / 3
    }

    func colorForRiskLevel(of report: Report) -> Color {
        let avg = averageScore(for: report)
        switch avg {
        case ..<0.3: return .green
        case 0.3..<0.6: return .yellow
        default: return .red
        }
    }

    func deleteReports(at offsets: IndexSet) {
        for index in offsets {
            let report = sortedReports[index]
            recentlyDeletedReport = report
            modelContext.delete(report)
        }

        showUndoSnackbar = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if showUndoSnackbar {
                showUndoSnackbar = false
                recentlyDeletedReport = nil
            }
        }
    }

    func undoDelete() {
        if let report = recentlyDeletedReport {
            modelContext.insert(report)
        }
        showUndoSnackbar = false
        recentlyDeletedReport = nil
    }
}
