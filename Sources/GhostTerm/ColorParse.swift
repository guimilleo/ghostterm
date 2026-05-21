import AppKit

enum ColorParse {
    // Accepts "#RGB", "#RRGGBB", "#RRGGBBAA", or named: white black red green blue
    // yellow cyan magenta gray grey. Falls back to nil on unknown input.
    static func nsColor(_ raw: String?) -> NSColor? {
        guard let raw else { return nil }
        let s = raw.trimmingCharacters(in: .whitespaces).lowercased()
        if let named = named[s] { return named }

        guard s.hasPrefix("#") else { return nil }
        let hex = String(s.dropFirst())
        switch hex.count {
        case 3:
            // #RGB → expand each char
            let chars = Array(hex)
            let r = component(String(chars[0]) + String(chars[0]))
            let g = component(String(chars[1]) + String(chars[1]))
            let b = component(String(chars[2]) + String(chars[2]))
            guard let r, let g, let b else { return nil }
            return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
        case 6:
            let r = component(String(hex.prefix(2)))
            let g = component(String(hex.dropFirst(2).prefix(2)))
            let b = component(String(hex.dropFirst(4).prefix(2)))
            guard let r, let g, let b else { return nil }
            return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
        case 8:
            let r = component(String(hex.prefix(2)))
            let g = component(String(hex.dropFirst(2).prefix(2)))
            let b = component(String(hex.dropFirst(4).prefix(2)))
            let a = component(String(hex.dropFirst(6).prefix(2)))
            guard let r, let g, let b, let a else { return nil }
            return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
        default:
            return nil
        }
    }

    private static func component(_ pair: String) -> CGFloat? {
        guard let v = UInt8(pair, radix: 16) else { return nil }
        return CGFloat(v) / 255.0
    }

    private static let named: [String: NSColor] = [
        "white":   .white,
        "black":   .black,
        "red":     NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1),
        "green":   NSColor(srgbRed: 0, green: 0.7, blue: 0, alpha: 1),
        "blue":    NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1),
        "yellow":  NSColor(srgbRed: 1, green: 1, blue: 0, alpha: 1),
        "cyan":    NSColor(srgbRed: 0, green: 1, blue: 1, alpha: 1),
        "magenta": NSColor(srgbRed: 1, green: 0, blue: 1, alpha: 1),
        "gray":    .gray,
        "grey":    .gray,
    ]
}
