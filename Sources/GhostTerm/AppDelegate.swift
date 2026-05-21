import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: GhostWindow!
    private var host: TerminalHost!
    private var hotkeys: HotkeyManager!
    private var opacityBar: OpacityBar!
    private var currentHotkey: String = AppConfig.default.screenshotHotkey
    private var prefsController: PreferencesController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        host = TerminalHost()

        // Container: terminal on top, opacity bar pinned to the bottom.
        let termFrame = host.view.frame
        let containerHeight = termFrame.height + OpacityBar.height
        let container = NSView(frame: NSRect(x: 0, y: 0, width: termFrame.width, height: containerHeight))
        container.autoresizingMask = [.width, .height]

        opacityBar = OpacityBar(initialOpacity: Prefs.opacity)
        opacityBar.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(opacityBar)

        host.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(host.view)

        NSLayoutConstraint.activate([
            opacityBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            opacityBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            opacityBar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            opacityBar.heightAnchor.constraint(equalToConstant: OpacityBar.height),

            host.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: container.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: opacityBar.topAnchor),
        ])

        opacityBar.onChange = { [weak self] v in
            Prefs.opacity = v
            self?.window.alphaValue = v
        }

        window = GhostWindow(contentRect: container.bounds)
        window.contentView = container
        window.alphaValue = Prefs.opacity
        window.makeFirstResponder(host.view)
        window.makeKeyAndOrderFront(nil)

        installMenu()
        installHotkeys()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // MARK: - Hotkeys

    private func installHotkeys() {
        let cfg = Prefs.loadConfig()
        currentHotkey = cfg.screenshotHotkey
        registerScreenshotHotkey(currentHotkey)
    }

    private func registerScreenshotHotkey(_ spec: String) {
        hotkeys = HotkeyManager() // drop old registrations
        guard let parsed = HotkeySpec.parse(spec) else {
            NSLog("GhostTerm: invalid hotkey '\(spec)', falling back to cmd+shift+p")
            if let fallback = HotkeySpec.parse(AppConfig.default.screenshotHotkey) {
                hotkeys.register(keyCode: fallback.keyCode, modifiers: fallback.modifiers) { [weak self] in
                    self?.captureAndPaste()
                }
            }
            return
        }
        hotkeys.register(keyCode: parsed.keyCode, modifiers: parsed.modifiers) { [weak self] in
            self?.captureAndPaste()
        }
    }

    @objc private func captureAndPaste() {
        guard let url = ScreenshotService.captureFullScreen() else {
            NSSound.beep()
            return
        }
        // Trailing space so repeated presses chain naturally: each new path gets
        // injected after the previous one.
        host.view.send(txt: url.path + " ")
    }

    // MARK: - Menu

    private func installMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "GhostTerm")
        appMenu.addItem(withTitle: "About GhostTerm",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        let prefs = NSMenuItem(title: "Preferences…",
                               action: #selector(openPreferences),
                               keyEquivalent: ",")
        prefs.target = self
        appMenu.addItem(prefs)
        let editCfg = NSMenuItem(title: "Edit Config File…",
                                 action: #selector(editConfig),
                                 keyEquivalent: "")
        editCfg.target = self
        appMenu.addItem(editCfg)
        let reload = NSMenuItem(title: "Reload Config",
                                action: #selector(reloadConfig),
                                keyEquivalent: "r")
        reload.keyEquivalentModifierMask = [.command, .shift]
        reload.target = self
        appMenu.addItem(reload)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit GhostTerm",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        let inc = NSMenuItem(title: "Increase Opacity",
                             action: #selector(increaseOpacity),
                             keyEquivalent: "=")
        inc.keyEquivalentModifierMask = [.command, .shift]
        inc.target = self
        let dec = NSMenuItem(title: "Decrease Opacity",
                             action: #selector(decreaseOpacity),
                             keyEquivalent: "-")
        dec.keyEquivalentModifierMask = [.command, .shift]
        dec.target = self
        viewMenu.addItem(inc)
        viewMenu.addItem(dec)
        viewItem.submenu = viewMenu
        main.addItem(viewItem)

        let captureItem = NSMenuItem()
        let captureMenu = NSMenu(title: "Capture")
        let snap = NSMenuItem(title: "Screenshot → Paste Path",
                              action: #selector(captureAndPaste),
                              keyEquivalent: "")
        snap.target = self
        captureMenu.addItem(snap)
        captureItem.submenu = captureMenu
        main.addItem(captureItem)

        NSApp.mainMenu = main
    }

    @objc private func increaseOpacity() {
        let next = Prefs.clamp(Prefs.opacity + 0.05)
        Prefs.opacity = next
        window.alphaValue = next
        opacityBar.setOpacity(next)
    }

    @objc private func decreaseOpacity() {
        let next = Prefs.clamp(Prefs.opacity - 0.05)
        Prefs.opacity = next
        window.alphaValue = next
        opacityBar.setOpacity(next)
    }

    @objc private func editConfig() {
        let url = Prefs.configFileURL
        _ = Prefs.loadConfig()  // ensures the file exists
        NSWorkspace.shared.open(url)
    }

    @objc private func openPreferences() {
        if prefsController == nil {
            prefsController = PreferencesController(initial: Prefs.loadConfig()) { [weak self] newCfg in
                // Live-apply both hotkey and theme as the user changes them.
                guard let self else { return }
                self.currentHotkey = newCfg.screenshotHotkey
                self.registerScreenshotHotkey(newCfg.screenshotHotkey)
                self.host.applyTheme(from: newCfg)
            }
        }
        prefsController?.show()
    }

    @objc private func reloadConfig() {
        let cfg = Prefs.loadConfig()
        currentHotkey = cfg.screenshotHotkey
        registerScreenshotHotkey(currentHotkey)
        host.applyTheme(from: cfg)
        NSLog("GhostTerm: reloaded config, hotkey=\(currentHotkey)")
    }
}
