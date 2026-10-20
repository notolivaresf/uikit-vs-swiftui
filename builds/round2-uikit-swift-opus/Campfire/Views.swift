import UIKit

/// A view with a 1 pt border in a dynamic colour (layer colours do not follow dark mode by themselves).
class StrokeView: UIView {
    var strokeColor: UIColor = .clear { didSet { applyStroke() } }
    var strokeWidth: CGFloat = 1 { didSet { applyStroke() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: StrokeView, _) in view.applyStroke() }
    }

    required init?(coder: NSCoder) { fatalError() }

    private func applyStroke() {
        layer.borderWidth = strokeWidth
        layer.borderColor = strokeColor.resolvedColor(with: traitCollection).cgColor
    }
}

/// Round avatar with a white initial and a ring in the page colour around it.
final class AvatarView: UIView {
    private let circle = UIView()
    private let label = UILabel()
    var ring: CGFloat = Metrics.avatarRing

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Palette.background
        addSubview(circle)
        circle.addSubview(label)
        label.textColor = .white
        label.textAlignment = .center
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(initial: String, color: UIColor, font: UIFont = .systemFont(ofSize: 16, weight: .bold)) {
        label.text = initial
        label.font = font
        circle.backgroundColor = color
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
        circle.frame = bounds.insetBy(dx: ring, dy: ring)
        circle.layer.cornerRadius = circle.bounds.width / 2
        label.frame = circle.bounds
    }
}

/// The "•••" message actions button (drawn only).
final class DotsView: UIView {
    private let dots = (0..<3).map { _ in UIView() }

    override init(frame: CGRect) {
        super.init(frame: frame)
        for dot in dots {
            dot.backgroundColor = Palette.textHalf
            addSubview(dot)
        }
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let d = bounds.height
        let step = (bounds.width - d) / 2
        for (i, dot) in dots.enumerated() {
            dot.frame = CGRect(x: CGFloat(i) * step, y: 0, width: d, height: d)
            dot.layer.cornerRadius = d / 2
        }
    }
}

/// One boost: the booster's initial avatar plus the emoji or short text.
final class BoostPillView: StrokeView {
    private let avatar = UIView()
    private let initial = UILabel()
    private let content = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Palette.boostPill
        strokeColor = Palette.borderDark
        addSubview(avatar)
        avatar.addSubview(initial)
        addSubview(content)
        initial.textColor = .white
        initial.textAlignment = .center
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(_ pill: RowLayout.Pill) {
        frame = pill.frame
        layer.cornerRadius = pill.frame.height / 2
        avatar.frame = pill.avatarFrame
        avatar.layer.cornerRadius = pill.avatarFrame.width / 2
        avatar.backgroundColor = pill.color
        initial.frame = avatar.bounds
        initial.font = pill.initialFont
        initial.text = pill.initial
        content.frame = pill.contentFrame
        content.attributedText = pill.content
    }
}

/// The add-boost button at the end of the strip (drawn only).
final class AddBoostView: StrokeView {
    private let face = UIImageView(image: UIImage(systemName: "face.smiling",
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)))
    private let plusBack = UIView()
    private let plus = UIImageView(image: UIImage(systemName: "plus",
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 7, weight: .heavy)))

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Palette.boostPill
        strokeColor = Palette.borderDark
        face.tintColor = Palette.text
        plus.tintColor = Palette.text
        plusBack.backgroundColor = Palette.boostPill
        addSubview(face)
        addSubview(plusBack)
        addSubview(plus)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
        face.sizeToFit()
        face.center = CGPoint(x: bounds.midX - 0.5, y: bounds.midY - 0.5)
        plus.sizeToFit()
        plus.center = CGPoint(x: face.frame.maxX - 1.5, y: face.frame.maxY - 1.5)
        plusBack.frame = plus.frame.insetBy(dx: -1, dy: -1)
        plusBack.layer.cornerRadius = plusBack.bounds.width / 2
    }
}

/// Selectable, non-editable text drawn by TextKit 1 to match `TextMeasurer`.
final class MessageTextView: UITextView {
    init() {
        let storage = NSTextStorage()
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: 100, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        super.init(frame: .zero, textContainer: container)
        isEditable = false
        isSelectable = true
        isScrollEnabled = false
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        backgroundColor = .clear
        dataDetectorTypes = []
        clipsToBounds = false
        scrollsToTop = false
    }

    required init?(coder: NSCoder) { fatalError() }
}
