//
//  FileDropViewModel.swift
//  NotchPro
//
//  Copyright © 2026 Murilo Ribeiro. All rights reserved.

import SwiftUI
import SwiftData
import AppKit
import Combine

@MainActor
class FileDropViewModel: ObservableObject {
    @Published var files: [DroppedFile] = []
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadFiles()
    }

    func loadFiles() {
        let descriptor = FetchDescriptor<DroppedFile>(
            sortBy: [SortDescriptor(\.droppedAt, order: .reverse)]
        )
        files = (try? modelContext.fetch(descriptor)) ?? []
    }

    func addFile(url: URL) {
        let file = DroppedFile(name: url.lastPathComponent, path: url.path)
        modelContext.insert(file)
        try? modelContext.save()
        loadFiles()
    }

    func openFile(_ file: DroppedFile) {
        let url = URL(fileURLWithPath: file.path)
        if FileManager.default.fileExists(atPath: file.path) {
            NSWorkspace.shared.open(url)
        }
    }

    func removeFile(_ file: DroppedFile) {
        modelContext.delete(file)
        try? modelContext.save()
        loadFiles()
    }
}
