import UIKit
import CampfireKit

/// A view whose layer border follows a dynamic colour across light and dark.
class BorderedView: UIView {
    var borderColor: UIColor = Palette.borderDark { didSet { layer.borderColor = borderColor.resolvedColor(with: traitCollection).cgColor } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.borderWidth = 1
        layer.borderColor = borderColor.resolvedColor(with: traitCollection).cgColor
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (v: BorderedView, _: UITraitCollection) in
            v.layer.borderColor = v.borderColor.resolvedColor(with: v.traitCollection).cgColor
        }
    }

    required init?(coder: NSCoder) { fatalError() }
}

/// Round avatar: palette colour, white initial, a ring of page colour around it.
final class AvatarView: UIView {
    private let disc = UIView()
    private let label = UILabel()
    private var ring: CGFloat = 0

    init(ring: CGFloat) {
        self.ring = ring
        super.init(frame: .zero)
        backgroundColor = ring > 0 ? Palette.background : .clear
        disc.clipsToBounds = true
        label.textColor = .white
        label.textAlignment = .center
        addSubview(disc)
        disc.addSubview(label)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    func set(user: User?, font: UIFont) {
        disc.backgroundColor = Palette.avatar(user?.id ?? 0)
        label.text = Glyphs.initial(of: user?.name ?? "?")
        if label.font != font { label.font = font }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
        disc.frame = bounds.insetBy(dx: ring, dy: ring)
        disc.layer.cornerRadius = disc.bounds.width / 2
        label.frame = disc.bounds
    }
}

final class BoostPillView: BorderedView {
    let avatar = AvatarView(ring: 0)
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Palette.background
        label.textColor = Palette.text
        addSubview(avatar)
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(_ pill: RowLayout.Pill, style: TextStyle) {
        let h = pill.frame.height
        layer.cornerRadius = h / 2
        let d = h - 2 * (1 + 1.6)
        avatar.set(user: pill.user, font: style.pillAvatar)
        avatar.frame = CGRect(x: 2.6, y: 2.6, width: d, height: d)
        label.font = pill.isEmoji ? style.boostEmoji : style.boostText
        label.text = pill.content
        let x = avatar.frame.maxX + 4.4 * style.scale
        label.frame = CGRect(x: x, y: 0, width: max(0, pill.frame.width - x - 4), height: h)
    }
}

final class MessageTextView: UITextView {
    init() {
        #if TK1
        // TextKit 1 text view: its own storage, layout manager and container.
        let storage = NSTextStorage()
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: 100, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        super.init(frame: .zero, textContainer: container)
        #else
        super.init(frame: .zero, textContainer: nil)
        #endif
        isEditable = false
        isSelectable = true
        isScrollEnabled = false
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        backgroundColor = .clear
        dataDetectorTypes = []
        clipsToBounds = false
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) { fatalError() }
}

final class MessageCell: UICollectionViewCell, UITextViewDelegate, UIContextMenuInteractionDelegate {
    static let reuseID = "message"

    private(set) var row: RowLayout?
    private weak var style: TextStyle?

    private var separatorLine: UIView?
    private var separatorPill: UIView?
    private var separatorLabel: UILabel?
    private let avatar = AvatarView(ring: Geo.avatarRing)
    private let bubble = UIView()
    private let nameLabel = UILabel()
    private let timeLabel = UILabel()
    private let dots = UIImageView()
    private let textView = MessageTextView()
    private var codeBoxes: [(box: BorderedView, text: MessageTextView)] = []
    private var imageBox: UIView?
    private var fileViews: (icon: UIImageView, name: UILabel, download: UIImageView, share: UIImageView)?
    private var pills: [BoostPillView] = []
    private var addBoost: BorderedView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        bubble.layer.cornerRadius = Geo.bubbleRadius
        bubble.layer.cornerCurve = .continuous
        bubble.clipsToBounds = true
        contentView.addSubview(bubble)
        contentView.addSubview(avatar)
        nameLabel.textColor = Palette.text
        timeLabel.textColor = Palette.textHalf
        dots.tintColor = Palette.textHalf
        dots.contentMode = .center
        bubble.addSubview(nameLabel)
        bubble.addSubview(timeLabel)
        bubble.addSubview(dots)
        bubble.addSubview(textView)
        textView.delegate = self
        bubble.addInteraction(UIContextMenuInteraction(delegate: self))
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(_ L: RowLayout, style s: TextStyle) {
        row = L
        if style !== s {
            style = s
            nameLabel.font = s.name
            timeLabel.font = s.meta
            dots.image = UIImage(systemName: "ellipsis",
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 12.8 * s.scale, weight: .black))
        }

