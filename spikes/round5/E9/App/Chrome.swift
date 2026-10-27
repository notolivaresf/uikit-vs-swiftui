import UIKit

/// Round outlined button drawn like Campfire's (it does nothing in this build).
final class CircleButton: UIButton {
    private let ring = BorderedView()

    init(symbol: String?, image: UIImage? = nil, pointSize: CGFloat = 17, weight: UIImage.SymbolWeight = .semibold, label: String) {
        super.init(frame: .zero)
        ring.isUserInteractionEnabled = false
        ring.borderColor = Palette.borderDarker
        ring.backgroundColor = Palette.background
        addSubview(ring)
        let img = image ?? UIImage(systemName: symbol ?? "circle",
                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight))
        setImage(img, for: .normal)
        tintColor = Palette.text
        accessibilityLabel = label
        bringSubviewToFront(imageView!)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        ring.frame = bounds
        ring.layer.cornerRadius = bounds.height / 2
        sendSubviewToBack(ring)
    }
}

final class HeaderView: UIView {
    let roomButton = UIButton(type: .custom)
    let moreButton = CircleButton(symbol: "ellipsis", pointSize: 17, weight: .black, label: "Room options")
    let bellButton = CircleButton(symbol: nil, image: HeaderView.bellImage, label: "Notifications")
    let menuButton = CircleButton(symbol: "line.3.horizontal", pointSize: 21, weight: .semibold, label: "Menu")
    private let bellRing = BorderedView()
    private let fade = CAGradientLayer()
    var safeTop: CGFloat = 0 { didSet { setNeedsLayout() } }
    var safeLeft: CGFloat = 0 { didSet { setNeedsLayout() } }
    var safeRight: CGFloat = 0 { didSet { setNeedsLayout() } }

    static let bellImage: UIImage = {
        let bell = UIImage(systemName: "bell.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))!
        let warn = UIImage(systemName: "exclamationmark.triangle.fill",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold))!
        let size = CGSize(width: 24, height: 22)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            bell.draw(in: CGRect(x: 0, y: 1, width: 17, height: 17 * bell.size.height / bell.size.width))
            let tri = CGRect(x: 9.5, y: 7.5, width: 14, height: 14 * warn.size.height / warn.size.width)
            ctx.cgContext.setBlendMode(.clear)
            let gap = UIBezierPath()
            gap.move(to: CGPoint(x: tri.midX, y: tri.minY - 2.2))
            gap.addLine(to: CGPoint(x: tri.maxX + 2.2, y: tri.maxY + 1.2))
            gap.addLine(to: CGPoint(x: tri.minX - 2.2, y: tri.maxY + 1.2))
            gap.close()
            gap.fill()
            ctx.cgContext.setBlendMode(.normal)
            warn.draw(in: tri)
        }.withRenderingMode(.alwaysTemplate)
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(fade)
        roomButton.setTitle("General", for: .normal)
        roomButton.titleLabel?.font = .systemFont(ofSize: 16.5, weight: .bold)
        roomButton.setTitleColor(Palette.background, for: .normal)
        roomButton.backgroundColor = Palette.text
        roomButton.layer.cornerRadius = 9
        roomButton.layer.cornerCurve = .continuous
        bellRing.borderColor = Palette.alertOrange
        bellRing.layer.borderWidth = 3.2
        bellRing.backgroundColor = .clear
        bellRing.isUserInteractionEnabled = false
        [roomButton, moreButton, bellButton, menuButton].forEach(addSubview)
        addSubview(bellRing)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (v: HeaderView, _: UITraitCollection) in v.updateFade() }
        updateFade()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func updateFade() {
        let bg = Palette.background.resolvedColor(with: traitCollection)
        fade.colors = [bg.cgColor, bg.cgColor, bg.withAlphaComponent(0).cgColor]
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fade.frame = bounds
        let solid = (safeTop + 22) / max(bounds.height, 1)
        fade.locations = [0, NSNumber(value: Double(solid)), 1]
        CATransaction.commit()
        let y = safeTop + 8.1
        let x = safeLeft
        roomButton.frame = CGRect(x: x + 10.2, y: y, width: 96.5, height: 41.8)
        moreButton.frame = CGRect(x: x + 113.5, y: y + 0.4, width: 41, height: 41)
        bellButton.frame = CGRect(x: x + 160.9, y: y + 0.4, width: 41, height: 41)
        bellRing.frame = bellButton.frame.insetBy(dx: -3.1, dy: -3.1)
        bellRing.layer.cornerRadius = bellRing.bounds.height / 2
        menuButton.frame = CGRect(x: bounds.width - safeRight - 10.7 - 41, y: y + 0.4, width: 41, height: 41)
    }
}

