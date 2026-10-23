import AppKit
import Carbon
import SwiftUI

/// System-wide shortcuts via Carbon hot keys (no Accessibility permission needed).
enum HotKeys {
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var refs: [EventHotKeyRef?] = []

    static func install() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            DispatchQueue.main.async { HotKeys.handlers[id.id]?() }
            return noErr
        }, 1, &spec, nil, nil)
    }

    static func register(_ keyCode: Int, _ handler: @escaping () -> Void) {
        let id = UInt32(handlers.count + 1)
        var ref: EventHotKeyRef?
        RegisterEventHotKey(UInt32(keyCode), UInt32(controlKey | optionKey),
                            EventHotKeyID(signature: OSType(0x4855_5348), id: id), // 'HUSH'
                            GetApplicationEventTarget(), 0, &ref)
        refs.append(ref)
        handlers[id] = handler
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var prompter: PrompterController!
    private var editor: NSWindow!
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()
        prompter = PrompterController()

        editor = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 620),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        editor.title = "Hush"
        editor.isReleasedWhenClosed = false
        editor.contentView = NSHostingView(rootView: EditorView())
        editor.setFrameAutosaveName("HushEditor")
        if editor.frame.origin == .zero { editor.center() }
        showEditor()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "Hush")
        let menu = NSMenu()
        menu.addItem(item("Play / Pause", #selector(togglePlay)))
        menu.addItem(item("Show / Hide Prompter", #selector(toggleVisible)))
        menu.addItem(item("Switch Notch / Floating", #selector(toggleMode)))
        menu.addItem(.separator())
        menu.addItem(item("Open Editor", #selector(showEditor)))
        menu.addItem(NSMenuItem(title: "Quit Hush", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        HotKeys.install()
        let p = Playback.shared, s = Store.shared
        HotKeys.register(kVK_Space) { s.playing.toggle() }
        HotKeys.register(kVK_UpArrow) { s.speed = min(200, s.speed + 5) }
        HotKeys.register(kVK_DownArrow) { s.speed = max(5, s.speed - 5) }
        HotKeys.register(kVK_RightArrow) { p.nextCue() }
        HotKeys.register(kVK_LeftArrow) { p.previousCue() }
        HotKeys.register(kVK_ANSI_R) { p.restart() }
        HotKeys.register(kVK_ANSI_H) { s.prompterVisible.toggle() }

        if s.voiceActivated { Mic.shared.setEnabled(true) }

        // Dev aid: HUSH_SNAPSHOT=/dir renders both windows to PNG (screen capture can't see the prompter).
        if let dir = ProcessInfo.processInfo.environment["HUSH_SNAPSHOT"] {
            if ProcessInfo.processInfo.environment["HUSH_PLAY"] != nil { s.playing = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [self] in
                for (name, view) in [("prompter", prompter.panel.contentView), ("editor", editor.contentView)] {
                    guard let v = view, let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { continue }
                    v.cacheDisplay(in: v.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
                }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showEditor()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @objc func showEditor() {
        editor.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func togglePlay() { Store.shared.playing.toggle() }
    @objc func toggleVisible() { Store.shared.prompterVisible.toggle() }
    @objc func toggleMode() { Store.shared.mode = Store.shared.mode == .notch ? .floating : .notch }
    @objc func restart() { Playback.shared.restart() }
    @objc func nextCue() { Playback.shared.nextCue() }
    @objc func previousCue() { Playback.shared.previousCue() }

    private func item(_ title: String, _ action: Selector, _ key: String = "",
                      _ mods: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.keyEquivalentModifierMask = mods
        i.target = self
        return i
    }

    private func buildMainMenu() {
        let main = NSMenu()

        let app = NSMenu()
        app.addItem(withTitle: "About Hush", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Hide Hush", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: "Quit Hush", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let prompt = NSMenu(title: "Prompter")
        prompt.addItem(item("Play / Pause", #selector(togglePlay), "\r"))
        prompt.addItem(item("Back to Top", #selector(restart), "r", [.command, .shift]))
        prompt.addItem(item("Next Cue", #selector(nextCue), "]"))
        prompt.addItem(item("Previous Cue", #selector(previousCue), "["))
        prompt.addItem(.separator())
        prompt.addItem(item("Show / Hide Prompter", #selector(toggleVisible), "p", [.command, .shift]))
        prompt.addItem(item("Switch Notch / Floating", #selector(toggleMode), "f", [.command, .shift]))

        let window = NSMenu(title: "Window")
        window.addItem(item("Editor", #selector(showEditor), "1"))
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        for (title, menu) in [("Hush", app), ("Edit", edit), ("Prompter", prompt), ("Window", window)] {
            let top = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            top.submenu = menu
            main.addItem(top)
        }
        NSApp.mainMenu = main
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
