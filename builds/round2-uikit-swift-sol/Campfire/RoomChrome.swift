import UIKit

@MainActor
final class RoomHeader: UIView {
    private let title = UIButton(type: .custom)
    private let more = UIButton(type: .custom)
    private let bell = UIButton(type: .custom)
    private let menu = UIButton(type: .custom)
    private let warning = UIImageView()
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.background
        title.setTitle("General", for: .normal)
        title.titleLabel?.font = Theme.font(16, weight: .bold)
        title.setTitleColor(Theme.background, for: .normal)
        title.backgroundColor = Theme.text; title.layer.cornerRadius = 8
        for (button, symbol, label) in [(more,"ellipsis","Room options"),(bell,"bell.fill","Notifications"),(menu,"line.3.horizontal","Menu")] {
            button.setImage(Theme.symbol(symbol, size: 23, weight: .bold), for: .normal)
            button.tintColor = Theme.text; button.backgroundColor = Theme.background
            button.layer.cornerRadius = 21; button.layer.borderWidth = 1
            button.accessibilityLabel = label
            addSubview(button)
        }
        bell.layer.borderWidth = 2.5
        warning.image = Theme.symbol("exclamationmark.triangle.fill", size: 16)
        warning.tintColor = Theme.text; warning.backgroundColor = Theme.background
        bell.addSubview(warning)
        title.accessibilityLabel = "General chat room"
        addSubview(title)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: RoomHeader, _: UITraitCollection) in self.updateBorders() }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    private func updateBorders() {
        for button in [more,menu] { button.layer.borderColor = Theme.outline.resolvedColor(with: traitCollection).cgColor }
        bell.layer.borderColor = UIColor.systemOrange.cgColor
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        title.frame = CGRect(x: 10, y: 8, width: 97, height: 42)
        more.frame = CGRect(x: 113.5, y: 8, width: 42, height: 42)
        bell.frame = CGRect(x: 158, y: 6, width: 46, height: 46)
        warning.frame = CGRect(x: 23, y: 22, width: 15, height: 15)
        menu.frame = CGRect(x: bounds.width - 53, y: 8, width: 42, height: 42)
        updateBorders()
    }
}

@MainActor
final class ComposerView: UIView {
    private let search = UIButton(type: .custom)
    private let capsule = UIView()
    private let chat = UIImageView()
    private let clip = UIButton(type: .custom)
    private let send = UIButton(type: .custom)
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.background
        search.setImage(Theme.symbol("magnifyingglass", size: 25, weight: .bold), for: .normal)
        search.tintColor = Theme.text; search.layer.cornerRadius = 21; search.layer.borderWidth = 1
        search.accessibilityLabel = "Search"
        capsule.layer.cornerRadius = 21; capsule.layer.borderWidth = 1
        chat.image = Theme.symbol("bubble", size: 24, weight: .regular); chat.tintColor = Theme.text
        clip.setImage(Theme.symbol("paperclip", size: 23, weight: .semibold), for: .normal); clip.tintColor = Theme.text
        clip.accessibilityLabel = "Attach file"
        send.setImage(Theme.symbol("arrow.up", size: 23, weight: .bold), for: .normal)
        send.tintColor = Theme.background; send.backgroundColor = Theme.text; send.layer.cornerRadius = 17
        send.accessibilityLabel = "Send message"
        capsule.accessibilityLabel = "Message composer"
        addSubview(search); addSubview(capsule)
        for v in [chat, clip, send] { capsule.addSubview(v) }
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: ComposerView, _: UITraitCollection) in self.updateBorders() }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    private func updateBorders() {
        for v in [search, capsule] { v.layer.borderColor = Theme.outline.resolvedColor(with: traitCollection).cgColor }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        search.frame = CGRect(x: 14, y: 24, width: 42, height: 42)
        capsule.frame = CGRect(x: 66, y: 24, width: bounds.width - 80, height: 42)
        chat.frame = CGRect(x: 13, y: 11, width: 23, height: 22)
        send.frame = CGRect(x: capsule.bounds.width - 39, y: 4, width: 34, height: 34)
        clip.frame = CGRect(x: capsule.bounds.width - 80, y: 0, width: 31, height: 42)
        updateBorders()
    }
}

@MainActor
final class CampfireMark: UIView {
    override func draw(_ rect: CGRect) {
        guard let c = UIGraphicsGetCurrentContext() else { return }
        let path = UIBezierPath(roundedRect: rect, cornerRadius: rect.width * 0.17)
        c.addPath(path.cgPath); c.clip()
        let colors = [UIColor(hex: 0x761D88).cgColor, UIColor(hex: 0x210824).cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0,1]) {
            c.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: rect.width, y: rect.height), options: [])
        }
        let shades: [UInt32] = [0xEA168C,0xF42B4E,0xF46E1E,0xFFD22B,0xF3CF3C,0xE4F3DF,0x68D1EC,0x7398CE]
        c.setLineCap(.round)
        for i in 0..<15 {
            let t = CGFloat(i) / 14
            let x = rect.width * (0.27 + t * 0.43)
            let y = rect.height * (0.25 + abs(t - 0.45) * 0.25)
            c.setStrokeColor(UIColor(hex: shades[min(7, i / 2)]).cgColor)
            c.setLineWidth(rect.width * 0.026)
            c.move(to: CGPoint(x: x, y: y))
            c.addCurve(to: CGPoint(x: x + rect.width * 0.06, y: rect.height * (0.78 - t * 0.15)),
                       control1: CGPoint(x: x - rect.width * 0.12, y: rect.height * 0.48),
                       control2: CGPoint(x: x + rect.width * 0.15, y: rect.height * 0.65))
            c.strokePath()
        }
    }
}

