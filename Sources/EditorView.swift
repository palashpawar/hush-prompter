import SwiftUI

struct EditorView: View {
    @ObservedObject var s = Store.shared

    private let swatches = ["FFFFFF", "FFE7A3", "7CFFB2", "7FD8FF", "FF9EDB"]

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Script").font(.headline)
                TextEditor(text: $s.script)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                Text("Start a line with # to make a cue. \(s.script.split { $0.isWhitespace }.count) words · \(s.cues.count) cues")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(minWidth: 380)

            Divider()

            ScrollView { sidebar.padding(16) }
                .frame(width: 300)
        }
        .frame(minWidth: 720, minHeight: 520)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            section("Playback") {
                HStack {
                    Button(action: { s.playing.toggle() }) {
                        Label(s.playing ? "Pause" : "Play", systemImage: s.playing ? "pause.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: .command)
                    Button(action: { Playback.shared.restart() }) {
                        Image(systemName: "backward.end.fill")
                    }
                    .controlSize(.large)
                    .help("Back to top")
                }
                slider("Speed", value: $s.speed, range: 5...200, format: "%.0f")
            }

            if !s.cues.isEmpty {
                section("Cues") {
                    ForEach(s.cues) { cue in
                        Button(action: { Playback.shared.jump(to: cue.id) }) {
                            HStack {
                                Text("\(cue.id + 1)").monospacedDigit().foregroundStyle(.secondary)
                                Text(cue.title?.isEmpty == false ? cue.title! : String(cue.body.prefix(30)))
                                    .lineLimit(1)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            section("Appearance") {
                slider("Text size", value: $s.fontSize, range: 12...56, format: "%.0f pt")
                if s.mode == .notch {
                    slider("Width", value: $s.notchW, range: 300...1000, format: "%.0f")
                    slider("Height", value: $s.notchH, range: 110...500, format: "%.0f")
                } else {
                    slider("Width", value: $s.floatW, range: 260...1400, format: "%.0f")
                    slider("Height", value: $s.floatH, range: 110...900, format: "%.0f")
                }
                HStack(spacing: 8) {
                    ForEach(swatches, id: \.self) { hex in
                        Circle().fill(Color(hex: hex))
                            .frame(width: 20, height: 20)
                            .overlay(Circle().stroke(Color.accentColor, lineWidth: s.colorHex == hex ? 2 : 0).padding(-3))
                            .overlay(Circle().stroke(Color.black.opacity(0.15)))
                            .onTapGesture { s.colorHex = hex }
                    }
                    ColorPicker("", selection: Binding(get: { Color(hex: s.colorHex) },
                                                       set: { s.colorHex = $0.hex }), supportsOpacity: false)
                        .labelsHidden()
                }
                Toggle("Mirror text (beam-splitter rigs)", isOn: $s.mirror)
            }

            section("Prompter") {
                Picker("", selection: $s.mode) {
                    ForEach(PrompterMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Toggle("Show prompter", isOn: $s.prompterVisible)
                Toggle("Hide from screen sharing", isOn: $s.hideFromCapture)
                Toggle("Pause on hover", isOn: $s.hoverPauses)
                Toggle("Voice activated", isOn: $s.voiceActivated)
                    .onChange(of: s.voiceActivated) { _, on in Mic.shared.setEnabled(on) }
                if s.voiceActivated {
                    slider("Mic threshold", value: $s.micThreshold, range: -70...(-10), format: "%.0f dB")
                    MicMeter()
                }
            }

            section("Shortcuts") {
                Group {
                    shortcut("⌃⌥Space", "Play / pause")
                    shortcut("⌃⌥↑ ↓", "Faster / slower")
                    shortcut("⌃⌥← →", "Previous / next cue")
                    shortcut("⌃⌥R", "Back to top")
                    shortcut("⌃⌥H", "Show / hide prompter")
                }
                .font(.caption)
            }
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value.wrappedValue)).monospacedDigit().foregroundStyle(.secondary)
            }
            .font(.callout)
            Slider(value: value, in: range)
        }
    }

    private func shortcut(_ keys: String, _ what: String) -> some View {
        HStack {
            Text(keys).monospaced()
            Spacer()
            Text(what).foregroundStyle(.secondary)
        }
    }
}

/// Separate view so 40 Hz mic updates don't re-render the whole editor.
struct MicMeter: View {
    @ObservedObject var p = Playback.shared
    @ObservedObject var s = Store.shared

    var body: some View {
        GeometryReader { g in
            let frac = { (db: Double) in CGFloat(min(1, max(0, (db + 80) / 80))) }
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule().fill(p.micDB > s.micThreshold ? Color.green : Color.secondary)
                    .frame(width: g.size.width * frac(p.micDB))
                Rectangle().fill(Color.primary).frame(width: 2)
                    .offset(x: g.size.width * frac(s.micThreshold) - 1)
            }
        }
        .frame(height: 6)
    }
}
