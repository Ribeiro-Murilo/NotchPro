//
//  NotchState.swift
//  NotchPro
//
//  Copyright © 2026 Murilo Ribeiro. All rights reserved.

import Foundation
import SwiftUI
import Combine

enum NotchTab {
    case media, files, settings
}

enum NotchMode {
    case collapsed  // dentro do notch, tamanho exato
    case hovered    // levemente expandido para indicar interatividade
    case expanded   // totalmente aberto com conteudo
}

class NotchState: ObservableObject {
    @Published var isHovering: Bool = false
    @Published var isClicked: Bool = false
    @Published var activeTab: NotchTab = .media
    @Published var isDraggingFileOver: Bool = false
    @Published var notchWidth: CGFloat = 180

    private var collapseTask: DispatchWorkItem?
    private var hoverCollapseTask: DispatchWorkItem?

    var mode: NotchMode {
        if isClicked || isDraggingFileOver { return .expanded }
        if isHovering { return .hovered }
        return .collapsed
    }

    var isExpanded: Bool { mode == .expanded }

    func toggleExpanded() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            isClicked.toggle()
        }
    }

    func collapse() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            isClicked = false
        }
    }

    func scheduleHoverCollapse(delay: Double = 0.3) {
        hoverCollapseTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if !self.isClicked && !self.isDraggingFileOver {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    self.isHovering = false
                }
            }
        }
        hoverCollapseTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
    }

    func cancelHoverCollapse() {
        hoverCollapseTask?.cancel()
        hoverCollapseTask = nil
    }

    func scheduleCollapse(delay: Double = 0.4) {
        collapseTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self, !self.isDraggingFileOver else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                self.isClicked = false
                self.isHovering = false
            }
        }
        collapseTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
    }

    func cancelCollapse() {
        collapseTask?.cancel()
        collapseTask = nil
    }
}
