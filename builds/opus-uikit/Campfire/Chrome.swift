import UIKit

/// Room header: "General" pill, "•••", the bell with its orange ring, and the sidebar button. Drawn, does nothing.
final class HeaderBar: UIView {
    private let gradient = CAGradientLayer()
    private let solid = UIView()
    private let pill = UIView()
    private let pillLabel = UILabel()
    private let more = CircleButton(symbolName: nil)
    private let moreDots = DotsView()
    private let bellRing = BorderedView()
    private let bell = CircleButton(symbolName: nil)
    private let bellIcon = BellIcon()
    private let menu = CircleButton(symbolName: nil)
    private let menuIcon = HamburgerIcon()
    var safeTop: CGFloat = 0
    var safeLeft: CGFloat = 0
    var safeRight: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        solid.backgroundColor = Colors.background
        addSubview(solid)
        layer.addSublayer(gradient)
        pill.backgroundColor = Colors.text
        pill.layer.cornerRadius = 9
        pillLabel.text = "General"
        pillLabel.font = .systemFont(ofSize: 17.6, weight: .bold)
        pillLabel.textColor = Colors.background
        pillLabel.textAlignment = .center
        pill.addSubview(pillLabel)
        pill.isAccessibilityElement = true
        pill.accessibilityLabel = "General"
        addSubview(pill)
        moreDots.color = Colors.text
        more.addSubview(moreDots)
        more.accessibilityLabel = "Room settings"
        addSubview(more)
        bellRing.borderColor = Colors.orange
        bellRing.layer.borderWidth = 3
        bellRing.isUserInteractionEnabled = false
        addSubview(bellRing)
        bell.addSubview(bellIcon)
        bell.accessibilityLabel = "Notifications"
        addSubview(bell)
        menu.addSubview(menuIcon)
        menu.accessibilityLabel = "Rooms"
        addSubview(menu)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: HeaderBar, _) in self.updateGradient() }
        updateGradient()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func updateGradient() {
        let bg = Colors.background.resolvedColor(with: traitCollection)
        gradient.colors = [bg.cgColor, bg.withAlphaComponent(0.85).cgColor, bg.withAlphaComponent(0).cgColor]
        gradient.locations = [0, 0.45, 1]
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        solid.frame = CGRect(x: 0, y: 0, width: bounds.width, height: safeTop)
        gradient.frame = CGRect(x: 0, y: safeTop, width: bounds.width, height: bounds.height - safeTop)
        CATransaction.commit()
        let y = safeTop + 8
        let x0 = safeLeft
        pill.frame = CGRect(x: x0 + 10, y: y, width: 97, height: 42)
        pillLabel.frame = pill.bounds
        more.frame = CGRect(x: x0 + 113, y: y, width: 42, height: 42)
        moreDots.frame = CGRect(x: 10.5, y: 18.3, width: 20.6, height: 5.4)
        bell.frame = CGRect(x: x0 + 160, y: y, width: 42, height: 42)
        bellRing.frame = bell.frame.insetBy(dx: -5, dy: -5)
        bellRing.layer.cornerRadius = bellRing.bounds.width / 2
        bellIcon.frame = CGRect(x: 5, y: 6, width: 32, height: 30)
        menu.frame = CGRect(x: bounds.width - safeRight - 11 - 42, y: y, width: 42, height: 42)
        menuIcon.frame = CGRect(x: 11.3, y: 13, width: 19.6, height: 16)
    }
}

final class HamburgerIcon: UIView {
    override init(frame: CGRect) { super.init(frame: frame); isOpaque = false; contentMode = .redraw }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ rect: CGRect) {
        Colors.text.setFill()
        let h: CGFloat = 2.6
        for i in 0..<3 {
            let y = CGFloat(i) * (bounds.height - h) / 2
            UIBezierPath(roundedRect: CGRect(x: 0, y: y, width: bounds.width, height: h), cornerRadius: h / 2).fill()
        }
    }
}

