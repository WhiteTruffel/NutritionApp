import SwiftUI
import HealthKit

struct HRVMeasurementView: View {
    @State private var isMonitoring = false
    @State private var hrvValue: Double? = nil
    @State private var advice: String = ""
    @State private var adviceColor: Color = .gray
    let health = NutritionHealthStore()

    var body: some View {
        VStack(spacing: 24) {
            Text("hrv.title".localized())
                .font(.title2.weight(.bold))

            if let hrv = hrvValue {
                VStack(spacing: 12) {
                    HRVGauge(value: hrv)
                        .frame(height: 200)

                    VStack(spacing: 4) {
                        Text(String(format: "%.1f ms", hrv))
                            .font(.headline.weight(.semibold))
                        Text("Heart Rate Variability")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !advice.isEmpty {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(adviceColor)
                                Text(advice)
                                    .font(.body)
                                    .lineLimit(3)
                            }
                            .padding(12)
                            .background(adviceColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    Button {
                        resetMeasurement()
                    } label: {
                        Label("hrv.measure".localized(), systemImage: "arrow.clockwise")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                }
            } else {
                VStack(spacing: 24) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.red)

                    VStack(spacing: 12) {
                        Text("hrv.title".localized())
                            .font(.headline.weight(.semibold))

                        Text("Place your finger on the camera for 30 seconds. Stay still and maintain good contact.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: startMeasurement) {
                        HStack(spacing: 8) {
                            if isMonitoring {
                                ProgressView()
                                    .tint(.white)
                                Text("hrv.measuring".localized())
                            } else {
                                Image(systemName: "camera.fill")
                                Text("hrv.measure".localized())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                    }
                    .disabled(isMonitoring)
                }
            }

            Spacer()
        }
        .padding(20)
    }

    private func startMeasurement() {
        isMonitoring = true

        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // Simulate 5-second capture

            let simulatedHRV = Double.random(in: 30...120)
            await MainActor.run {
                hrvValue = simulatedHRV
                advice = getAdvice(for: simulatedHRV)
                adviceColor = colorForAdvice(simulatedHRV)
                isMonitoring = false

                // Save to HealthKit
                Task {
                    try? await health.saveHRVSample(hrv: simulatedHRV)
                }
            }
        }
    }

    private func resetMeasurement() {
        hrvValue = nil
        advice = ""
        adviceColor = .gray
    }

    private func getAdvice(for hrv: Double) -> String {
        if hrv > 75 {
            return "hrv.advice.great".localized()
        } else if hrv > 50 {
            return "hrv.advice.good".localized()
        } else if hrv > 25 {
            return "hrv.advice.moderate".localized()
        } else {
            return "hrv.advice.rest".localized()
        }
    }

    private func colorForAdvice(_ hrv: Double) -> Color {
        if hrv > 75 { return .green }
        if hrv > 50 { return .blue }
        if hrv > 25 { return .orange }
        return .red
    }
}

struct HRVGauge: View {
    let value: Double
    let maxValue: Double = 150

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray4), lineWidth: 12)

            Circle()
                .trim(from: 0, to: min(value / maxValue, 1))
                .stroke(
                    LinearGradient(gradient: Gradient(colors: [.red, .orange, .green]), startPoint: .bottomLeading, endPoint: .topTrailing),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: value)

            VStack(spacing: 4) {
                Text(String(format: "%.0f", value))
                    .font(.title.weight(.bold))
                Text("ms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    HRVMeasurementView()
}
