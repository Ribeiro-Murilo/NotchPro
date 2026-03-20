//
//  ExpandedContentView.swift
//  NotchPro
//
//  Copyright © 2026 Murilo Ribeiro. All rights reserved.
//  Copyright © 2026 Murilo Ribeiro. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Expanded root

struct ExpandedContentView: View {
    @ObservedObject var mediaService:  MediaService
    @ObservedObject var fileViewModel: FileDropViewModel
    @ObservedObject var state:         NotchState
    @EnvironmentObject var settings:   NotchSettings

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar — Media e Files nas bordas, centro livre (câmera), gear à direita
            HStack(spacing: 0) {
                // Esquerda
                TabButton(label: "Media", icon: "music.note", tab: .media, activeTab: $state.activeTab)

                Spacer() // centro vazio = câmera do Mac

                // Direita: Files + engrenagem
                HStack(spacing: 4) {
                    TabButton(label: "Files", icon: "folder", tab: .files,
                              activeTab: $state.activeTab, badge: fileViewModel.files.count)

                    // Botão de engrenagem pequeno
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            state.activeTab = state.activeTab == .settings ? .media : .settings
                        }
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(state.activeTab == .settings
                                             ? settings.accentColor.color
                                             : .white.opacity(0.35))
                            .frame(width: 26, height: 26)
                            .background(state.activeTab == .settings
                                        ? settings.accentColor.color.opacity(0.18)
                                        : Color.clear)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Divider()
                .background(Color.white.opacity(0.08))
                .padding(.horizontal, 16)
                .padding(.top, 6)

            Group {
                switch state.activeTab {
                case .media:
                    MediaTabView(mediaService: mediaService)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .leading)),
                            removal:   .opacity.combined(with: .move(edge: .trailing))
                        ))
                case .files:
                    FilesTabView(fileViewModel: fileViewModel, isDragOver: state.isDraggingFileOver)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal:   .opacity.combined(with: .move(edge: .leading))
                        ))
                case .settings:
                    SettingsTabView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal:   .opacity.combined(with: .move(edge: .leading))
                        ))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state.activeTab)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            .padding(.top, 8)
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let label:    String
    let icon:     String
    let tab:      NotchTab
    @Binding var activeTab: NotchTab
    var badge: Int = 0
    @EnvironmentObject var settings: NotchSettings

    var isActive: Bool { activeTab == tab }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                activeTab = tab
            }
        } label: {
            HStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                    if badge > 0 {
                        Text("\(min(badge, 99))")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(settings.accentColor.color)
                            .clipShape(Capsule())
                            .offset(x: 8, y: -5)
                    }
                }
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(isActive ? .white : .white.opacity(0.4))
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(isActive ? settings.accentColor.color.opacity(0.2) : .clear)
            .clipShape(Capsule())
            .animation(.easeInOut(duration: 0.2), value: isActive)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Tab

struct SettingsTabView: View {
    @EnvironmentObject var settings: NotchSettings

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {

                // Cor de destaque
                SettingsSection(title: "Cor de destaque") {
                    HStack(spacing: 10) {
                        ForEach(AccentColorOption.allCases, id: \.rawValue) { option in
                            ColorCircleButton(option: option,
                                             isSelected: settings.accentColor == option) {
                                settings.accentColor = option
                            }
                        }
                    }
                }

                // Comportamento do hover
                SettingsSection(title: "Ao passar o mouse") {
                    VStack(spacing: 5) {
                        ForEach(HoverBehavior.allCases, id: \.rawValue) { option in
                            HoverOptionRow(option: option,
                                          isSelected: settings.hoverBehavior == option) {
                                settings.hoverBehavior = option
                            }
                        }
                    }
                }

                // Tamanho expandido
                SettingsSection(title: "Tamanho expandido") {
                    HStack(spacing: 6) {
                        ForEach(ExpandedSizeOption.allCases, id: \.rawValue) { option in
                            SizeOptionButton(option: option,
                                            isSelected: settings.expandedSize == option) {
                                settings.expandedSize = option
                            }
                        }
                    }
                }

                // Copyright
                Spacer(minLength: 6)
                Text("© 2026 Murilo Ribeiro · NotchPro")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.22))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.35))
                .tracking(1)
            content()
        }
    }
}

// MARK: - Color circle

struct ColorCircleButton: View {
    let option:     AccentColorOption
    let isSelected: Bool
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(option.color)
                    .frame(width: 22, height: 22)
                if isSelected {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 26, height: 26)
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Hover option row

struct HoverOptionRow: View {
    let option:     HoverBehavior
    let isSelected: Bool
    let action:     () -> Void
    @EnvironmentObject var settings: NotchSettings

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? settings.accentColor.color : Color.white.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                    if isSelected {
                        Circle()
                            .fill(settings.accentColor.color)
                            .frame(width: 8, height: 8)
                    }
                }
                Image(systemName: option.icon)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                Text(option.label)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isSelected ? settings.accentColor.color.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Size option button

struct SizeOptionButton: View {
    let option:     ExpandedSizeOption
    let isSelected: Bool
    let action:     () -> Void
    @EnvironmentObject var settings: NotchSettings