/// Bell with a warning triangle (Campfire's "notifications off/limited" glyph).
final class BellIcon: UIView {
    private let bell = UIImageView(image: symbol("bell.fill", size: 21, weight: .bold))
    private let warn = UIImageView(image: symbol("exclamationmark.triangle.fill", size: 13, weight: .bold))
    private let warnBack = UIImageView(image: symbol("triangle.fill", size: 17, weight: .black))

    override init(frame: CGRect) {
        super.init(frame: frame)
        bell.tintColor = Colors.text
        bell.transform = CGAffineTransform(rotationAngle: -0.3)
        warnBack.tintColor = Colors.background
        warn.tintColor = Colors.text
        [bell, warnBack, warn].forEach { $0.contentMode = .center; addSubview($0) }
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        bell.bounds = CGRect(x: 0, y: 0, width: 24, height: 24)
        bell.center = CGPoint(x: 14, y: 14)
        warnBack.frame = CGRect(x: 13, y: 12, width: 20, height: 18)
        warn.frame = CGRect(x: 14, y: 13, width: 18, height: 16)
    }
}

/// Composer: search button, message field with chat glyph, paperclip and send. Drawn, does nothing.
final class ComposerView: UIView {
    private let search = CircleButton(symbolName: "magnifyingglass", size: 19, weight: .heavy)
    private let field = BorderedView()
    private let chat = UIImageView(image: symbol("bubble.left", size: 20, weight: .medium))
    private let clip = UIImageView(image: symbol("paperclip", size: 19, weight: .medium))
    private let send = UIView()
    private let sendIcon = UIImageView(image: symbol("arrow.up", size: 17, weight: .heavy))

    override init(frame: CGRect) {
        super.init(frame: frame)
        search.accessibilityLabel = "Search"
        addSubview(search)
        field.layer.borderWidth = 1
        field.backgroundColor = Colors.background
        field.applyBorder()
        field.isAccessibilityElement = true
        field.accessibilityLabel = "Write a message"
        addSubview(field)
        [chat, clip].forEach { $0.tintColor = Colors.text; $0.contentMode = .center; field.addSubview($0) }
        send.backgroundColor = Colors.text
        sendIcon.tintColor = Colors.background
        sendIcon.contentMode = .center
        send.addSubview(sendIcon)
        send.isAccessibilityElement = true
        send.accessibilityLabel = "Send"
        send.accessibilityTraits = .button
        field.addSubview(send)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let h = bounds.height
        search.frame = CGRect(x: 14, y: 0, width: 42, height: h)
        field.frame = CGRect(x: 66, y: 0, width: bounds.width - 66 - 14, height: h)
        field.layer.cornerRadius = h / 2
        chat.frame = CGRect(x: 14, y: 11, width: 22, height: 21)
        let fw = field.bounds.width
        send.frame = CGRect(x: fw - 5 - 34, y: 4, width: 34, height: 34)
        send.layer.cornerRadius = 17
        sendIcon.frame = send.bounds
        clip.frame = CGRect(x: fw - 76, y: 11, width: 20, height: 20)
    }
}

/// Shown above the first message of the room.
final class WelcomeView: UICollectionReusableView {
    static let reuseID = "WelcomeView"
    /// Height of the welcome block in content coordinates; the first row follows after one row gap.
    static let height: CGFloat = 358.4

    private let card = UIView()
    private let logo = CampfireLogo()
    private let globe = CircleButton(symbolName: nil)
    private let globeLabel = UILabel()
    private let title = UILabel()
    private let subtitle = UILabel()
    private let link = BorderedView()
    private let linkIcon = UIImageView(image: symbol("person.fill.badge.plus", size: 19, weight: .regular))
    private let linkLabel = UILabel()
    private let buttons = [CircleButton(symbolName: "qrcode.viewfinder", size: 21, weight: .medium),
                           CircleButton(symbolName: "doc.on.clipboard", size: 19, weight: .medium),
                           CircleButton(symbolName: "square.and.arrow.up", size: 19, weight: .medium)]

