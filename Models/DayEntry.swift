import Foundation

struct DayEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let day: CivilDay

    /// A completion for Do and a violation for Avoid.
    var isMarked: Bool
    var note: String?
    var count: Int?

    init(id: UUID = UUID(), day: CivilDay, isMarked: Bool = false, note: String? = nil, count: Int? = nil) {
        self.id = id
        self.day = day
        self.isMarked = isMarked
        self.note = note
        self.count = count
    }
}
