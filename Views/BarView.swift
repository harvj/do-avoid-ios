import SwiftUI

struct BarView: View {
    let title: String
    let color: Color
    let status: DailyStatus
    let progression: Progression?
    let archived: Bool
    let kind: DoAvoidKind?
    let forecast: ProgressionForecast?
    let showsForecastUnavailable: Bool

    private var typeLabel: String? {
        kind.map { $0 == .doItem ? "Do" : "Avoid" }
    }

    private var forecastLabel: String? {
        guard let forecast else {
            return showsForecastUnavailable ? "No next milestone forecast" : nil
        }
        let days = forecast.days.formatted()
        let unit = forecast.days == 1 ? "day" : "days"
        switch forecast.milestone {
        case .doCycle:
            return "Estimated \(days) \(unit) to the next 40-completion cycle with daily completion"
        case .avoid(let state):
            return "Estimated \(days) \(unit) to the \(state.rawValue) milestone without another violation"
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(.title, design: .rounded).weight(.semibold))
                .textCase(.uppercase)
                .multilineTextAlignment(.center)
            if status != .neutral {
                Image(systemName: status.symbol)
                    .foregroundStyle(status == .violated ? Color.red : Color.primary)
                    .accessibilityHidden(true)
            }
            if archived || progression?.mature == true {
                Text(archived ? "Archived" : "Mature")
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, typeLabel != nil || forecast != nil || showsForecastUnavailable ? 54 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(color)
        .overlay(alignment: .topLeading) {
            if let typeLabel {
                Text(typeLabel.uppercased())
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.primary.opacity(0.83))
                    .dynamicTypeSize(...DynamicTypeSize.large)
                    .padding(12)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .topTrailing) {
            if forecast != nil || showsForecastUnavailable {
                ZStack {
                    Circle().strokeBorder(.primary.opacity(0.24), lineWidth: 1.5)
                    if let forecast {
                        Circle().trim(from: 0, to: forecast.fraction)
                            .stroke(.primary.opacity(0.82), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .padding(0.75)
                    }
                    Text(forecast.map { $0.days.formatted() } ?? "–")
                        .font(.system(.caption, design: .rounded).weight(.semibold).monospacedDigit())
                        .dynamicTypeSize(...DynamicTypeSize.large)
                }
                .frame(width: 34, height: 34)
                .padding(12)
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(typeLabel.map { "\($0), \(title)" } ?? title)
        .accessibilityValue([status.label, archived ? "Archived" : (progression?.mature == true ? "Mature" : nil), forecastLabel]
            .compactMap { $0 }.joined(separator: ", "))
    }
}
