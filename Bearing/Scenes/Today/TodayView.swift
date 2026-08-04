import ReadinessCore
import SwiftUI

struct TodayView: View {
    @State private var model = TodayModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ContentView(model: model)
        }
        .task(model.onViewAppear)
    }
}

private struct ContentView: View {
    let model: TodayModel

    var body: some View {
        switch model.state {
        case .loading:
            ProgressView().tint(.white)
        case .loadFailed:
            FailureView(model: model)
        case .loaded(let readiness, let trend):
            ScrollView {
                VStack(spacing: 24) {
                    ReadinessSection(readiness: readiness)
                    if !trend.isEmpty {
                        TrendStrip(trend: trend)
                    }
                    OutdoorCard(conditions: model.conditions, isUnavailable: model.isConditionsUnavailable)
                    DisclaimerFooter()
                }
                .padding(20)
            }
        }
    }
}

private struct FailureView: View {
    let model: TodayModel

    var body: some View {
        VStack(spacing: 12) {
            Text("Couldn't read your health data")
                .font(.headline)
            Text("Bearing needs access to heart rate variability, resting heart rate and sleep.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try again") {
                Task(operation: model.retry)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
}

private struct ReadinessSection: View {
    let readiness: ReadinessResult

    var body: some View {
        switch readiness {
        case .score(let score):
            VStack(spacing: 16) {
                ScoreRing(score: score)
                ForEach(score.factors, id: \.metric) { factor in
                    FactorRow(factor: factor)
                }
            }
        case .insufficientData(let reason):
            InsufficientDataView(reason: reason)
        }
    }
}

private struct ScoreRing: View {
    let score: ReadinessScore

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: CGFloat(score.value) / 100)
                    .stroke(score.band.tint, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(score.value)")
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
            }
            .frame(width: 180, height: 180)

            Text(score.band.title)
                .font(.title3.weight(.medium))

            if score.confidence != .high {
                Text(score.confidence.caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct FactorRow: View {
    let factor: ReadinessFactor

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(factor.metric.title)
                    .font(.subheadline.weight(.medium))
                Text(factor.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(factor.componentScore.rounded()))")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct InsufficientDataView: View {
    let reason: InsufficientDataReason

    var body: some View {
        VStack(spacing: 10) {
            Text("Not enough data yet")
                .font(.headline)
            Text(reason.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct TrendStrip: View {
    let trend: [DatedScore]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Last \(trend.count) days")
                .font(.subheadline.weight(.medium))
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(trend, id: \.day) { point in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ReadinessBand(score: point.value).tint)
                        .frame(height: max(6, CGFloat(point.value) * 0.72))
                }
            }
            .frame(height: 72)
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct OutdoorCard: View {
    let conditions: OutdoorConditions?
    let isUnavailable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Outside")
                .font(.subheadline.weight(.medium))

            if let conditions {
                HStack(spacing: 18) {
                    if let temperature = conditions.temperature {
                        Measurement(title: "Feels", value: "\(Int((conditions.apparentTemperature ?? temperature).rounded()))°")
                    }
                    if let aqi = conditions.europeanAQI {
                        Measurement(title: "AQI", value: "\(Int(aqi.rounded()))")
                    }
                    if let uv = conditions.uvIndex {
                        Measurement(title: "UV", value: "\(Int(uv.rounded()))")
                    }
                }
            } else if isUnavailable {
                Text("Location off, so conditions aren't available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView().tint(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct Measurement: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.medium).monospacedDigit())
        }
    }
}

private struct DisclaimerFooter: View {
    var body: some View {
        Text("A heuristic compared against your own recent averages. Not a medical device, and not validated against any outcome.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
    }
}

#Preview {
    TodayView()
}
