//
//  NotchSettings.swift
//  NotchPro
//
//  Copyright © 2026 Murilo Ribeiro. All rights reserved.
//

import SwiftUI
import Combine

// MARK: - Enums

enum HoverBehavior: String, CaseIterable {
    case peek       = "peek"
    case expandFull = "expandFull"

    var label: String {
        switch self {
        case .peek:       return "Aparecer levemente"
        case .expandFull: return "Abrir completo"
        }
    }
    var icon: String {
        switch self {
        case .peek:       return "arrow.up.left.and.arrow.down.right"
        case .expandFull: return "rectangle.expand.vertical"
        }
    }
}

enum AccentColorOption: String, CaseIterable {
    case blue   = "blue"
    case purple = "purple"
    case green  = "green"
    case orange = "orange"
    case pink   = "pink"
    case white  = "white"

    var color: Color {
        switch self {
        case .blue:   return Color(red: 0.10, green: 0.47, blue: 1.00)
        case .purple: return Color(red: 0.69, green: 0.32, blue: 1.00)
        case .green:  return Color(red: 0.20, green: 0.85, blue: 0.45)
        case .orange: return Color(red: 1.00, green: 0.58, blue: 0.10)
        case .pink:   return Color(red: 1.00, green: 0.25, blue: 0.60)
        case .white:  return Color(white: 0.85)
        }
    }
}

enum ExpandedSizeOption: String, CaseIterable {
    case compact = "compact"
    case normal  = "normal"
    case large   = "large"

    var label: String {
        switch self {
        case .compact: return "Compacto"
        case .normal:  return "Normal"
        case .large:   return "Grande"
        }
    }
    var width: CGFloat {
        switch self {
        case .compact: return 480
        case .normal:  return 560
        case .large:   return 640
        }
    }
    var height: CGFloat {
        switch self {
        case .compact: return 195
        case .normal:  return 215
        case .large:   return 240
        }
    }
}

// MARK: - NotchSettings

class NotchSettings: ObservableObject {

    @Published var hoverBehavior: HoverBehavior {
        didSet { save("hoverBehavior", hoverBehavior.rawValue) }
    }
    @Published var accentColor: AccentColorOption {
        didSet { save("accentColor", accentColor.rawValue) }
    }
    @Published var expandedSize: ExpandedSizeOption {
        didSet { save("expandedSize", expandedSize.rawValue) }
    }

    init() {
        let ud = UserDefaults.standard
        hoverBehavior = HoverBehavior(rawValue: ud.string(forKey: "hoverBehavior") ?? "") ?? .peek
        accentColor   = AccentColorOption(rawValue: ud.string(forKey: "accentColor") ?? "") ?? .blue
        expandedSize  = ExpandedSizeOption(rawValue: ud.string(forKey: "expandedSize") ?? "") ?? .normal
    }

    private func save(_ key: String, _ value: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
