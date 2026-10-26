import UIKit

/// App start, taken on the first line of the app's own code.
public enum SpikeClock {
    nonisolated(unsafe) public static var launch: CFTimeInterval = CACurrentMediaTime()
}

/// The debug bar the harness reads (PROMPT.md): six buttons, a "Stream done" label and the state label
/// `first 49961 last 50000 loaded 40 pinned yes top 49990 y -12.5 ms 8`. `ms` runs from the touch up of the last
/// tapped button until `finishTap` (called once the rows are laid out), and at launch from the first line of code.
public final class DebugBar: UIView {
    public struct State {
        public var first = 0, last = 0, loaded = 0
        public var pinned = false
        public var top = 0
        public var y: CGFloat = 0
    }

    public let stateLabel = UILabel()
    public let streamDone = UILabel()
    private var buttons: [String: UIButton] = [:]
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
            let b = UIButton(configuration: c)
            b.addAction(UIAction { [weak self] _ in self?.tapped(t) }, for: .touchUpInside)
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

    private func tapped(_ title: String) {
        // Boost burst and Start stream don't change `ms`.
        if title != "Start stream" && title != "Boost burst" { tapStart = CACurrentMediaTime() }
        onTap?(title)
    }

    /// Call once the tap's result is laid out on screen (or, at launch, the first rows).
    public func finishTap() {
        let from = tapStart ?? SpikeClock.launch
        ms = Int((CACurrentMediaTime() - from) * 1000)
        tapStart = nil
    }

    public func show(_ s: State) {
        let text = "first \(s.first) last \(s.last) loaded \(s.loaded) pinned \(s.pinned ? "yes" : "no") top \(s.top) y \(String(format: "%.1f", Double(s.y))) ms \(ms)"
        if text != lastText { lastText = text; stateLabel.text = text }
    }
}
