//
//  ScreenshotMonitor.swift
//  NotchPro
//
//  Copyright © 2026 Murilo Ribeiro. All rights reserved.
//

import Foundation
import AppKit

class ScreenshotMonitor {
    private let fileViewModel: FileDropViewModel
    private var sources: [DispatchSourceFileSystemObject] = []
    private var knownFiles: [String: Set<String>] = [:]

    init(fileViewModel: FileDropViewModel) {
        self.fileViewModel = fileViewModel
        startMonitoring()
    }

    deinit {
        sources.forEach { $0.cancel() }
    }

    private func screenshotDirectories() -> [URL] {
        var dirs: [URL] = []
        if let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            dirs.append(desktop)
        }
        if let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first {
            let screenshots = pictures.appendingPathComponent("Screenshots")
            if FileManager.default.fileExists(atPath: screenshots.path) {
                dirs.append(screenshots)
            }
        }
        return dirs
    }

    private func startMonitoring() {
        for dir in screenshotDirectories() {
            knownFiles[dir.path] = currentScreenshots(in: dir)

            let fd = open(dir.path, O_EVTONLY)
            guard fd >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: .write,
                queue: DispatchQueue.global(qos: .utility)
            )
            source.setEventHandler { [weak self] in self?.directoryChanged(dir) }
            source.setCancelHandler { close(fd) }
            source.resume()
            sources.append(source)
        }
    }

    private func currentScreenshots(in dir: URL) -> Set<String> {
        let items = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return Set(items.filter { isScreenshot($0) })
    }

    private func isScreenshot(_ name: String) -> Bool {
        let lower = name.lowercased()
        guard lower.hasSuffix(".png") else { return false }
        return lower.hasPrefix("screenshot") ||
               lower.hasPrefix("captura de tela") ||
               lower.hasPrefix("screen shot")
    }

    private func directoryChanged(_ dir: URL) {
        let current = currentScreenshots(in: dir)
        let known = knownFiles[dir.path] ?? []
        let newFiles = current.subtracting(known)
        knownFiles[dir.path] = current

        for name in newFiles {
            let url = dir.appendingPathComponent(name)
            // Aguarda arquivo ser escrito completamente
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    self.fileViewModel.addFile(url: url)
                }
            }
        }
    }
}
