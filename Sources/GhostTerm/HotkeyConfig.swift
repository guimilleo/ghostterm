import Foundation
import Carbon

// Parses strings like "cmd+shift+p" into a Carbon (keyCode, modifiers) pair.
struct HotkeySpec {
    let keyCode: UInt32
    let modifiers: UInt32

    static func parse(_ s: String) -> HotkeySpec? {
        let parts = s.lowercased()
            .split(whereSeparator: { $0 == "+" || $0 == "-" || $0 == " " })
            .map(String.init)
        guard !parts.isEmpty else { return nil }

        var mods: UInt32 = 0
        var key: String?
        for p in parts {
            switch p {
            case "cmd", "command", "⌘":    mods |= UInt32(cmdKey)
            case "shift", "⇧":             mods |= UInt32(shiftKey)
            case "opt", "option", "alt", "⌥": mods |= UInt32(optionKey)
            case "ctrl", "control", "⌃":  mods |= UInt32(controlKey)
            default:                        key = p
            }
        }
        guard let key, let code = Self.keyCode(for: key) else { return nil }
        return HotkeySpec(keyCode: code, modifiers: mods)
    }

    private static func keyCode(for s: String) -> UInt32? {
        // Letters
        if s.count == 1, let scalar = s.unicodeScalars.first, scalar.isASCII {
            let c = Character(scalar)
            if let code = letterMap[c] { return code }
            if let code = digitMap[c] { return code }
        }
        // Function keys
        if s.hasPrefix("f"), let n = Int(s.dropFirst()), (1...12).contains(n) {
            return fkeyMap[n]
        }
        return namedMap[s]
    }

    private static let letterMap: [Character: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "o": 31, "u": 32, "i": 34, "p": 35, "l": 37,
        "j": 38, "k": 40, "n": 45, "m": 46
    ]
    private static let digitMap: [Character: UInt32] = [
        "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22,
        "7": 26, "8": 28, "9": 25, "0": 29
    ]
    private static let fkeyMap: [Int: UInt32] = [
        1: 122, 2: 120, 3: 99, 4: 118, 5: 96, 6: 97,
        7: 98, 8: 100, 9: 101, 10: 109, 11: 103, 12: 111
    ]
    private static let namedMap: [String: UInt32] = [
        "space": 49, "return": 36, "enter": 36, "tab": 48, "escape": 53, "esc": 53
    ]
}
