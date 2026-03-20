//
//  DroppedFile.swift
//  NotchPro
//
//  Copyright © 2026 Murilo Ribeiro. All rights reserved.

import Foundation
import SwiftData

@Model
final class DroppedFile {
    var name: String
    var path: String
    var bookmarkData: Data?
    var droppedAt: Date

    init(name: String, path: String, bookmarkData: Data? = nil, droppedAt: Date = .now) {
        self.name = name
        self.path = path
        self.bookmarkData = bookmarkData
        self.droppedAt = droppedAt
    }
}
