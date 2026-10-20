import UIKit

/// "Welcome to Campfire" card shown above the very first message of the room.
final class WelcomeCell: UICollectionViewCell {
    static let reuseID = "welcome"
    /// Item height and the gap to the first message below it.
    static let height: CGFloat = 378
    static let gapAfter: CGFloat = 23.5

    private let card = UIView()
    private let logo = CampfireLogoView()
    private let globe = StrokeView()
    private let globeLabel = UILabel()
    private let title = UILabel()
    private let body = UILabel()
    private let linkField = StrokeView()
    private let linkIcon = UIImageView(image: UIImage(systemName: "person.fill.badge.plus",
                                                      withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)))
    private let linkLabel = UILabel()
    private let buttons: [StrokeView] = (0..<3).map { _ in StrokeView() }
    private let symbols = ["qrcode", "list.clipboard", "square.and.arrow.up"]

    override init(frame: CGRect) {
        super.init(frame: frame)
        accessibilityIdentifier = "welcome"
        card.backgroundColor = Palette.bubble
        card.layer.cornerRadius = Metrics.bubbleRadius
        contentView.addSubview(card)
        card.addSubview(globe)
        contentView.addSubview(logo)
        globe.backgroundColor = Palette.background
        globe.strokeColor = Palette.borderDarker
        globeLabel.text = "🌍"
        globeLabel.font = .systemFont(ofSize: 17)
        globeLabel.textAlignment = .center
        globe.addSubview(globeLabel)

        title.text = "Welcome to Campfire"
        title.font = .systemFont(ofSize: 16, weight: .bold)
        title.textColor = Palette.text
        title.textAlignment = .center
        body.text = "To invite people to chat, share the join link below."
        body.font = .systemFont(ofSize: 16)
        body.textColor = Palette.text
        body.textAlignment = .center
        body.numberOfLines = 0
        let p = NSMutableParagraphStyle()
        p.minimumLineHeight = 22.4
        p.maximumLineHeight = 22.4
        p.alignment = .center
        body.attributedText = NSAttributedString(string: body.text!, attributes: [
            .font: UIFont.systemFont(ofSize: 16), .foregroundColor: Palette.text, .paragraphStyle: p,
        ])
        card.addSubview(title)
        card.addSubview(body)

        linkField.backgroundColor = Palette.background
        linkField.strokeColor = Palette.borderDarker
        linkField.layer.cornerRadius = 8
        linkIcon.tintColor = Palette.text
        linkLabel.text = "http://127.0.0.1:3055/join/GwHG-HbZN"
        linkLabel.font = .systemFont(ofSize: 16)
        linkLabel.textColor = Palette.text
        linkLabel.lineBreakMode = .byTruncatingTail
        linkField.addSubview(linkIcon)
        linkField.addSubview(linkLabel)
        card.addSubview(linkField)

        for (button, name) in zip(buttons, symbols) {
            button.backgroundColor = Palette.background
            button.strokeColor = Palette.borderDarker
            button.layer.cornerRadius = 21
            let icon = UIImageView(image: UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .medium)))
            icon.tintColor = Palette.text
            icon.tag = 1
            button.addSubview(icon)
            card.addSubview(button)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        layoutAttributes
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        // Positions measured from room-top.png (content top is the header's bottom edge, 58 pt).
        card.frame = CGRect(x: Metrics.screenPaddingX, y: 109, width: w - 2 * Metrics.screenPaddingX, height: 269)
        logo.frame = CGRect(x: (w - 68) / 2, y: 85, width: 68, height: 68)
        globe.frame = CGRect(x: 16, y: 16.5, width: 42, height: 42)
        globe.layer.cornerRadius = 21
        globeLabel.frame = globe.bounds
        let cw = card.bounds.width
        title.frame = CGRect(x: 24, y: 77.8, width: cw - 48, height: 22.4)
        body.frame = CGRect(x: 24, y: 100.2, width: cw - 48, height: 44.8)
        linkField.frame = CGRect(x: 15, y: 160, width: cw - 30, height: 40)
        linkIcon.sizeToFit()
        linkIcon.center = CGPoint(x: 23, y: 20)
        linkLabel.frame = CGRect(x: 43.67, y: 0, width: linkField.bounds.width - 43.67 - 12, height: 40)
        let centerX = cw / 2 - 4.5
        for (i, button) in buttons.enumerated() {
            button.frame = CGRect(x: centerX + CGFloat(i - 1) * 53 - 21, y: 217, width: 42, height: 42)
            if let icon = button.viewWithTag(1) {
                icon.sizeToFit()
                icon.center = CGPoint(x: 21, y: 21)
            }
        }
    }
}

/// Campfire's app icon: purple tile with bright flame strokes.
final class CampfireLogoView: UIView {
    private let gradient = CAGradientLayer()
    private let strokes = CAGradientLayer()
    private let strokeMask = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradient.type = .radial
        gradient.colors = [UIColor(hex: 0x7A2286).cgColor, UIColor(hex: 0x2B0A30).cgColor]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.3)
        gradient.endPoint = CGPoint(x: 1.2, y: 1.2)
        layer.addSublayer(gradient)
        strokes.colors = [UIColor(hex: 0xE30673).cgColor, UIColor(hex: 0xF23C39).cgColor,
                          UIColor(hex: 0xF5BA75).cgColor, UIColor(hex: 0xF1BF0A).cgColor, UIColor(hex: 0x4FA3F7).cgColor]
        strokes.startPoint = CGPoint(x: 0.2, y: 0.2)
        strokes.endPoint = CGPoint(x: 0.8, y: 0.85)
        strokeMask.fillColor = UIColor.clear.cgColor
        strokeMask.strokeColor = UIColor.black.cgColor
        strokeMask.lineWidth = 2.6
        strokeMask.lineCap = .round
        strokes.mask = strokeMask
        layer.addSublayer(strokes)
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        strokes.frame = bounds
        let s = bounds.width / 68
        let path = UIBezierPath()
        for i in 0..<8 {
            let t = CGFloat(i)
            let start = CGPoint(x: (24 + t * 3.2) * s, y: (18 + t * 1.2) * s)
            let end = CGPoint(x: (40 + t * 2.6) * s, y: (46 + t * 0.6) * s)
            path.move(to: start)
            path.addQuadCurve(to: end, controlPoint: CGPoint(x: (24 + t * 3.2) * s, y: (40 + t * 0.5) * s))
        }
        strokeMask.path = path.cgPath
    }
}
