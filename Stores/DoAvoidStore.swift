//
//  DoAvoidStore.swift
//  DoAvoid
//
//  Created by Jim Harvey on 1/31/26.
//

import Foundation
import SwiftUI
import Combine

final class DoAvoidStore: ObservableObject {
    private let persistence: PersistenceStore
    private var cancellables = Set<AnyCancellable>()

    init() {

        let dir = AppDirectories.applicationSupport()
        self.persistence = PersistenceStore(baseDirectory: dir)

        if let saved: [DoAvoidItem] = persistence.load() {
            self.items = saved
        } else {
            self.items = []
        }

        $items
            .dropFirst()
            .sink { [weak self] items in
                self?.persistence.save(items)
            }
            .store(in: &cancellables)
    }

    @Published var items: [DoAvoidItem] = []
    
    func toggleToday(for itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            return
        }
        items[index].toggleMarked(on: Date())
    }
}
