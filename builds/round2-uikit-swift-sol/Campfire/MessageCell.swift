import UIKit
import CampfireKit

@MainActor
final class SelectableMessageText: UITextView, UITextViewDelegate {
    init() {
        super.init(frame: .zero, textContainer: nil)
        isEditable = false
        isSelectable = true
        isScrollEnabled = false
        backgroundColor = .clear
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        contentInset = .zero
        delegate = self
        adjustsFontForContentSizeCategory = false // The room applies one shared, anchored scale change.
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    func textView(_ textView: UITextView, editMenuForTextIn range: NSRange,
                  suggestedActions: [UIMenuElement]) -> UIMenu? {
        let copy = UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { [weak textView] _ in
            guard let textView, range.location + range.length <= (textView.text as NSString).length else { return }
            UIPasteboard.general.string = (textView.text as NSString).substring(with: range)
        }
        return UIMenu(children: [copy, UIAction(title: "Reply", image: UIImage(systemName: "arrowshape.turn.up.left")) { _ in }])
    }
}

@MainActor
final class AddBoostButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: AddBoostButton, _: UITraitCollection) in self.setNeedsDisplay() }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let unit = bounds.width / 28.64
        context.scaleBy(x: unit, y: unit)
        Theme.text.setStroke(); Theme.text.setFill()
        context.setLineWidth(1.6); context.setLineCap(.round)
        context.strokeEllipse(in: CGRect(x: 7, y: 6, width: 13.5, height: 13.5))
        context.fillEllipse(in: CGRect(x: 10.2, y: 10, width: 1.8, height: 1.8))
        context.fillEllipse(in: CGRect(x: 15.5, y: 10, width: 1.8, height: 1.8))
        context.move(to: CGPoint(x: 10.6, y: 14.3))
        context.addQuadCurve(to: CGPoint(x: 16.8, y: 14.3), control: CGPoint(x: 13.7, y: 18.6))
        context.strokePath()
        Theme.background.setFill()
        context.fillEllipse(in: CGRect(x: 16, y: 15, width: 9, height: 9))
        Theme.text.setStroke()
        context.move(to: CGPoint(x: 17, y: 19.5)); context.addLine(to: CGPoint(x: 23, y: 19.5))
        context.move(to: CGPoint(x: 20, y: 16.5)); context.addLine(to: CGPoint(x: 20, y: 22.5))
        context.strokePath()
    }
}