@MainActor
final class WelcomeCell: UICollectionViewCell {
    private let card = UIView()
    private let mark = CampfireMark()
    private let globe = UILabel()
    private let title = UILabel()
    private let subtitle = UILabel()
    private let link = UILabel()
    private var actions: [UIButton] = []
    override init(frame: CGRect) {
        super.init(frame: frame)
        card.backgroundColor = Theme.bubble; card.layer.cornerRadius = 10.56
        contentView.addSubview(card); contentView.addSubview(mark)
        globe.text = "🌎"; globe.textAlignment = .center; globe.font = Theme.font(16)
        globe.backgroundColor = Theme.background; globe.layer.cornerRadius = 21; globe.layer.borderWidth = 1; globe.clipsToBounds = true
        title.text = "Welcome to Campfire"; title.font = Theme.font(16, weight: .bold); title.textAlignment = .center; title.textColor = Theme.text
        subtitle.text = "To invite people to chat, share the join link\nbelow."
        subtitle.font = Theme.font(16); subtitle.numberOfLines = 0; subtitle.textAlignment = .center; subtitle.textColor = Theme.text
        link.text = "  ♟  http://127.0.0.1:3055/join/GwHG-HbZN"
        link.font = Theme.font(16); link.textColor = Theme.text; link.backgroundColor = Theme.background
        link.layer.cornerRadius = 8; link.layer.borderWidth = 1; link.clipsToBounds = true
        link.adjustsFontSizeToFitWidth = true; link.minimumScaleFactor = 0.65
        for v in [globe,title,subtitle,link] { card.addSubview(v) }
        for icon in ["qrcode.viewfinder","document.on.clipboard","square.and.arrow.up"] {
            let b = UIButton(type: .custom); b.setImage(Theme.symbol(icon, size: 21, weight: .semibold), for: .normal)
            b.tintColor = Theme.text; b.backgroundColor = Theme.background; b.layer.cornerRadius = 21; b.layer.borderWidth = 1
            card.addSubview(b); actions.append(b)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    var scale: CGFloat = 1
    static func cardHeight(width: CGFloat, scale: CGFloat) -> CGFloat {
        let subtitle = Theme.attributed("To invite people to chat, share the join link\nbelow.", size: 16, line: 22.4, scale: scale)
        let textHeight = max(48, MessageLayout.measure(subtitle, width: width - 52).height)
        return 78 + 22.4 * scale - 0.4 + textHeight + 12 + 40 * scale + 16 + 42 + 11
    }
    static func height(width: CGFloat, scale: CGFloat) -> CGFloat { 129 + cardHeight(width: width, scale: scale) }
    override func layoutSubviews() {
        super.layoutSubviews()
        card.frame = CGRect(x: 14, y: 107, width: bounds.width - 28, height: Self.cardHeight(width: bounds.width, scale: scale))
        mark.frame = CGRect(x: bounds.midX - 34.5, y: 83, width: 69, height: 69)
        globe.frame = CGRect(x: 16, y: 16, width: 42, height: 42)
        title.font = Theme.font(16, weight: .bold, scale: scale)
        title.frame = CGRect(x: 10, y: 78, width: card.bounds.width - 20, height: 22.4 * scale)
        subtitle.attributedText = Theme.attributed("To invite people to chat, share the join link\nbelow.", size: 16, line: 22.4, scale: scale)
        let textHeight = max(48, MessageLayout.measure(subtitle.attributedText!, width: card.bounds.width - 24).height)
        subtitle.frame = CGRect(x: 12, y: title.frame.maxY - 0.4, width: card.bounds.width - 24, height: textHeight)
        link.font = Theme.font(16, scale: scale)
        link.frame = CGRect(x: 15.5, y: subtitle.frame.maxY + 12, width: card.bounds.width - 31, height: 40 * scale)
        for (i, b) in actions.enumerated() {
            b.frame = CGRect(x: card.bounds.midX - 78 + CGFloat(i) * 52, y: link.frame.maxY + 16, width: 42, height: 42)
            b.layer.borderColor = Theme.outline.resolvedColor(with: traitCollection).cgColor
        }
        for v in [globe,link] { v.layer.borderColor = Theme.outline.resolvedColor(with: traitCollection).cgColor }
    }
}
