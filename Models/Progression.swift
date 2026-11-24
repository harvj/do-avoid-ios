import Foundation

struct Progression: Equatable {
    var strength: Double
    var mature: Bool
    var archived = false
}

#if DOAVOID_LAB
enum ProgressionCandidate: String, CaseIterable, Identifiable {
    case recent = "Recent activity"
    case recovery = "Momentum"

    var id: Self { self }
}

struct ProgressionParameters {
    var window = 21.0
    var recovery = 10.0
    var maturityAge = 60.0
    var maturityStrength = 0.7
}

extension ProgressionCandidate {
    func project(_ item: DoAvoidItem, on day: CivilDay, using parameters: ProgressionParameters) -> Progression? {
        guard day >= item.createdDay else { return nil }
        let age = item.createdDay.distance(to: day)
        let window = max(1, Int(parameters.window))
        let days = min(age + 1, window)
        let horizon = max(1, parameters.recovery)
        let lookback = self == .recent ? window - 1 : Int(horizon.rounded(.up)) - 1
        let firstDay = max(item.createdDay, day.advanced(by: -lookback))
        let markedAges = item.entries.values.compactMap { entry -> Int? in
            guard entry.isMarked, entry.day >= firstDay, entry.day <= day else { return nil }
            return entry.day.distance(to: day)
        }

        let strength: Double
        switch self {
        case .recent:
            let frequency = Double(markedAges.count) / Double(days)
            strength = item.kind == .doItem ? frequency : 1 - frequency
        case .recovery:
            let weighted = Double(markedAges.count) - Double(markedAges.reduce(0, +)) / horizon
            switch item.kind {
            case .doItem:
                strength = min(1, weighted / max(1, horizon / 2))
            case .avoidItem:
                strength = max(0, 1 - weighted)
            }
        }

        return Progression(
            strength: strength,
            mature: Double(age) >= parameters.maturityAge && strength >= parameters.maturityStrength
        )
    }
}
#endif
