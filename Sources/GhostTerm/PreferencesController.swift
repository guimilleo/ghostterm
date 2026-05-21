import AppKit

final class PreferencesController: NSWindowController {
    private var cfg: AppConfig
    private let onApply: (AppConfig) -> Void

    init(initial: AppConfig, onApply: @escaping (AppConfig) -> Void) {
        self.cfg = initial
        self.onApply = onApply

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 280),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "GhostTerm Preferences"
        win.isReleasedWhenClosed = false
        // Pop above the main GhostTerm panel (which is at .statusBar).
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        win.center()
        super.init(window: win)
        win.contentView = buildContent()
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - UI

    private func buildContent() -> NSView {
        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false

        let hotkeyItem = NSTabViewItem(identifier: "hotkey")
        hotkeyItem.label = "Hotkey"
        hotkeyItem.view = buildHotkeyTab()
        tabView.addTabViewItem(hotkeyItem)

        let themeItem = NSTabViewItem(identifier: "theme")
        themeItem.label = "Theme"
        themeItem.view = buildThemeTab()
        tabView.addTabViewItem(themeItem)

        let container = NSView()
        container.addSubview(tabView)
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            tabView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            tabView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            tabView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
        ])
        return container
    }

    private func buildHotkeyTab() -> NSView {
        let v = NSView()

        let title = NSTextField(labelWithString: "Screenshot Hotkey")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(title)

        let hint = NSTextField(labelWithString: "Capture the screen and paste the path at the cursor. Press multiple times to chain.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.lineBreakMode = .byWordWrapping
        hint.maximumNumberOfLines = 0
        hint.preferredMaxLayoutWidth = 400
        hint.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(hint)

        let recorder = HotkeyRecorder(currentSpec: cfg.screenshotHotkey)
        recorder.translatesAutoresizingMaskIntoConstraints = false
        recorder.onChange = { [weak self] spec in
            guard let self else { return }
            self.cfg.screenshotHotkey = spec
            Prefs.save(self.cfg)
            self.onApply(self.cfg)
        }
        v.addSubview(recorder)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: v.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),

            hint.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            hint.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),
            hint.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -16),

            recorder.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 12),
            recorder.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),
            recorder.trailingAnchor.constraint(lessThanOrEqualTo: v.trailingAnchor, constant: -16),
        ])
        return v
    }

    private func buildThemeTab() -> NSView {
        let v = NSView()

        let bgLabel = NSTextField(labelWithString: "Background")
        bgLabel.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(bgLabel)

        let bgWell = NSColorWell()
        bgWell.color = ColorParse.nsColor(cfg.background) ?? .black
        bgWell.translatesAutoresizingMaskIntoConstraints = false
        bgWell.target = self
        bgWell.action = #selector(bgChanged(_:))
        v.addSubview(bgWell)

        let fgLabel = NSTextField(labelWithString: "Foreground")
        fgLabel.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(fgLabel)

        let fgWell = NSColorWell()
        fgWell.color = ColorParse.nsColor(cfg.foreground) ?? .white
        fgWell.translatesAutoresizingMaskIntoConstraints = false
        fgWell.target = self
        fgWell.action = #selector(fgChanged(_:))
        v.addSubview(fgWell)

        // Presets row
        let presetsLabel = NSTextField(labelWithString: "Presets:")
        presetsLabel.translatesAutoresizingMaskIntoConstraints = false
        presetsLabel.textColor = .secondaryLabelColor
        v.addSubview(presetsLabel)

        let darkButton = makePresetButton("Dark", bg: "#000000", fg: "#FFFFFF", wells: (bgWell, fgWell))
        let lightButton = makePresetButton("Light", bg: "#FFFFFF", fg: "#000000", wells: (bgWell, fgWell))
        let solarButton = makePresetButton("Solarized", bg: "#FDF6E3", fg: "#586E75", wells: (bgWell, fgWell))
        let presetsStack = NSStackView(views: [darkButton, lightButton, solarButton])
        presetsStack.orientation = .horizontal
        presetsStack.spacing = 6
        presetsStack.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(presetsStack)

        NSLayoutConstraint.activate([
            bgLabel.topAnchor.constraint(equalTo: v.topAnchor, constant: 24),
            bgLabel.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),
            bgLabel.widthAnchor.constraint(equalToConstant: 100),
            bgWell.centerYAnchor.constraint(equalTo: bgLabel.centerYAnchor),
            bgWell.leadingAnchor.constraint(equalTo: bgLabel.trailingAnchor, constant: 8),
            bgWell.widthAnchor.constraint(equalToConstant: 48),
            bgWell.heightAnchor.constraint(equalToConstant: 24),

            fgLabel.topAnchor.constraint(equalTo: bgLabel.bottomAnchor, constant: 16),
            fgLabel.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),
            fgLabel.widthAnchor.constraint(equalToConstant: 100),
            fgWell.centerYAnchor.constraint(equalTo: fgLabel.centerYAnchor),
            fgWell.leadingAnchor.constraint(equalTo: fgLabel.trailingAnchor, constant: 8),
            fgWell.widthAnchor.constraint(equalToConstant: 48),
            fgWell.heightAnchor.constraint(equalToConstant: 24),

            presetsLabel.topAnchor.constraint(equalTo: fgLabel.bottomAnchor, constant: 24),
            presetsLabel.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),
            presetsStack.centerYAnchor.constraint(equalTo: presetsLabel.centerYAnchor),
            presetsStack.leadingAnchor.constraint(equalTo: presetsLabel.trailingAnchor, constant: 8),
        ])
        return v
    }

    private func makePresetButton(_ title: String, bg: String, fg: String, wells: (NSColorWell, NSColorWell)) -> NSButton {
        let b = NSButton(title: title, target: nil, action: nil)
        b.bezelStyle = .rounded
        b.controlSize = .small
        b.target = self
        b.action = #selector(applyPreset(_:))
        b.identifier = NSUserInterfaceItemIdentifier("\(bg)|\(fg)")
        objc_setAssociatedObject(b, &wellsKey, wells, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return b
    }

    @objc private func applyPreset(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        let parts = id.split(separator: "|").map(String.init)
        guard parts.count == 2 else { return }
        cfg.background = parts[0]
        cfg.foreground = parts[1]
        Prefs.save(cfg)
        if let wells = objc_getAssociatedObject(sender, &wellsKey) as? (NSColorWell, NSColorWell) {
            wells.0.color = ColorParse.nsColor(cfg.background) ?? .black
            wells.1.color = ColorParse.nsColor(cfg.foreground) ?? .white
        }
        onApply(cfg)
    }

    @objc private func bgChanged(_ sender: NSColorWell) {
        cfg.background = sender.color.hexString
        Prefs.save(cfg)
        onApply(cfg)
    }

    @objc private func fgChanged(_ sender: NSColorWell) {
        cfg.foreground = sender.color.hexString
        Prefs.save(cfg)
        onApply(cfg)
    }
}

private var wellsKey: UInt8 = 0

extension NSColor {
    var hexString: String {
        let c = usingColorSpace(.sRGB) ?? self
        let r = Int((c.redComponent * 255).rounded())
        let g = Int((c.greenComponent * 255).rounded())
        let b = Int((c.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
