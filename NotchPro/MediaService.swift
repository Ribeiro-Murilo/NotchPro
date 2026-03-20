//
//  MediaService.swift
//  NotchPro
//
//  Copyright © 2026 Murilo Ribeiro. All rights reserved.

import Foundation
import AppKit
import Combine

// MARK: - MediaRemote Bridge

private enum MRBridge: Sendable {
    nonisolated(unsafe) static let handle = dlopen(
        "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW
    )

    static var isLoaded: Bool { handle != nil }

    private static func sym<T>(_ name: String) -> T? {
        guard let h = handle, let ptr = dlsym(h, name) else { return nil }
        return unsafeBitCast(ptr, to: T.self)
    }

    typealias RegisterFn   = @convention(c) (DispatchQueue) -> Void
    typealias GetInfoFn    = @convention(c) (DispatchQueue, @convention(block) @escaping (CFDictionary?) -> Void) -> Void
    typealias GetPlayingFn = @convention(c) (DispatchQueue, @convention(block) @escaping (Bool) -> Void) -> Void
    typealias GetClientFn  = @convention(c) (DispatchQueue, @convention(block) @escaping (AnyObject?) -> Void) -> Void
    typealias SendCmdFn    = @convention(c) (UInt32, AnyObject?) -> Bool

    nonisolated(unsafe) static let register:   RegisterFn?   = sym("MRMediaRemoteRegisterForNowPlayingNotifications")
    nonisolated(unsafe) static let getInfo:    GetInfoFn?    = sym("MRMediaRemoteGetNowPlayingInfo")
    nonisolated(unsafe) static let getPlaying: GetPlayingFn? = sym("MRMediaRemoteGetNowPlayingApplicationIsPlaying")
    nonisolated(unsafe) static let getClient:  GetClientFn?  = sym("MRMediaRemoteGetNowPlayingClient")
    nonisolated(unsafe) static let sendCmd:    SendCmdFn?    = sym("MRMediaRemoteSendCommand")
}

private let kInfoDidChange    = NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification")
private let kPlayingDidChange = NSNotification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification")

private let kTitle       = "kMRMediaRemoteNowPlayingInfoTitle"
private let kArtist      = "kMRMediaRemoteNowPlayingInfoArtist"
private let kArtworkData = "kMRMediaRemoteNowPlayingInfoArtworkData"
private let kDuration    = "kMRMediaRemoteNowPlayingInfoDuration"
private let kElapsedTime = "kMRMediaRemoteNowPlayingInfoElapsedTime"

@objc private protocol MRNowPlayingClientProtocol: NSObjectProtocol {
    var bundleIdentifier: String? { get }
}

// MARK: - Source

private enum MediaSource {
    case spotify, appleMusic, mediaRemote, none
}

// MARK: - Snapshot (value passed across threads)

private struct NowPlayingSnapshot {
    var source:    MediaSource
    var title:     String
    var artist:    String
    var appName:   String
    var isPlaying: Bool
    var duration:  Double
    var elapsed:   Double
    var artworkURL: URL?
}

// MARK: - MediaService

class MediaService: ObservableObject {
    @Published var title:     String   = "Not Playing"
    @Published var artist:    String   = ""
    @Published var isPlaying: Bool     = false
    @Published var appName:   String   = ""
    @Published var artwork:   NSImage? = nil
    @Published var elapsed:   Double   = 0
    @Published var duration:  Double   = 0
    @Published var volume:    Float    = 0.5

    private var elapsedBase:      Double = 0
    private var elapsedTimestamp: Date   = .now
    private var cancellables = Set<AnyCancellable>()
    private var progressTimer: Timer?
    private var currentSource: MediaSource = .none

    private var artworkCache: [String: NSImage] = [:]
    private var artworkLoadingURL: String?

    private let bgQueue = DispatchQueue(label: "notchpro.media", qos: .userInitiated)

    nonisolated init() {
        MainActor.assumeIsolated { startMonitoring() }
    }

    // MARK: - Setup

