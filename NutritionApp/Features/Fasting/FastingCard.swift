import SwiftUI
import Combine

/// Intervallfasten-Timer (BL22). Wählbares Protokoll (16:8 …), Start/Stop, Live-Fortschritt.
/// Zustand persistiert über @AppStorage – kein Datenmodell nötig.
struct FastingCard: View {
    @AppStorage("fastingStartEpoch") private var startEpoch: Double = 0   // 0 = nicht aktiv
    @AppStorage("fastingGoalHours") private var goalHours: Int = 16
    @State private var now = Date()

    private let presets = [14, 16, 18, 20]   // Fasten-Stunden; Essensfenster = 24 − x

    private var isFasting: Bool { startEpoch > 0 }
    private var elapsed: TimeInterval { isFasting ? max(0, now.timeIntervalSince1970 - startEpoch) : 0 }
    private var goal: TimeInterval { Double(goalHours) * 3600 }
    private var progress: Double { goal > 0 ? min(elapsed / goal, 1) : 0 }
    private var reached: Bool { elapsed >= goal }
    private var endDate: Date { Date(timeIntervalSince1970: startEpoch + goal) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Intervallfasten", systemImage: "timer").font(.headline)
                Spacer()
                Text("\(goalHours):\(24 - goalHours)").font(.caption).foregroundStyle(.secondary)
            }

            if isFasting {
                HStack(spacing: 16) {
                    ZStack {
                        Circle().stroke(Color(.systemGray5), lineWidth: 8)
                        Circle().trim(from: 0, to: progress)
                            .stroke(reached ? Color.green : Theme.accent,
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.4), value: progress)
                        Text("\(Int(progress * 100))%").font(.caption.weight(.semibold)).monospacedDigit()
                    }
                    .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(hm(elapsed)).font(.title2.weight(.bold)).monospacedDigit()
                        Text(reached
                             ? "fasting.goal_reached".localized()
                             : "Ziel um \(endDate.formatted(date: .omitted, time: .shortened)) (\(goalHours) h)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                Button(role: .destructive) { startEpoch = 0 } label: {
                    Text("fasting.end".localized()).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                Picker("fasting.protocol".localized(), selection: $goalHours) {
                    ForEach(presets, id: \.self) { Text("\($0):\(24 - $0)").tag($0) }
                }
                .pickerStyle(.segmented)
                Button { startEpoch = Date().timeIntervalSince1970 } label: {
                    Label("Fasten starten", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
        .onAppear { now = Date() }
    }

    private func hm(_ seconds: TimeInterval) -> String {
        let m = Int(seconds / 60)
        return "\(m / 60) h \(m % 60) min"
    }
}
