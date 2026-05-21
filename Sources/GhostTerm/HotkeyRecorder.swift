import AppKit
import Carbon

// A single-row hotkey recorder: shows the current binding and a Record button.
// Click Record, press a combo, the new spec is committed via `onChange`.
final class HotkeyRecorder: NSView {
    private let label = NSTextField(labelWithString: "")
    private let recordButton = NSButton(title: "Record", target: nil, action: nil)
    private var recording = false
    private var eventMonitor: Any?

    var onChange: ((String) -> Void)?

    init(currentSpec: String) {
        super.init(frame: .zero)
        label.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        label.stringValue = Self.pretty(currentSpec)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        recordButton.bezelStyle = .rounded
        recordButton.target = self
        recordButton.action = #selector(toggleRecord)
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(recordButton)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),

            recordButton.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 12),
            recordButton.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            recordButton.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        if let m = eventMonitor { NSEvent.removeMonitor(m) }
    }

    func update(spec: String) {
        label.stringValue = Self.pretty(spec)
    }

    @objc private func toggleRecord() {
        if recording { stopRecording(cancelled: true) } else { startRecording() }
    }

    private func startRecording() {
        recording = true
        recordButton.title = "Cancel"
        label.stringValue = "Press a key combo…"
        // Local monitor: captures events while our app is active. The recorder
        // window is key during recording, so this is sufficient.
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
            return nil  // swallow so the keystroke doesn't propagate
        }
    }

    private func stopRecording(cancelled: Bool) {
        recording = false
        recordButton.title = "Record"
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
    }

    private func handle(_ event: NSEvent) {
        // Only accept combos with at least one modifier, to avoid trapping bare keys.
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var parts: [String] = []
        if flags.contains(.control) { parts.append("ctrl") }
        if flags.contains(.option)  { parts.append("opt") }
        if flags.contains(.shift)   { parts.append("shift") }
        if flags.contains(.command) { parts.append("cmd") }

        guard !parts.isEmpty else {
            label.stringValue = "Need at least one modifier"
            return
        }
        guard let keyName = Self.keyName(for: UInt32(event.keyCode)) else {
            label.stringValue = "Unsupported key"
            return
        }
        parts.append(keyName)
        let spec = parts.joined(separator: "+")
        update(spec: spec)
        onChange?(spec)
        stopRecording(cancelled: false)
    }

    // MARK: - Formatting

    static func pretty(_ spec: String) -> String {
        let parts = spec.lowercased().split(separator: "+").map(String.init)
        var result = ""
        for p in parts {
            switch p {
            case "ctrl", "control": result += "⌃"
            case "opt", "option", "alt": result += "⌥"
            case "shift": result += "⇧"
            case "cmd", "command": result += "⌘"
            default: result += p.uppercased()
            }
        }
        return result.isEmpty ? "(none)" : result
    }

    // Reverse map: keyCode → name string we use in config.
    static func keyName(for keyCode: UInt32) -> String? {
        for (name, code) in nameToKey where code == keyCode {
            return name
        }
        return nil
    }

    private static let nameToKey: [(String, UInt32)] = [
        ("a", 0), ("s", 1), ("d", 2), ("f", 3), ("h", 4), ("g", 5), ("z", 6), ("x", 7),
        ("c", 8), ("v", 9), ("b", 11), ("q", 12), ("w", 13), ("e", 14), ("r", 15),
        ("y", 16), ("t", 17), ("o", 31), ("u", 32), ("i", 34), ("p", 35), ("l", 37),
        ("j", 38), ("k", 40), ("n", 45), ("m", 46),
        ("1", 18), ("2", 19), ("3", 20), ("4", 21), ("5", 23), ("6", 22),
        ("7", 26), ("8", 28), ("9", 25), ("0", 29),
        ("f1", 122), ("f2", 120), ("f3", 99), ("f4", 118), ("f5", 96), ("f6", 97),
        ("f7", 98), ("f8", 100), ("f9", 101), ("f10", 109), ("f11", 103), ("f12", 111),
        ("space", 49), ("return", 36), ("tab", 48), ("escape", 53)
    ]
}
