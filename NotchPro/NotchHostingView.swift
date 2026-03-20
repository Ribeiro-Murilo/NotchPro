//
//  NotchHostingView.swift
//  NotchPro
//
//  Copyright © 2026 Murilo Ribeiro. All rights reserved.

import SwiftUI

class NotchHostingView<Content: View>: NSHostingView<Content> {
    var state:         NotchState?
    var fileViewModel: FileDropViewModel?
    var settings:      NotchSettings?

    private var currentSize: CGSize {
        guard let state else { return CGSize(width: 180, height: 32) }
        switch state.mode {
        case .collapsed:
            return CGSize(width: state.notchWidth, height: 32)
        case .hovered:
            return CGSize(width: state.notchWidth + 80, height: 54)
        case .expanded:
            let s = settings?.expandedSize ?? .normal
            return CGSize(width: s.width, height: s.height)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        registerForDraggedTypes([NSPasteboard.PasteboardType("public.file-url")])
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = self.convert(point, from: nil)
        let size = currentSize
        let x = (bounds.width - size.width) / 2
        let y: CGFloat = 0
        let interactiveRect = CGRect(origin: CGPoint(x: x, y: y), size: size)
        return interactiveRect.contains(localPoint) ? super.hitTest(point) : nil
    }

    // MARK: - NSDraggingDestination

    private func hasFiles(_ sender: NSDraggingInfo) -> Bool {
        sender.draggingPasteboard.canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard hasFiles(sender) else { return [] }
        Task { @MainActor [weak self] in
            guard let self, let state = self.state else { return }
            state.cancelCollapse()
            state.cancelHoverCollapse()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                state.activeTab = .files
                state.isDraggingFileOver = true
            }
        }
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return hasFiles(sender) ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        Task { @MainActor [weak self] in
            guard let self, let state = self.state else { return }
            state.isDraggingFileOver = false
            if !state.isClicked {
                state.scheduleCollapse(delay: 0.5)
            }
        }
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        Task { @MainActor [weak self] in
            self?.state?.isDraggingFileOver = false
        }
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self], options: options
        ) as? [URL], !urls.isEmpty else { return false }

        Task { @MainActor [weak self] in
            urls.forEach { self?.fileViewModel?.addFile(url: $0) }
            self?.state?.isDraggingFileOver = false
        }
        return true
    }
}
