import UIKit

/// Three grey dots: the message menu button (drawn, does nothing).
final class DotsView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        isUserInteractionEnabled = false
        contentMode = .redraw
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (v: DotsView, _) in v.setNeedsDisplay() }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        Theme.dimText.setFill()
        let d: CGFloat = 4.4, gap: CGFloat = (bounds.width - 3 * d) / 2
        for i in 0..<3 {
            UIBezierPath(ovalIn: CGRect(x: CGFloat(i) * (d + gap), y: (bounds.height - d) / 2, width: d, height: d)).fill()
        }
    }
}

/// Round avatar with a white initial and a ring in the page colour (it overlaps the bubble edge).
final class AvatarView: UIView {
    let label = UILabel()
    var ring: CGFloat = Metrics.avatarRing { didSet { setNeedsLayout() } }
    private let circle = UIView()

    init(fontSize: CGFloat) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = Theme.background
        addSubview(circle)
        label.font = .systemFont(ofSize: fontSize, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        circle.addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError() }

    /// `frame` is the coloured circle; the ring is drawn outside it.
    func place(circle r: CGRect, color: UIColor, initial: String) {
        frame = r.insetBy(dx: -ring, dy: -ring)
        circle.backgroundColor = color
        if label.text != initial { label.text = initial }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
        circle.frame = bounds.insetBy(dx: ring, dy: ring)
        circle.layer.cornerRadius = circle.bounds.width / 2
        label.frame = circle.bounds
    }
}

final class BoostPillView: UIView {
    let avatar = AvatarView(fontSize: 11)
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.pillBackground
        layer.borderWidth = 1
        avatar.ring = 0
        addSubview(avatar)
        addSubview(label)
        isUserInteractionEnabled = false
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (v: BoostPillView, _) in v.updateColors() }
        updateColors()
    }
    required init?(coder: NSCoder) { fatalError() }

    func updateColors() { layer.borderColor = Theme.borderDark.resolvedColor(with: traitCollection).cgColor }

    func configure(_ p: PillGeo) {
        frame = p.frame
        layer.cornerRadius = p.frame.height / 2
        let a = Metrics.pillAvatar
        avatar.place(circle: CGRect(x: 2.6, y: (p.frame.height - a) / 2, width: a, height: a), color: p.avatarColor, initial: p.initial)
        label.attributedText = p.content
        label.frame = p.contentFrame
    }
}

/// The round "add boost" button: an outlined smiley with a plus, drawn by hand.
final class AddBoostView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.pillBackground
        layer.borderWidth = 1
        clipsToBounds = true
        contentMode = .redraw
        isAccessibilityElement = true
        accessibilityLabel = "Add boost"
        accessibilityTraits = .button
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (v: AddBoostView, _) in
            v.updateColors()
            v.setNeedsDisplay()
        }
        updateColors()
    }
    required init?(coder: NSCoder) { fatalError() }

    func updateColors() { layer.borderColor = Theme.borderDark.resolvedColor(with: traitCollection).cgColor }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    override func draw(_ rect: CGRect) {
        let c = CGPoint(x: bounds.midX - 0.5, y: bounds.midY - 0.5)
        let r: CGFloat = 7.2
        Theme.text.setStroke()
        Theme.text.setFill()
        let face = UIBezierPath(arcCenter: c, radius: r, startAngle: 0.5, endAngle: 0.5 + 2 * .pi - 1.0, clockwise: true)
        face.lineWidth = 1.6
        face.stroke()
        for dx in [-2.6, 2.6] {
            UIBezierPath(ovalIn: CGRect(x: c.x + dx - 1.1, y: c.y - 3.2, width: 2.2, height: 2.2)).fill()
        }
        let smile = UIBezierPath(arcCenter: CGPoint(x: c.x, y: c.y + 0.6), radius: 3.6, startAngle: 0.35, endAngle: .pi - 0.35, clockwise: true)
        smile.lineWidth = 1.5
        smile.lineCapStyle = .round
        smile.stroke()
        let p = CGPoint(x: c.x + r - 0.6, y: c.y + r - 0.6)
        let plus = UIBezierPath()
        plus.move(to: CGPoint(x: p.x - 3, y: p.y)); plus.addLine(to: CGPoint(x: p.x + 3, y: p.y))
        plus.move(to: CGPoint(x: p.x, y: p.y - 3)); plus.addLine(to: CGPoint(x: p.x, y: p.y + 3))
        plus.lineWidth = 1.6
        plus.lineCapStyle = .round
        plus.stroke()
    }
}

protocol MessageCellDelegate: AnyObject {
    func replyAction() -> UIAction
}

