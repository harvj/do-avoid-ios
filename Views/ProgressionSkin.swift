import SwiftUI

struct ProgressionSkin {
    var doColor: Color = .yellow
    var avoidColor: Color = .gray
    var highStrengthOpacity = 0.72

    func fill(for kind: DoAvoidKind, progression: Progression?) -> Color {
        let color = kind == .doItem ? doColor : avoidColor
        guard let progression else { return color.opacity(kind == .doItem ? 0.45 : 0.25) }
        return color.opacity(0.14 + progression.strength * (highStrengthOpacity - 0.14))
    }
}

extension DailyStatus {
    var label: String {
        switch self {
        case .outsideLifetime: return "Before creation"
        case .neutral: return "Unmarked"
        case .completed: return "Completed"
        case .successful: return "No violation marked"
        case .violated: return "Violated"
        }
    }

    var symbol: String {
        switch self {
        case .outsideLifetime: return "minus"
        case .neutral: return "circle"
        case .completed, .successful: return "checkmark"
        case .violated: return "xmark"
        }
    }
}
