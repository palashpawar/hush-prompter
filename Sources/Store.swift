import SwiftUI

enum PrompterMode: String, CaseIterable, Identifiable {
    case notch, floating
    var id: String { rawValue }
    var label: String { self == .notch ? "Notch" : "Floating" }
}

struct Cue: Identifiable, Equatable {
    let id: Int
    let title: String?
    let body: String
}

/// Persistent settings + the script. Changes rarely, so the editor can observe it freely.
final class Store: ObservableObject {
    static let shared = Store()
    private let defaults = UserDefaults.standard

    @Published var script: String { didSet { save(script, "script"); cues = Store.parse(script) } }
    @Published private(set) var cues: [Cue] = []

    @Published var speed: Double { didSet { save(speed, "speed") } }            // points per second
    @Published var fontSize: Double { didSet { save(fontSize, "fontSize") } }
    @Published var colorHex: String { didSet { save(colorHex, "colorHex") } }
    @Published var mode: PrompterMode { didSet { save(mode.rawValue, "mode") } }
    @Published var notchW: Double { didSet { save(notchW, "notchW") } }
    @Published var notchH: Double { didSet { save(notchH, "notchH") } }
    @Published var floatW: Double { didSet { save(floatW, "floatW") } }
    @Published var floatH: Double { didSet { save(floatH, "floatH") } }
    @Published var voiceActivated: Bool { didSet { save(voiceActivated, "voiceActivated") } }
    @Published var micThreshold: Double { didSet { save(micThreshold, "micThreshold") } } // dBFS
    @Published var hideFromCapture: Bool { didSet { save(hideFromCapture, "hideFromCapture") } }
    @Published var hoverPauses: Bool { didSet { save(hoverPauses, "hoverPauses") } }
    @Published var mirror: Bool { didSet { save(mirror, "mirror") } }
    @Published var prompterVisible: Bool { didSet { save(prompterVisible, "prompterVisible") } }

    @Published var playing = false

    var floatOrigin: NSPoint? {
        get {
            guard let x = defaults.object(forKey: "floatX") as? Double,
                  let y = defaults.object(forKey: "floatY") as? Double else { return nil }
            return NSPoint(x: x, y: y)
        }
        set {
            defaults.set(newValue.map { Double($0.x) }, forKey: "floatX")
            defaults.set(newValue.map { Double($0.y) }, forKey: "floatY")
        }
    }

    private init() {
        let d = UserDefaults.standard
        d.register(defaults: [
            "script": Store.sample, "speed": 40.0, "fontSize": 24.0, "colorHex": "FFFFFF",
            "mode": PrompterMode.notch.rawValue, "notchW": 460.0, "notchH": 170.0,
            "floatW": 560.0, "floatH": 260.0, "voiceActivated": false, "micThreshold": -42.0,
            "hideFromCapture": true, "hoverPauses": true, "mirror": false, "prompterVisible": true,
        ])
        script = d.string(forKey: "script") ?? Store.sample
        speed = d.double(forKey: "speed")
        fontSize = d.double(forKey: "fontSize")
        colorHex = d.string(forKey: "colorHex") ?? "FFFFFF"
        mode = PrompterMode(rawValue: d.string(forKey: "mode") ?? "") ?? .notch
        notchW = d.double(forKey: "notchW")
        notchH = d.double(forKey: "notchH")
        floatW = d.double(forKey: "floatW")
        floatH = d.double(forKey: "floatH")
        voiceActivated = d.bool(forKey: "voiceActivated")
        micThreshold = d.double(forKey: "micThreshold")
        hideFromCapture = d.bool(forKey: "hideFromCapture")
        hoverPauses = d.bool(forKey: "hoverPauses")
        mirror = d.bool(forKey: "mirror")
        prompterVisible = d.bool(forKey: "prompterVisible")
        cues = Store.parse(script)
    }

    private func save(_ value: Any, _ key: String) { defaults.set(value, forKey: key) }

    /// Lines starting with `#` open a new cue; everything until the next one is its body.
    static func parse(_ text: String) -> [Cue] {
        var cues: [Cue] = []
        var title: String?
        var body: [String] = []
        func flush() {
            let b = body.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if title != nil || !b.isEmpty { cues.append(Cue(id: cues.count, title: title, body: b)) }
        }
        for line in text.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("#") {
                flush()
                title = String(t.drop(while: { $0 == "#" })).trimmingCharacters(in: .whitespaces)
                body = []
            } else {
                body.append(line)
            }
        }
        flush()
        return cues
    }

    static let sample = """
    # Welcome
    Hi there. This is Hush, a teleprompter that lives in your MacBook's notch, right under the camera, so you can read your script and keep eye contact at the same time.

    # How it works
    Paste your script into the editor. Start any line with a pound sign to make a cue, then jump between cues with Control Option and the left or right arrow.

    # Controls
    Press Control Option Space to play or pause. Hover over the prompter to pause instantly, and scroll with your trackpad to move around.

    # Wrap up
    Turn on voice mode and the text only moves while you're talking. When you share your screen, nobody else can see this. Thanks for watching!
    """
}

extension Color {
    init(hex: String) {
        let v = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0xFFFFFF
        self.init(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }

    var hex: String {
        let c = NSColor(self).usingColorSpace(.sRGB) ?? .white
        return String(format: "%02X%02X%02X", Int(round(c.redComponent * 255)),
                      Int(round(c.greenComponent * 255)), Int(round(c.blueComponent * 255)))
    }
}
