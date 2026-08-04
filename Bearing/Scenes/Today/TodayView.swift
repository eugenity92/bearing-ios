import SwiftUI

struct TodayView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ContentView()
        }
    }
}

private struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Bearing")
                .font(.largeTitle.weight(.semibold))
            Text("Readiness, grounded in your own baseline.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    TodayView()
}