        // Day separator
        if let text = L.separatorText {
            if separatorLine == nil {
                let line = UIView()
                line.backgroundColor = Palette.border
                let pill = UIView()
                pill.backgroundColor = Palette.bubble
                let label = UILabel()
                label.textColor = Palette.text
                label.textAlignment = .center
                pill.addSubview(label)
                contentView.insertSubview(line, at: 0)
                contentView.insertSubview(pill, aboveSubview: line)
                separatorLine = line; separatorPill = pill; separatorLabel = label
            }
            separatorLine!.isHidden = false
            separatorPill!.isHidden = false
            separatorLine!.frame = CGRect(x: Geo.padX, y: L.separatorLineY, width: bounds.width - 2 * Geo.padX, height: Geo.sepLine)
            separatorPill!.frame = L.separatorPill
            separatorPill!.layer.cornerRadius = L.separatorPill.height / 2
            separatorLabel!.font = s.separator
            separatorLabel!.text = text
            separatorLabel!.frame = separatorPill!.bounds
        } else {
            separatorLine?.isHidden = true
            separatorPill?.isHidden = true
        }

        // Avatar
        if let f = L.avatarFrame {
            avatar.isHidden = false
            avatar.frame = f
            avatar.set(user: L.avatarUser, font: TextStyle.avatarInitial)
        } else {
            avatar.isHidden = true
        }

        // Bubble
        bubble.frame = L.bubble
        switch L.bubbleKind {
        case .plain: bubble.backgroundColor = Palette.bubble
        case .mention: bubble.backgroundColor = Palette.mentionBubble
        case .clear: bubble.backgroundColor = .clear
        }
        if let name = L.nameText {
            nameLabel.isHidden = false
            nameLabel.text = name
            nameLabel.frame = L.nameFrame
        } else {
            nameLabel.isHidden = true
        }
        timeLabel.text = L.timeText
        timeLabel.frame = L.timeFrame
        dots.frame = L.dotsFrame

        if let body = L.body {
            textView.isHidden = false
            #if CELL_SKIP
            if textView.attributedText != body { textView.attributedText = body }
            if textView.frame != L.bodyFrame { textView.frame = L.bodyFrame }
            #else
            textView.attributedText = body
            textView.frame = L.bodyFrame
            #endif
        } else {
            textView.isHidden = true
            textView.attributedText = nil
        }

        // Code blocks
        while codeBoxes.count < L.codes.count {
            let box = BorderedView()
            box.borderColor = Palette.border
            box.backgroundColor = Palette.background
            box.layer.cornerRadius = Geo.codeRadius
            let tv = MessageTextView()
            tv.delegate = self
            box.addSubview(tv)
            bubble.addSubview(box)
            codeBoxes.append((box, tv))
        }
        for (i, c) in codeBoxes.enumerated() {
            if i < L.codes.count {
                let code = L.codes[i]
                c.box.isHidden = false
                c.box.frame = code.box
                let tf = CGRect(x: code.textFrame.minX - code.box.minX, y: code.textFrame.minY - code.box.minY,
                                width: code.textFrame.width, height: code.textFrame.height)
                #if CELL_SKIP
                if c.text.attributedText != code.text { c.text.attributedText = code.text }
                if c.text.frame != tf { c.text.frame = tf }
                #else
                c.text.attributedText = code.text
                c.text.frame = tf
                #endif
            } else {
                c.box.isHidden = true
            }
        }

