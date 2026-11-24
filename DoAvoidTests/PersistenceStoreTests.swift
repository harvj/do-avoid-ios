import XCTest
@testable import DoAvoid

final class PersistenceStoreTests: XCTestCase {
    private var directory: URL!
    private var persistence: PersistenceStore!

    private var primary: URL { directory.appendingPathComponent("doavoid.json") }
    private var backup: URL { directory.appendingPathComponent("doavoid.backup.json") }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        persistence = PersistenceStore(baseDirectory: directory, migrationTimeZone: TimeZone(identifier: "America/Los_Angeles")!)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testFirstLaunchAndVersionedRoundTrip() throws {
        let initial = try persistence.load()
        XCTAssertEqual(initial.items, [])
        XCTAssertNil(initial.primary)
        XCTAssertFalse(initial.didRecoverBackup)

        let day = CivilDay(containing: Date(), in: CivilDay.utc)
        var item = DoAvoidItem(title: "Read", kind: .doItem)
        item.updateEntry(on: day, isMarked: true, note: "A note", count: -1)
        let bytes = try persistence.save([item], replacing: initial.primary)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        XCTAssertEqual(json["version"] as? Int, 1)
        XCTAssertEqual(try persistence.load().items, [item])
    }

    func testLegacyUpgradePreservesIdentityHistoryAndOriginalBytes() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "legacy-history", withExtension: "json"))
        let original = try Data(contentsOf: url)
        try original.write(to: primary)

        let migrated = try persistence.load()
        let reading = try XCTUnwrap(migrated.items.first)
        XCTAssertEqual(reading.id.uuidString, "5099B771-40D9-4FAD-A4F5-D053B379740A")
        XCTAssertEqual(reading.createdAt.timeIntervalSinceReferenceDate, 731_592_000)
        let day = try JSONDecoder().decode(CivilDay.self, from: Data("20240310".utf8))
        let entry = try XCTUnwrap(reading.entries[day])
        XCTAssertEqual(entry.id.uuidString, "16F70187-1A68-42DD-A2B5-07CCC3DBD559")
        XCTAssertEqual(entry.note, "First chapter")
        XCTAssertEqual(entry.count, 12)
        XCTAssertEqual(reading.status(on: day), .completed)
        XCTAssertEqual(reading.allEntriesSorted.last?.note, "Made a plan")
        XCTAssertEqual(reading.allEntriesSorted.last?.isMarked, false)
        let avoidance = try XCTUnwrap(migrated.items.last)
        XCTAssertTrue(avoidance.isRetired)
        XCTAssertEqual(avoidance.allEntriesSorted.map(\.count), [-2, 0])
        XCTAssertEqual(avoidance.status(on: try XCTUnwrap(avoidance.allEntriesSorted.first?.day)), .violated)
        let archives = try retainedFiles(with: "legacy")
        XCTAssertEqual(archives.count, 1)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(archives.first)), original)
        XCTAssertEqual(try Data(contentsOf: backup), migrated.primary)

        let relaunchedElsewhere = PersistenceStore(baseDirectory: directory, migrationTimeZone: TimeZone(identifier: "Asia/Tokyo")!)
        let reloaded = try relaunchedElsewhere.load()
        XCTAssertEqual(reloaded.items, migrated.items)
        XCTAssertEqual(reloaded.primary, migrated.primary)
        XCTAssertEqual(try retainedFiles(with: "legacy").count, 1)
    }

    func testAmbiguousLegacyDaysKeepOriginalAndDoNotRollBackToBackup() throws {
        let legacy = """
        [{
          "id":"5099B771-40D9-4FAD-A4F5-D053B379740A","title":"Read","kind":"doItem",
          "createdAt":731592000,"isRetired":false,"entries":[
            731750400,{"date":731750400,"id":"16F70187-1A68-42DD-A2B5-07CCC3DBD559","isMarked":true,"note":"First"},
            731754000,{"date":731754000,"id":"A9B1531B-E5DC-45F3-9E47-2255F9C0C83E","isMarked":false,"note":"Second"}
          ]
        }]
        """
        let original = Data(legacy.utf8)
        let goodBackup = try persistence.save([], replacing: nil)
        try goodBackup.write(to: backup)
        try original.write(to: primary)

        XCTAssertThrowsError(try persistence.load()) {
            guard case PersistenceStore.Failure.ambiguousLegacyHistory = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: primary), original)
        XCTAssertEqual(try Data(contentsOf: backup), goodBackup)
    }

    func testCorruptPrimaryRestoresValidatedBackupAndKeepsCorruptBytes() throws {
        let older = DoAvoidItem(title: "Older", kind: .doItem)
        let newer = DoAvoidItem(title: "Newer", kind: .avoidItem)
        let previous = try persistence.save([older], replacing: nil)
        _ = try persistence.save([older, newer], replacing: previous)
        let corrupt = Data("broken primary".utf8)
        try corrupt.write(to: primary)

        let loaded = try persistence.load()
        XCTAssertTrue(loaded.didRecoverBackup)
        XCTAssertEqual(loaded.items, [older])
        XCTAssertEqual(try Data(contentsOf: primary), previous)
        XCTAssertEqual(try Data(contentsOf: backup), previous)
        let archived = try XCTUnwrap(retainedFiles(with: "corrupt").first)
        XCTAssertEqual(try Data(contentsOf: archived), corrupt)
        XCTAssertFalse(try persistence.load().didRecoverBackup)
    }

    func testMissingPrimaryRecoversLegacyBackup() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "legacy-history", withExtension: "json"))
        let original = try Data(contentsOf: url)
        try original.write(to: backup)

        let loaded = try persistence.load()
        XCTAssertTrue(loaded.didRecoverBackup)
        XCTAssertEqual(loaded.items.map(\.title), ["Read", "Late caffeine"])
        XCTAssertEqual(try Data(contentsOf: backup), original)
        XCTAssertNotEqual(try Data(contentsOf: primary), original)
    }

    func testInvalidFilesAndPreviouslyQuarantinedHistoryAreNotFirstLaunch() throws {
        let broken = Data("broken".utf8)
        try broken.write(to: primary)
        try broken.write(to: backup)
        XCTAssertThrowsError(try persistence.load())
        XCTAssertEqual(try Data(contentsOf: primary), broken)
        XCTAssertEqual(try Data(contentsOf: backup), broken)

        try FileManager.default.moveItem(at: primary, to: directory.appendingPathComponent("doavoid-corrupt-prior.json"))
        try FileManager.default.removeItem(at: backup)
        XCTAssertThrowsError(try persistence.load())
    }

    func testUnsupportedVersionDoesNotFallBackOrOverwriteNewerBackup() throws {
        let current = try persistence.save([], replacing: nil)
        let future = Data(#"{"version":2,"items":[]}"#.utf8)
        try current.write(to: backup)
        try future.write(to: primary)
        XCTAssertThrowsError(try persistence.load()) {
            guard case PersistenceStore.Failure.unsupportedVersion(2) = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: primary), future)
        XCTAssertEqual(try Data(contentsOf: backup), current)

        try current.write(to: primary)
        try future.write(to: backup)
        XCTAssertEqual(try persistence.load().items, [])
        XCTAssertThrowsError(try persistence.save([], replacing: current))
        XCTAssertEqual(try Data(contentsOf: backup), future)
    }

    func testInvalidVersionedDayCannotBeUsedAsBackup() throws {
        let fixture = """
        {"version":1,"items":[{
          "id":"5099B771-40D9-4FAD-A4F5-D053B379740A","title":"Read","kind":"doItem",
          "createdAt":731592000,"createdDay":20240230,"isRetired":false,"entries":[]
        }]}
        """
        try Data(fixture.utf8).write(to: backup)
        XCTAssertThrowsError(try persistence.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: primary.path))
    }

    func testUnreadablePrimaryDoesNotReplaceItWithBackup() throws {
        let previous = try persistence.save([], replacing: nil)
        try previous.write(to: backup)
        try FileManager.default.removeItem(at: primary)
        try FileManager.default.createDirectory(at: primary, withIntermediateDirectories: false)

        XCTAssertThrowsError(try persistence.load())
        XCTAssertEqual(try Data(contentsOf: backup), previous)
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: primary.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testReadModifyWriteRejectsStalePrimary() throws {
        let original = DoAvoidItem(title: "Original", kind: .doItem)
        let bytes = try persistence.save([original], replacing: nil)
        var edited = original
        edited.title = "Edited"
        let current = try persistence.save([edited], replacing: bytes)

        XCTAssertThrowsError(try persistence.save([], replacing: bytes))
        XCTAssertEqual(try Data(contentsOf: primary), current)
        XCTAssertEqual(try Data(contentsOf: backup), bytes)
    }

    @MainActor
    func testRenameAndArchiveRetainIdentityAndHistoryAcrossRelaunch() throws {
        let store = DoAvoidStore(persistence: persistence)
        XCTAssertTrue(store.createItem(title: " Read ", kind: .doItem))
        let original = try XCTUnwrap(store.items.first)
        XCTAssertEqual(original.title, "Read")
        let day = store.today
        XCTAssertTrue(store.updateEntry(for: original.id, on: day, isMarked: true, note: "Chapter one", count: 12))
        let entry = try XCTUnwrap(store.items.first?.entries[day])
        XCTAssertTrue(store.renameItem(original.id, to: "Read a novel"))
        XCTAssertTrue(store.setArchived(true, for: original.id))

        let relaunched = DoAvoidStore(persistence: persistence)
        let archived = try XCTUnwrap(relaunched.items.first)
        XCTAssertEqual(archived.id, original.id)
        XCTAssertEqual(archived.title, "Read a novel")
        XCTAssertTrue(archived.isRetired)
        XCTAssertEqual(archived.entries[day], entry)
        XCTAssertTrue(relaunched.setArchived(false, for: original.id))
        XCTAssertEqual(try persistence.load().items.first?.isRetired, false)
        XCTAssertEqual(try persistence.load().items.first?.entries[day], entry)
    }

    @MainActor
    func testBackupWriteFailureSurfacesAndLeavesBothSnapshotsIntact() throws {
        let store = DoAvoidStore(persistence: persistence)
        XCTAssertTrue(store.createItem(title: "Original", kind: .doItem))
        XCTAssertTrue(store.createItem(title: "Second", kind: .avoidItem))
        let before = try Data(contentsOf: primary)
        let beforeBackup = try Data(contentsOf: backup)
        let unavailable = PersistenceStore(baseDirectory: directory) { bytes, url in
            if url.lastPathComponent == "doavoid.backup.json" { throw CocoaError(.fileWriteNoPermission) }
            try bytes.write(to: url, options: .atomic)
        }
        let relaunched = DoAvoidStore(persistence: unavailable)

        XCTAssertFalse(relaunched.createItem(title: "Unsaved", kind: .doItem))
        XCTAssertEqual(relaunched.items, store.items)
        guard case .saveFailed = relaunched.notice else { return XCTFail("Expected a visible write notice") }
        XCTAssertEqual(try Data(contentsOf: primary), before)
        XCTAssertEqual(try Data(contentsOf: backup), beforeBackup)
    }

    @MainActor
    func testPrimaryWriteFailureDoesNotPublishAndCanBeRetried() throws {
        let store = DoAvoidStore(persistence: persistence)
        XCTAssertTrue(store.createItem(title: "Original", kind: .doItem))
        let before = try Data(contentsOf: primary)
        var failWrite = true
        let intermittent = PersistenceStore(baseDirectory: directory) { bytes, url in
            if failWrite, url.lastPathComponent == "doavoid.json" { throw CocoaError(.fileWriteOutOfSpace) }
            try bytes.write(to: url, options: .atomic)
        }
        let relaunched = DoAvoidStore(persistence: intermittent)
        let itemID = try XCTUnwrap(relaunched.items.first?.id)
        let day = relaunched.today

        XCTAssertFalse(relaunched.updateEntry(for: itemID, on: day, isMarked: true, note: "draft", count: 7))
        guard case .saveFailed = relaunched.notice else { return XCTFail("Expected a visible write notice") }
        XCTAssertEqual(relaunched.items, store.items)
        XCTAssertEqual(try Data(contentsOf: primary), before)
        XCTAssertEqual(try Data(contentsOf: backup), before)

        failWrite = false
        XCTAssertTrue(relaunched.updateEntry(for: itemID, on: day, isMarked: true, note: "draft", count: 7))
        XCTAssertNil(relaunched.notice)
        XCTAssertEqual(try persistence.load().items.first?.entries[day]?.count, 7)
    }

    @MainActor
    func testFailedLoadBlocksMutationsUntilSuccessfulRecovery() throws {
        let corrupt = Data("problem".utf8)
        try corrupt.write(to: primary)
        let store = DoAvoidStore(persistence: persistence)

        XCTAssertNotNil(store.loadError)
        XCTAssertFalse(store.createItem(title: "Will not overwrite", kind: .doItem))
        XCTAssertEqual(try Data(contentsOf: primary), corrupt)

        let validEmpty = Data(#"{"version":1,"items":[]}"#.utf8)
        try validEmpty.write(to: backup)
        store.reload()
        XCTAssertNil(store.loadError)
        XCTAssertEqual(store.notice, .recovered)
        XCTAssertTrue(store.createItem(title: "Recovered", kind: .doItem))
    }

    private func retainedFiles(with label: String) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("doavoid-\(label)-") }
    }
}