final class MessageCell: UICollectionViewCell, UITextViewDelegate, UIContextMenuInteractionDelegate {
    static let reuseID = "message"

    weak var delegate: MessageCellDelegate?
    private(set) var geo: RowGeo?

    private let separatorLine = UIView()
    private let separatorPill = UILabel()
    private let bubble = UIView()
    private let avatar = AvatarView(fontSize: 16)
    private let nameLabel = UILabel()
    private let timeLabel = UILabel()
    private let dots = DotsView()
    private let bodyView = MessageCell.makeTextView()

    // Rare parts, created the first time a row needs them.
    private var codeBox: UIView?
    private var codeView: UITextView?
    private var imageView: UIView?
    private var fileViews: (icon: UIImageView, name: UILabel, download: UIImageView, share: UIImageView)?
    private var pillViews: [BoostPillView] = []
    private var addBoostView: AddBoostView?

    static func makeTextView() -> UITextView {
        let t = UITextView(usingTextLayoutManager: true)
        t.isEditable = false
        t.isSelectable = true
        t.isScrollEnabled = false
        t.textContainerInset = .zero
        t.textContainer.lineFragmentPadding = 0
        t.backgroundColor = .clear
        t.dataDetectorTypes = []
        t.textDragInteraction?.isEnabled = false
        return t
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        separatorLine.backgroundColor = Theme.bubble
        separatorPill.backgroundColor = Theme.bubble
        separatorPill.textAlignment = .center
        separatorPill.layer.masksToBounds = true
        separatorLine.isHidden = true
        separatorPill.isHidden = true
        contentView.addSubview(separatorLine)
        contentView.addSubview(separatorPill)

        bubble.layer.cornerRadius = Metrics.bubbleRadius
        bubble.layer.cornerCurve = .circular
        contentView.addSubview(bubble)
        bubble.addInteraction(UIContextMenuInteraction(delegate: self))

        contentView.addSubview(nameLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(dots)
        bodyView.delegate = self
        contentView.addSubview(bodyView)
        contentView.addSubview(avatar)
        nameLabel.isUserInteractionEnabled = false
        timeLabel.isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(_ g: RowGeo) {
        geo = g
        if let sep = g.separatorText {
            separatorLine.isHidden = false
            separatorPill.isHidden = false
            separatorLine.frame = g.separatorLine
            separatorPill.frame = g.separatorPill
            separatorPill.layer.cornerRadius = g.separatorPill.height / 2
            separatorPill.attributedText = sep
        } else {
            separatorLine.isHidden = true
            separatorPill.isHidden = true
        }

        bubble.frame = g.bubble
        switch g.style {
        case .normal: bubble.backgroundColor = Theme.bubble
        case .mention: bubble.backgroundColor = Theme.mentionBubble
        case .none: bubble.backgroundColor = .clear
        }

        if let a = g.avatar {
            avatar.isHidden = false
            avatar.place(circle: a, color: g.avatarColor, initial: g.initial)
        } else {
            avatar.isHidden = true
        }

        if let n = g.name {
            nameLabel.isHidden = false
            nameLabel.attributedText = n
            nameLabel.frame = g.nameFrame
        } else {
            nameLabel.isHidden = true
        }
        timeLabel.attributedText = g.time
        timeLabel.frame = g.timeFrame
        dots.frame = g.dots

        if let b = g.body {
            bodyView.isHidden = false
            bodyView.attributedText = b
            bodyView.frame = g.bodyFrame
        } else {
            bodyView.isHidden = true
            bodyView.attributedText = nil
        }

        if let c = g.code {
            let box = codeBox ?? makeCodeBox()
            box.isHidden = false
            box.frame = g.codeBox
            codeView!.attributedText = c
            codeView!.frame = g.codeTextFrame
        } else {
            codeBox?.isHidden = true
        }

        if let r = g.image {
            let v = imageView ?? makeImageView()
            v.isHidden = false
            v.frame = r
            v.backgroundColor = g.imageColor
        } else {
            imageView?.isHidden = true
        }

        if let f = g.file {
            let v = fileViews ?? makeFileViews()
            [v.icon, v.name, v.download, v.share].forEach { $0.isHidden = false }
            v.icon.frame = f.icon
            v.name.attributedText = f.name
            v.name.frame = f.nameFrame
            v.download.frame = f.download
            v.share.frame = f.share
        } else if let v = fileViews {
            [v.icon, v.name, v.download, v.share].forEach { $0.isHidden = true }
        }

        while pillViews.count < g.pills.count {
            let p = BoostPillView()
            contentView.addSubview(p)
            pillViews.append(p)
        }
        for (i, v) in pillViews.enumerated() {
            if i < g.pills.count {
                v.isHidden = false
                v.configure(g.pills[i])
            } else {
                v.isHidden = true
            }
        }
        if let r = g.addBoost {
            let v = addBoostView ?? {
                let v = AddBoostView()
                contentView.addSubview(v)
                addBoostView = v
                return v
            }()
            v.isHidden = false
            v.frame = r
        } else {
            addBoostView?.isHidden = true
        }
        contentView.bringSubviewToFront(avatar)

        accessibilityIdentifier = "message-\(g.id)"
    }

    private func makeCodeBox() -> UIView {
        let box = UIView()
        box.backgroundColor = Theme.codeBox
        box.layer.cornerRadius = Metrics.codeRadius
        let t = MessageCell.makeTextView()
        t.delegate = self
        box.addSubview(t)
        contentView.insertSubview(box, aboveSubview: bodyView)
        codeBox = box
        codeView = t
        return box
    }

    private func makeImageView() -> UIView {
        let v = UIView()
        v.isUserInteractionEnabled = false
        contentView.insertSubview(v, aboveSubview: bubble)
        imageView = v
        return v
    }

    private func makeFileViews() -> (icon: UIImageView, name: UILabel, download: UIImageView, share: UIImageView) {
        func symbol(_ name: String, _ size: CGFloat, _ weight: UIImage.SymbolWeight) -> UIImageView {
            let v = UIImageView(image: UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: weight)))
            v.tintColor = Theme.text
            v.contentMode = .center
            contentView.addSubview(v)
            return v
        }
        let icon = symbol("doc.text.fill", 20, .regular)
        let name = UILabel()
        name.lineBreakMode = .byTruncatingMiddle
        contentView.addSubview(name)
        let v = (icon: icon, name: name, download: symbol("arrow.down.to.line", 16, .bold), share: symbol("square.and.arrow.up", 16, .medium))
        fileViews = v
        return v
    }

