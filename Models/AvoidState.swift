//
//  AvoidState.swift
//  DoAvoid
//
//  Created by Jim Harvey on 2/4/26.
//

import Foundation

enum AvoidState: String, Codable {
    case solid        // fresh / active avoidance (concrete intact)
    case cracked      // healing, but still relevant
    case open         // habit has weakened significantly
    case overgrown    // resolved; ready for retirement

    var startDay: Int {
        switch self {
        case .solid: return 0
        case .cracked: return 7
        case .open: return 21
        case .overgrown: return 40
        }
    }

    var next: Self? {
        switch self {
        case .solid: return .cracked
        case .cracked: return .open
        case .open: return .overgrown
        case .overgrown: return nil
        }
    }

    init(elapsed: Int) {
        var state = Self.solid
        while let next = state.next, elapsed >= next.startDay {
            state = next
        }
        self = state
    }
}
