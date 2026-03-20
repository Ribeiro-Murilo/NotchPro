# NotchPro

> Transform your MacBook notch into a dynamic control center for media, files, and more.

![macOS](https://img.shields.io/badge/macOS-14%2B-black?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)

---

## Overview

NotchPro lives in your MacBook's notch area and stays out of your way until you need it. Hover to see what's playing, click to expand the full control center, or drag files directly onto it to store them temporarily.

The window is fully click-through when not in use — nothing gets in your way.

---

## Features

### Media Player
- Displays the current track from **Spotify**, **Apple Music**, or any system media source (YouTube, podcasts, etc.)
- Album artwork, artist name, progress bar, and playback controls (previous / play-pause / next)
- Volume control via the vertical slider on the left
- Runs on a background thread — zero UI freezes

### File Tray
- Drag files onto the notch to store them temporarily
- Drag stored files to the **AirDrop** zone to share instantly
- Drag stored files to the **Save** zone to copy via the save panel
- File count badge visible on hover so you always know what's stored

### Notch Integration
- **Collapsed**: sits flush with the physical notch — completely invisible
- **Hovered**: expands slightly, shows media status and file badge
- **Expanded**: full control center with media and files tabs
- Dock-like frosted glass background — shows what's behind it

---

## Requirements

- MacBook with notch (2021 or later)
- macOS 14 Sonoma or later
- Xcode 15+

---

## Installation

```bash
git clone https://github.com/your-username/NotchPro.git
cd NotchPro
open NotchPro.xcodeproj
```

Build and run in Xcode. No external dependencies.

### Permissions

On first launch macOS will ask for **Automation** permissions so NotchPro can read playback info from Music and Spotify via AppleScript:

**System Settings → Privacy & Security → Automation**

Enable access for **Music** and **Spotify**.

---

## Architecture

```
NotchPro
├── NotchWindowController   Window setup, positioning, mouse passthrough
├── NotchHostingView        Hit testing — restricts interaction to notch area only
├── NotchState              Observable state machine (collapsed / hovered / expanded)
├── MediaService            Media polling — AppleScript (bg thread) + MediaRemote
├── FileDropViewModel       File tray persistence via SwiftData
└── Views
    ├── ContentView         Root layout + notch shape + hover/tap logic
    ├── ExpandedContentView Media tab, Files tab, drag zones
    └── VisualEffectView    NSVisualEffectView wrapper for blur
```

**Mouse passthrough**: the window covers 600×260 pt at the top of the screen. A global + local `NSEvent` monitor toggles `ignoresMouseEvents` dynamically based on cursor position, so only the active notch area captures clicks.

**Media**: AppleScript (Spotify + Apple Music) runs on a dedicated background queue. MediaRemote handles everything else (browsers, system audio). Sources are prioritised: Spotify → Apple Music → MediaRemote.

---

## License

MIT
