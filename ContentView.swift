//
//  ContentView.swift
//  DoAvoid
//
//  Created by Jim Harvey on 1/30/26.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

enum AppMode {
    case field          // normal portrait
    case create         // swipe-right input
}

enum DisplayMode: CaseIterable {
    case minimal        // no badges
    case withBadges     // default
    // future: .diagnostic, .debug, etc.
}

enum FilterMode {
    case all
    case dosOnly
    case avoidsOnly
}

struct ContentView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var store: DoAvoidStore

    @State private var filterMode: FilterMode = .all
    @State private var appMode: AppMode = .field
    @State private var displayMode: DisplayMode = .withBadges

    var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        Group {
            if let loadError = store.loadError {
                VStack(spacing: 16) {
                    Text("Saved History Unavailable")
                        .font(.headline)
                    Text(loadError)
                        .multilineTextAlignment(.center)
                    Button("Retry Loading History") { store.reload() }
                }
                .padding()
            } else {
                mainContent
            }
        }
        .alert(item: $store.notice) { notice in
            switch notice {
            case .recovered:
                return Alert(
                    title: Text("History Restored"),
                    message: Text(notice.message),
                    dismissButton: .default(Text("OK"))
                )
            case .saveFailed:
                return Alert(
                    title: Text("Couldn’t Save"),
                    message: Text(notice.message),
                    primaryButton: .default(Text("OK")),
                    secondaryButton: .default(Text("Reload History"), action: store.reload)
                )
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { store.refreshToday() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            store.refreshToday()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            store.refreshToday()
        }
    }

    @ViewBuilder private var mainContent: some View {
        if isLandscape {
            TimelineView(store: store)

        } else {

            ZStack(alignment: .bottom) {

                // Main Content
                Group {
                    switch appMode {

                    case .field:
                        FieldView(
                            store: store,
                            displayMode: displayMode,
                            filterMode: filterMode,
                            onAdd: { openCreate() },
                            onSwipeUp: toggleAvoids,
                            onSwipeDown: toggleDos
                        )

                    case .create:
                        CreateItemView(
                            store: store,
                            onDone: closeCreate
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onReceive(store.$items) { _ in
                validateFilter()
            }
        }
    }

    var hasDos: Bool {
        store.items.contains { $0.kind == .doItem }
    }

    var hasAvoids: Bool {
        store.items.contains { $0.kind == .avoidItem }
    }

    func validateFilter() {

        switch filterMode {

        case .dosOnly where !hasDos:
            filterMode = .all

        case .avoidsOnly where !hasAvoids:
            filterMode = .all

        default:
            break
        }
    }

    func toggleAvoids() {
        guard hasAvoids else {
            filterMode = .all
            return
        }

        if filterMode == .dosOnly {
            filterMode = .all
        } else {
            filterMode = .avoidsOnly
        }
    }
    
    func toggleDos() {
        guard hasDos else {
            filterMode = .all
            return
        }

        if filterMode == .avoidsOnly {
            filterMode = .all
        } else {
            filterMode = .dosOnly
        }
    }

    func openCreate() {
        withAnimation(.spring()) {
            appMode = .create
        }
        triggerDismissHaptic()
    }

    func closeCreate() {
        withAnimation(.spring()) {
            appMode = .field
        }
        triggerDismissHaptic()
    }

    func dismissKeyboard() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    func triggerDismissHaptic() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
}

#Preview {
    ContentView(store: DoAvoidStore())
}

