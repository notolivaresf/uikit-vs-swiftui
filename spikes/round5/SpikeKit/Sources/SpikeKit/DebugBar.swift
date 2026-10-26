import UIKit

/// App start, taken on the first line of the app's own code.
public enum SpikeClock {
    nonisolated(unsafe) public static var launch: CFTimeInterval = CACurrentMediaTime()
}

/// The debug bar the harness reads (PROMPT.md): six buttons, a "Stream done" label and the state label
/// `first 49961 last 50000 loaded 40 pinned yes top 49990 y -12.5 ms 8`. `ms` runs from the touch up of the last
/// tapped button until `finishTap` (called once the rows are laid out), and at launch from the first line of code.
/// A button that remembers when the finger came up (the touch's own timestamp, same clock as CACurrentMediaTime).
final class TimedButton: UIButton {
    var touchUp: CFTimeInterval?
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchUp = touches.first?.timestamp
        super.touchesEnded(touches, with: event)
    }
}

public final class DebugBar: UIView {
    /// Opt-in (E2, E3): `ms` runs from the touch up (the touch's own timestamp) to the first display-link frame after
    /// the result is laid out. Off: from the action to the end of the layout, as in E1.
    nonisolated(unsafe) public static var nextFrameClock = false
    private var lastState = State()
    private var actionStart: CFTimeInterval = 0
    private var lastTitle = ""
    private var syncMs = 0
    private var link: CADisplayLink?
    public struct State {
        public var first = 0, last = 0, loaded = 0
        public var pinned = false
        public var top = 0
        public var y: CGFloat = 0
    }

    public let stateLabel = UILabel()
    public let streamDone = UILabel()
    private var buttons: [String: TimedButton] = [:]
    private var tapStart: CFTimeInterval?
    private var ms = 0
    private var lastText = ""
    public var onTap: ((String) -> Void)?

    public static let titles = ["Reset", "Jump to 2500", "Load older", "Start stream", "Text size +", "Boost burst"]

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        for t in Self.titles {
            var c = UIButton.Configuration.gray()
            c.title = t
            c.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { var a = $0; a.font = .systemFont(ofSize: 12); return a }
            c.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
            let b = TimedButton(configuration: c)
            b.addAction(UIAction { [weak self, weak b] _ in self?.tapped(t, touchUp: b?.touchUp) }, for: .touchUpInside)
            addSubview(b); buttons[t] = b
        }
        stateLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        stateLabel.numberOfLines = 2
        streamDone.text = "Stream done"; streamDone.font = .systemFont(ofSize: 10); streamDone.isHidden = true
        addSubview(stateLabel); addSubview(streamDone)
    }
    public required init?(coder: NSCoder) { fatalError() }

    public static let height: CGFloat = 110

    public override func layoutSubviews() {
        let w = bounds.width
        let bw = (w - 16 - 8) / 3
        for (i, t) in Self.titles.enumerated() {
            buttons[t]?.frame = CGRect(x: 8 + CGFloat(i % 3) * (bw + 4), y: 4 + CGFloat(i / 3) * 34, width: bw, height: 30)
        }
        stateLabel.frame = CGRect(x: 8, y: 74, width: w - 16, height: 22)
        streamDone.frame = CGRect(x: 8, y: 94, width: 100, height: 14)
    }

    private func tapped(_ title: String, touchUp: CFTimeInterval?) {
        // Boost burst and Start stream don't change `ms`.
        if title != "Start stream" && title != "Boost burst" {
            let now = CACurrentMediaTime()
            actionStart = now; lastTitle = title
            tapStart = Self.nextFrameClock ? min(touchUp ?? now, now) : now
        }
        onTap?(title)
    }

    /// Call once the tap's result is laid out on screen (or, at launch, the first rows).
    public func finishTap() {
        let from = tapStart ?? SpikeClock.launch
        tapStart = nil
        syncMs = Int((CACurrentMediaTime() - actionStart) * 1000)
        if Self.nextFrameClock && link == nil {
            let l = CADisplayLink(target: self, selector: #selector(frame(_:)))
            pendingFrom = from
            l.add(to: .main, forMode: .common)
            link = l
            return
        }
        ms = Int((CACurrentMediaTime() - from) * 1000)
    }

    private var pendingFrom: CFTimeInterval = 0

    /// Spike-only side channel (E2, E3): the app's own work time for each tap, action to end of layout, next to the
    /// touch-to-next-frame time, appended to a file in the app's temporary folder. The harness never reads it.
    private func logWork() {
        let line = "\(Date().timeIntervalSince1970) \(lastTitle) work_ms \(syncMs) frame_ms \(ms)\n"
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("uvs-work.log")
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close() }
        else { try? Data(line.utf8).write(to: url) }
    }
    @objc private func frame(_ l: CADisplayLink) {
        l.invalidate(); link = nil
        ms = Int((CACurrentMediaTime() - pendingFrom) * 1000)
        logWork()
        show(lastState)
    }

    public func show(_ s: State) {
        lastState = s
        let text = "first \(s.first) last \(s.last) loaded \(s.loaded) pinned \(s.pinned ? "yes" : "no") top \(s.top) y \(String(format: "%.1f", Double(s.y))) ms \(ms)"
        if text != lastText { lastText = text; stateLabel.text = text }
    }
}
