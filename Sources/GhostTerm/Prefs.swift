import Foundation

enum Prefs {
    static let minOpacity: CGFloat = 0.25
    static let maxOpacity: CGFloat = 0.95   // never fully opaque

    private static let kOpacity = "ghostterm.opacity"

    static var opacity: CGFloat {
        get {
            let raw = UserDefaults.standard.object(forKey: kOpacity) as? Double
            return clamp(CGFloat(raw ?? 0.80))
        }
        set {
            UserDefaults.standard.set(Double(clamp(newValue)), forKey: kOpacity)
        }
    }

    static func clamp(_ v: CGFloat) -> CGFloat {
        min(maxOpacity, max(minOpacity, v))
    }

    // MARK: - Config file (hotkey, future expansion)

    static var configFileURL: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/ghostterm", isDirectory: true)
        return dir.appendingPathComponent("config.json", isDirectory: false)
    }

    static func loadConfig() -> AppConfig {
        let url = configFileURL
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var cfg: AppConfig
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) {
            cfg = decoded
        } else {
            cfg = .default
        }
        // Self-heal: backfill any missing optional keys with their defaults,
        // then write back so the file always reflects the full schema.
        if cfg.background == nil { cfg.background = AppConfig.default.background }
        if cfg.foreground == nil { cfg.foreground = AppConfig.default.foreground }
        try? JSONEncoder.pretty.encode(cfg).write(to: url)
        return cfg
    }

    static func save(_ cfg: AppConfig) {
        let url = configFileURL
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? JSONEncoder.pretty.encode(cfg).write(to: url)
    }
}

struct AppConfig: Codable {
    var screenshotHotkey: String
    var background: String?
    var foreground: String?

    static let `default` = AppConfig(
        screenshotHotkey: "cmd+shift+p",
        background: "#000000",
        foreground: "#FFFFFF"
    )
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}
