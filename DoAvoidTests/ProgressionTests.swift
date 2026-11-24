#if DOAVOID_LAB
import XCTest
@testable import DoAvoid

final class ProgressionTests: XCTestCase {
    func testFixturesAreDeterministicAndSpanYears() {
        let first = LabScenario.allCases.map { $0.makeItem() }
        XCTAssertEqual(first, LabScenario.allCases.map { $0.makeItem() })
        XCTAssertEqual(first.count, 9)
        XCTAssertEqual(first.first?.createdDay, LabScenario.reference)
        XCTAssertEqual(first.map { $0.createdDay.distance(to: LabScenario.reference) }.max(), 730)
    }

    func testAvoidRecoveryDependsOnCandidateParameters() throws {
        let item = LabScenario.recovering.makeItem()
        let difficultDay = LabScenario.reference.advanced(by: -10)
        let long = ProgressionParameters(window: 21, recovery: 30)
        let short = ProgressionParameters(window: 21, recovery: 4)
        let candidate = ProgressionCandidate.recovery
        let low = try XCTUnwrap(candidate.project(item, on: difficultDay, using: short))
        let recovered = try XCTUnwrap(candidate.project(item, on: LabScenario.reference, using: short))
        let slow = try XCTUnwrap(candidate.project(item, on: LabScenario.reference, using: long))
        XCTAssertGreaterThan(recovered.strength, low.strength)
        XCTAssertGreaterThan(recovered.strength, slow.strength)
        XCTAssertTrue(item.entries.values.allSatisfy(\.isMarked))
    }

    func testHistoricalProjectionIgnoresFutureMarksAndRespondsToCorrections() throws {
        var item = LabScenario.regular.makeItem()
        let day = item.createdDay.advanced(by: 8)
        let candidate = ProgressionCandidate.recent
        let settings = ProgressionParameters()
        let original = candidate.project(item, on: day, using: settings)
        item.toggleMarked(on: day.advanced(by: 1))
        XCTAssertEqual(candidate.project(item, on: day, using: settings), original)
        item.toggleMarked(on: day)
        XCTAssertNotEqual(candidate.project(item, on: day, using: settings), original)
        XCTAssertNil(candidate.project(item, on: item.createdDay.advanced(by: -1), using: settings))
    }

    func testArchiveScenarioIsDatedWithoutMutatingItemHistory() {
        let scenario = LabScenario.lifecycle
        let day = LabScenario.reference
        XCTAssertFalse(scenario.isArchived(on: day.advanced(by: -66)))
        XCTAssertTrue(scenario.isArchived(on: day.advanced(by: -65)))
        XCTAssertTrue(scenario.isArchived(on: day.advanced(by: -9)))
        XCTAssertFalse(scenario.isArchived(on: day.advanced(by: -8)))
        XCTAssertFalse(scenario.makeItem().isRetired)
    }
}
#endif