    // MARK: Selection and menus

    func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        guard let reply = delegate?.replyAction() else { return UIMenu(children: suggestedActions) }
        return UIMenu(children: [reply] + suggestedActions)
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        // Over the text, the text view's own selection and edit menu take the long press.
        let inCell = bubble.convert(location, to: contentView)
        if !bodyView.isHidden && bodyView.frame.contains(inCell) { return nil }
        if let box = codeBox, !box.isHidden, box.frame.contains(inCell) { return nil }
        let text = geo?.copyText ?? ""
        let reply = delegate?.replyAction()
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let copy = UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in UIPasteboard.general.string = text }
            return UIMenu(children: [copy] + (reply.map { [$0] } ?? []))
        }
    }
}

/// The card shown above the room's first message.
final class WelcomeView: UICollectionReusableView {
    static let reuseID = "welcome"
    static let height: CGFloat = 401.7

    private let card = UIView()
    private let logo = UIView()
    private let globe = UIView()
    private let globeLabel = UILabel()
    private let title = UILabel()
    private let subtitle = UILabel()
    private let link = UIView()
    private let linkIcon = UIImageView()
    private let linkLabel = UILabel()
    private var buttons: [UIView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        card.backgroundColor = Theme.bubble
        card.layer.cornerRadius = 14
        addSubview(card)

        let side: CGFloat = 68.7
        let g = CAGradientLayer()
        g.type = .radial
        g.colors = [Theme.hex(0x7D2384).cgColor, Theme.hex(0x3E0C40).cgColor]
        g.startPoint = CGPoint(x: 0.5, y: 0.35); g.endPoint = CGPoint(x: 1.2, y: 1.2)
        g.frame = CGRect(x: 0, y: 0, width: side, height: side)
        logo.layer.addSublayer(g)
        // The Campfire mark: a zigzag scribble in a warm-to-blue gradient.
        let scribble = CAGradientLayer()
        scribble.frame = g.frame
        scribble.colors = [0xE5127D, 0xF0403A, 0xF7941D, 0xFFE08A, 0x3BA7F5, 0xF7941D].map { Theme.hex($0).cgColor }
        scribble.startPoint = CGPoint(x: 0.25, y: 0.25); scribble.endPoint = CGPoint(x: 0.8, y: 0.8)
        let mask = CAShapeLayer()
        let path = UIBezierPath()
        let c = CGPoint(x: side * 0.5, y: side * 0.5), r = side * 0.26
        let n = 11
        for i in 0..<n {
            // Parallel strokes along the diagonal, clipped to a circle, joined end to end.
            let t = (CGFloat(i) / CGFloat(n - 1) - 0.5) * 2 * r * 0.95
            let dir = CGPoint(x: 0.57, y: 0.82), nrm = CGPoint(x: 0.82, y: -0.57)
            let half = sqrt(max(r * r - t * t, 0))
            let mid = CGPoint(x: c.x + nrm.x * t, y: c.y + nrm.y * t)
            let a = CGPoint(x: mid.x - dir.x * half, y: mid.y - dir.y * half)
            let b = CGPoint(x: mid.x + dir.x * half, y: mid.y + dir.y * half)
            if i == 0 { path.move(to: i % 2 == 0 ? a : b) }
            path.addLine(to: i % 2 == 0 ? a : b)
            path.addLine(to: i % 2 == 0 ? b : a)
        }
        mask.path = path.cgPath
        mask.lineWidth = 2.6
        mask.lineCap = .round
        mask.lineJoin = .round
        mask.strokeColor = UIColor.black.cgColor
        mask.fillColor = nil
        scribble.mask = mask
        logo.layer.addSublayer(scribble)
        logo.layer.cornerRadius = 12
        logo.layer.cornerCurve = .continuous
        logo.clipsToBounds = true
        addSubview(logo)

        globe.layer.borderWidth = 1
        globe.backgroundColor = Theme.background
        globeLabel.text = "🌍"
        globeLabel.font = .systemFont(ofSize: 17)
        globeLabel.textAlignment = .center
        globe.addSubview(globeLabel)
        card.addSubview(globe)

        title.text = "Welcome to Campfire"
        title.font = .systemFont(ofSize: 18.5, weight: .bold)
        title.textColor = Theme.text
        title.textAlignment = .center
        card.addSubview(title)
        subtitle.text = "To invite people to chat, share the join link below."
        subtitle.font = .systemFont(ofSize: 17)
        subtitle.textColor = Theme.text
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0
        card.addSubview(subtitle)

        link.layer.borderWidth = 1
        link.layer.cornerRadius = 8
        link.backgroundColor = Theme.background
        linkIcon.image = UIImage(systemName: "person.crop.circle.badge.plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .regular))
        linkIcon.tintColor = Theme.text
        linkIcon.contentMode = .center
        link.addSubview(linkIcon)
        linkLabel.text = "http://127.0.0.1:3055/join/GwHG-HbZN"
        linkLabel.font = .systemFont(ofSize: 16)
        linkLabel.textColor = Theme.text
        linkLabel.lineBreakMode = .byTruncatingTail
        link.addSubview(linkLabel)
        card.addSubview(link)

        for name in ["qrcode", "doc.on.clipboard", "square.and.arrow.up"] {
            let b = UIView()
            b.layer.borderWidth = 1
            b.backgroundColor = Theme.background
            let i = UIImageView(image: UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)))
            i.tintColor = Theme.text
            i.contentMode = .center
            i.tag = 1
            b.addSubview(i)
            card.addSubview(b)
            buttons.append(b)
        }
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (v: WelcomeView, _) in v.updateColors() }
        updateColors()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func updateColors() {
        let border = Theme.borderDarker.resolvedColor(with: traitCollection).cgColor
        globe.layer.borderColor = border
        link.layer.borderColor = border
        buttons.forEach { $0.layer.borderColor = border }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        card.frame = CGRect(x: 14, y: 109, width: w - 28, height: 269)
        logo.frame = CGRect(x: (w - 68.7) / 2, y: 85.4, width: 68.7, height: 68.7)
        globe.frame = CGRect(x: 16.3, y: 16.9, width: 41.4, height: 41.4)
        globe.layer.cornerRadius = 20.7
        globeLabel.frame = globe.bounds
        let cw = card.bounds.width
        title.frame = CGRect(x: 0, y: 77, width: cw, height: 22.6)
        subtitle.frame = CGRect(x: 20, y: 99.6, width: cw - 40, height: 46)
        link.frame = CGRect(x: 15.4, y: 161, width: cw - 30.8, height: 39)
        linkIcon.frame = CGRect(x: 10, y: 0, width: 26, height: 39)
        linkLabel.frame = CGRect(x: 42.3, y: 0, width: link.bounds.width - 50, height: 39)
        for (i, b) in buttons.enumerated() {
            b.frame = CGRect(x: cw / 2 - 4.9 - 21 + CGFloat(i - 1) * 52.7, y: 217, width: 42, height: 42)
            b.layer.cornerRadius = 21
            b.viewWithTag(1)?.frame = b.bounds
        }
    }
}
