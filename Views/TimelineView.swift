import SwiftUI

struct TimelineView: View {
    let items: [DoAvoidItem]
    let day: CivilDay
    var skin = ProgressionSkin()
    var projection: (DoAvoidItem, CivilDay) -> Progression? = { _, _ in nil }
    @State private var page = 0

    private var days: [CivilDay] {
        (0..<14).reversed().map { day.advanced(by: -page * 14 - $0) }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button { page += 1 } label: { Label("Earlier", systemImage: "chevron.left") }
                    .disabled(days.first.map { first in !items.contains { $0.createdDay < first } } ?? true)
                Spacer()
                Button { page -= 1 } label: { Label("Later", systemImage: "chevron.right") }
                    .disabled(page == 0)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            GeometryReader { viewport in
                ScrollView([.vertical, .horizontal]) {
                    Grid(alignment: .leading, horizontalSpacing: 5, verticalSpacing: 5) {
                        GridRow {
                            Text("Item").font(.caption)
                            ForEach(days, id: \.self) { date in
                                Text(date.formatted(includeYear: false))
                                    .font(.caption2)
                                    .frame(width: 70, height: 38)
                            }
                        }
                        ForEach(items.filter { $0.createdDay <= day }) { item in
                            GridRow {
                                Text(item.title)
                                    .font(.callout.weight(.semibold))
                                    .frame(width: 115, alignment: .leading)
                                ForEach(days, id: \.self) { date in
                                    let status = item.status(on: date)
                                    let progression = projection(item, date)
                                    Image(systemName: status.symbol)
                                        .foregroundStyle(status == .violated ? Color.red : Color.primary)
                                        .frame(width: 70, height: 38)
                                        .background {
                                            if status != .outsideLifetime {
                                                RoundedRectangle(cornerRadius: 5)
                                                    .fill(skin.fill(for: item.kind, progression: progression))
                                            }
                                        }
                                        .overlay(alignment: .topTrailing) {
                                            if progression?.archived == true || progression?.mature == true {
                                                Image(systemName: progression?.archived == true ? "archivebox" : "seal").font(.caption2).padding(3)
                                            }
                                        }
                                        .accessibilityLabel("\(item.title), \(date.formatted())")
                                        .accessibilityValue([status.label, progression?.archived == true ? "Archived" : (progression?.mature == true ? "Mature" : nil)].compactMap { $0 }.joined(separator: ", "))
                                }
                            }
                        }
                    }
                    .padding([.horizontal, .bottom])
                    .frame(minWidth: viewport.size.width, minHeight: viewport.size.height, alignment: .topLeading)
                }
            }
        }
        .onChange(of: day) { _ in page = 0 }
    }
}
