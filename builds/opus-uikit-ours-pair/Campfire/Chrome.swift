import UIKit

/// A drawn-only round button with a 1 pt border and an SF Symbol.
class CircleButton: UIButton {
    private let ringView = StrokeView()

    init(symbol: String?, pointSize: CGFloat = 19, weight: UIImage.SymbolWeight = .bold, label: String) {
        super.init(frame: .zero)
        ringView.isUserInteractionEnabled = false
        ringView.backgroundColor = Palette.background
        ringView.strokeColor = Palette.borderDarker
        insertSubview(ringView, at: 0)
        if let symbol {
            setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)), for: .normal)
        }
        tintColor = Palette.text
        accessibilityLabel = label
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        ringView.frame = bounds
        ringView.layer.cornerRadius = bounds.height / 2
        sendSubviewToBack(ringView)
    }
}

/// Room header: the room name, the room menu, notifications (with the orange "on" ring) and the sidebar button.
/// The background fades from the page colour to clear so rows scroll under it, as in Campfire.
final class HeaderView: UIView {
    private let gradient = CAGradientLayer()
    private let roomButton = UIButton(type: .custom)
    private let moreButton = CircleButton(symbol: "ellipsis", pointSize: 21, weight: .black, label: "Room settings")
    private let bellButton = CircleButton(symbol: nil, label: "Notifications")
    private let bellRing = UIView()
    private let bellIcon = UIImageView(image: UIImage(systemName: "bell.fill",
                                                      withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .bold)))
    private let bellBadgeBack = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill",
                                                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .black)))
    private let bellBadge = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill",
                                                       withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)))
    private let menuButton = CircleButton(symbol: "line.3.horizontal", pointSize: 20, weight: .bold, label: "Rooms")
    var topInset: CGFloat = 0 { didSet { setNeedsLayout() } }

    init(roomName: String) {
        super.init(frame: .zero)
        accessibilityIdentifier = "room-header"
        layer.addSublayer(gradient)
        roomButton.setAttributedTitle(NSAttributedString(string: roomName, attributes: [
            .font: UIFont.systemFont(ofSize: 16.5, weight: .heavy), .foregroundColor: Palette.background,
        ]), for: .normal)
        roomButton.backgroundColor = Palette.text
        roomButton.layer.cornerRadius = 8
        roomButton.layer.cornerCurve = .continuous
        addSubview(roomButton)
        addSubview(moreButton)
        bellRing.isUserInteractionEnabled = false
        addSubview(bellRing)
        addSubview(bellButton)
        for v in [bellIcon, bellBadgeBack, bellBadge] {
            v.isUserInteractionEnabled = false
            bellButton.addSubview(v)
        }
        bellIcon.tintColor = Palette.text
        bellIcon.transform = CGAffineTransform(rotationAngle: -0.3)
        bellBadgeBack.tintColor = Palette.background
        bellBadge.tintColor = Palette.text
        addSubview(menuButton)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: HeaderView, _) in view.updateColors() }
        updateColors()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func updateColors() {
        let bg = Palette.background.resolvedColor(with: traitCollection)
        gradient.colors = [bg.cgColor, bg.cgColor, bg.withAlphaComponent(0).cgColor]
        bellRing.layer.borderColor = Palette.bellRing.cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let top = topInset
        let left = safeAreaInsets.left
        let right = bounds.width - safeAreaInsets.right
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        let h = max(bounds.height, 1)
        gradient.locations = [0, NSNumber(value: Double((top + 10) / h)), 1]
        CATransaction.commit()
        roomButton.frame = CGRect(x: left + 10.33, y: top + 8, width: 96, height: 42)
        moreButton.frame = CGRect(x: left + 113, y: top + 8, width: 42, height: 42)
        bellButton.frame = CGRect(x: left + 160, y: top + 8, width: 42, height: 42)
        bellRing.frame = bellButton.frame.insetBy(dx: -3, dy: -3)
        bellRing.layer.borderWidth = 3
        bellRing.layer.cornerRadius = bellRing.bounds.width / 2
        bellIcon.bounds.size = bellIcon.image?.size ?? .zero
        bellIcon.center = CGPoint(x: 18.5, y: 19)
        bellBadgeBack.sizeToFit()
        bellBadgeBack.center = CGPoint(x: 26.5, y: 25.5)
        bellBadge.sizeToFit()
        bellBadge.center = CGPoint(x: 26.5, y: 26)
        menuButton.frame = CGRect(x: right - 11 - 42, y: top + 8, width: 42, height: 42)
    }

    /// Only the buttons take touches; the faded area lets them through to the rows.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}

