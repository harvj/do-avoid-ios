//
//  PersistenceStore.swift
//  DoAvoid
//
//  Created by Jim Harvey on 2/19/26.
//

import Foundation

struct PersistenceStore {

    private let fileURL: URL
    private let backupURL: URL

    init(baseDirectory: URL) {
        self.fileURL = baseDirectory.appendingPathComponent("doavoid.json")
        self.backupURL = baseDirectory.appendingPathComponent("doavoid.backup.json")
    }

    // MARK: - Public

    func load<T: Decodable>() -> T? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return decoded
        } catch {
            print("⚠️ Load failed:", error)
            handleCorruptFile()
            return nil
        }
    }

    func save<T: Encodable>(_ value: T) {
        do {
            let data = try JSONEncoder().encode(value)

            // Backup current file if it exists
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: backupURL)
                try FileManager.default.copyItem(at: fileURL, to: backupURL)
            }

            // Atomic write
            try data.write(to: fileURL, options: .atomic)

        } catch {
            print("⚠️ Save failed:", error)
        }
    }

    // MARK: - Private

    private func handleCorruptFile() {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let corruptURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("doavoid-corrupt-\(timestamp).json")

        try? FileManager.default.moveItem(at: fileURL, to: corruptURL)
    }
}