    override init(frame: CGRect) {
        super.init(frame: frame)
        card.backgroundColor = Colors.bubble
        card.layer.cornerRadius = 12
        addSubview(card)
        addSubview(logo)
        globeLabel.text = "🌎"
        globeLabel.font = .systemFont(ofSize: 15)
        globeLabel.textAlignment = .center
        globe.addSubview(globeLabel)
        card.addSubview(globe)
        title.text = "Welcome to Campfire"
        title.font = .systemFont(ofSize: 16, weight: .bold)
        title.textAlignment = .center
        title.textColor = Colors.text
        card.addSubview(title)
        let p = NSMutableParagraphStyle()
        p.minimumLineHeight = 22.4
        p.maximumLineHeight = 22.4
        p.alignment = .center
        subtitle.attributedText = NSAttributedString(
            string: "To invite people to chat, share the join link below.",
            attributes: [.font: UIFont.systemFont(ofSize: 16), .foregroundColor: Colors.text, .paragraphStyle: p,
                         .baselineOffset: (22.4 - UIFont.systemFont(ofSize: 16).lineHeight) / 4])
        subtitle.numberOfLines = 0
        card.addSubview(subtitle)
        link.layer.borderWidth = 1
        link.layer.cornerRadius = 8
        link.backgroundColor = Colors.background
        link.applyBorder()
        linkIcon.tintColor = Colors.text
        linkIcon.contentMode = .center
        link.addSubview(linkIcon)
        linkLabel.text = "http://127.0.0.1:3055/join/GwHG-HbZN"
        linkLabel.font = .systemFont(ofSize: 16)
        linkLabel.textColor = Colors.text
        linkLabel.adjustsFontSizeToFitWidth = true
        link.addSubview(linkLabel)
        card.addSubview(link)
        buttons.forEach { card.addSubview($0) }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let W = bounds.width
        card.frame = CGRect(x: K.screenPadX, y: 87.72, width: W - 2 * K.screenPadX, height: 269)
        logo.frame = CGRect(x: (W - 69) / 2, y: 63.72, width: 69, height: 69)
        globe.frame = CGRect(x: 16, y: 16, width: 42, height: 42)
        globeLabel.frame = globe.bounds
        let cw = card.bounds.width
        title.frame = CGRect(x: 10, y: 75.3, width: cw - 20, height: 22.4)
        subtitle.frame = CGRect(x: 28, y: 98, width: cw - 56, height: 44.8)
        link.frame = CGRect(x: 15, y: 160, width: cw - 30, height: 40)
        linkIcon.frame = CGRect(x: 12, y: 9, width: 22, height: 22)
        linkLabel.frame = CGRect(x: 43, y: 0, width: link.bounds.width - 50, height: 40)
        let cx = W / 2 - 5 - K.screenPadX
        for (i, b) in buttons.enumerated() {
            b.frame = CGRect(x: cx + CGFloat(i - 1) * 52.7 - 21, y: 217, width: 42, height: 42)
        }
    }
}

