import ReadinessCore
import SwiftUI

extension ReadinessBand {
    var title: LocalizedStringKey {
        switch self {
        case .low: "Low"
        case .fair: "Fair"
        case .good: "Good"
        case .high: "High"
        }
    }

    var tint: Color {
        switch self {
        case .low: .red
        case .fair: .orange
        case .good: .green
        case .high: .mint
        }
    }
}

extension ReadinessConfidence {
    var caption: LocalizedStringKey {
        switch self {
        case .low: "Still learning your baseline"
        case .medium: "Baseline is still filling in"
        case .high: "Based on a full baseline"
        }
    }
}

extension ReadinessMetric {
    var title: LocalizedStringKey {
        switch self {
        case .heartRateVariability: "Heart rate variability"
        case .restingHeartRate: "Resting heart rate"
        case .sleep: "Sleep"
        }
    }

    var unit: String {
        switch self {
        case .heartRateVariability: "ms"
        case .restingHeartRate: "bpm"
        case .sleep: "h"
        }
    }
}

extension ReadinessFactor {
    var detail: String {
        let today = "\(Int(todayValue.rounded()))\(metric.unit)"

        guard let baselineMean else {
            return today
        }

        let difference = todayValue - baselineMean
        let direction = difference >= 0 ? "above" : "below"
        return "\(today) — \(abs(Int(difference.rounded())))\(metric.unit) \(direction) your average"
    }
}

extension InsufficientDataReason {
    var explanation: LocalizedStringKey {
        switch self {
        case .noDataToday:
            "Nothing was recorded today. Either Bearing has no access to Health, or your devices haven't logged anything yet."
        case .baselineTooShort:
            "A baseline needs at least a week of readings. Check back in a few days."
        case .notEnoughSignalWeight:
            "Sleep alone isn't enough to score a day. Heart rate variability or resting heart rate is needed too."
        }
    }
}