@MainActor
final class MessageCell: UICollectionViewCell, UIContextMenuInteractionDelegate {
    let bubbleView = UIView()
    private let avatar = AvatarView()
    private let avatarBorder = UIView()
    private let meta = UILabel()
    private let dayLine = UIView()
    private let dayPill = UILabel()
    private let placeholder = UIView()
    private let fileIcon = UIImageView()
    private let fileLabel = UILabel()
    private let download = UIImageView()
    private let share = UIImageView()
    private var texts: [SelectableMessageText] = []
    private var codeBackgrounds: [UIView] = []
    private var pills: [UIView] = []
    private var model: MessageLayout?
    private var copyText = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentView.addSubview(dayLine); contentView.addSubview(dayPill)
        contentView.addSubview(bubbleView)
        contentView.addSubview(avatarBorder); contentView.addSubview(avatar)
        for view in [meta, placeholder, fileIcon, fileLabel, download, share] { bubbleView.addSubview(view) }
        bubbleView.layer.cornerRadius = 10.56
        avatarBorder.backgroundColor = Theme.background
        dayLine.backgroundColor = Theme.bubble
        dayPill.backgroundColor = Theme.bubble
        dayPill.textAlignment = .center
        dayPill.textColor = Theme.text
        meta.numberOfLines = 0
        meta.isUserInteractionEnabled = true
        meta.addInteraction(UIContextMenuInteraction(delegate: self))
        placeholder.addInteraction(UIContextMenuInteraction(delegate: self))
        placeholder.isUserInteractionEnabled = true
        fileLabel.isUserInteractionEnabled = true
        fileLabel.addInteraction(UIContextMenuInteraction(delegate: self))
        fileIcon.tintColor = Theme.text; download.tintColor = Theme.text; share.tintColor = Theme.text
        fileIcon.contentMode = .scaleAspectFit; download.contentMode = .scaleAspectFit; share.contentMode = .scaleAspectFit
        fileLabel.textColor = Theme.text
        isAccessibilityElement = false
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: MessageCell, _: UITraitCollection) in
            for pill in self.pills { pill.layer.borderColor = Theme.border.resolvedColor(with: self.traitCollection).cgColor }
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }

    func show(_ layout: MessageLayout, users: [Int: User]) {
        let selectedRanges = model?.id == layout.id ? texts.map(\.selectedRange) : []
        model = layout
        accessibilityIdentifier = "message-\(layout.id)"
        bubbleView.frame = layout.bubble
        bubbleView.backgroundColor = layout.message.isEmojiOnly ? .clear : layout.presentation.mentionsMe ? Theme.mention : Theme.bubble
        avatar.frame = layout.avatar
        avatar.show(id: layout.author.id, name: layout.author.name, size: 35.27, fontSize: 16)
        avatarBorder.frame = layout.avatar.insetBy(dx: -2.4, dy: -2.4)
        avatarBorder.layer.cornerRadius = avatarBorder.bounds.width / 2
        avatar.isHidden = layout.presentation.isThreaded
        avatarBorder.isHidden = layout.presentation.isThreaded
        meta.frame = layout.header
        meta.attributedText = layout.headerText
        meta.textAlignment = layout.presentation.isMine ? .right : .left
        meta.accessibilityLabel = "\(layout.author.name), \(layout.headerText.string)"
        dayLine.isHidden = layout.day.isEmpty
        dayPill.isHidden = layout.day.isEmpty
        if !layout.day.isEmpty {
            dayLine.frame = CGRect(x: layout.day.minX, y: layout.day.midY - 1, width: layout.day.width, height: 2)
            dayPill.font = Theme.font(12.8, weight: .semibold, scale: layout.scale)
            dayPill.text = layout.dayText
            let width = min(layout.day.width, dayPill.intrinsicContentSize.width + 39)
            dayPill.frame = CGRect(x: layout.day.midX - width / 2, y: layout.day.minY, width: width, height: layout.day.height)
            dayPill.layer.cornerRadius = layout.day.height / 2; dayPill.clipsToBounds = true
        }
        while texts.count < layout.pieces.count {
            let bg = UIView(); bg.backgroundColor = Theme.background; bg.layer.cornerRadius = 6.4
            let text = SelectableMessageText()
            bubbleView.addSubview(bg); bubbleView.addSubview(text)
            codeBackgrounds.append(bg); texts.append(text)
        }
        for i in texts.indices {
            let visible = i < layout.pieces.count
            texts[i].isHidden = !visible; codeBackgrounds[i].isHidden = true
            guard visible else { continue }
            let piece = layout.pieces[i]
            if piece.code {
                codeBackgrounds[i].isHidden = false; codeBackgrounds[i].frame = piece.frame
                texts[i].frame = piece.frame.insetBy(dx: 12.8, dy: 12.8)
            } else { texts[i].frame = piece.frame }
            texts[i].attributedText = piece.text
            texts[i].accessibilityIdentifier = "text-\(layout.id)-\(i)"
            if i < selectedRanges.count, NSMaxRange(selectedRanges[i]) <= piece.text.length {
                texts[i].selectedRange = selectedRanges[i]
            } else { texts[i].selectedRange = NSRange(location: 0, length: 0) }
        }
        placeholder.frame = layout.image; placeholder.backgroundColor = layout.imageColor
        placeholder.isHidden = layout.image.isEmpty
        placeholder.accessibilityLabel = "Image attachment"
        placeholder.isAccessibilityElement = !layout.image.isEmpty
        let hasFile = layout.fileName != nil
        for v in [fileIcon, fileLabel, download, share] { v.isHidden = !hasFile }
        if hasFile {
            let r = layout.file, s = layout.scale
            fileIcon.image = Theme.symbol("doc.text.fill", size: 22 * s)
            fileIcon.frame = CGRect(x: r.minX, y: r.midY - 12 * s, width: 20 * s, height: 26 * s)
            download.image = Theme.symbol("square.and.arrow.down", size: 19 * s, weight: .semibold)
            share.image = Theme.symbol("square.and.arrow.up", size: 18 * s, weight: .semibold)
            share.frame = CGRect(x: r.maxX - 23 * s, y: r.midY - 12 * s, width: 23 * s, height: 24 * s)
            download.frame = share.frame.offsetBy(dx: -34 * s, dy: 0)
            fileLabel.frame = CGRect(x: r.minX + 27 * s, y: r.minY, width: max(0, r.width - 89 * s), height: r.height)
            fileLabel.font = Theme.font(16, scale: s); fileLabel.text = layout.fileName
            fileLabel.adjustsFontSizeToFitWidth = true; fileLabel.minimumScaleFactor = 0.75
            fileLabel.accessibilityLabel = "\(layout.fileName ?? ""), \(layout.fileSize)"
        }
        pills.forEach { $0.removeFromSuperview() }; pills.removeAll(keepingCapacity: true)
        for (i, boost) in layout.boosts.enumerated() {
            let frame = layout.boostFrames[i]
            let pill = UIView(frame: frame)
            pill.backgroundColor = Theme.background; pill.layer.cornerRadius = frame.height / 2; pill.clipsToBounds = true
            pill.layer.borderWidth = 1; pill.layer.borderColor = Theme.border.resolvedColor(with: traitCollection).cgColor
            let av = AvatarView()
            let aSize = frame.height - 5.5
            let user = users[boost.boosterID]!
            av.frame = CGRect(x: 2.4, y: (frame.height - aSize) / 2, width: aSize, height: aSize)
            av.show(id: user.id, name: user.name, size: aSize, fontSize: 11 * layout.scale)
            pill.addSubview(av)
            let label = UILabel(frame: CGRect(x: aSize + 6, y: 0, width: frame.width - aSize - 8, height: frame.height))
            label.text = boost.content; label.font = Theme.font(boost.textSize, scale: layout.scale); label.textColor = Theme.text
            pill.addSubview(label)
            pill.isAccessibilityElement = true; pill.accessibilityLabel = "\(user.name) boosted \(boost.content)"
            bubbleView.addSubview(pill); pills.append(pill)
        }
        if !layout.addBoost.isEmpty {
            let add = AddBoostButton(frame: layout.addBoost)
            add.backgroundColor = Theme.background; add.tintColor = Theme.text
            add.layer.cornerRadius = add.bounds.height / 2; add.layer.borderWidth = 1
            add.layer.borderColor = Theme.border.resolvedColor(with: traitCollection).cgColor
            add.accessibilityLabel = "Add boost"
            bubbleView.addSubview(add); pills.append(add)
        }
        copyText = layout.pieces.map { $0.text.string }.joined(separator: "\n")
        if let file = layout.fileName { copyText += file }
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        let copied = copyText
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            UIMenu(children: [UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in UIPasteboard.general.string = copied },
                              UIAction(title: "Reply", image: UIImage(systemName: "arrowshape.turn.up.left")) { _ in }])
        }
    }
    override func prepareForReuse() {
        super.prepareForReuse()
        texts.forEach { $0.resignFirstResponder(); $0.selectedRange = NSRange(location: 0, length: 0) }
    }
}
