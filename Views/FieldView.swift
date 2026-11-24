import SwiftUI

struct FieldView: View {
    let items: [DoAvoidItem]
    let day: CivilDay
    var skin = ProgressionSkin()
    var projection: (DoAvoidItem, CivilDay) -> Progression? = { _, _ in nil }
    var onAdd: (() -> Void)?
    let onToggle: (UUID) -> Void

    var body: some View {
        GeometryReader { geometry in
            let visible = items.filter { $0.createdDay <= day }
            let available = geometry.size.height - (onAdd == nil ? 0 : 76)
            let rowHeight = max(84, available / CGFloat(max(1, visible.count)))

            VStack(spacing: 0) {
                if visible.isEmpty {
                    EmptyStateView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(visible) { item in
                                let progression = projection(item, day)
                                Button {
                                    onToggle(item.id)
                                } label: {
                                    BarView(
                                        title: item.title,
                                        color: skin.fill(for: item.kind, progression: progression),
                                        status: item.status(on: day),
                                        progression: progression,
                                        archived: item.isRetired
                                    )
                                    .frame(minHeight: rowHeight)
                                }
                                .buttonStyle(.plain)
                                .disabled(item.isRetired)
                                Divider()
                            }
                        }
                    }
                }

                if let onAdd {
                    Button(action: onAdd) {
                        Text("Add New +")
                            .font(.system(.title, design: .rounded).weight(.semibold))
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity, minHeight: 76)
                    }
                    .buttonStyle(.plain)
                    .background(.background)
                }
            }
        }
    }
}
