import SwiftUI

private struct HeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct CueOffsetKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

struct PrompterView: View {
    @ObservedObject var s = Store.shared
    @ObservedObject var p = Playback.shared

    private var color: Color { Color(hex: s.colorHex) }
    private var shape: UnevenRoundedRectangle {
        let r: CGFloat = p.isNotch ? 20 : 16
        return UnevenRoundedRectangle(topLeadingRadius: p.isNotch ? 0 : r, bottomLeadingRadius: r,
                                      bottomTrailingRadius: r, topTrailingRadius: p.isNotch ? 0 : r)
    }

    var body: some View {
        ZStack(alignment: .top) {
            shape.fill(Color.black)
            if !p.isNotch { shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 1) }

            VStack(spacing: 0) {
                statusBand
                script
            }

            VStack {
                Spacer()
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(color.opacity(0.12))
                        Capsule().fill(color.opacity(0.55)).frame(width: g.size.width * p.progress)
                    }
                }
                .frame(height: 2)
                .padding(.horizontal, 22)
                .padding(.bottom, 7)
            }
        }
        .clipShape(shape)
    }

    private var statusBand: some View {
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: stateIcon)
                Text("\(Int(s.speed))")
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)

            Color.clear.frame(width: p.notchWidth)

            HStack(spacing: 6) {
                if !s.cues.isEmpty { Text("\(p.currentCue + 1)/\(s.cues.count)").monospacedDigit() }
                if s.voiceActivated {
                    Circle()
                        .fill(p.speaking ? Color.green : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundColor(.white.opacity(0.65))
        .frame(height: p.topInset)
    }

    private var stateIcon: String {
        if !s.playing { return "pause.fill" }
        if s.hoverPauses && p.hovering { return "hand.raised.fill" }
        if s.voiceActivated && !p.speaking { return "mic.fill" }
        return "play.fill"
    }

    private var script: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: s.fontSize * 0.9) {
                ForEach(s.cues) { cue in
                    VStack(alignment: .leading, spacing: 4) {
                        if let title = cue.title, !title.isEmpty {
                            Text(title.uppercased())
                                .font(.system(size: max(10, s.fontSize * 0.42), weight: .bold, design: .rounded))
                                .tracking(1.2)
                                .foregroundColor(color.opacity(0.45))
                        }
                        Text(cue.body)
                            .font(.system(size: s.fontSize, weight: .medium, design: .rounded))
                            .lineSpacing(s.fontSize * 0.22)
                            .foregroundColor(color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .background(GeometryReader { g in
                        Color.clear.preference(key: CueOffsetKey.self,
                                               value: [cue.id: g.frame(in: .named("content")).minY])
                    })
                }
                Color.clear.frame(height: geo.size.height)
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .frame(width: geo.size.width, alignment: .leading)
            .coordinateSpace(name: "content")
            .background(GeometryReader { g in Color.clear.preference(key: HeightKey.self, value: g.size.height) })
            .scaleEffect(x: s.mirror ? -1 : 1, y: 1)
            .offset(y: -p.offset)
            .onPreferenceChange(HeightKey.self) { Playback.shared.contentHeight = $0 }
            .onPreferenceChange(CueOffsetKey.self) { Playback.shared.cueOffsets = $0 }
            .onAppear { Playback.shared.viewportHeight = geo.size.height }
            .onChange(of: geo.size.height) { _, h in Playback.shared.viewportHeight = h }
        }
        .clipped()
        .mask(
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.06),
                .init(color: .black, location: 0.7),
                .init(color: .clear, location: 1),
            ], startPoint: .top, endPoint: .bottom)
        )
        .padding(.bottom, 12)
    }
}
