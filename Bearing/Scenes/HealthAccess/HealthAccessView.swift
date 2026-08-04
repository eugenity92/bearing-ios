import SwiftUI

struct HealthAccessView: View {
    @State private var model = HealthAccessModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ContentView(model: model)
        }
    }
}

private struct ContentView: View {
    let model: HealthAccessModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "heart.text.square")
                .font(.system(size: 56))
                .foregroundStyle(.mint)
                .padding(.bottom, 24)

            Text("Bearing reads three things")
                .font(.title2.weight(.semibold))
                .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 14) {
                ExplanationRow(
                    title: "Heart rate variability",
                    detail: "The strongest signal, compared against your own 28-day average."
                )
                ExplanationRow(
                    title: "Resting heart rate",
                    detail: "Lower than your baseline usually means recovered."
                )
                ExplanationRow(
                    title: "Sleep",
                    detail: "Total time asleep, merged across every source that recorded it."
                )
            }
            .padding(.bottom, 24)

            Text("Nothing leaves your device. Bearing has no account and no server.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            if model.didFail {
                Text("Health access couldn't be requested. You can grant it later in Settings › Health › Data Access & Devices.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 12)
            }

            Button {
                Task(operation: model.requestAccess)
            } label: {
                if model.isRequesting {
                    ProgressView().tint(.black)
                } else {
                    Text("Continue")
                        .font(.headline)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.mint)
            .controlSize(.large)
            .disabled(model.isRequesting || !model.isHealthDataAvailable)

            if !model.isHealthDataAvailable {
                Text("Health data isn't available on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)

                Button("Continue anyway", action: model.continueWithoutHealthData)
                    .font(.footnote)
                    .padding(.top, 4)
            }
        }
        .padding(28)
    }
}

private struct ExplanationRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(.mint)
                .frame(width: 6, height: 6)
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    HealthAccessView()
}
