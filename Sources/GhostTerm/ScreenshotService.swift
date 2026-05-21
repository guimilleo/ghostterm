import AppKit
import ScreenCaptureKit

enum ScreenshotService {
    static var saveDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/GhostTermShots", isDirectory: true)
    }

    // Capture the full main display using ScreenCaptureKit. We use this instead
    // of the older CGDisplayCreateImage / screencapture CLI because both have
    // been degraded on macOS Sequoia — they now return only the desktop layer,
    // missing all other apps' windows. SCScreenshotManager is the only API
    // Apple actively maintains for full-screen capture on macOS 14+.
    //
    // ScreenCaptureKit also honors NSWindowSharingType.none, so GhostTerm itself
    // is still excluded from the captured image.
    static func captureFullScreen(completion: @escaping (URL?) -> Void) {
        Task.detached {
            let url = await capture()
            await MainActor.run { completion(url) }
        }
    }

    private static func capture() async -> URL? {
        do {
            // Enumerate displays. onScreenWindowsOnly = true keeps things light.
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            guard let display = content.displays.first else {
                NSLog("GhostTerm: no displays available")
                return nil
            }

            // Capture all windows on the display except GhostTerm's own panel.
            // sharingType=.none should already exclude us, but belt-and-suspenders.
            let ourPID = pid_t(ProcessInfo.processInfo.processIdentifier)
            let ourWindows = content.windows.filter { $0.owningApplication?.processID == ourPID }

            let filter = SCContentFilter(
                display: display,
                excludingApplications: [],
                exceptingWindows: ourWindows
            )

            let config = SCStreamConfiguration()
            config.width = Int(CGFloat(display.width) * displayScale())
            config.height = Int(CGFloat(display.height) * displayScale())
            config.showsCursor = false
            config.scalesToFit = false

            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )

            // Write PNG to disk.
            let dir = saveDirectory
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let ts = Int(Date().timeIntervalSince1970 * 1000)
            let url = dir.appendingPathComponent("shot-\(ts).png", isDirectory: false)

            let rep = NSBitmapImageRep(cgImage: cgImage)
            rep.size = NSSize(width: cgImage.width, height: cgImage.height)
            guard let data = rep.representation(using: .png, properties: [:]) else {
                NSLog("GhostTerm: PNG encoding failed")
                return nil
            }
            try data.write(to: url)
            NSLog("GhostTerm: captured \(cgImage.width)x\(cgImage.height) → \(url.path)")
            return url
        } catch {
            NSLog("GhostTerm: ScreenCaptureKit failed: \(error)")
            return nil
        }
    }

    private static func displayScale() -> CGFloat {
        NSScreen.main?.backingScaleFactor ?? 2.0
    }
}
