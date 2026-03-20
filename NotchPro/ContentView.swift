//
//  ContentView.swift
//  NotchPro
//
//  Copyright © 2026 Murilo Ribeiro. All rights reserved.

import SwiftUI

struct ContentView: View {
    @ObservedObject var state:         NotchState
    @ObservedObject var mediaService:  MediaService
    @ObservedObject var fileViewModel: FileDropViewModel
    @EnvironmentObject var settings:   NotchSettings

    private let spring = Animation.spring(response: 0.4, dampingFraction: 0.78)

    private let collapsedH:    CGFloat = 32
    private let hoveredExtraW: CGFloat = 80
    private let hoveredH:      CGFloat = 54

    private var currentW: CGFloat {
        switch state.mode {
        case .collapsed: return state.notchWidth
        case .hovered:   return state.notchWidth + hoveredExtraW
        case .expanded:  return settings.expandedSize.width
        }
    }

    private var currentH: CGFloat {
        switch state.mode {
        case .collapsed: return collapsedH
        case .hovered:   return hoveredH
        case .expanded:  return settings.expandedSize.height
        }
    }

    private var cornerR: CGFloat {
        switch state.mode {
        case .collapsed: return 0
        case .hovered:   return 16
        case .expanded:  return 22
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear

            ZStack(alignment: .top) {
                // Background: Dock-like translucent frosted glass
                ZStack {
                    VisualEffectView(
                        material: .sidebar,
                        blendingMode: .behindWindow
                    )
                    Color.black.opacity(0.52)
                }
                .clipShape(NotchShape(topRadius: 0, bottomRadius: cornerR))
                .overlay(
                    // Glass border on hover/expanded
                    NotchShape(topRadius: 0, bottomRadius: cornerR)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(state.mode == .collapsed ? 0 : 0.25),
                                    Color.white.opacity(state.mode == .collapsed ? 0 : 0.08),
                                    Color.white.opacity(state.mode == .collapsed ? 0 : 0.15)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: .black.opacity(state.mode == .collapsed ? 0 : 0.5),
                    radius: state.mode == .expanded ? 18 : 8,
                    x: 0,
                    y: state.mode == .expanded ? 8 : 4
                )
                .frame(width: currentW, height: currentH)

                // Content
                Group {
                    switch state.mode {
                    case .collapsed:
                        CollapsedContentView()
                            .frame(width: state.notchWidth, height: collapsedH)
                            .transition(.opacity)

                    case .hovered:
                        HoveredContentView(mediaService: mediaService, state: state, fileViewModel: fileViewModel)
                            .frame(width: state.notchWidth + hoveredExtraW, height: hoveredH)
                            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))

                    case .expanded:
                        ExpandedContentView(
                            mediaService: mediaService,
                            fileViewModel: fileViewModel,
                            state: state
                        )
                        .frame(width: settings.expandedSize.width, height: settings.expandedSize.height)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.92, anchor: .top)),
                            removal:   .opacity.combined(with: .scale(scale: 0.88, anchor: .top))
                        ))
                    }
                }
            }
            .animation(spring, value: state.mode == .collapsed)
            .animation(spring, value: state.mode == .hovered)
            .animation(spring, value: state.mode == .expanded)
            .onHover { hovering in
                if hovering {
                    state.cancelHoverCollapse()
                    state.cancelCollapse()
                    if !state.isClicked {
                        if settings.hoverBehavior == .expandFull {
                            withAnimation(spring) { state.isClicked = true }
                        } else {
                            withAnimation(spring) { state.isHovering = true }
                        }
                    }
                } else {
                    if settings.hoverBehavior == .expandFull {
                        state.scheduleCollapse(delay: 0.8)
                    } else if state.isClicked {
                        state.scheduleCollapse(delay: 0.6)
                    } else {
                        state.scheduleHoverCollapse()
                    }
                }
            }
            .onTapGesture {
                state.cancelCollapse()
                state.cancelHoverCollapse()
                state.toggleExpanded()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Notch Shape (flat top, rounded bottom)

struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let tr = min(topRadius, rect.height / 2, rect.width / 2)
        let br = min(bottomRadius, rect.height / 2, rect.width / 2)

        var p = Path()
        // Top-left
        p.move(to: CGPoint(x: rect.minX + tr, y: rect.minY))
        // Top edge
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        // Top-right corner
        if tr > 0 {
            p.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                     radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        }
        // Right edge
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        // Bottom-right corner
        if br > 0 {
            p.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                     radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        }
        // Bottom edge
        p.addLine(to: CGPoint(x: rect.minX + br, y: rect.maxY))
        // Bottom-left corner
        if br > 0 {
            p.addArc(center: CGPoint(x: rect.minX + br, y: rect.maxY - br),
                     radius: br, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        }
        // Left edge
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tr))
        // Top-left corner
        if tr > 0 {
            p.addArc(center: CGPoint(x: rect.minX + tr, y: rect.minY + tr),
                     radius: tr, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Collapsed

struct CollapsedContentView: View {
    var body: some View {
        Color.clear
    }
}

// MARK: - Hovered (hint visual with glass look)

struct HoveredContentView: View {
    @ObservedObject var mediaService:  MediaService
    @ObservedObject var state:         NotchState
    @ObservedObject var fileViewModel: FileDropViewModel
    @EnvironmentObject var settings:   NotchSettings

    var body: some View {
        HStack(spacing: 8) {
            Button {
                state.activeTab = .media
                state.cancelHoverCollapse()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                    state.isClicked = true
                }
            } label: {
                Image(systemName: "music.note")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)

            Spacer()

            if mediaService.isPlaying {
                HStack(spacing: 4) {
                    PlayingBars()
                    Text(mediaService.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 100)
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }

            Spacer()

            Button {
                state.activeTab = .files
                state.cancelHoverCollapse()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                    state.isClicked = true
                }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "folder")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))

                    if fileViewModel.files.count > 0 {
                        Text("\(min(fileViewModel.files.count, 99))")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(settings.accentColor.color)
                            .clipShape(Capsule())
                            .offset(x: 9, y: -5)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Playing bars animation

struct PlayingBars: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.green)
                    .frame(width: 2, height: animate ? CGFloat.random(in: 4...10) : 3)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.15),
                        value: animate
                    )
            }
        }
        .frame(width: 10, height: 10)
        .onAppear { animate = true }
    }
}
