//
//  FieldView.swift
//  DoAvoid
//
//  Created by Jim Harvey on 1/31/26.
//

import Foundation
import SwiftUI

struct FieldView: View {
    @ObservedObject var store: DoAvoidStore
    let displayMode: DisplayMode
    let filterMode: FilterMode
    let onAdd: () -> Void
    let onSwipeUp: () -> Void
    let onSwipeDown: () -> Void

    var body: some View {
        GeometryReader { geo in
            let visibleItems: [DoAvoidItem] = store.items.filter { item in
                switch filterMode {
                case .all:
                    return true
                case .dosOnly:
                    return item.kind == .doItem
                case .avoidsOnly:
                    return item.kind == .avoidItem
                }
            }

            let buttonHeight: CGFloat = 94
            let availableHeight = geo.size.height - buttonHeight
            let rowHeight = visibleItems.isEmpty
                ? availableHeight
                : availableHeight / CGFloat(visibleItems.count)

            VStack(spacing: 0) {
                if store.items.isEmpty {
                    EmptyStateView()
                } else {
                    ForEach(visibleItems.indices, id: \.self) { index in
                        let item = visibleItems[index]
                        
                        BarView(
                            title: item.title,
                            color: item.kind == .doItem
                            ? Color.yellow.opacity(0.45)
                            : Color.gray.opacity(0.25),
                            isTop: index == 0,
                            isBottom: index == visibleItems.count - 1,
                            daysCount: item.entries.values.filter { $0.isMarked }.count,
                            isMarkedToday: (item.entry(for: Date())?.isMarked ?? false),
                            showBadges: displayMode == .withBadges
                        )
                        .frame(height: rowHeight)
                    }
                }

                Button {
                    onAdd()
                } label: {
                    Text("Add New +")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.semibold)
                        .textCase(.uppercase)
                        .foregroundStyle(.gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: buttonHeight)
                        .background(Color.white)
                }
                .ignoresSafeArea(.container, edges: .bottom)
            }
        }
    }
}

