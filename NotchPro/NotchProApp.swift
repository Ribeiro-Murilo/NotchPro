//
//  NotchProApp.swift
//  NotchPro
//
//  Copyright © 2026 Murilo Ribeiro. All rights reserved.

import SwiftUI

@main
struct NotchProApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
