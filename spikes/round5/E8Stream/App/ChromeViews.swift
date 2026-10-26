import UIKit

private func symbolView(_ name: String, _ size: CGFloat, _ weight: UIImage.SymbolWeight, tint: UIColor = Theme.text) -> UIImageView {
    let v = UIImageView(image: UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: weight)))
    v.tintColor = tint
    v.contentMode = .center
    return v
}

/// A round outlined button that does nothing.
final class CircleButton: UIView {
    let icon: UIView
    var borderColor: UIColor = Theme.borderDarker { didSet { updateColors() } }

    init(icon: UIView, label: String) {
        self.icon = icon
        super.init(frame: .zero)
        backgroundColor = Theme.background
        layer.borderWidth = 1
        addSubview(icon)
        isAccessibilityElement = true
        accessibilityLabel = label
        accessibilityTraits = .button
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (v: CircleButton, _) in v.updateColors() }
        updateColors()
    }
    required init?(coder: NSCoder) { fatalError() }

    func updateColors() { layer.borderColor = borderColor.resolvedColor(with: traitCollection).cgColor }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        icon.frame = bounds
    }
}

/// Room header: name pill, room menu, notifications, side menu; fades the list out beneath it.
final class HeaderView: UIView {
    private let fade = CAGradientLayer()
    private let roomPill = UILabel()
    private let more = CircleButton(icon: symbolView("ellipsis", 21, .black), label: "Room settings")
    private let bell: CircleButton
    private let ring = UIView()
    private let menu = CircleButton(icon: symbolView("line.3.horizontal", 21, .heavy), label: "Menu")

    override init(frame: CGRect) {
        let bellIcon = UIView()
        let b = symbolView("bell.fill", 16, .regular)
        let gap = symbolView("triangle.fill", 17, .black, tint: Theme.background)
        let warn = symbolView("exclamationmark.triangle.fill", 13, .bold)
        bellIcon.addSubview(b)
        bellIcon.addSubview(gap)
        bellIcon.addSubview(warn)
        b.tag = 1; warn.tag = 2; gap.tag = 3
        bell = CircleButton(icon: bellIcon, label: "Notifications")
        super.init(frame: frame)
        layer.addSublayer(fade)
        roomPill.text = "General"
        roomPill.font = .systemFont(ofSize: 17, weight: .heavy)
        roomPill.textAlignment = .center
        roomPill.textColor = Theme.invertedText
        roomPill.backgroundColor = Theme.inverted
        roomPill.layer.cornerRadius = 9
        roomPill.layer.masksToBounds = true
        roomPill.accessibilityTraits = .header
        addSubview(roomPill)
        addSubview(more)
        ring.layer.borderWidth = 3
        ring.layer.borderColor = Theme.alertOrange.cgColor
        ring.isUserInteractionEnabled = false
        addSubview(bell)
        addSubview(ring)
        addSubview(menu)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (v: HeaderView, _) in v.updateColors() }
        updateColors()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func updateColors() {
        let bg = Theme.background.resolvedColor(with: traitCollection)
        fade.colors = [bg.cgColor, bg.cgColor, bg.withAlphaComponent(0).cgColor]
        fade.locations = [0, 0.19, 1]
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        fade.frame = bounds
        CATransaction.commit()
        let x0 = safeAreaInsets.left, w = bounds.width - safeAreaInsets.right
        roomPill.frame = CGRect(x: x0 + 10, y: 8, width: 97, height: 42)
        more.frame = CGRect(x: x0 + 113, y: 8, width: 42, height: 42)
        bell.frame = CGRect(x: x0 + 160, y: 8, width: 42, height: 42)
        ring.frame = bell.frame.insetBy(dx: -3, dy: -3)
        ring.layer.cornerRadius = ring.bounds.width / 2
        if let b = bell.icon.viewWithTag(1), let warn = bell.icon.viewWithTag(2) {
            b.frame = CGRect(x: 8, y: 9, width: 22, height: 22)
            warn.frame = CGRect(x: 17.5, y: 16, width: 16, height: 16)
            bell.icon.viewWithTag(3)?.frame = warn.frame.insetBy(dx: -1, dy: -1.5).offsetBy(dx: 0, dy: 0.5)
        }
        menu.frame = CGRect(x: w - 53, y: 8, width: 42, height: 42)
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        subviews.contains { !$0.isHidden && $0.isUserInteractionEnabled && $0.frame.contains(point) }
    }
}

/// Search button and the message field with attach and send. Drawn only.
final class ComposerView: UIView {
    private let search = CircleButton(icon: symbolView("magnifyingglass", 19, .bold), label: "Search")
    private let field = UIView()
    private let chat = symbolView("message", 18, .regular)
    private let clip = symbolView("paperclip", 18, .regular)
    private let send = UIView()
    private let sendIcon = symbolView("arrow.up", 17, .heavy, tint: Theme.invertedText)

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(search)
        field.backgroundColor = Theme.background
        field.layer.borderWidth = 1
        field.isAccessibilityElement = true
        field.accessibilityLabel = "Message"
        addSubview(field)
        field.addSubview(chat)
        field.addSubview(clip)
        send.backgroundColor = Theme.inverted
        send.isAccessibilityElement = true
        send.accessibilityLabel = "Send"
        send.accessibilityTraits = .button
        send.addSubview(sendIcon)
        field.addSubview(send)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (v: ComposerView, _) in v.updateColors() }
        updateColors()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func updateColors() {
        field.layer.borderColor = Theme.borderDarker.resolvedColor(with: traitCollection).cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let h = bounds.height
        search.frame = CGRect(x: 14, y: 0, width: h, height: h)
        field.frame = CGRect(x: 66, y: 0, width: bounds.width - 66 - 14, height: h)
        field.layer.cornerRadius = h / 2
        chat.frame = CGRect(x: 12, y: 0, width: 26, height: h)
        send.frame = CGRect(x: field.bounds.width - 4 - 34, y: 4, width: 34, height: 34)
        send.layer.cornerRadius = 17
        sendIcon.frame = send.bounds
        clip.frame = CGRect(x: send.frame.minX - 41, y: 0, width: 26, height: h)
    }
}
