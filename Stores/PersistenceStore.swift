import Foundation

struct PersistenceStore {
    static let currentVersion = 1

    enum Failure: LocalizedError {
        case unsupportedVersion(Int)
        case invalidHistory
        case ambiguousLegacyHistory
        case unavailableHistory
        case changedOnDisk

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version):
                return "Saved history uses storage version \(version). Open it with a compatible version of Do / Avoid."
            case .invalidHistory:
                return "Saved history is invalid."
            case .ambiguousLegacyHistory:
                return "Some older entries could not be assigned to unique days. The original files were kept."
            case .unavailableHistory:
                return "Saved history could not be recovered. The original files were kept."
            case .changedOnDisk:
                return "Saved history changed on disk. Reload it before trying again."
            }
        }
    }

    struct Loaded {
        let items: [DoAvoidItem]
        let primary: Data?
        let didRecoverBackup: Bool
    }

    private struct Header: Decodable {
        let version: Int
    }

    private struct Snapshot: Codable {
        let version: Int
        let items: [DoAvoidItem]
    }

    private struct Decoded {
        let items: [DoAvoidItem]
        let isLegacy: Bool
    }

    private let directory: URL
    private let primaryURL: URL
    private let backupURL: URL
    private let migrationTimeZone: TimeZone
    private let writeAtomically: (Data, URL) throws -> Void

    init(
        baseDirectory: URL,
        migrationTimeZone: TimeZone = .current,
        writeAtomically: @escaping (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }
    ) {
        directory = baseDirectory
        primaryURL = baseDirectory.appendingPathComponent("doavoid.json")
        backupURL = baseDirectory.appendingPathComponent("doavoid.backup.json")
        self.migrationTimeZone = migrationTimeZone
        self.writeAtomically = writeAtomically
    }

    func load() throws -> Loaded {
        let primary = try read(primaryURL)
        if let primary, let decoded = try validated(primary) {
            guard decoded.isLegacy else {
                return Loaded(items: decoded.items, primary: primary, didRecoverBackup: false)
            }
            try preserve(primary, as: "legacy")
            let migrated = try encode(decoded.items)
            if try read(backupURL) == nil {
                try writeAtomically(migrated, backupURL)
            }
            try writeAtomically(migrated, primaryURL)
            return Loaded(items: decoded.items, primary: migrated, didRecoverBackup: false)
        }

        guard let backup = try read(backupURL) else {
            guard primary == nil, try !hasRetainedHistory() else { throw Failure.unavailableHistory }
            return Loaded(items: [], primary: nil, didRecoverBackup: false)
        }
        guard let decoded = try validated(backup) else { throw Failure.unavailableHistory }

        if let primary {
            try preserve(primary, as: "corrupt")
        }
        if decoded.isLegacy {
            try preserve(backup, as: "legacy")
        }
        let restored = decoded.isLegacy ? try encode(decoded.items) : backup
        try writeAtomically(restored, primaryURL)
        return Loaded(items: decoded.items, primary: restored, didRecoverBackup: true)
    }

    func save(_ items: [DoAvoidItem], replacing expectedPrimary: Data?) throws -> Data {
        let next = try encode(items)
        let primary = try read(primaryURL)
        guard primary == expectedPrimary else { throw Failure.changedOnDisk }

        // A backup appearing after first launch may contain history. Reload it before writing.
        let backup = try read(backupURL)
        if primary == nil, backup != nil {
            throw Failure.changedOnDisk
        }
        if let primary {
            // Preserve backups from a newer format, even when the current primary is readable.
            if let backup { try checkBackupVersion(backup) }
            try writeAtomically(primary, backupURL)
        } else {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        try writeAtomically(next, primaryURL)
        return next
    }

    private func read(_ url: URL) throws -> Data? {
        do {
            return try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return nil
        }
    }

    private func hasRetainedHistory() throws -> Bool {
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            return files.contains { $0.hasPrefix("doavoid-legacy-") || $0.hasPrefix("doavoid-corrupt-") }
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return false
        }
    }

    private func preserve(_ data: Data, as label: String) throws {
        let url = directory.appendingPathComponent("doavoid-\(label)-\(UUID().uuidString).json")
        try writeAtomically(data, url)
    }

    private func encode(_ items: [DoAvoidItem]) throws -> Data {
        try validateItemIDs(items)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Snapshot(version: Self.currentVersion, items: items))
    }

    /// An unreadable format can recover from backup. A newer version or ambiguous migration must stop.
    private func validated(_ data: Data) throws -> Decoded? {
        let decoder = JSONDecoder()
        do {
            let items: [DoAvoidItem]
            let isLegacy: Bool
            if let header = try? decoder.decode(Header.self, from: data) {
                guard header.version == Self.currentVersion else {
                    throw Failure.unsupportedVersion(header.version)
                }
                items = try decoder.decode(Snapshot.self, from: data).items
                isLegacy = false
            } else {
                let legacy = try decoder.decode([LegacyItem].self, from: data)
                items = try legacy.map { try $0.migrated(in: migrationTimeZone) }
                isLegacy = true
            }
            try validateItemIDs(items)
            return Decoded(items: items, isLegacy: isLegacy)
        } catch is DecodingError {
            return nil
        } catch Failure.invalidHistory {
            return nil
        }
    }

    private func checkBackupVersion(_ data: Data) throws {
        if let header = try? JSONDecoder().decode(Header.self, from: data),
           header.version > Self.currentVersion {
            throw Failure.unsupportedVersion(header.version)
        }
    }

    private func validateItemIDs(_ items: [DoAvoidItem]) throws {
        guard Set(items.map(\.id)).count == items.count else { throw Failure.invalidHistory }
    }
}

private struct LegacyItem: Decodable {
    struct Entry: Decodable {
        let id: UUID
        let date: Date
        let isMarked: Bool
        let note: String?
        let count: Int?
    }

    struct Entries: Decodable {
        let pairs: [(Date, Entry)]

        init(from decoder: Decoder) throws {
            // Swift's Codable dictionary format for Date keys alternates keys and values.
            var container = try decoder.unkeyedContainer()
            var records: [(Date, Entry)] = []
            while !container.isAtEnd {
                let key = try container.decode(Date.self)
                let entry = try container.decode(Entry.self)
                records.append((key, entry))
            }
            pairs = records
        }
    }

    let id: UUID
    let title: String
    let kind: DoAvoidKind
    let createdAt: Date
    let entries: Entries
    let isRetired: Bool

    func migrated(in timeZone: TimeZone) throws -> DoAvoidItem {
        var days: [CivilDay: DayEntry] = [:]
        var ids: Set<UUID> = []
        for (key, entry) in entries.pairs {
            let day = try migrationDay(for: key, in: timeZone)
            guard key == entry.date, days[day] == nil, ids.insert(entry.id).inserted else {
                throw PersistenceStore.Failure.ambiguousLegacyHistory
            }
            days[day] = DayEntry(
                id: entry.id, day: day, isMarked: entry.isMarked, note: entry.note, count: entry.count
            )
        }
        return DoAvoidItem(
            id: id, title: title, kind: kind, createdAt: createdAt,
            createdDay: try migrationDay(for: createdAt, in: timeZone),
            entries: days, isRetired: isRetired
        )
    }

    private func migrationDay(for date: Date, in timeZone: TimeZone) throws -> CivilDay {
        // Legacy data was produced by this app in the modern Gregorian era.
        guard (-62_000_000_000...252_000_000_000).contains(date.timeIntervalSinceReferenceDate) else {
            throw PersistenceStore.Failure.ambiguousLegacyHistory
        }
        return CivilDay(containing: date, in: timeZone)
    }
}