    var body: some View {
        Button(action: action) {
            Text(option.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.45))
                .padding(.vertical, 5)
                .padding(.horizontal, 12)
                .background(isSelected ? settings.accentColor.color.opacity(0.25) : Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? settings.accentColor.color.opacity(0.6) : Color.clear, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Media Tab

struct MediaTabView: View {
    @ObservedObject var mediaService: MediaService

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 8) {
                ControlButton(icon: "speaker.wave.3.fill", size: 10) { mediaService.volumeUp() }
                VolumeBar(volume: mediaService.volume)
                    .frame(width: 4, height: 50)
                ControlButton(icon: "speaker.fill", size: 10) { mediaService.volumeDown() }
            }
            .frame(width: 24)

            Group {
                if let img = mediaService.artwork {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    LinearGradient(colors: [.purple, .indigo],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                    .overlay(Image(systemName: "music.note")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.7)))
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(mediaService.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(mediaService.artist.isEmpty ? mediaService.appName : mediaService.artist)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }

                HStack(spacing: 20) {
                    ControlButton(icon: "backward.fill",  size: 14) { mediaService.previousTrack() }
                    ControlButton(icon: mediaService.isPlaying ? "pause.fill" : "play.fill", size: 18) { mediaService.togglePlayPause() }
                    ControlButton(icon: "forward.fill",   size: 14) { mediaService.nextTrack() }
                }
                .padding(.top, 2)

                if mediaService.duration > 0 {
                    VStack(spacing: 2) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.15)).frame(height: 3)
                                Capsule().fill(Color.white.opacity(0.6))
                                    .frame(width: geo.size.width * min(mediaService.elapsed / mediaService.duration, 1.0), height: 3)
                            }
                        }
                        .frame(height: 3)
                        HStack {
                            Text(formatTime(mediaService.elapsed))
                            Spacer()
                            Text(formatTime(mediaService.duration))
                        }
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.35))
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Volume bar

struct VolumeBar: View {
    let volume: Float

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.15))
                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.6))
                    .frame(height: geo.size.height * CGFloat(max(0, min(volume, 1))))
            }
        }
    }
}

struct ControlButton: View {
    let icon:   String
    let size:   CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: size + 12, height: size + 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Files Tab

struct FilesTabView: View {
    @ObservedObject var fileViewModel: FileDropViewModel
    @EnvironmentObject var settings:   NotchSettings
    let isDragOver: Bool

    var body: some View {
        VStack(spacing: 6) {
            // Drop zone for new files
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isDragOver ? settings.accentColor.color.opacity(0.8) : Color.white.opacity(0.15),
                            style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isDragOver ? settings.accentColor.color.opacity(0.1) : Color.white.opacity(0.04))
                    )
                    .animation(.easeInOut(duration: 0.2), value: isDragOver)

                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 12, weight: .medium))
                    Text(isDragOver ? "Soltar para adicionar" : "Arraste arquivos aqui")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.white.opacity(isDragOver ? 0.9 : 0.4))
            }
            .frame(height: 32)

            if fileViewModel.files.isEmpty {
                Spacer()
                Text("Nenhum arquivo guardado")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(fileViewModel.files) { file in
                            DraggableFileRow(file: file, viewModel: fileViewModel)
                        }
                    }
                }
                .frame(maxHeight: 62)

                Divider().background(Color.white.opacity(0.08))

                HStack(spacing: 6) {
                    DragActionZone(icon: "wifi",            label: "AirDrop", color: settings.accentColor.color) { url in
                        NSSharingService(named: .sendViaAirDrop)?.perform(withItems: [url])
                    }
                    DragActionZone(icon: "folder.badge.plus", label: "Guardar", color: .green) { url in
                        let panel = NSSavePanel()
                        panel.nameFieldStringValue = url.lastPathComponent
                        panel.directoryURL = FileManager.default
                            .urls(for: .downloadsDirectory, in: .userDomainMask).first
                        panel.begin { response in
                            guard response == .OK, let dest = panel.url else { return }
                            try? FileManager.default.copyItem(at: url, to: dest)
                        }
                    }
                }
                .frame(height: 34)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Drag Action Zone

struct DragActionZone: View {
    let icon:    String
    let label:   String
    let color:   Color
    let onDrop:  (URL) -> Void

    @State private var isTargeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isTargeted ? color.opacity(0.25) : Color.white.opacity(0.05))
            RoundedRectangle(cornerRadius: 8)
                .stroke(isTargeted ? color.opacity(0.7) : Color.white.opacity(0.12), lineWidth: 1)

            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isTargeted ? color : .white.opacity(0.5))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isTargeted ? color : .white.opacity(0.5))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { item, _ in
                guard let url = item else { return }
                DispatchQueue.main.async { onDrop(url) }
            }
            return true
        }
    }
}

// MARK: - Draggable File Row

struct DraggableFileRow: View {
    let file:  DroppedFile
    @ObservedObject var viewModel: FileDropViewModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: fileIcon(for: file.name))
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 18)

            Text(file.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button { viewModel.openFile(file) } label: {
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { viewModel.removeFile(file) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onDrag {
            NSItemProvider(object: URL(fileURLWithPath: file.path) as NSURL)
        }
    }

    private func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf":                                return "doc.text"
        case "png", "jpg", "jpeg", "gif", "heic": return "photo"
        case "mp4", "mov", "avi":                  return "film"
        case "mp3", "aac", "flac", "wav":          return "music.note"
        case "zip", "gz", "tar":                   return "archivebox"
        case "swift", "py", "js", "ts", "html":   return "doc.badge.gearshape"
        default:                                   return "doc"
        }
    }
}
