//
//  DoAvoidApp.swift
//  DoAvoid
//
//  Created by Jim Harvey on 1/30/26.
//

import SwiftUI

@main
struct DoAvoidApp: App {
    @StateObject private var store = DoAvoidStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
