import Foundation

enum DailyStatus: Equatable {
    case outsideLifetime
    case neutral
    case completed
    case successful
    case violated
}

struct DoAvoidItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    let kind: DoAvoidKind
    let createdAt: Date
    let createdDay: CivilDay
    private(set) var entries: [CivilDay: DayEntry]
    var isRetired: Bool

    init(
        title: String,
        kind: DoAvoidKind,
        createdAt: Date = Date(),
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        self.init(
            id: UUID(), title: title, kind: kind, createdAt: createdAt,
            createdDay: CivilDay(containing: createdAt, in: timeZone), entries: [:], isRetired: false
        )
    }

    init(
        id: UUID, title: String, kind: DoAvoidKind, createdAt: Date,
        createdDay: CivilDay, entries: [CivilDay: DayEntry], isRetired: Bool
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.createdAt = createdAt
        self.createdDay = createdDay
        self.entries = entries
        self.isRetired = isRetired
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, kind, createdAt, createdDay, entries, isRetired
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let records = try container.decode([DayEntry].self, forKey: .entries)
        var entries: [CivilDay: DayEntry] = [:]
        var ids: Set<UUID> = []
        for entry in records {
            guard entries[entry.day] == nil, ids.insert(entry.id).inserted else {
                throw DecodingError.dataCorruptedError(
                    forKey: .entries, in: container, debugDescription: "Duplicate day or entry ID"
                )
            }
            entries[entry.day] = entry
        }
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            title: try container.decode(String.self, forKey: .title),
            kind: try container.decode(DoAvoidKind.self, forKey: .kind),
            createdAt: try container.decode(Date.self, forKey: .createdAt),
            createdDay: try container.decode(CivilDay.self, forKey: .createdDay),
            entries: entries,
            isRetired: try container.decode(Bool.self, forKey: .isRetired)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(kind, forKey: .kind)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(createdDay, forKey: .createdDay)
        try container.encode(allEntriesSorted, forKey: .entries)
        try container.encode(isRetired, forKey: .isRetired)
    }

    var allEntriesSorted: [DayEntry] {
        entries.values.sorted { $0.day < $1.day }
    }

    var markedDays: Int {
        entries.values.filter { $0.isMarked }.count
    }

    func status(on day: CivilDay) -> DailyStatus {
        let entry = entries[day]
        guard entry != nil || day >= createdDay else { return .outsideLifetime }
        let marked = entry?.isMarked ?? false
        switch kind {
        case .doItem: return marked ? .completed : .neutral
        case .avoidItem: return marked ? .violated : .successful
        }
    }

    mutating func toggleMarked(on day: CivilDay) {
        var entry = entries[day] ?? DayEntry(day: day)
        entry.isMarked.toggle()
        entries[day] = entry
    }

    mutating func updateEntry(on day: CivilDay, isMarked: Bool, note: String?, count: Int?) {
        entries[day] = DayEntry(
            id: entries[day]?.id ?? UUID(), day: day, isMarked: isMarked, note: note, count: count
        )
    }
}

extension DoAvoidItem {
    static let doCycleLength = 40

    var progressUnits: Int {
        kind == .doItem ? markedDays : 0
    }

    var completedCycles: Int { progressUnits / Self.doCycleLength }
    var targetPhase: Int { progressUnits % Self.doCycleLength }

    func missedDays(until day: CivilDay) -> Int {
        guard day >= createdDay else { return 0 }
        let recordedDays = entries.keys.filter { $0 >= createdDay && $0 <= day }.count
        return createdDay.distance(to: day) + 1 - recordedDays
    }

    // Existing prototype thresholds. P0.3 discovery will evaluate candidate rules separately.
    func avoidState(asOf day: CivilDay) -> AvoidState {
        guard kind == .avoidItem else { return .solid }
        return AvoidState(elapsed: daysSinceViolationOrCreation(asOf: day))
    }

    func daysSinceViolationOrCreation(asOf day: CivilDay) -> Int {
        let lastViolation = entries.values.filter { $0.isMarked && $0.day <= day }.map(\.day).max()
        return max(0, (lastViolation ?? createdDay).distance(to: day))
    }

    mutating func checkForRetirement(asOf day: CivilDay) {
        if avoidState(asOf: day) == .overgrown { isRetired = true }
    }
}
