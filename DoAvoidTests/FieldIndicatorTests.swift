import XCTest
@testable import DoAvoid

final class FieldIndicatorTests: XCTestCase {
    private let start = CivilDay(containing: Date(timeIntervalSince1970: 1_735_689_600), in: CivilDay.utc)

    func testIndicatorsDefaultOnAndPersistIndependently() throws {
        let domain = "FieldIndicatorTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let settings = FieldIndicatorSettings(store: defaults)
        XCTAssertTrue(settings.showsTypeLabels)
        XCTAssertTrue(settings.showsClocks)

        settings.showsTypeLabels = false
        XCTAssertFalse(FieldIndicatorSettings(store: defaults).showsTypeLabels)
        XCTAssertTrue(FieldIndicatorSettings(store: defaults).showsClocks)

        settings.showsClocks = false
        XCTAssertFalse(FieldIndicatorSettings(store: defaults).showsClocks)
        XCTAssertFalse(FieldIndicatorSettings(store: defaults).showsTypeLabels)

        settings.showsTypeLabels = true
        XCTAssertTrue(FieldIndicatorSettings(store: defaults).showsTypeLabels)
        XCTAssertFalse(FieldIndicatorSettings(store: defaults).showsClocks)
    }

    func testDoForecastRetainsCompletionsDuringAbsenceAndRollsOverAtCycleBoundary() throws {
        var item = makeItem(.doItem)
        for offset in 0..<39 {
            item.toggleMarked(on: start.advanced(by: offset))
        }
        let today = start.advanced(by: 69)
        let before = try XCTUnwrap(ProgressionForecast.estimate(for: item, on: today))
        XCTAssertEqual(before.milestone, .doCycle)
        XCTAssertEqual(before.days, 1)
        XCTAssertEqual(before.fraction, 39.0 / 40, accuracy: 0.0001)
        item.toggleMarked(on: today)
        XCTAssertEqual(item.completedCycles, 1)
        XCTAssertEqual(ProgressionForecast.estimate(for: item, on: today)?.days, 40)
        XCTAssertEqual(ProgressionForecast.estimate(for: item, on: today)?.fraction, 0)

        item.updateEntry(on: start, isMarked: false, note: "Correction", count: 8)
        XCTAssertEqual(ProgressionForecast.estimate(for: item, on: today)?.days, 1)
        item.toggleMarked(on: today.advanced(by: 1))
        XCTAssertEqual(ProgressionForecast.estimate(for: item, on: today)?.days, 1)
    }

    func testAvoidForecastAtEveryBoundaryAndAfterSetback() throws {
        var item = makeItem(.avoidItem)
        let milestones: [(Int, AvoidState, AvoidState, Int)] = [
            (0, .solid, .cracked, 7), (6, .solid, .cracked, 1),
            (7, .cracked, .open, 14), (20, .cracked, .open, 1),
            (21, .open, .overgrown, 19), (39, .open, .overgrown, 1),
        ]
        for (offset, current, next, days) in milestones {
            let day = start.advanced(by: offset)
            XCTAssertEqual(item.avoidState(asOf: day), current)
            let forecast = try XCTUnwrap(ProgressionForecast.estimate(for: item, on: day))
            XCTAssertEqual(forecast.milestone, .avoid(next))
            XCTAssertEqual(forecast.days, days)
        }

        let terminal = start.advanced(by: 40)
        XCTAssertEqual(item.avoidState(asOf: terminal), .overgrown)
        XCTAssertNil(ProgressionForecast.estimate(for: item, on: terminal))
        XCTAssertFalse(item.isRetired)
        item.toggleMarked(on: terminal)
        XCTAssertEqual(item.avoidState(asOf: terminal), .solid)
        XCTAssertEqual(ProgressionForecast.estimate(for: item, on: terminal)?.days, 7)
        XCTAssertEqual(ProgressionForecast.estimate(for: item, on: terminal.advanced(by: 1))?.days, 6)

        item.updateEntry(on: terminal, isMarked: false, note: "Correction", count: nil)
        XCTAssertNil(ProgressionForecast.estimate(for: item, on: terminal))
        XCTAssertEqual(item.entries[terminal]?.note, "Correction")
    }

    func testForecastUnavailableBeforeCreationOrWhileArchived() {
        for kind in [DoAvoidKind.doItem, .avoidItem] {
            var item = makeItem(kind)
            XCTAssertNil(ProgressionForecast.estimate(for: item, on: start.advanced(by: -1)))
            let original = ProgressionForecast.estimate(for: item, on: start)
            item.isRetired = true
            XCTAssertNil(ProgressionForecast.estimate(for: item, on: start))
            item.isRetired = false
            XCTAssertEqual(ProgressionForecast.estimate(for: item, on: start), original)
            XCTAssertTrue(item.entries.isEmpty)
        }
    }

    @MainActor
    func testStorePublishesMarkAndPastEditForecastsAndRetainsHistoryOnReload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = PersistenceStore(baseDirectory: directory)
        let store = DoAvoidStore(persistence: persistence)
        XCTAssertTrue(store.createItem(title: "Read", kind: .doItem))
        let id = try XCTUnwrap(store.items.first?.id)
        let today = store.today
        XCTAssertEqual(ProgressionForecast.estimate(for: store.items[0], on: today)?.days, 40)
        XCTAssertTrue(store.toggleToday(for: id))
        XCTAssertEqual(ProgressionForecast.estimate(for: store.items[0], on: today)?.days, 39)
        let past = today.advanced(by: -1)
        XCTAssertTrue(store.updateEntry(for: id, on: past, isMarked: true, note: "Imported correction", count: 4))
        XCTAssertEqual(ProgressionForecast.estimate(for: store.items[0], on: today)?.days, 38)
        XCTAssertEqual(DoAvoidStore(persistence: persistence).items, store.items)
    }

    private func makeItem(_ kind: DoAvoidKind) -> DoAvoidItem {
        DoAvoidItem(title: "Example", kind: kind, createdAt: Date(timeIntervalSince1970: 1_735_689_600), timeZone: CivilDay.utc)
    }
}
