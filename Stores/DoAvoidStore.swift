import Combine
import Foundation

/// One instance is shared by the app's windows. Publish changes only after persistence succeeds.
@MainActor
final class DoAvoidStore: ObservableObject {
    enum Notice: Identifiable, Equatable {
        case recovered
        case saveFailed(String)

        var id: String {
            switch self {
            case .recovered: return "recovered"
            case .saveFailed: return "write"
            }
        }

        var message: String {
            switch self {
            case .recovered:
                return "The latest saved file was unavailable. The app restored the last valid backup, which may be missing recent changes."
            case .saveFailed(let detail):
                return "The change was not applied. You can try again. \(detail)"
            }
        }
    }

    @Published private(set) var items: [DoAvoidItem] = []
    @Published private(set) var loadError: String?
    @Published var notice: Notice?
    @Published private(set) var today = CivilDay(containing: Date())

    private let persistence: PersistenceStore
    private var primary: Data?

    init(persistence: PersistenceStore = PersistenceStore(baseDirectory: AppDirectories.applicationSupport())) {
        self.persistence = persistence
        reload()
    }

    func reload() {
        do {
            let loaded = try persistence.load()
            guard loaded.primary != nil || primary == nil else {
                throw PersistenceStore.Failure.unavailableHistory
            }
            primary = loaded.primary
            items = loaded.items
            loadError = nil
            notice = loaded.didRecoverBackup ? .recovered : nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    func refreshToday() {
        let current = CivilDay(containing: Date())
        if current != today { today = current }
    }

    @discardableResult
    func createItem(title: String, kind: DoAvoidKind) -> Bool {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        return commit(items + [DoAvoidItem(title: title, kind: kind)])
    }

    @discardableResult
    func toggleToday(for itemID: UUID) -> Bool {
        refreshToday()
        let day = today
        return updateItem(itemID) { $0.toggleMarked(on: day) }
    }

    @discardableResult
    func updateEntry(for itemID: UUID, on day: CivilDay, isMarked: Bool, note: String?, count: Int?) -> Bool {
        updateItem(itemID) { $0.updateEntry(on: day, isMarked: isMarked, note: note, count: count) }
    }

    @discardableResult
    func renameItem(_ itemID: UUID, to title: String) -> Bool {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        return updateItem(itemID) { $0.title = title }
    }

    @discardableResult
    func setArchived(_ archived: Bool, for itemID: UUID) -> Bool {
        updateItem(itemID) { $0.isRetired = archived }
    }

    private func updateItem(_ itemID: UUID, edit: (inout DoAvoidItem) -> Void) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return false }
        var next = items
        edit(&next[index])
        return commit(next)
    }

    private func commit(_ next: [DoAvoidItem]) -> Bool {
        guard loadError == nil else { return false }
        do {
            primary = try persistence.save(next, replacing: primary)
            items = next
            notice = nil
            return true
        } catch {
            notice = .saveFailed(error.localizedDescription)
            return false
        }
    }
}
