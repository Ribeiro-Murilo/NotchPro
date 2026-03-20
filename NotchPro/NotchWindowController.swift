//
//  NotchWindowController.swift
//  NotchPro
//
//  Copyright © 2026 Murilo Ribeiro. All rights reserved.
//

import Cocoa
import SwiftUI

class NotchWindowController {

    private static let windowWidth:  CGFloat = 700
    private static let windowHeight: CGFloat = 270

    private(set) var window: NSWindow!

    private let notchState:    NotchState
    private let mediaService:  MediaService
    private let fileViewModel: FileDropViewModel
    private let settings:      NotchSettings

    private var globalMouseMonitor: Any?
    private var localMouseMonitor:  Any?

    init(notchState: NotchState, mediaService: MediaService,
         fileViewModel: FileDropViewModel, settings: NotchSettings) {
        self.notchState    = notchState
        self.mediaService  = mediaService
        self.fileViewModel = fileViewModel
        self.settings      = settings
    }

    deinit {
        if let m = globalMouseMonitor { NSEvent.removeMonitor(m) }
        if let m = localMouseMonitor  { NSEvent.removeMonitor(m) }
    }

    // MARK: - Setup

    func setup() {
        detectNotchWidth()

        window = NSWindow(
            contentRect: .zero,
            styleMask:   [.borderless],
            backing:     .buffered,
            defer:       false
        )
        configureWindow()

        let contentView = ContentView(
            state:         notchState,
            mediaService:  mediaService,
            fileViewModel: fileViewModel
        )
        .environmentObject(settings)
        .frame(width: Self.windowWidth, height: Self.windowHeight)

        let hostingView = NotchHostingView(rootView: contentView)
        hostingView.state         = notchState
        hostingView.fileViewModel = fileViewModel
        hostingView.settings      = settings
        hostingView.frame         = CGRect(
            x: 0, y: 0,
            width:  Self.windowWidth,
            height: Self.windowHeight
        )

        window.contentView = hostingView

        positionWindow()
        window.makeKeyAndOrderFront(nil)

        startMousePassthroughMonitor()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenChanged() {
        detectNotchWidth()
        positionWindow()
    }

    private func detectNotchWidth() {
        guard let screen = NSScreen.main else { return }
        if #available(macOS 12.0, *),
           let left  = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let width = right.minX - left.maxX
            notchState.notchWidth = max(width, 160)
        } else {
            notchState.notchWidth = 180
        }
    }

    private func configureWindow() {
        window.level               = .statusBar
        window.isOpaque            = false
        window.backgroundColor     = .clear
        window.hasShadow           = false
        window.ignoresMouseEvents  = true
        window.collectionBehavior  = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    // MARK: - Mouse passthrough

    private func startMousePassthroughMonitor() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .leftMouseDragged]
        ) { [weak self] _ in
            self?.updateMousePassthrough()
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .leftMouseDragged]
        ) { [weak self] event in
            self?.updateMousePassthrough()
            return event
        }
    }

    private func updateMousePassthrough() {
        guard let window = window else { return }
        let mouse        = NSEvent.mouseLocation
        let rect         = interactiveScreenRect()
        let shouldIgnore = !rect.contains(mouse)
        if window.ignoresMouseEvents != shouldIgnore {
            window.ignoresMouseEvents = shouldIgnore
        }
    }

    private func interactiveScreenRect() -> CGRect {
        let size: CGSize
        switch notchState.mode {
        case .collapsed:
            size = CGSize(width: notchState.notchWidth,      height: 32)
        case .hovered:
            size = CGSize(width: notchState.notchWidth + 80, height: 54)
        case .expanded:
            size = CGSize(width: settings.expandedSize.width, height: settings.expandedSize.height)
        }
        let ix = window.frame.midX - size.width / 2
        let iy = window.frame.maxY - size.height
        return CGRect(x: ix, y: iy, width: size.width, height: size.height)
    }

    // MARK: - Positioning

    @objc func positionWindow() {
        guard let screen = NSScreen.main else { return }
        let targetFrame = notchFrame(for: screen)
        window.setFrame(targetFrame, display: true)
    }

    private func notchFrame(for screen: NSScreen) -> CGRect {
        let sw = screen.frame.width
        let sh = screen.frame.height
        let ox = screen.frame.minX
        let oy = screen.frame.minY

        let ww = Self.windowWidth
        let wh = Self.windowHeight

        if #available(macOS 12.0, *),
           let left  = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let notchCenter = left.maxX + (right.minX - left.maxX) / 2
            let x = ox + notchCenter - ww / 2
            let y = oy + sh - wh
            return CGRect(x: x, y: y, width: ww, height: wh)
        } else {
            let x = ox + (sw - ww) / 2
            let y = oy + sh - wh
            return CGRect(x: x, y: y, width: ww, height: wh)
        }
    }
}
