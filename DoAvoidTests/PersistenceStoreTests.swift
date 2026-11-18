//
//  PersistenceStoreTests.swift
//  DoAvoid
//
//  Created by Jim Harvey on 2/19/26.
//

import XCTest
@testable import DoAvoid

final class PersistenceStoreTests: XCTestCase {

    var tempDir: URL!
    var store: PersistenceStore!

    override func setUp() {
        super.setUp()

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try? FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )

        store = PersistenceStore(baseDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSaveAndLoad() {

        let items = [
            DoAvoidItem(title: "Test", kind: .doItem)
        ]

        store.save(items)

        let loaded: [DoAvoidItem]? = store.load()

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.count, 1)
        XCTAssertEqual(loaded?.first?.title, "Test")
    }

    func testMissingFileReturnsNil() {

        let loaded: [DoAvoidItem]? = store.load()

        XCTAssertNil(loaded)
    }

    func testCorruptFileDoesNotCrash() throws {

        let badFile = tempDir.appendingPathComponent("doavoid.json")

        try "garbage".data(using: .utf8)!.write(to: badFile)

        let loaded: [DoAvoidItem]? = store.load()

        XCTAssertNil(loaded)

        let files = try FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil
        )

        let hasCorrupt = files.contains {
            $0.lastPathComponent.contains("doavoid-corrupt")
        }

        XCTAssertTrue(hasCorrupt)
    }
}
