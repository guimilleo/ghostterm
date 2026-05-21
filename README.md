# GhostTerm

A macOS terminal that is **invisible to screen captures**, **always on top** of every app (including those in macOS fullscreen mode), and lets you **paste screenshot paths into the prompt with a hotkey**.

Built natively in Swift + AppKit on top of [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm). ~40 KB of glue code; no Electron, no Xcode required to build.

## Features

- **Invisible to screen sharing** — `NSWindow.sharingType = .none` excludes the window from `CGWindowList`-based capture. QuickTime screen recording, Zoom / Google Meet / Slack screenshare, and the `screencapture` CLI all see right through it. The window is still fully visible to you.
- **Always on top** — `NSPanel` with `isFloatingPanel = true` at `.statusBar` level. Stays above normal app windows, follows you across Spaces, and remains visible over apps in macOS fullscreen mode.
- **Configurable transparency** — slider at the bottom of the window, range 25%–95% (never fully opaque by design). Setting persists across launches.
- **Screenshot hotkey** — default `Cmd+Shift+P`. Captures the full screen via `/usr/sbin/screencapture` and pastes the saved file path at the terminal cursor with a trailing space. Multiple presses chain as space-separated paths so you can do `claude analyze shot1.png shot2.png shot3.png` style commands.
- **Themeable** — background and foreground colors are configurable via a Preferences window with native color pickers (Dark / Light / Solarized presets included) or directly in the JSON config file.
- **Configurable hotkey** — record any modifier+key combo in Preferences, or edit `screenshotHotkey` in the config file.
- **No network. No telemetry. No keylogging.** See [Security & privacy](#security--privacy).

## Build

Requires macOS 13+, Swift 5.9+ (Command Line Tools is sufficient; full Xcode not required).

```bash
git clone git@github.com:guimilleo/ghostterm.git
cd ghostterm
./scripts/bundle.sh debug      # or `release`
open .build/arm64-apple-macosx/debug/GhostTerm.app
```

The build script compiles via SPM, then wraps the binary into a proper `.app` bundle and ad-hoc-signs it so macOS TCC permissions (Screen Recording) can be granted to a stable identity.

## First run

On first capture you will be prompted for **Screen Recording** permission. Grant it in *System Settings → Privacy & Security → Screen Recording* and relaunch. This is required because the screenshot hotkey shells out to `/usr/sbin/screencapture`.

You may also see a one-time prompt to access your **Documents folder** the first time a screenshot is saved — that's where `~/Documents/GhostTermShots/` lives.

## Configuration

Edit `~/.config/ghostterm/config.json`:

```json
{
  "screenshotHotkey": "cmd+shift+p",
  "background": "#000000",
  "foreground": "#FFFFFF"
}
```

- **Hotkey format:** `cmd | ctrl | opt | shift | alt | command | option | control` joined by `+`, followed by a key: any letter `a`–`z`, digit `0`–`9`, function key `f1`–`f12`, or `space | return | tab | escape`.
- **Colors:** `#RGB`, `#RRGGBB`, `#RRGGBBAA`, or named (`white`, `black`, `red`, `green`, `blue`, `yellow`, `cyan`, `magenta`, `gray`).

The file self-heals: any missing keys are backfilled with defaults on next launch.

In-app:
- `Cmd+,` opens **Preferences** (Hotkey + Theme tabs).
- `Cmd+Shift+R` reloads the config without restart.
- `Cmd+Shift+=` / `Cmd+Shift+-` step opacity up/down by 5%.

## How invisibility works

The single line that does it:

```swift
window.sharingType = .none   // GhostWindow.swift
```

`NSWindowSharingType.none` excludes the window from every macOS readback API: `CGWindowListCreateImage`, `ScreenCaptureKit`, the `screencapture` CLI, and the surfaces that Zoom / Meet / Slack use to enumerate windows for screen sharing. The window keeps drawing normally to your physical display — only software that reads pixels back from the compositor sees it as absent.

**Caveats:** a hardware capture card or a phone camera pointed at your screen still sees it. macOS Screen Recording will also show a brief indicator dot whenever screencapture runs, because we shell out to it for the screenshot hotkey.

## Security & privacy

GhostTerm makes **zero network calls.** Verifiable three ways:

1. Source grep:
   ```bash
   grep -rn -E "URLSession|Network\.|CFNetwork|libcurl|http" Sources/
   ```
   Returns nothing.
2. Linker output:
   ```bash
   otool -L .build/arm64-apple-macosx/debug/ghostterm | grep -i 'network\|curl\|cfnetwork'
   ```
   Returns nothing — the binary doesn't even *link* networking frameworks.
3. Live verification:
   ```bash
   sudo nettop -nP -p $(pgrep -x ghostterm)
   ```
   Stays empty while you use the app.

**No keyboard monitoring.** The screenshot hotkey uses Carbon `RegisterEventHotKey`, which registers a specific target combo with the OS — it does not observe other key presses and does not require Accessibility or Input Monitoring permission. No `CGEventTap`, no `NSEvent` global monitor.

**No mouse monitoring, no clipboard polling, no automation of other apps.**

The only permissions GhostTerm ever requests are:
- **Screen Recording** — required for the `screencapture` shell-out behind the hotkey.
- (macOS 14+) **Documents folder access** — first time a screenshot is saved to `~/Documents/GhostTermShots/`.

## Pending / known limitations

- [ ] **Brief flicker during fullscreen transitions.** When another app enters macOS fullscreen mode, GhostTerm disappears for ~0.5s during the Space-switch animation, then reappears on top. This is the OS's transition animation, not our window losing its level. Workaround: System Settings → Accessibility → Display → *Reduce motion*. Tunable improvement: set `animationBehavior = .none` (not yet applied — easy todo).
- [ ] **Opacity bar fades with the window.** Because `window.alphaValue` composites the whole window uniformly, the slider control also dims at low opacity. Possible improvement: move the slider into a separate floating panel so it stays at 100%.
- [ ] **Ad-hoc code signing re-triggers Screen Recording permission on each rebuild.** Every `swift build` produces a fresh signature, and macOS TCC binds permissions to the signature. Fix: sign with a stable Developer ID. Workaround: stop rebuilding once you have a working binary you like.
- [ ] **No tests.** Hand-tested only.
- [ ] **No LICENSE file yet.** Source is currently "all rights reserved" by default until a license is added (recommend MIT for compatibility with SwiftTerm).
- [ ] **Theme reload may leave a glyph cache stale until you type or resize.** SwiftTerm caches glyph rasterizations; the `terminal.refresh` call invalidates row state but not the glyph cache. Typing or dragging a resize edge forces a full repaint.
- [ ] **Single-window only.** No tabs, no split panes.
- [ ] **macOS-only.** `sharingType = .none` has no equivalent on X11/Wayland; on Windows the analogous call is `SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE)` but porting would mean changing the AppKit foundation.

## Built with

- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) by Miguel de Icaza — the terminal emulator and PTY driver. MIT licensed.

## License

Not yet declared. See pending items above.
