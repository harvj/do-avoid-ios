import XCTest
@testable import DoAvoid

final class CivilDayTests: XCTestCase {
    private let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    func testSpringAndFallDayBoundariesUseCalendarDays() throws {
        let springStart = try instant("2024-03-10T08:00:00Z")
        let springNext = try instant("2024-03-11T07:00:00Z")
        let fallStart = try instant("2024-11-03T07:00:00Z")
        let fallNext = try instant("2024-11-04T08:00:00Z")

        XCTAssertEqual(springNext.timeIntervalSince(springStart), 23 * 60 * 60)
        XCTAssertEqual(fallNext.timeIntervalSince(fallStart), 25 * 60 * 60)
        for (start, next) in [(springStart, springNext), (fallStart, fallNext)] {
            let day = CivilDay(containing: start, in: losAngeles)
            XCTAssertEqual(day, CivilDay(containing: next.addingTimeInterval(-1), in: losAngeles))
            XCTAssertEqual(day.distance(to: CivilDay(containing: next, in: losAngeles)), 1)
        }

        let firstOccurrence = try instant("2024-11-03T08:30:00Z")
        let repeatedOccurrence = try instant("2024-11-03T09:30:00Z")
        XCTAssertEqual(CivilDay(containing: firstOccurrence, in: losAngeles), CivilDay(containing: repeatedOccurrence, in: losAngeles))
    }

    func testTravelChangesTodayWithoutRelabelingRecordedHistory() throws {
        let created = try instant("2024-03-11T04:30:00Z")
        let homeDay = CivilDay(containing: created, in: losAngeles)
        let travelDay = CivilDay(containing: created, in: tokyo)
        XCTAssertEqual(homeDay.distance(to: travelDay), 1)
        XCTAssertEqual(travelDay, CivilDay(containing: try instant("2024-03-12T04:30:00Z"), in: losAngeles))
        var item = DoAvoidItem(title: "Read", kind: .doItem, createdAt: created, timeZone: losAngeles)
        item.updateEntry(on: homeDay, isMarked: true, note: "At home", count: 4)

        let roundTrip = try JSONDecoder().decode(DoAvoidItem.self, from: JSONEncoder().encode(item))
        XCTAssertEqual(roundTrip.createdDay, homeDay)
        XCTAssertEqual(roundTrip.entries[homeDay]?.note, "At home")
        XCTAssertEqual(roundTrip.entries[homeDay]?.count, 4)
        XCTAssertEqual(roundTrip.status(on: travelDay), .neutral)
        XCTAssertEqual(roundTrip.status(on: homeDay), .completed)
    }

    func testDoAndAvoidDefaultsAndTogglesPreservePayload() throws {
        let created = try instant("2024-03-10T12:00:00Z")
        let oldDay = CivilDay(containing: created.addingTimeInterval(-86_400), in: losAngeles)
        let day = CivilDay(containing: created, in: losAngeles)
        for (kind, initial, marked): (DoAvoidKind, DailyStatus, DailyStatus) in [
            (.doItem, .neutral, .completed), (.avoidItem, .successful, .violated)
        ] {
            var item = DoAvoidItem(title: "Item", kind: kind, createdAt: created, timeZone: losAngeles)
            XCTAssertEqual(item.status(on: oldDay), .outsideLifetime)
            XCTAssertEqual(item.status(on: day), initial)
            item.updateEntry(on: day, isMarked: false, note: "A note", count: 0)
            let id = item.entries[day]?.id
            XCTAssertEqual(item.status(on: day), initial)
            item.toggleMarked(on: day)
            XCTAssertEqual(item.status(on: day), marked)
            item.toggleMarked(on: day)
            XCTAssertEqual(item.status(on: day), initial)
            XCTAssertEqual(item.entries[day]?.id, id)
            XCTAssertEqual(item.entries[day]?.note, "A note")
            XCTAssertEqual(item.entries[day]?.count, 0)
            item.updateEntry(on: day, isMarked: false, note: nil, count: -2)
            XCTAssertEqual(item.entries[day]?.id, id)
            XCTAssertNil(item.entries[day]?.note)
            XCTAssertEqual(item.entries[day]?.count, -2)
        }
    }

    private func instant(_ value: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: value))
    }
}