    private func startMonitoring() {
        MRBridge.register?(DispatchQueue.main)

        // MediaRemote notifications → re-poll immediately
        NotificationCenter.default.publisher(for: kInfoDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.triggerPoll() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: kPlayingDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.triggerPoll() }
            .store(in: &cancellables)

        // Regular poll every 1.5 s — runs on background thread
        Timer.publish(every: 1.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.triggerPoll() }
            .store(in: &cancellables)

        // Progress timer stays on main (lightweight math only)
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isPlaying, self.duration > 0 else { return }
                self.elapsed = min(
                    self.elapsedBase + Date().timeIntervalSince(self.elapsedTimestamp),
                    self.duration
                )
            }
        }

        updateSystemVolume()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.triggerPoll()
        }
    }

    private func triggerPoll() {
        bgQueue.async { [weak self] in self?.pollNowPlaying() }
    }

    // MARK: - Polling (background thread)

    private func pollNowPlaying() {
        if let snap = pollSpotify()     { apply(snap); return }
        if let snap = pollAppleMusic()  { apply(snap); return }
        fetchMediaRemote()
    }

    // MARK: - Spotify (AppleScript, background)

    private func pollSpotify() -> NowPlayingSnapshot? {
        guard isRunning(bundleID: "com.spotify.client") else {
            if currentSource == .spotify { scheduleReset() }
            return nil
        }
        let script = """
        tell application "Spotify"
            if player state is playing or player state is paused then
                set t to name of current track
                set a to artist of current track
                set d to duration of current track
                set p to player position
                set s to player state as string
                set u to artwork url of current track
                return t & "||" & a & "||" & (d as text) & "||" & (p as text) & "||" & s & "||" & u
            else
                return "IDLE"
            end if
        end tell
        """
        guard let result = runAppleScript(script), result != "IDLE" else { return nil }
        let parts = result.components(separatedBy: "||")
        guard parts.count >= 5 else { return nil }

        let artURL = parts.count >= 6 ? URL(string: parts[5]) : nil
        return NowPlayingSnapshot(
            source:     .spotify,
            title:      parts[0],
            artist:     parts[1],
            appName:    "Spotify",
            isPlaying:  parts[4].lowercased().contains("playing"),
            duration:   (Double(parts[2]) ?? 0) / 1000.0,
            elapsed:    Double(parts[3]) ?? 0,
            artworkURL: artURL
        )
    }

    // MARK: - Apple Music (AppleScript, background)

    private func pollAppleMusic() -> NowPlayingSnapshot? {
        guard isRunning(bundleID: "com.apple.Music") else {
            if currentSource == .appleMusic { scheduleReset() }
            return nil
        }
        let script = """
        tell application "Music"
            if player state is playing or player state is paused then
                set t to name of current track
                set a to artist of current track
                set d to duration of current track
                set p to player position
                set s to player state as string
                return t & "||" & a & "||" & (d as text) & "||" & (p as text) & "||" & s
            else
                return "IDLE"
            end if
        end tell
        """
        guard let result = runAppleScript(script), result != "IDLE" else { return nil }
        let parts = result.components(separatedBy: "||")
        guard parts.count >= 5 else { return nil }

        return NowPlayingSnapshot(
            source:     .appleMusic,
            title:      parts[0],
            artist:     parts[1],
            appName:    "Apple Music",
            isPlaying:  parts[4].lowercased().contains("playing"),
            duration:   Double(parts[2]) ?? 0,
            elapsed:    Double(parts[3]) ?? 0,
            artworkURL: nil
        )
    }

    // MARK: - MediaRemote (any app: browsers, podcasts, etc.)

    private func fetchMediaRemote() {
        guard let fn = MRBridge.getInfo else { return }
        fn(DispatchQueue.main) { [weak self] dict in
            MainActor.assumeIsolated {
                guard let self else { return }
                let info   = dict as NSDictionary? ?? [:]
                let newTitle = (info[kTitle] as? String) ?? ""

                if newTitle.isEmpty {
                    if self.currentSource == .mediaRemote { self.resetState() }
                    return
                }

                self.currentSource   = .mediaRemote
                self.title           = newTitle
                self.artist          = (info[kArtist] as? String) ?? ""
                self.duration        = (info[kDuration] as? Double) ?? 0
                self.elapsedBase     = (info[kElapsedTime] as? Double) ?? 0
                self.elapsedTimestamp = Date()
                self.elapsed         = self.elapsedBase

                if let data = info[kArtworkData] as? Data {
                    self.artwork = NSImage(data: data)
                }

                self.fetchMediaRemotePlayState()
                self.fetchMediaRemoteClient()
            }
        }
    }

    private func fetchMediaRemotePlayState() {
        MRBridge.getPlaying?(DispatchQueue.main) { [weak self] playing in
            MainActor.assumeIsolated {
                guard let self, self.currentSource == .mediaRemote else { return }
                self.isPlaying = playing
            }
        }
    }

    private func fetchMediaRemoteClient() {
        MRBridge.getClient?(DispatchQueue.main) { [weak self] clientObj in
            MainActor.assumeIsolated {
                guard let self else { return }
                guard let client = clientObj as? MRNowPlayingClientProtocol,
                      let bundleID = client.bundleIdentifier, !bundleID.isEmpty else { return }
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                    self.appName = FileManager.default
                        .displayName(atPath: url.path)
                        .replacingOccurrences(of: ".app", with: "")
                } else {
                    self.appName = bundleID
                }
            }
        }
    }

    // MARK: - Apply snapshot (main thread)

    private func apply(_ snap: NowPlayingSnapshot) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentSource    = snap.source
            self.title            = snap.title
            self.artist           = snap.artist
            self.appName          = snap.appName
            self.isPlaying        = snap.isPlaying
            self.duration         = snap.duration
            self.elapsedBase      = snap.elapsed
            self.elapsedTimestamp = Date()
            self.elapsed          = snap.elapsed

            if let url = snap.artworkURL {
                self.loadArtwork(from: url)
            } else if snap.source == .appleMusic {
                self.fetchMediaRemoteArtwork()
            }
        }
    }

    private func fetchMediaRemoteArtwork() {
        MRBridge.getInfo?(DispatchQueue.main) { [weak self] dict in
            MainActor.assumeIsolated {
                guard let self else { return }
                let info = dict as NSDictionary? ?? [:]
                if let data = info[kArtworkData] as? Data {
                    self.artwork = NSImage(data: data)
                }
            }
        }
    }

    private func scheduleReset() {
        DispatchQueue.main.async { [weak self] in self?.resetState() }
    }

    private func resetState() {
        currentSource = .none
        title         = "Not Playing"
        artist        = ""
        isPlaying     = false
        appName       = ""
        artwork       = nil
        elapsed       = 0
        duration      = 0
    }

    // MARK: - Helpers

    private func isRunning(bundleID: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
    }

    @discardableResult
    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        guard error == nil else { return nil }
        return result?.stringValue
    }

    private func loadArtwork(from url: URL) {
        let key = url.absoluteString
        if let cached = artworkCache[key] { artwork = cached; return }
        guard artworkLoadingURL != key else { return }
        artworkLoadingURL = key
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = NSImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.artworkCache[key] = image
                self?.artwork = image
                self?.artworkLoadingURL = nil
            }
        }.resume()
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        bgQueue.async { [weak self] in
            guard let self else { return }
            switch self.currentSource {
            case .spotify:
                self.runAppleScript(#"tell application "Spotify" to playpause"#)
            case .appleMusic:
                self.runAppleScript(#"tell application "Music" to playpause"#)
            default:
                _ = MRBridge.sendCmd?(2, nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.triggerPoll()
            }
        }
    }

    func nextTrack() {
        bgQueue.async { [weak self] in
            guard let self else { return }
            switch self.currentSource {
            case .spotify:
                self.runAppleScript(#"tell application "Spotify" to next track"#)
            case .appleMusic:
                self.runAppleScript(#"tell application "Music" to next track"#)
            default:
                _ = MRBridge.sendCmd?(4, nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.triggerPoll()
            }
        }
    }

    func previousTrack() {
        bgQueue.async { [weak self] in
            guard let self else { return }
            switch self.currentSource {
            case .spotify:
                self.runAppleScript(#"tell application "Spotify" to previous track"#)
            case .appleMusic:
                self.runAppleScript(#"tell application "Music" to back track"#)
            default:
                _ = MRBridge.sendCmd?(5, nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.triggerPoll()
            }
        }
    }

    // MARK: - Volume

    func volumeUp()   { adjustVolume(delta:  6.25) }
    func volumeDown() { adjustVolume(delta: -6.25) }

    private func adjustVolume(delta: Float) {
        let newVol = max(0, min(100, volume * 100 + delta))
        bgQueue.async { [weak self] in
            self?.runAppleScript("set volume output volume \(Int(newVol))")
            DispatchQueue.main.async { self?.updateSystemVolume() }
        }
    }

    private func updateSystemVolume() {
        bgQueue.async { [weak self] in
            guard let result = self?.runAppleScript("output volume of (get volume settings)"),
                  let val = Int(result) else { return }
            DispatchQueue.main.async { self?.volume = Float(val) / 100.0 }
        }
    }
}