/// The composer, drawn only: search, the message field with the attach button, and send.
final class ComposerView: UIView {
    private let searchButton = CircleButton(symbol: "magnifyingglass", pointSize: 20, weight: .bold, label: "Search")
    private let field = StrokeView()
    private let bubbleIcon = UIImageView(image: UIImage(systemName: "bubble.left",
                                                        withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .medium)))
    private let clipIcon = UIImageView(image: UIImage(systemName: "paperclip",
                                                      withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .medium)))
    private let sendButton = UIButton(type: .custom)
    /// Distance from the view's bottom to the bottom of the field.
    var bottomInset: CGFloat = 24 { didSet { setNeedsLayout() } }
    static let fieldTop: CGFloat = 24
    static let fieldHeight: CGFloat = 42

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Palette.background
        accessibilityIdentifier = "composer"
        field.strokeColor = Palette.borderDarker
        field.backgroundColor = Palette.background
        bubbleIcon.tintColor = Palette.text
        clipIcon.tintColor = Palette.text
        clipIcon.transform = CGAffineTransform(rotationAngle: 0.78)
        field.addSubview(bubbleIcon)
        field.addSubview(clipIcon)
        sendButton.backgroundColor = Palette.text
        sendButton.setImage(UIImage(systemName: "arrow.up", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .heavy)), for: .normal)
        sendButton.tintColor = Palette.background
        sendButton.accessibilityLabel = "Send"
        field.addSubview(sendButton)
        addSubview(searchButton)
        addSubview(field)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let left = safeAreaInsets.left
        let right = bounds.width - safeAreaInsets.right
        let y = Self.fieldTop
        searchButton.frame = CGRect(x: left + 14, y: y, width: 42, height: 42)
        field.frame = CGRect(x: left + 66.4, y: y, width: right - 14 - (left + 66.4), height: Self.fieldHeight)
        field.layer.cornerRadius = Self.fieldHeight / 2
        let fw = field.bounds.width
        bubbleIcon.sizeToFit()
        bubbleIcon.center = CGPoint(x: 24.9, y: 21.6)
        clipIcon.bounds.size = clipIcon.image?.size ?? .zero
        clipIcon.center = CGPoint(x: fw - 65, y: 21)
        sendButton.frame = CGRect(x: fw - 21 - 17.5 + 1, y: 21 - 17.5, width: 35, height: 35)
        sendButton.layer.cornerRadius = 17.5
    }
}

/// Floating button shown when the room is not pinned to the newest message.
final class JumpToBottomButton: CircleButton {
    init() {
        super.init(symbol: "arrow.down", pointSize: 18, weight: .bold, label: "Jump to newest")
        accessibilityIdentifier = "jump-to-bottom"
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)
    }

    required init?(coder: NSCoder) { fatalError() }
}

/// The benchmark debug bar (`-uvsBenchmark YES`).
final class DebugBar: UIView {
    enum Action: String, CaseIterable {
        case reset = "Reset"
        case jump = "Jump to 2500"
        case loadOlder = "Load older"
        case startStream = "Start stream"
        case textSize = "Text size +"
        case boostBurst = "Boost burst"
    }

    let stateLabel = UILabel()
    let doneLabel = UILabel()
    var onAction: ((Action, TimeInterval) -> Void)?
    private var buttons: [UIButton] = []
    private static let pad: CGFloat = 8
    private static let spacing: CGFloat = 6
    private static let labelHeight: CGFloat = 18

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground
        accessibilityIdentifier = "debug-bar"
        for (index, action) in Action.allCases.enumerated() {
            var config = UIButton.Configuration.gray()
            config.title = action.rawValue
            config.buttonSize = .mini
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
                var a = attrs
                a.font = UIFont.systemFont(ofSize: 13, weight: .medium)
                return a
            }
            let button = UIButton(configuration: config)
            button.accessibilityIdentifier = action.rawValue
            button.tag = index
            button.addTarget(self, action: #selector(tapped(_:event:)), for: .touchUpInside)
            addSubview(button)
            buttons.append(button)
        }
        doneLabel.text = "Stream done"
        doneLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        doneLabel.textColor = .systemGreen
        doneLabel.accessibilityIdentifier = "stream-done"
        doneLabel.isHidden = true
        addSubview(doneLabel)
        stateLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        stateLabel.textColor = .label
        stateLabel.adjustsFontSizeToFitWidth = true
        stateLabel.minimumScaleFactor = 0.6
        stateLabel.accessibilityIdentifier = "debug-state"
        addSubview(stateLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Lays the buttons out left to right, wrapping, then the state label. Returns the height used.
    @discardableResult
    private func flow(width: CGFloat, left: CGFloat, apply: Bool) -> CGFloat {
        let maxX = width - Self.pad
        var x = left + Self.pad
        var y = Self.pad
        var rowHeight: CGFloat = 0
        doneLabel.sizeToFit()
        let views: [UIView] = buttons + [doneLabel]
        for view in views {
            let size = view === doneLabel ? doneLabel.bounds.size : view.sizeThatFits(CGSize(width: 300, height: 40))
            if x > left + Self.pad && x + size.width > maxX {
                x = left + Self.pad
                y += rowHeight + Self.spacing
                rowHeight = 0
            }
            if apply { view.frame = CGRect(x: x, y: y + (view === doneLabel ? 6 : 0), width: size.width, height: size.height) }
            x += size.width + Self.spacing
            rowHeight = max(rowHeight, view === doneLabel ? 0 : size.height)
        }
        y += rowHeight + 4
        if apply { stateLabel.frame = CGRect(x: left + Self.pad, y: y, width: maxX - left - Self.pad, height: Self.labelHeight) }
        return y + Self.labelHeight + Self.pad
    }

    func preferredHeight(for width: CGFloat) -> CGFloat {
        flow(width: width - safeAreaInsets.right, left: safeAreaInsets.left, apply: false)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        flow(width: bounds.width - safeAreaInsets.right, left: safeAreaInsets.left, apply: true)
    }

    /// Passes on the tap with its touch-up time (the event's timestamp, on the system uptime clock).
    @objc private func tapped(_ sender: UIControl, event: UIEvent) {
        let time = event.allTouches?.first?.timestamp ?? event.timestamp
        onAction?(Action.allCases[sender.tag], time)
    }
}
