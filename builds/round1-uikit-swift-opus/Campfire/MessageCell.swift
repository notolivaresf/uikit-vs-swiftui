import UIKit

/// One message row, laid out by hand from a precomputed RowGeometry (no Auto Layout).
final class MessageCell: UICollectionViewCell, UITextViewDelegate, UIGestureRecognizerDelegate, UIEditMenuInteractionDelegate {
    static let reuseID = "MessageCell"

    private let dayLine = UIView()
    private let dayPill = UIView()
    private let dayLabel = UILabel()
    private let bubble = UIView()
    private let ring = UIView()
    private let avatar = AvatarView()
    private let nameLabel = UILabel()
    private let timeLabel = UILabel()
    private let dots = DotsView()
    private var textViews: [MessageTextView] = []
    private var codeBoxes: [CodeBoxView] = []
    private let imageView = UIView()
    private let fileIcon = UIImageView()
    private let fileName = UILabel()
    private let fileDownload = UIImageView()
    private let fileShare = UIImageView()
    private var pills: [BoostPillView] = []
    private let addBoost = AddBoostView()
    private var editMenu: UIEditMenuInteraction!
    private(set) var geometry: RowGeometry?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.clipsToBounds = false
        dayLine.backgroundColor = Colors.bubble
        dayPill.backgroundColor = Colors.bubble
        dayLabel.textAlignment = .center
        dayLabel.textColor = Colors.text
        dayPill.addSubview(dayLabel)
        contentView.addSubview(dayLine)
        contentView.addSubview(dayPill)

        bubble.layer.cornerRadius = K.bubbleRadius
        bubble.clipsToBounds = true
        contentView.addSubview(bubble)
        ring.backgroundColor = Colors.background
        ring.isUserInteractionEnabled = false
        contentView.addSubview(ring)
        contentView.addSubview(avatar)

        nameLabel.textColor = Colors.text
        timeLabel.textColor = Colors.dimText
        [nameLabel, timeLabel, dots].forEach { bubble.addSubview($0) }
        bubble.addSubview(imageView)
        fileIcon.image = UIImage(systemName: "doc.text.fill")
        fileIcon.contentMode = .scaleToFill
        fileDownload.image = symbol("arrow.down.to.line", size: 15, weight: .bold)
        fileShare.image = symbol("square.and.arrow.up", size: 15, weight: .semibold)
        fileDownload.contentMode = .scaleAspectFit
        fileShare.contentMode = .scaleAspectFit
        [fileIcon, fileDownload, fileShare].forEach { $0.tintColor = Colors.text; bubble.addSubview($0) }
        fileName.textColor = Colors.text
        bubble.addSubview(fileName)
        bubble.addSubview(addBoost)

        editMenu = UIEditMenuInteraction(delegate: self)
        bubble.addInteraction(editMenu)
        let press = UILongPressGestureRecognizer(target: self, action: #selector(longPress(_:)))
        press.delegate = self
        bubble.addGestureRecognizer(press)
        bubble.isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        for tv in textViews { tv.selectedRange = NSRange(location: 0, length: 0) }
        for box in codeBoxes { box.textView.selectedRange = NSRange(location: 0, length: 0) }
    }

