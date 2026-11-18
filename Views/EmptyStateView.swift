//
//  EmptyStateView.swift
//  DoAvoid
//
//  Created by Jim Harvey on 2/19/26.
//

import SwiftUI

struct EmptyStateView: View {

    var body: some View {
        VStack(spacing: 16) {

            Text("Do / Avoid")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Text("Nothing here yet.")
                .font(.body)
                .foregroundColor(.secondary)

            Text("Pull up to create your first item.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}

#Preview {
    EmptyStateView()
}
