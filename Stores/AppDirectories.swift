//
//  AppDirectories.swift
//  DoAvoid
//
//  Created by Jim Harvey on 2/19/26.
//

import Foundation

enum AppDirectories {

    static func applicationSupport() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        let bundleID = Bundle.main.bundleIdentifier ?? "DoAvoid"

        let dir = base.appendingPathComponent(bundleID)

        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
        }

        return dir
    }
}
