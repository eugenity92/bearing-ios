import Sharing
import SwiftUI

struct RootView: View {
    @Shared(.hasRequestedHealthAccess) private var hasRequestedHealthAccess: Bool

    var body: some View {
        if hasRequestedHealthAccess {
            TodayView()
        } else {
            HealthAccessView()
        }
    }
}

#Preview {
    RootView()
}
