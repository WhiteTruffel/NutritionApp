import SwiftUI

/// Dashboard-Karte: Apple-Aktivitätsringe + vereinfachter Erholungsring (aus Apple Health).
struct ActivityRecoveryCard: View {
    let rings: ActivityRings?
    let readiness: ReadinessResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("activity_recovery.title".localized()).font(.headline)

            if rings == nil && readiness == nil {
                Text("activity_recovery.empty".localized())
                    .font(.caption).foregroundStyle(.secondary)
            }

            HStack(spacing: 28) {
                VStack(spacing: 6) {
                    ActivityRingsView(rings: rings).frame(width: 92, height: 92)
                    Text("settings.section.activity".localized()).font(.caption2).foregroundStyle(.secondary)
                }
                VStack(spacing: 6) {
                    ReadinessRingView(score: readiness?.score).frame(width: 92, height: 92)
                    Text("today.recovery".localized()).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let r = rings {
                VStack(spacing: 6) {
                    legendRow("load.movement".localized(), "\(Int(r.moveKcal)) / \(Int(r.moveGoal)) kcal", .red)
                    legendRow("trends.training".localized(), "\(Int(r.exerciseMin)) / \(Int(r.exerciseGoal)) min", .green)
                    legendRow("activity.stand".localized(),   "\(Int(r.standHours)) / \(Int(r.standGoal)) h", .blue)
                }
            }

            if let rd = readiness, rd.hrv != nil || rd.rhr != nil || rd.sleepHours != nil {
                Divider()
                HStack(spacing: 14) {
                    if let h = rd.hrv { metric("\(Int(h)) ms", "HRV") }
                    if let p = rd.rhr { metric("\(Int(p)) bpm", "recovery.rhr".localized()) }
                    if let s = rd.sleepHours { metric(String(format: "%.1f h", s), "Schlaf") }
                    Spacer()
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func legendRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.subheadline.weight(.medium)).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

/// Drei konzentrische Apple-Style-Ringe (Move/Exercise/Stand).
struct ActivityRingsView: View {
    let rings: ActivityRings?

    var body: some View {
        ZStack {
            ring(progress: prog(rings?.moveKcal, rings?.moveGoal), color: .red, inset: 0)
            ring(progress: prog(rings?.exerciseMin, rings?.exerciseGoal), color: .green, inset: 16)
            ring(progress: prog(rings?.standHours, rings?.standGoal), color: .blue, inset: 32)
        }
    }

    private func prog(_ value: Double?, _ goal: Double?) -> Double {
        guard let value, let goal, goal > 0 else { return 0 }
        return value / goal
    }

    private func ring(progress: Double, color: Color, inset: CGFloat) -> some View {
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: 10).padding(inset)
            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(inset)
        }
    }
}

/// Erholungsring mit Score (0–100); Farbe nach Bereich.
struct ReadinessRingView: View {
    let score: Int?

    private var progress: Double { Double(score ?? 0) / 100 }
    private var color: Color {
        switch score ?? 0 {
        case ..<34: return .red
        case ..<67: return .orange
        default:    return .green
        }
    }

    var body: some View {
        ZStack {
            Circle().stroke(Color(.systemGray5), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(score.map(String.init) ?? "–")
                .font(.title3.bold().monospacedDigit())
        }
    }
}