final class ComposerBar: UIView {
    let searchButton = CircleButton(symbol: "magnifyingglass", pointSize: 19, weight: .bold, label: "Search")
    private let field = BorderedView()
    private let bubbleIcon = UIImageView(image: UIImage(systemName: "bubble.left",
                                                        withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .medium)))
    let attachButton = UIButton(type: .custom)
    let sendButton = UIButton(type: .custom)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Palette.background
        field.borderColor = Palette.borderDarker
        field.layer.borderWidth = 1.2
        field.backgroundColor = Palette.background
        bubbleIcon.tintColor = Palette.text
        attachButton.setImage(UIImage(systemName: "paperclip",
                                      withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .medium)), for: .normal)
        attachButton.tintColor = Palette.text
        attachButton.accessibilityLabel = "Attach"
        sendButton.setImage(UIImage(systemName: "arrow.up",
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .heavy)), for: .normal)
        sendButton.tintColor = Palette.background
        sendButton.backgroundColor = Palette.text
        sendButton.accessibilityLabel = "Send"
        field.accessibilityLabel = "Write a message"
        field.isAccessibilityElement = true
        [searchButton, field].forEach(addSubview)
        field.addSubview(bubbleIcon)
        field.addSubview(attachButton)
        field.addSubview(sendButton)
    }

    required init?(coder: NSCoder) { fatalError() }

    static let topPad: CGFloat = 23.6
    static let height: CGFloat = 41

    override func layoutSubviews() {
        super.layoutSubviews()
        let y = Self.topPad
        searchButton.frame = CGRect(x: 14.5, y: y, width: 41, height: 41)
        field.frame = CGRect(x: 67, y: y, width: bounds.width - 67 - 13.3, height: 41)
        field.layer.cornerRadius = 20.5
        bubbleIcon.frame = CGRect(x: 12, y: 8.5, width: 24, height: 24)
        bubbleIcon.contentMode = .center
        let w = field.bounds.width
        attachButton.frame = CGRect(x: w - 12.3 - 34 - 38, y: 3.5, width: 34, height: 34)
        sendButton.frame = CGRect(x: w - 3.6 - 34, y: 3.5, width: 34, height: 34)
        sendButton.layer.cornerRadius = 17
    }
}

/// Campfire's empty-room card, shown above the very first message.
final class WelcomeView: UICollectionReusableView {
    static let reuseID = "welcome"
    private let card = UIView()
    private let icon = UIImageView(image: WelcomeView.appIcon)
    private let globe = BorderedView()
    private let title = UILabel()
    private let body = UILabel()
    private let link = BorderedView()
    private let linkIcon = UIImageView(image: UIImage(systemName: "person.fill.badge.plus"))
    private let linkLabel = UILabel()
    private let buttons = [
        CircleButton(symbol: "qrcode.viewfinder", pointSize: 19, weight: .medium, label: "QR code"),
        CircleButton(symbol: "doc.on.clipboard", pointSize: 18, weight: .medium, label: "Copy link"),
        CircleButton(symbol: "square.and.arrow.up", pointSize: 18, weight: .medium, label: "Share link"),
    ]

