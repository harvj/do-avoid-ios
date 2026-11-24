#if DOAVOID_LAB && DOAVOID_PRODUCTION
#error("Progression Lab must be excluded from production builds")
#endif
#if DOAVOID_LAB
import SwiftUI

enum LabScenario: String, CaseIterable, Identifiable {
    case newDo = "New Do"
    case regular = "Regular Do"
    case intermittent = "Intermittent Do"
    case abandoned = "Abandoned Do"
    case noViolations = "Avoid · no violations"
    case occasional = "Avoid · occasional violations"
    case frequent = "Avoid · frequent violations"
    case recovering = "Recovering Avoid"
    case lifecycle = "Mature · archive · reactivate"

    static let reference = CivilDay(containing: Date(timeIntervalSince1970: 1_735_689_600), in: CivilDay.utc)

    var id: Self { self }

    var age: Int {
        switch self {
        case .newDo: return 0
        case .regular: return 90
        case .intermittent: return 42
        case .abandoned: return 240
        case .noViolations: return 730
        case .occasional: return 56
        case .frequent: return 20
        case .recovering: return 70
        case .lifecycle: return 600
        }
    }

    private var kind: DoAvoidKind {
        switch self {
        case .newDo, .regular, .intermittent, .abandoned, .lifecycle: return .doItem
        case .noViolations, .occasional, .frequent, .recovering: return .avoidItem
        }
    }

    func makeItem() -> DoAvoidItem {
        let index = Self.allCases.firstIndex(of: self)!
        let created = Self.reference.advanced(by: -age)
        let createdAt = Date(timeIntervalSince1970: 1_735_689_600 - Double(age) * 86_400)
        let entries = (0...age).reduce(into: [CivilDay: DayEntry]()) { entries, offset in
            guard hasMark(offset) else { return }
            let day = created.advanced(by: offset)
            entries[day] = DayEntry(id: fixtureID(index, offset), day: day, isMarked: true)
        }
        return DoAvoidItem(
            id: fixtureID(index, 9999), title: rawValue, kind: kind, createdAt: createdAt,
            createdDay: created, entries: entries, isRetired: false
        )
    }

    func isArchived(on day: CivilDay) -> Bool {
        self == .lifecycle && day >= Self.reference.advanced(by: -65) && day < Self.reference.advanced(by: -8)
    }

    private func hasMark(_ offset: Int) -> Bool {
        switch self {
        case .newDo, .noViolations: return false
        case .regular: return offset % 7 < 5
        case .intermittent: return offset % 8 == 0 || offset % 13 == 0
        case .abandoned: return offset < 60 && offset % 3 != 1
        case .occasional: return offset % 12 == 0
        case .frequent: return offset % 4 != 1
        case .recovering: return (38...62).contains(offset) && offset % 5 != 0
        case .lifecycle: return (offset < 535 || offset >= 592) && offset % 7 < 6
        }
    }

    private func fixtureID(_ index: Int, _ offset: Int) -> UUID {
        UUID(uuidString: String(format: "F10A0000-0000-4000-8000-%04d%08d", index, offset))!
    }
}

struct ProgressionLab: View {
    private enum Surface: String, CaseIterable { case field = "Field", timeline = "Timeline" }
    private enum Palette: String, CaseIterable {
        case classic = "Yellow & gray", garden = "Teal & plum", mineral = "Blue & orange"

