import Foundation

/// A Gregorian date label. Only converting an instant to a label needs a time zone.
struct CivilDay: Codable, Hashable, Comparable {
    static let utc = TimeZone(secondsFromGMT: 0)!
    private static let utcCalendar = calendar(in: utc)

    private let stamp: Int

    init(containing instant: Date, in timeZone: TimeZone = .autoupdatingCurrent) {
        let parts = Self.calendar(in: timeZone).dateComponents([.year, .month, .day], from: instant)
        stamp = parts.year! * 10_000 + parts.month! * 100 + parts.day!
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        stamp = try container.decode(Int.self)
        guard (10101...99991231).contains(stamp),
              let date = Self.utcCalendar.date(from: components),
              Self(containing: date, in: Self.utc).stamp == stamp else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid Gregorian day")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stamp)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.stamp < rhs.stamp
    }

    func advanced(by days: Int) -> Self {
        let date = Self.utcCalendar.date(byAdding: .day, value: days, to: utcDate)!
        return Self(containing: date, in: Self.utc)
    }

    func distance(to day: Self) -> Int {
        Self.utcCalendar.dateComponents([.day], from: utcDate, to: day.utcDate).day!
    }

    func formatted(includeYear: Bool = true) -> String {
        var style = includeYear
            ? Date.FormatStyle(date: .abbreviated, time: .omitted)
            : Date.FormatStyle().month(.abbreviated).day()
        style.calendar = Self.utcCalendar
        style.timeZone = Self.utc
        return utcDate.formatted(style)
    }

    private var components: DateComponents {
        DateComponents(year: stamp / 10_000, month: stamp / 100 % 100, day: stamp % 100)
    }

    private var utcDate: Date {
        Self.utcCalendar.date(from: components)!
    }

    private static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