    static let appIcon: UIImage = {
        let s: CGFloat = 69
        return UIGraphicsImageRenderer(size: CGSize(width: s, height: s)).image { ctx in
            let c = ctx.cgContext
            let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s), cornerRadius: 15)
            path.addClip()
            let space = CGColorSpaceCreateDeviceRGB()
            let g = CGGradient(colorsSpace: space, colors: [Palette.rgb(0x7A1A72).cgColor, Palette.rgb(0x2E0626).cgColor] as CFArray,
                               locations: [0, 1])!
            c.drawRadialGradient(g, startCenter: CGPoint(x: s * 0.45, y: s * 0.3), startRadius: 0,
                                 endCenter: CGPoint(x: s * 0.5, y: s * 0.5), endRadius: s * 0.75, options: .drawsAfterEndLocation)
            let colors: [UInt32] = [0xFF2D7A, 0xFF3D3D, 0xFF7A1A, 0xFFB31A, 0xFFE07A, 0x7AD3FF, 0xFFFFFF, 0xFF5C8A]
            c.setLineCap(.round)
            c.setLineWidth(2.6)
            for i in 0..<14 {
                let t = CGFloat(i) / 13
                Palette.rgb(colors[i % colors.count]).setStroke()
                let x0 = s * (0.26 + 0.42 * t), y0 = s * (0.2 + 0.12 * t)
                c.move(to: CGPoint(x: x0, y: y0))
                c.addLine(to: CGPoint(x: x0 - s * 0.16, y: y0 + s * 0.4))
                c.strokePath()
            }
        }
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        card.backgroundColor = Palette.bubble
        card.layer.cornerRadius = 14
        card.layer.cornerCurve = .continuous
        addSubview(card)
        addSubview(icon)
        globe.borderColor = Palette.borderDarker
        globe.backgroundColor = Palette.background
        let globeLabel = UILabel()
        globeLabel.text = "🌎"
        globeLabel.font = .systemFont(ofSize: 15)
        globeLabel.textAlignment = .center
        globeLabel.tag = 1
        globe.addSubview(globeLabel)
        card.addSubview(globe)
        title.text = "Welcome to Campfire"
        title.font = .systemFont(ofSize: 16, weight: .bold)
        title.textAlignment = .center
        title.textColor = Palette.text
        body.text = "To invite people to chat, share the join link below."
        body.font = .systemFont(ofSize: 16)
        body.numberOfLines = 0
        body.textAlignment = .center
        body.textColor = Palette.text
        let p = NSMutableParagraphStyle()
        p.minimumLineHeight = 22.4
        p.maximumLineHeight = 22.4
        p.alignment = .center
        body.attributedText = NSAttributedString(string: body.text!, attributes: [
            .font: UIFont.systemFont(ofSize: 16), .paragraphStyle: p, .foregroundColor: Palette.text,
        ])
        card.addSubview(title)
        card.addSubview(body)
        link.borderColor = Palette.borderDarker
        link.backgroundColor = Palette.background
        link.layer.cornerRadius = 8
        linkIcon.tintColor = Palette.text
        linkIcon.contentMode = .scaleAspectFit
        linkLabel.text = "http://127.0.0.1:3055/join/GwHG-HbZN"
        linkLabel.font = .systemFont(ofSize: 16)
        linkLabel.textColor = Palette.text
        link.addSubview(linkIcon)
        link.addSubview(linkLabel)
        card.addSubview(link)
        buttons.forEach(card.addSubview)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let W = bounds.width
        card.frame = CGRect(x: 14, y: 107, width: W - 28, height: 269)
        icon.frame = CGRect(x: (W - 68.6) / 2, y: 83.3, width: 68.6, height: 68.6)
        globe.frame = CGRect(x: 16, y: 16.5, width: 41.3, height: 41.3)
        globe.layer.cornerRadius = 20.65
        globe.viewWithTag(1)?.frame = globe.bounds
        let cw = card.bounds.width
        title.frame = CGRect(x: 16, y: 77, width: cw - 32, height: 22.4)
        body.frame = CGRect(x: 16, y: 99.4 - 1.65, width: cw - 32, height: 44.8)
        link.frame = CGRect(x: 15.4, y: 161, width: cw - 30.8, height: 39)
        linkIcon.frame = CGRect(x: 14, y: 9.5, width: 18, height: 20)
        linkLabel.frame = CGRect(x: 42.3, y: 0, width: link.bounds.width - 50, height: 39)
        let centers: [CGFloat] = [-57.5, -4.9, 48]
        for (b, dx) in zip(buttons, centers) {
            b.frame = CGRect(x: cw / 2 + dx - 20.8, y: 217, width: 41.6, height: 41.6)
        }
    }
}

/// Shown with `-uvsBenchmark YES`.
final class DebugBar: UIView {
    let buttons: [UIButton]
    let stateLabel = UILabel()
    let streamDoneLabel = UILabel()
    static let titles = ["Reset", "Jump to 2500", "Load older", "Start stream", "Text size +", "Boost burst"]

    override init(frame: CGRect) {
        buttons = Self.titles.map { t in
            var cfg = UIButton.Configuration.gray()
            cfg.title = t
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
            cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
                var a = a
                a.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
                return a
            }
            let b = UIButton(configuration: cfg)
            b.accessibilityIdentifier = t
            return b
        }
        super.init(frame: frame)
        backgroundColor = Palette.background
        buttons.forEach(addSubview)
        stateLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        stateLabel.textColor = Palette.text
        stateLabel.numberOfLines = 2
        stateLabel.accessibilityIdentifier = "state"
        streamDoneLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        streamDoneLabel.textColor = Palette.text
        streamDoneLabel.text = "Stream done"
        streamDoneLabel.isHidden = true
        streamDoneLabel.accessibilityIdentifier = "streamDone"
        addSubview(stateLabel)
        addSubview(streamDoneLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// One row of buttons when there is room (landscape), two otherwise; the state label below.
    static func height(forWidth w: CGFloat) -> CGFloat { w > 600 ? 30 + 4 + 30 + 2 : 2 * 30 + 4 + 30 + 4 }

    override func layoutSubviews() {
        super.layoutSubviews()
        let pad: CGFloat = 8, gap: CGFloat = 4
        let perRow = bounds.width > 600 ? 6 : 3
        let w = (bounds.width - 2 * pad - CGFloat(perRow - 1) * gap) / CGFloat(perRow)
        for (i, b) in buttons.enumerated() {
            b.frame = CGRect(x: pad + CGFloat(i % perRow) * (w + gap), y: CGFloat(i / perRow) * (30 + gap), width: w, height: 30)
        }
        let labelY = CGFloat((buttons.count + perRow - 1) / perRow) * (30 + gap)
        streamDoneLabel.sizeToFit()
        let sw = streamDoneLabel.bounds.width
        streamDoneLabel.frame = CGRect(x: bounds.width - pad - sw, y: labelY, width: sw, height: 30)
        stateLabel.frame = CGRect(x: pad, y: labelY, width: bounds.width - 3 * pad - sw, height: 30)
    }
}
