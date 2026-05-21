import Foundation

enum ScreenshotService {
    static var saveDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/GhostTermShots", isDirectory: true)
    }

    // Capture full screen via /usr/sbin/screencapture. The GhostTerm window is
    // already excluded because the NSWindow has sharingType = .none.
    static func captureFullScreen() -> URL? {
        let dir = saveDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Millisecond resolution — supports rapid repeated captures without filename collisions.
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        let url = dir.appendingPathComponent("shot-\(ts).png", isDirectory: false)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        // -x: silent (no shutter sound).  -t png: explicit format.
        proc.arguments = ["-x", "-t", "png", url.path]
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            NSLog("GhostTerm: screencapture failed to launch: \(error)")
            return nil
        }
        guard proc.terminationStatus == 0, FileManager.default.fileExists(atPath: url.path) else {
            NSLog("GhostTerm: screencapture exited \(proc.terminationStatus)")
            return nil
        }
        return url
    }
}
