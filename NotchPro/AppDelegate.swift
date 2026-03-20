//
//  AppDelegate.swift
//  NotchPro
//
//  Copyright © 2026 Murilo Ribeiro. All rights reserved.
//

import Cocoa
import SwiftUI
import SwiftData

class AppDelegate: NSObject, NSApplicationDelegate {

    private var notchState:      NotchState      = NotchState()
    private var mediaService:    MediaService     = MediaService()
    private var settings:        NotchSettings    = NotchSettings()
    private var fileViewModel:   FileDropViewModel!
    private var modelContainer:  ModelContainer!
    private var windowController: NotchWindowController!
    private var statusItem:      NSStatusItem!
    private var screenshotMonitor: ScreenshotMonitor!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        do {
            modelContainer = try ModelContainer(for: DroppedFile.self)
            fileViewModel  = FileDropViewModel(modelContext: modelContainer.mainContext)
        } catch {
            fatalError("SwiftData setup failed: \(error)")
        }

        windowController = NotchWindowController(
            notchState:    notchState,
            mediaService:  mediaService,
            fileViewModel: fileViewModel,
            settings:      settings
        )
        windowController.setup()
        screenshotMonitor = ScreenshotMonitor(fileViewModel: fileViewModel)
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.topthird.inset.filled",
                accessibilityDescription: "NotchPro"
            )
        }
        let menu = NSMenu()
        let aboutItem = NSMenuItem(title: "Sobre o NotchPro", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Sair", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
