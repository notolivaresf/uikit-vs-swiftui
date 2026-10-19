import UIKit

/// Round avatar: palette colour with the white initial.
final class AvatarView: UIView {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.textColor = .white
        label.textAlignment = .center
        addSubview(label)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(initial: String, color: UIColor, fontSize: CGFloat) {
        backgroundColor = color
        if label.text != initial { label.text = initial }
        if label.font?.pointSize != fontSize { label.font = .systemFont(ofSize: fontSize, weight: .heavy) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
        label.frame = bounds
    }
}

/// The "•••" message menu button (drawn, does nothing).
final class DotsView: UIView {
    var color: UIColor = Colors.dimText { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        contentMode = .redraw
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        color.setFill()
        let d = min(bounds.height, bounds.width / 3.6)
        let step = (bounds.width - d) / 2
        for i in 0..<3 {
            UIBezierPath(ovalIn: CGRect(x: CGFloat(i) * step, y: (bounds.height - d) / 2, width: d, height: d)).fill()
        }
    }
}

/// Smiley with a plus: Campfire's add-boost icon.
final class AddBoostIcon: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        contentMode = .redraw
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        let s = min(bounds.width, bounds.height) / 14
        Colors.text.setStroke()
        Colors.text.setFill()
        let lw = 1.5 * s
        // Face outline, open at the bottom right where the plus sits.
        let c = CGPoint(x: 6.5 * s, y: 6.5 * s)
        let face = UIBezierPath(arcCenter: c, radius: 5.8 * s, startAngle: .pi * 0.42, endAngle: .pi * 0.08, clockwise: true)
        face.lineWidth = lw
        face.lineCapStyle = .round
        face.stroke()
        UIBezierPath(ovalIn: CGRect(x: 3.9 * s, y: 4.2 * s, width: 1.7 * s, height: 1.9 * s)).fill()
        UIBezierPath(ovalIn: CGRect(x: 7.6 * s, y: 4.2 * s, width: 1.7 * s, height: 1.9 * s)).fill()
        let smile = UIBezierPath(arcCenter: CGPoint(x: 6.6 * s, y: 7.2 * s), radius: 2.6 * s, startAngle: .pi * 0.15,
                                 endAngle: .pi * 0.85, clockwise: true)
        smile.lineWidth = lw
        smile.lineCapStyle = .round
        smile.stroke()
        let plus = UIBezierPath()
        plus.move(to: CGPoint(x: 11.2 * s, y: 9.2 * s)); plus.addLine(to: CGPoint(x: 11.2 * s, y: 13.6 * s))
        plus.move(to: CGPoint(x: 9.0 * s, y: 11.4 * s)); plus.addLine(to: CGPoint(x: 13.4 * s, y: 11.4 * s))
        plus.lineWidth = lw
        plus.lineCapStyle = .round
        plus.stroke()
    }
}

/// One boost: booster's initial avatar plus the emoji or short text, in a round pill.
final class BoostPillView: BorderedView {
    let avatar = AvatarView()
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        borderColor = Colors.borderDark
        layer.borderWidth = 1
        backgroundColor = Colors.background
        label.textColor = Colors.text
        addSubview(avatar)
        addSubview(label)
        applyBorder()
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(_ pill: RowGeometry.Pill, m: Metrics) {
        let h = pill.frame.height
        layer.cornerRadius = h / 2
        let d = m.boostAvatar
        avatar.frame = CGRect(x: 2.6, y: (h - d) / 2, width: d, height: d)
        avatar.configure(initial: pill.initial, color: pill.color, fontSize: 11)
        label.font = pill.isEmoji ? m.boostEmoji : m.boostText
        label.text = pill.boost.content
        let x = avatar.frame.maxX + (pill.isEmoji ? 5 : 4)
        label.frame = CGRect(x: x, y: 0, width: max(0, pill.frame.width - x - 2), height: h)
    }
}

final class AddBoostView: BorderedView {
    let icon = AddBoostIcon()

    override init(frame: CGRect) {
        super.init(frame: frame)
        borderColor = Colors.borderDark
        layer.borderWidth = 1
        backgroundColor = Colors.background
        addSubview(icon)
        applyBorder()
        accessibilityLabel = "Add a boost"
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        icon.frame = CGRect(x: (bounds.width - 14) / 2, y: (bounds.height - 14) / 2, width: 14, height: 14)
    }
}

/// Selectable message text: long-press selects, the edit menu offers Copy and Reply.
final class MessageTextView: UITextView {
    private let storage: NSTextStorage
    /// The attributed string last applied (skips re-layout when unchanged).
    var source: NSAttributedString?

    init() {
        // An explicit TextKit 1 stack, matching TextMeasurer.
        storage = NSTextStorage()
        let lm = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        lm.addTextContainer(container)
        storage.addLayoutManager(lm)
        super.init(frame: .zero, textContainer: container)
        isEditable = false
        isSelectable = true
        isScrollEnabled = false
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        backgroundColor = .clear
        dataDetectorTypes = []
        clipsToBounds = false
        showsVerticalScrollIndicator = false
    }

    required init?(coder: NSCoder) { fatalError() }
}

final class CodeBoxView: UIView {
    let textView = MessageTextView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Colors.codeBox
        layer.cornerRadius = K.codeRadius
        addSubview(textView)
    }

    required init?(coder: NSCoder) { fatalError() }
}

func symbol(_ name: String, size: CGFloat, weight: UIImage.SymbolWeight = .regular) -> UIImage? {
    UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: weight))
}

/// Circle button outline used in the header, composer and welcome card.
class CircleButton: BorderedView {
    let iconView = UIImageView()

    init(symbolName: String?, size: CGFloat = 20, weight: UIImage.SymbolWeight = .bold) {
        super.init(frame: .zero)
        layer.borderWidth = 1
        backgroundColor = Colors.background
        if let symbolName { iconView.image = symbol(symbolName, size: size, weight: weight) }
        iconView.tintColor = Colors.text
        iconView.contentMode = .center
        addSubview(iconView)
        applyBorder()
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
        iconView.frame = bounds
    }
}
