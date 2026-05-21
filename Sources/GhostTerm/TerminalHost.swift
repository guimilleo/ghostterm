import AppKit
import SwiftTerm

final class TerminalHost: NSObject, LocalProcessTerminalViewDelegate {
    let view: LocalProcessTerminalView

    override init() {
        let frame = NSRect(x: 0, y: 0, width: 900, height: 560)
        view = LocalProcessTerminalView(frame: frame)
        super.init()
        view.processDelegate = self
        applyTheme(from: Prefs.loadConfig())
        startShell()
    }

    func applyTheme(from cfg: AppConfig) {
        let bg = ColorParse.nsColor(cfg.background) ?? .black
        let fg = ColorParse.nsColor(cfg.foreground) ?? .white
        view.nativeBackgroundColor = bg
        view.nativeForegroundColor = fg
        // Force-update the layer (SwiftTerm only sets this in setupOptions) so
        // the gap between cells / margins repaints.
        view.layer?.backgroundColor = bg.cgColor
        // Force every cell to repaint with the new palette.
        let rows = view.terminal.rows
        if rows > 0 {
            view.terminal.refresh(startRow: 0, endRow: rows - 1)
        }
        view.setNeedsDisplay(view.bounds)
        NSLog("GhostTerm: applied theme bg=\(bg) fg=\(fg)")
    }

    private func startShell() {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        // Login shell so the user's normal env/profile is sourced.
        let execName = "-" + (shell as NSString).lastPathComponent
        var env = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        env.append("LANG=en_US.UTF-8")
        view.startProcess(executable: shell, args: [], environment: env, execName: execName)
    }

    // MARK: - LocalProcessTerminalViewDelegate

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        source.window?.title = title.isEmpty ? "GhostTerm" : title
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        NSApp.terminate(nil)
    }
}