        // Image
        if let f = L.imageFrame {
            if imageBox == nil {
                let v = UIView()
                v.isAccessibilityElement = true
                v.accessibilityLabel = "Image"
                bubble.addSubview(v)
                imageBox = v
            }
            imageBox!.isHidden = false
            imageBox!.frame = f
            imageBox!.backgroundColor = L.imageColor
        } else {
            imageBox?.isHidden = true
        }

        // File
        if let file = L.file {
            if fileViews == nil {
                func icon(_ name: String, _ weight: UIImage.SymbolWeight) -> UIImageView {
                    let v = UIImageView(image: UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(weight: weight)))
                    v.tintColor = Palette.text
                    v.contentMode = .scaleAspectFit
                    bubble.addSubview(v)
                    return v
                }
                let name = UILabel()
                name.textColor = Palette.text
                bubble.addSubview(name)
                fileViews = (icon("doc.text.fill", .regular), name, icon("arrow.down.to.line", .bold), icon("square.and.arrow.up", .medium))
            }
            let f = fileViews!
            [f.icon, f.name, f.download, f.share].forEach { $0.isHidden = false }
            f.icon.frame = file.icon
            f.name.font = s.fileName
            f.name.text = file.name
            f.name.frame = file.nameFrame
            f.download.frame = file.download.insetBy(dx: 2, dy: 2)
            f.share.frame = file.share.insetBy(dx: 2, dy: 1)
        } else if let f = fileViews {
            [f.icon, f.name, f.download, f.share].forEach { $0.isHidden = true }
        }

        // Boosts
        while pills.count < L.pills.count {
            let p = BoostPillView()
            bubble.addSubview(p)
            pills.append(p)
        }
        for (i, p) in pills.enumerated() {
            if i < L.pills.count {
                p.isHidden = false
                p.frame = L.pills[i].frame
                p.configure(L.pills[i], style: s)
            } else {
                p.isHidden = true
            }
        }
        if let f = L.addBoostFrame {
            if addBoost == nil {
                let v = BorderedView()
                v.backgroundColor = Palette.background
                let iv = UIImageView(image: Glyphs.addBoost)
                iv.tintColor = Palette.text
                iv.contentMode = .scaleAspectFit
                iv.tag = 1
                v.addSubview(iv)
                v.isAccessibilityElement = true
                v.accessibilityLabel = "Add boost"
                v.accessibilityTraits = .button
                bubble.addSubview(v)
                addBoost = v
            }
            addBoost!.isHidden = false
            addBoost!.frame = f
            addBoost!.layer.cornerRadius = f.height / 2
            let g = 20 * s.scale
            addBoost!.viewWithTag(1)!.frame = CGRect(x: (f.width - g) / 2 + 0.5, y: (f.height - g) / 2 + 0.5, width: g, height: g)
        } else {
            addBoost?.isHidden = true
        }
    }

    // MARK: Menus

    private func replyAction() -> UIAction {
        UIAction(title: "Reply", image: UIImage(systemName: "arrowshape.turn.up.left")) { _ in }
    }

    func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        UIMenu(children: [replyAction()] + suggestedActions)
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        if !textView.isHidden && textView.frame.contains(location) { return nil }
        for c in codeBoxes where !c.box.isHidden && c.box.frame.contains(location) { return nil }
        let text = row?.plainText ?? ""
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            UIMenu(children: [
                UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in UIPasteboard.general.string = text },
                self?.replyAction() ?? UIAction(title: "Reply") { _ in },
            ])
        }
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        let params = UIPreviewParameters()
        params.visiblePath = UIBezierPath(roundedRect: bubble.bounds, cornerRadius: Geo.bubbleRadius)
        params.backgroundColor = .clear
        return UITargetedPreview(view: bubble, parameters: params)
    }
}