        var colors: (Color, Color) {
            switch self {
            case .classic: return (.yellow, .gray)
            case .garden: return (.teal, .purple)
            case .mineral: return (.blue, .orange)
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var history = LabScenario.allCases.map { $0.makeItem() }
    @State private var scenario = LabScenario.regular
    @State private var surface = Surface.field
    @State private var candidate = ProgressionCandidate.recent
    @State private var palette = Palette.classic
    @State private var parameters = ProgressionParameters()
    @State private var intensity = 0.72
    @State private var offset = 0.0
    @State private var showTuning = false
    @State private var showAll = false

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--lab-timeline") { _surface = State(initialValue: .timeline) }
        if arguments.contains("--lab-momentum") { _candidate = State(initialValue: .recovery) }
        if arguments.contains("--lab-all") { _showAll = State(initialValue: true) }
        if arguments.contains("--lab-recovery") {
            _scenario = State(initialValue: .recovering)
            _palette = State(initialValue: .garden)
        }
        if arguments.contains("--lab-archive") {
            _scenario = State(initialValue: .lifecycle)
            _offset = State(initialValue: -30)
        }
    }

    private var day: CivilDay { LabScenario.reference.advanced(by: Int(offset)) }
    private var selectedIndex: Int { LabScenario.allCases.firstIndex(of: scenario)! }

    private var displayedItems: [DoAvoidItem] {
        let indexes = showAll ? Array(history.indices) : [selectedIndex]
        return indexes.map { index in
            var item = history[index]
            item.isRetired = LabScenario.allCases[index].isArchived(on: day)
            return item
        }
    }

    private func projection(_ item: DoAvoidItem, on day: CivilDay) -> Progression? {
        guard var state = candidate.project(item, on: day, using: parameters),
              let index = history.firstIndex(where: { $0.id == item.id }) else { return nil }
        state.archived = LabScenario.allCases[index].isArchived(on: day)
        return state
    }

    var body: some View {
        NavigationStack {
            Group {
                if verticalSizeClass == .compact {
                    HStack(spacing: 16) {
                        ScrollView { controls }.frame(width: 270)
                        preview
                    }
                } else {
                    VStack(spacing: 10) {
                        controls
                        preview
                    }
                }
            }
            .padding(.horizontal)
            .navigationTitle("Progression Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Tune") { showTuning = true } }
            }
            .sheet(isPresented: $showTuning) { tuning }
            .onChange(of: scenario) { _ in offset = 0 }
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack {
                Picker("Scenario", selection: $scenario) {
                    ForEach(LabScenario.allCases) { Text($0.rawValue).tag($0) }
                }
                Spacer()
                Toggle("All items", isOn: $showAll).fixedSize()
            }
            HStack {
                Button { offset = max(-730, offset - 1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Previous day")
                Spacer()
                Text(day.formatted()).font(.subheadline.monospacedDigit())
                Spacer()
                Button { offset = min(180, offset + 1) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("Next day")
            }
            Slider(value: $offset, in: -730...180, step: 1) { Text("Simulated day") }
                .accessibilityValue(day.formatted())
            Picker("Candidate", selection: $candidate) {
                ForEach(ProgressionCandidate.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Surface", selection: $surface) {
                ForEach(Surface.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            if !showAll, let result = projection(history[selectedIndex], on: day) {
                Text("Strength \(result.strength, format: .percent.precision(.fractionLength(0)))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var preview: some View {
        let colors = palette.colors
        let skin = ProgressionSkin(doColor: colors.0, avoidColor: colors.1, highStrengthOpacity: intensity)
        switch surface {
        case .field:
            FieldView(items: displayedItems, day: day, skin: skin, projection: projection) { id in
                if let index = history.firstIndex(where: { $0.id == id }) {
                    history[index].toggleMarked(on: day)
                }
            }
        case .timeline:
            TimelineView(items: displayedItems, day: day, skin: skin, projection: projection)
        }
    }

    private var tuning: some View {
        NavigationStack {
            Form {
                Section("Behavior") {
                    Stepper("Activity window: \(Int(parameters.window)) days", value: $parameters.window, in: 3...90)
                    Stepper("Momentum horizon: \(Int(parameters.recovery)) days", value: $parameters.recovery, in: 2...60)
                    Stepper("Maturity age: \(Int(parameters.maturityAge)) days", value: $parameters.maturityAge, in: 7...730, step: 7)
                    VStack(alignment: .leading) {
                        Text("Maturity strength: \(parameters.maturityStrength, format: .percent.precision(.fractionLength(0)))")
                        Slider(value: $parameters.maturityStrength, in: 0.1...1, step: 0.05) { Text("Maturity strength") }
                    }
                }
                Section("Skin") {
                    Picker("Palette", selection: $palette) {
                        ForEach(Palette.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Slider(value: $intensity, in: 0.2...1) { Text("Color intensity") }
                }
                Section("Scenario") {
                    Button("Reset examples") {
                        history = LabScenario.allCases.map { $0.makeItem() }
                        offset = 0
                    }
                    if scenario == .lifecycle {
                        Button("Jump to archived") { offset = -30 }
                        Button("Jump to reactivation") { offset = -8 }
                    }
                }
            }
            .navigationTitle("Tune Progression")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showTuning = false } } }
        }
    }
}

#Preview("Progression Lab") { ProgressionLab() }
#endif