/// The Campfire app icon: a purple tile with a fan of warm-to-cool strokes.
final class CampfireLogo: UIView {
    override init(frame: CGRect) { super.init(frame: frame); isOpaque = false; contentMode = .redraw }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let r = bounds
        let tile = UIBezierPath(roundedRect: r, cornerRadius: r.width * 0.2)
        ctx.saveGState()
        tile.addClip()
        let space = CGColorSpaceCreateDeviceRGB()
        let g = CGGradient(colorsSpace: space, colors: [UIColor(hex: 0x8A1C86).cgColor, UIColor(hex: 0x3C0A3E).cgColor] as CFArray,
                           locations: [0, 1])!
        ctx.drawRadialGradient(g, startCenter: CGPoint(x: r.width * 0.3, y: r.height * 0.15), startRadius: 0,
                               endCenter: CGPoint(x: r.midX, y: r.midY), endRadius: r.width * 0.9, options: .drawsAfterEndLocation)
        let colors: [UInt32] = [0xE8306B, 0xF0475A, 0xF26B3A, 0xF59A3B, 0xF7C55A, 0xC7D7E8, 0x58A6E0]
        ctx.setLineCap(.round)
        for (i, c) in colors.enumerated() {
            let t = CGFloat(i)
            UIColor(hex: c).setStroke()
            let p = UIBezierPath()
            p.move(to: CGPoint(x: r.width * (0.30 + t * 0.045), y: r.height * (0.30 + t * 0.012)))
            p.addCurve(to: CGPoint(x: r.width * (0.55 + t * 0.04), y: r.height * (0.78 - t * 0.02)),
                       controlPoint1: CGPoint(x: r.width * (0.36 + t * 0.05), y: r.height * 0.55),
                       controlPoint2: CGPoint(x: r.width * (0.45 + t * 0.04), y: r.height * 0.66))
            p.lineWidth = r.width * 0.045
            p.stroke()
        }
        ctx.restoreGState()
    }
}

/// Floating "jump to bottom" button shown when the room is not pinned.
final class JumpButton: CircleButton {
    init() {
        super.init(symbolName: "arrow.down", size: 18, weight: .bold)
        accessibilityLabel = "Jump to bottom"
        accessibilityIdentifier = "Jump to bottom"
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)
    }

    required init?(coder: NSCoder) { fatalError() }
}

/// Benchmark controls, shown with `-uvsBenchmark YES`.
final class DebugBar: UIView {
    static let height: CGFloat = 104
    let stateLabel = UILabel()
    let doneLabel = UILabel()
    private var buttons: [UIButton] = []
    var onTap: ((String, TimeInterval) -> Void)?

    static let titles = ["Reset", "Jump to 2500", "Load older", "Start stream", "Text size +", "Boost burst"]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Colors.bubble
        for t in DebugBar.titles {
            var config = UIButton.Configuration.filled()
            config.title = t
            config.baseBackgroundColor = Colors.text
            config.baseForegroundColor = Colors.background
            config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            config.cornerStyle = .medium
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
                var a = a
                a.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
                return a
            }
            let b = UIButton(configuration: config)
            b.accessibilityIdentifier = t
            b.accessibilityLabel = t
            b.addTarget(self, action: #selector(tapped(_:event:)), for: .touchUpInside)
            buttons.append(b)
            addSubview(b)
        }
        stateLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        stateLabel.textColor = Colors.text
        stateLabel.adjustsFontSizeToFitWidth = true
        stateLabel.minimumScaleFactor = 0.6
        stateLabel.accessibilityIdentifier = "debugState"
        addSubview(stateLabel)
        doneLabel.text = "Stream done"
        doneLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        doneLabel.textColor = Colors.text
        doneLabel.accessibilityIdentifier = "Stream done"
        doneLabel.isHidden = true
        addSubview(doneLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapped(_ sender: UIButton, event: UIEvent) {
        // Touch-up time of the tap (system uptime, same clock as CACurrentMediaTime).
        let t = event.allTouches?.first?.timestamp ?? event.timestamp
        onTap?(sender.configuration?.title ?? "", t)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let pad: CGFloat = 8
        let w = bounds.width - 2 * pad
        let bw = (w - 2 * 6) / 3
        for (i, b) in buttons.enumerated() {
            let row = i / 3, col = i % 3
            b.frame = CGRect(x: pad + CGFloat(col) * (bw + 6), y: 6 + CGFloat(row) * 34, width: bw, height: 30)
        }
        let doneW: CGFloat = 76
        stateLabel.frame = CGRect(x: pad, y: 74, width: w - doneW - 4, height: 22)
        doneLabel.frame = CGRect(x: bounds.width - pad - doneW, y: 74, width: doneW, height: 22)
    }
}
