import AppKit
import CoreGraphics

enum ScreenshotService {
    static var saveDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/GhostTermShots", isDirectory: true)
    }

    // Capture the full main display directly in-process via CGDisplayCreateImage.
    // No subprocess — avoids two macOS Sequoia bugs:
    //   1. /usr/sbin/screencapture runs in a degraded mode under our parent's
    //      TCC attribution and only captures the desktop layer, missing other
    //      apps' windows.
    //   2. The same binary loads Photos.framework internally, which triggers a
    //      spurious Photos permission prompt attributed to GhostTerm.
    //
    // Our window's sharingType = .none still excludes GhostTerm itself from
    // the captured image — that's a window-server-level rule, not a CLI flag.
    static func captureFullScreen() -> URL? {
        let dir = saveDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Millisecond resolution — supports rapid repeated captures.
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        let url = dir.appendingPathComponent("shot-\(ts).png", isDirectory: false)

        guard let cgImage = CGDisplayCreateImage(CGMainDisplayID()) else {
            NSLog("GhostTerm: CGDisplayCreateImage returned nil — check Screen Recording permission")
            return nil
        }

        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = NSSize(width: cgImage.width, height: cgImage.height)

        guard let data = rep.representation(using: .png, properties: [:]) else {
            NSLog("GhostTerm: PNG encoding failed")
            return nil
        }

        do {
            try data.write(to: url)
            NSLog("GhostTerm: captured \(cgImage.width)x\(cgImage.height) → \(url.path)")
            return url
        } catch {
            NSLog("GhostTerm: failed to write screenshot: \(error)")
            return nil
        }
    }
}
