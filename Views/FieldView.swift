import SwiftUI

struct FieldIndicatorSettings: DynamicProperty {
    @AppStorage private var typeLabels: Bool
    @AppStorage private var clocks: Bool

    init(store: UserDefaults? = nil) {
        _typeLabels = AppStorage(wrappedValue: true, "field.showsTypeLabels", store: store)
        _clocks = AppStorage(wrappedValue: true, "field.showsClocks", store: store)
    }

    var showsTypeLabels: Bool {
        get { typeLabels }
        nonmutating set { typeLabels = newValue }
    }

    var showsClocks: Bool {
        get { clocks }
        nonmutating set { clocks = newValue }
    }
}

struct FieldView: View {
    let items: [DoAvoidItem]
    let day: CivilDay
    var skin = ProgressionSkin()
    var projection: (DoAvoidItem, CivilDay) -> Progression? = { _, _ in nil }
    var showsTypeLabels = true
    var showsClocks = true
    var onAdd: (() -> Void)?
    var onDisplaySettings: (() -> Void)?
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
                                        archived: item.isRetired,
                                        kind: showsTypeLabels ? item.kind : nil,
                                        forecast: showsClocks ? ProgressionForecast.estimate(for: item, on: day) : nil,
                                        showsForecastUnavailable: showsClocks && !item.isRetired
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
                    HStack(spacing: 0) {
                        if onDisplaySettings != nil {
                            Color.clear.frame(width: 48, height: 48).accessibilityHidden(true)
                        }
                        Button(action: onAdd) {
                            Text("Add New +")
                                .font(.system(.title, design: .rounded).weight(.semibold))
                                .textCase(.uppercase)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, minHeight: 76)
                                .contentShape(Rectangle())
                        }
                        if let onDisplaySettings {
                            Button(action: onDisplaySettings) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.body.weight(.medium))
                                    .frame(width: 48, height: 48)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityLabel("Field display settings")
                        }
                    }
                    .buttonStyle(.plain)
                    .background(.background)
                }
            }
        }
    }
}
