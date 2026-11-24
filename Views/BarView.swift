import SwiftUI

struct BarView: View {
    let title: String
    let color: Color
    let status: DailyStatus
    let progression: Progression?
    let archived: Bool

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
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue([status.label, archived ? "Archived" : (progression?.mature == true ? "Mature" : nil)]
            .compactMap { $0 }.joined(separator: ", "))
    }
}