    func configure(_ g: RowGeometry, m: Metrics) {
        geometry = g

        // Day separator.
        let hasDay = g.dayText != nil
        dayLine.isHidden = !hasDay
        dayPill.isHidden = !hasDay
        if hasDay {
            dayLine.frame = CGRect(x: K.screenPadX, y: g.dayLineY, width: g.dayPill.midX * 2 - 2 * K.screenPadX, height: K.dayLine)
            dayPill.frame = g.dayPill
            dayPill.layer.cornerRadius = g.dayPill.height / 2
            dayLabel.font = m.day
            dayLabel.text = g.dayText
            dayLabel.frame = dayPill.bounds
        }

        // Bubble.
        bubble.frame = g.bubble
        switch g.style {
        case .normal: bubble.backgroundColor = Colors.bubble
        case .mention: bubble.backgroundColor = Colors.mentionBubble
        case .none: bubble.backgroundColor = .clear
        }

        // Avatar with a ring of page colour where it overlaps the bubble.
        if let a = g.avatar {
            avatar.isHidden = false
            ring.isHidden = g.style == .none
            avatar.frame = a
            avatar.configure(initial: g.initial, color: g.avatarColor, fontSize: 16)
            ring.frame = a.insetBy(dx: -K.avatarRing, dy: -K.avatarRing)
            ring.layer.cornerRadius = ring.bounds.width / 2
        } else {
            avatar.isHidden = true
            ring.isHidden = true
        }

        // Header.
        nameLabel.isHidden = g.name == nil
        if let name = g.name {
            nameLabel.font = m.metaBold
            nameLabel.text = name
            nameLabel.frame = g.nameFrame
        }
        timeLabel.font = m.meta
        timeLabel.text = g.time
        timeLabel.frame = g.timeFrame
        dots.frame = g.dotsFrame

        // Text and code blocks.
        var t = 0, c = 0
        for item in g.texts {
            let tv: MessageTextView
            if let box = item.codeBox {
                if c == codeBoxes.count {
                    let b = CodeBoxView()
                    b.textView.delegate = self
                    codeBoxes.append(b)
                    bubble.insertSubview(b, belowSubview: addBoost)
                }
                let b = codeBoxes[c]
                c += 1
                b.isHidden = false
                b.frame = box
                tv = b.textView
            } else {
                if t == textViews.count {
                    let v = MessageTextView()
                    v.delegate = self
                    textViews.append(v)
                    bubble.insertSubview(v, belowSubview: addBoost)
                }
                tv = textViews[t]
                t += 1
                tv.isHidden = false
            }
            let frame = CGRect(x: item.frame.minX, y: item.frame.minY + item.textViewOffsetY,
                               width: item.frame.width, height: item.frame.height)
            if tv.source !== item.text {
                tv.attributedText = item.text
                tv.source = item.text
            }
            if tv.frame != frame { tv.frame = frame }
        }
        for i in t..<textViews.count { textViews[i].isHidden = true }
        for i in c..<codeBoxes.count { codeBoxes[i].isHidden = true }

        // Image: solid placeholder colour, edge to edge.
        if let r = g.image {
            imageView.isHidden = false
            imageView.frame = r
            imageView.backgroundColor = g.imageColor
        } else {
            imageView.isHidden = true
        }

        // File.
        let hasFile = g.file != nil
        [fileIcon, fileName, fileDownload, fileShare].forEach { $0.isHidden = !hasFile }
        if let f = g.file {
            fileIcon.frame = f.icon
            fileName.font = m.body
            fileName.text = f.nameText
            fileName.frame = f.name
            fileDownload.frame = f.download
            fileShare.frame = f.share
        }

        // Boosts.
        for (i, pill) in g.pills.enumerated() {
            if i == pills.count {
                let v = BoostPillView()
                pills.append(v)
                bubble.insertSubview(v, belowSubview: addBoost)
            }
            pills[i].isHidden = false
            pills[i].frame = pill.frame
            pills[i].configure(pill, m: m)
        }
        for i in g.pills.count..<pills.count { pills[i].isHidden = true }
        if let r = g.addBoost {
            addBoost.isHidden = false
            addBoost.frame = r
        } else {
            addBoost.isHidden = true
        }
    }

    // MARK: Long-press menu (Copy, Reply)

    private func menu(copying text: @escaping () -> String) -> UIMenu {
        UIMenu(children: [
            UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in UIPasteboard.general.string = text() },
            UIAction(title: "Reply", image: UIImage(systemName: "arrowshape.turn.up.left")) { _ in },
        ])
    }

    func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        menu { [weak textView] in
            guard let tv = textView, let r = Range(tv.selectedRange, in: tv.text) else { return "" }
            return String(tv.text[r])
        }
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Text handles its own long-press (selection + menu); this one covers images, files and the bubble chrome.
        var v: UIView? = touch.view
        while let view = v, view !== bubble {
            if view is UITextView { return false }
            v = view.superview
        }
        return true
    }

    @objc private func longPress(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began else { return }
        let p = g.location(in: bubble)
        editMenu.presentEditMenu(with: UIEditMenuConfiguration(identifier: nil, sourcePoint: p))
    }

    func editMenuInteraction(_ interaction: UIEditMenuInteraction, menuFor configuration: UIEditMenuConfiguration,
                             suggestedActions: [UIMenuElement]) -> UIMenu? {
        let text = geometry?.plainText ?? ""
        return menu { text }
    }
}
