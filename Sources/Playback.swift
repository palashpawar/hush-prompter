import AVFoundation
import QuartzCore
import SwiftUI

/// Fast-changing scroll state. Only the prompter (and the mic meter) observe this.
final class Playback: ObservableObject {
    static let shared = Playback()

    @Published var offset: CGFloat = 0
    @Published var hovering = false
    @Published var micDB: Double = -160
    @Published var topInset: CGFloat = 0
    @Published var notchWidth: CGFloat = 0
    @Published var isNotch = true

    var contentHeight: CGFloat = 0   // includes one viewport of trailing space
    var viewportHeight: CGFloat = 0
    var cueOffsets: [Int: CGFloat] = [:]
    var lastVoice: CFTimeInterval = 0

    private var target: CGFloat?
    private var velocity: CGFloat = 0
    private var lastTick: CFTimeInterval = 0

    var maxOffset: CGFloat { max(0, contentHeight - viewportHeight) }
    var progress: CGFloat { maxOffset > 0 ? min(1, offset / maxOffset) : 0 }
    var speaking: Bool { CACurrentMediaTime() - lastVoice < 0.7 }

    var currentCue: Int {
        let sorted = cueOffsets.sorted { $0.value < $1.value }
        return sorted.last(where: { $0.value <= offset + 2 })?.key ?? 0
    }

    var isAdvancing: Bool {
        let s = Store.shared
        return s.playing && !(s.hoverPauses && hovering) && (!s.voiceActivated || speaking)
    }

    func tick(_ now: CFTimeInterval) {
        let dt = CGFloat(lastTick == 0 ? 0 : min(now - lastTick, 0.05))
        lastTick = now

        if let t = target {
            let diff = t - offset
            if abs(diff) < 0.5 { set(t); target = nil } else { set(offset + diff * min(1, dt * 10)) }
            return
        }

        // Ease velocity toward the target speed so voice/hover pauses don't jerk.
        let goal = isAdvancing ? CGFloat(Store.shared.speed) : 0
        velocity += (goal - velocity) * min(1, dt * 8)
        if velocity < 0.5 && goal == 0 { velocity = 0; return }
        set(offset + velocity * dt)
        if offset >= maxOffset && Store.shared.playing { Store.shared.playing = false }
    }

    private func set(_ value: CGFloat) {
        let v = min(max(0, value), maxOffset)
        if v != offset { offset = v }
    }

    func scrollBy(_ delta: CGFloat) {
        target = nil
        set(offset + delta)
    }

    func jump(to cue: Int) {
        guard let y = cueOffsets[cue] else { return }
        target = min(y, maxOffset)
    }

    func nextCue() {
        let n = Store.shared.cues.count
        jump(to: min(currentCue + 1, max(0, n - 1)))
    }

    func previousCue() {
        let i = currentCue
        let start = cueOffsets[i] ?? 0
        jump(to: offset - start > 20 ? i : max(0, i - 1))
    }

    func restart() {
        Store.shared.playing = false
        target = 0
    }
}

/// Mic level gate for voice mode: text advances only while input is above the threshold.
final class Mic {
    static let shared = Mic()
    private let engine = AVAudioEngine()
    private(set) var running = false

    func setEnabled(_ on: Bool) { on ? start() : stop() }

    private func start() {
        guard !running else { return }
        AVCaptureDevice.requestAccess(for: .audio) { ok in
            DispatchQueue.main.async {
                if ok { self.begin() } else { Store.shared.voiceActivated = false }
            }
        }
    }

    private func begin() {
        guard !running else { return }
        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buf, _ in
            guard let ch = buf.floatChannelData?[0], buf.frameLength > 0 else { return }
            var sum: Float = 0
            for i in 0..<Int(buf.frameLength) { sum += ch[i] * ch[i] }
            let db = Double(20 * log10(max(sqrt(sum / Float(buf.frameLength)), 1e-7)))
            DispatchQueue.main.async {
                let p = Playback.shared
                p.micDB = db
                if db > Store.shared.micThreshold { p.lastVoice = CACurrentMediaTime() }
            }
        }
        do {
            try engine.start()
            running = true
        } catch {
            input.removeTap(onBus: 0)
            Store.shared.voiceActivated = false
        }
    }

    private func stop() {
        guard running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        running = false
        Playback.shared.micDB = -160
    }
}
