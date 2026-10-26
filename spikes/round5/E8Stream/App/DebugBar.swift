import UIKit

/// Shown with `-uvsBenchmark YES`: action buttons, the "Stream done" label and the state label.
final class DebugBar: UIView {
    static let titles = ["Reset", "Jump to 2500", "Load older", "Start stream", "Text size +", "Boost burst"]

    var onAction: ((String, UIEvent?) -> Void)?
    private var buttons: [UIButton] = []
    let stateLabel = UILabel()
    let doneLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.secondarySystemBackground
        for t in DebugBar.titles {
            var c = UIButton.Configuration.filled()
            c.title = t
            c.baseBackgroundColor = .systemBlue
            c.baseForegroundColor = .white
            c.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
            c.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
                var a = a
                a.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
                return a
            }
            let b = UIButton(configuration: c)
            b.accessibilityIdentifier = t
            b.addTarget(self, action: #selector(tapped(_:event:)), for: .touchUpInside)
            addSubview(b)
            buttons.append(b)
        }
        stateLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        stateLabel.numberOfLines = 2
        stateLabel.textColor = .label
        stateLabel.accessibilityIdentifier = "state"
        addSubview(stateLabel)
        doneLabel.font = .systemFont(ofSize: 11, weight: .bold)
        doneLabel.textColor = .systemGreen
        doneLabel.text = "Stream done"
        doneLabel.isHidden = true
        doneLabel.textAlignment = .right
        doneLabel.accessibilityIdentifier = "streamDone"
        addSubview(doneLabel)
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapped(_ sender: UIButton, event: UIEvent) {
        onAction?(sender.accessibilityIdentifier ?? "", event)
    }

    /// Height for a given width: two rows of buttons when narrow, one when wide, plus the label row.
    static func height(for width: CGFloat) -> CGFloat { width >= 600 ? 74 : 108 }

    override func layoutSubviews() {
        super.layoutSubviews()
        let pad: CGFloat = 6, gap: CGFloat = 5, bh: CGFloat = 30
        let perRow = bounds.width >= 600 ? 6 : 3
        let x0 = safeAreaInsets.left + pad
        let w = bounds.width - safeAreaInsets.left - safeAreaInsets.right - 2 * pad
        let bw = (w - gap * CGFloat(perRow - 1)) / CGFloat(perRow)
        for (i, b) in buttons.enumerated() {
            let r = i / perRow, c = i % perRow
            b.frame = CGRect(x: x0 + CGFloat(c) * (bw + gap), y: pad + CGFloat(r) * (bh + gap), width: bw, height: bh)
        }
        let rows = (buttons.count + perRow - 1) / perRow
        let ly = pad + CGFloat(rows) * (bh + gap)
        doneLabel.frame = CGRect(x: x0 + w - 80, y: ly, width: 80, height: 30)
        stateLabel.frame = CGRect(x: x0, y: ly, width: w - 84, height: 30)
    }
}
