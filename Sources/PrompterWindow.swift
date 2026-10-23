import AppKit
import Combine
import SwiftUI

final class PrompterPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // Let the notch panel sit over the menu bar instead of being pushed below it.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

final class PrompterHostingView: NSHostingView<PrompterView> {
    private var tracking: NSTrackingArea?
    private var link: CADisplayLink?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        link?.invalidate()
        guard window != nil else { return }
        let l = displayLink(target: self, selector: #selector(step(_:)))
        l.add(to: .main, forMode: .common)
        link = l
    }

    @objc private func step(_ l: CADisplayLink) { Playback.shared.tick(l.timestamp) }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = tracking { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                               owner: self, userInfo: nil)
        addTrackingArea(t)
        tracking = t
    }

    override func mouseEntered(with event: NSEvent) { Playback.shared.hovering = true }
    override func mouseExited(with event: NSEvent) { Playback.shared.hovering = false }

    override func scrollWheel(with event: NSEvent) {
        let scale: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 10
        Playback.shared.scrollBy(-event.scrollingDeltaY * scale)
    }

    override func mouseDown(with event: NSEvent) {
        // Floating: drag to move. A click without movement toggles play/pause in either mode.
        if !Playback.shared.isNotch, let w = window {
            let origin = w.frame.origin
            w.performDrag(with: event)
            if w.frame.origin != origin { return }
        }
        Store.shared.playing.toggle()
    }
}

final class PrompterController: NSObject, NSWindowDelegate {
    let panel: PrompterPanel
    private var bag = Set<AnyCancellable>()

    override init() {
        panel = PrompterPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 150),
                              styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.acceptsMouseMovedEvents = true
        panel.minSize = NSSize(width: 260, height: 110)
        panel.delegate = self
        panel.contentView = PrompterHostingView(rootView: PrompterView())

        Store.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.layout() }
            .store(in: &bag)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.layout() }
            .store(in: &bag)
        layout()
    }

    private var notchScreen: NSScreen {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    func layout() {
        let s = Store.shared, p = Playback.shared
        guard s.prompterVisible else { panel.orderOut(nil); return }
        // .none keeps the window out of screen sharing, recordings and screenshots.
        panel.sharingType = s.hideFromCapture ? .none : .readOnly

        let screen = notchScreen
        let f = screen.frame
        var frame: NSRect
        if s.mode == .notch {
            let hasNotch = screen.safeAreaInsets.top > 0
            let inset = hasNotch ? screen.safeAreaInsets.top : f.maxY - screen.visibleFrame.maxY
            var notch: CGFloat = 0
            if hasNotch, let l = screen.auxiliaryTopLeftArea, let r = screen.auxiliaryTopRightArea {
                notch = r.minX - l.maxX
            }
            let w = max(CGFloat(s.notchW), notch + 140)
            let h = max(CGFloat(s.notchH), inset + 70)
            if p.topInset != inset { p.topInset = inset }
            if p.notchWidth != notch { p.notchWidth = notch }
            if !p.isNotch { p.isNotch = true }
            panel.styleMask.remove(.resizable)
            frame = NSRect(x: f.midX - w / 2, y: f.maxY - h, width: w, height: h)
        } else {
            if p.topInset != 24 { p.topInset = 24 }
            if p.notchWidth != 0 { p.notchWidth = 0 }
            if p.isNotch { p.isNotch = false }
            panel.styleMask.insert(.resizable)
            let w = CGFloat(s.floatW), h = CGFloat(s.floatH)
            let vis = screen.visibleFrame
            let origin = s.floatOrigin ?? NSPoint(x: vis.midX - w / 2, y: vis.maxY - h - 60)
            frame = NSRect(origin: origin, size: NSSize(width: w, height: h))
        }
        if panel.frame != frame { panel.setFrame(frame, display: true) }
        panel.orderFrontRegardless()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard Store.shared.mode == .floating else { return }
        Store.shared.floatOrigin = panel.frame.origin
        Store.shared.floatW = Double(panel.frame.width)
        Store.shared.floatH = Double(panel.frame.height)
    }

    func windowDidMove(_ notification: Notification) {
        guard Store.shared.mode == .floating, !panel.inLiveResize else { return }
        Store.shared.floatOrigin = panel.frame.origin
    }
}
