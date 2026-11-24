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

struct ContentView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var store: DoAvoidStore

    @State private var appMode: AppMode = .field
    #if DOAVOID_LAB
    @State private var showsLab = ProcessInfo.processInfo.arguments.contains("--progression-lab")
    #endif

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
        #if DOAVOID_LAB
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Text("Build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Progression Lab") { showsLab = true }
                    .padding(.vertical, 8)
            }
            .padding(.horizontal)
            .background(.regularMaterial)
        }
        .sheet(isPresented: $showsLab) { ProgressionLab() }
        #endif
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
            TimelineView(items: store.items, day: store.today)
        } else {
            switch appMode {
            case .field:
                FieldView(items: store.items, day: store.today, onAdd: openCreate) { id in
                    store.toggleToday(for: id)
                }
            case .create:
                CreateItemView(store: store, onDone: closeCreate)
            }
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

