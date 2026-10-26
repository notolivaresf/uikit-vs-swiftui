import UIKit
import CampfireKit

/// One message row. All frames come from `RowLayout`; the cell only places views.
final class MessageCell: UICollectionViewCell, UITextViewDelegate, UIContextMenuInteractionDelegate {
    static let reuseID = "message"

    private let separatorLine = UIView()
    private let separatorPill = UIView()
    private let separatorLabel = UILabel()
    private let avatar = AvatarView()
    private let bubble = UIView()
    private let headerLabel = UILabel()
    private let dots = DotsView()
    private let textView = MessageTextView()
    private let codeBox = UIView()
    private let codeView = MessageTextView()
    private let imageView = UIView()
    private let fileIcon = UIImageView(image: UIImage(systemName: "doc.text.fill",
                                                      withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .regular)))
    private let fileName = UILabel()
    private let fileDownload = UIImageView(image: UIImage(systemName: "arrow.down.to.line",
                                                          withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)))
    private let fileShare = UIImageView(image: UIImage(systemName: "square.and.arrow.up",
                                                       withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)))
    private var pillViews: [BoostPillView] = []
    private let addBoost = AddBoostView()

    private(set) var messageID: MessageID = 0
    private var copyText = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        separatorLine.backgroundColor = Palette.border
        separatorPill.backgroundColor = Palette.bubble
        separatorPill.addSubview(separatorLabel)
        contentView.addSubview(separatorLine)
        contentView.addSubview(separatorPill)

        bubble.layer.cornerRadius = Metrics.bubbleRadius
        bubble.layer.cornerCurve = .circular
        contentView.addSubview(bubble)
        contentView.addSubview(avatar)
        bubble.addSubview(headerLabel)
        bubble.addSubview(dots)
        textView.delegate = self
        bubble.addSubview(textView)
        codeBox.backgroundColor = Palette.codeBox
        codeBox.layer.cornerRadius = Metrics.codeBoxRadius
        codeView.delegate = self
        codeBox.addSubview(codeView)
        bubble.addSubview(codeBox)
        bubble.addSubview(imageView)
        for v in [fileIcon, fileDownload, fileShare] {
            v.tintColor = Palette.text
            v.contentMode = .center
            bubble.addSubview(v)
        }
        bubble.addSubview(fileName)
        bubble.addSubview(addBoost)
        bubble.addInteraction(UIContextMenuInteraction(delegate: self))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        layoutAttributes
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // Only when something is selected: setting a range makes the text view scroll its caret into view,
        // which would scroll the room (animated) to wherever this reused cell last was.
        for view in [textView, codeView] where view.selectedRange.length > 0 {
            view.selectedRange = NSRange(location: 0, length: 0)
        }
    }

    func configure(_ row: RowLayout) {
        messageID = row.id
        copyText = row.copyText
        accessibilityIdentifier = "message-\(row.id)"

        if let sep = row.separator {
            separatorLine.isHidden = false
            separatorPill.isHidden = false
            separatorLine.frame = sep.lineFrame
            separatorPill.frame = sep.pillFrame
            separatorPill.layer.cornerRadius = sep.pillFrame.height / 2
            separatorLabel.frame = sep.labelFrame
            separatorLabel.attributedText = sep.text
        } else {
            separatorLine.isHidden = true
            separatorPill.isHidden = true
        }

        if let frame = row.avatarFrame {
            avatar.isHidden = false
            avatar.frame = frame
            avatar.configure(initial: row.avatarInitial, color: row.avatarColor)
        } else {
            avatar.isHidden = true
        }

        bubble.frame = row.bubbleFrame
        switch row.bubbleStyle {
        case .plain: bubble.backgroundColor = Palette.bubble
        case .mentioned: bubble.backgroundColor = Palette.mentionedBubble
        case .transparent: bubble.backgroundColor = .clear
        }
        headerLabel.frame = row.headerFrame
        headerLabel.attributedText = row.header
        headerLabel.lineBreakMode = .byTruncatingTail
        dots.frame = row.dotsFrame

        if let text = row.text, let frame = row.textFrame {
            textView.isHidden = false
            if textView.attributedText != text { textView.attributedText = text }
            textView.frame = frame
        } else {
            textView.isHidden = true
        }

        if let code = row.code, let box = row.codeBoxFrame, let inner = row.codeTextFrame {
            codeBox.isHidden = false
            codeBox.frame = box
            if codeView.attributedText != code { codeView.attributedText = code }
            codeView.frame = inner
        } else {
            codeBox.isHidden = true
        }

        // CampfireKit's placeholder images are one solid colour; filling the frame with it draws the same
        // pixels as decoding `Placeholder.pngData` would, without building and holding a bitmap per image.
        if let frame = row.imageFrame {
            imageView.isHidden = false
            imageView.frame = frame
            imageView.backgroundColor = row.imageColor
        } else {
            imageView.isHidden = true
        }

        let hasFile = row.file != nil
        for v in [fileIcon, fileDownload, fileShare] { v.isHidden = !hasFile }
        fileName.isHidden = !hasFile
        if let file = row.file {
            fileIcon.frame = file.iconFrame
            fileName.frame = file.nameFrame
            fileName.attributedText = file.name
            fileName.lineBreakMode = .byTruncatingMiddle
            fileDownload.frame = file.downloadFrame
            fileShare.frame = file.shareFrame
        }

        while pillViews.count < row.pills.count {
            let pill = BoostPillView()
            bubble.insertSubview(pill, belowSubview: addBoost)
            pillViews.append(pill)
        }
        for (i, view) in pillViews.enumerated() {
            if i < row.pills.count {
                view.isHidden = false
                view.configure(row.pills[i])
            } else {
                view.isHidden = true
            }
        }
        if let frame = row.addBoostFrame {
            addBoost.isHidden = false
            addBoost.frame = frame
        } else {
            addBoost.isHidden = true
        }
    }

    // MARK: Selection menu and context menu

    private func replyAction() -> UIAction {
        UIAction(title: "Reply", image: UIImage(systemName: "arrowshape.turn.up.left")) { _ in }
    }

    /// The system edit menu with Reply placed right after Copy, so both show on the menu's first page.
    private func editMenu(_ suggested: [UIMenuElement]) -> UIMenu {
        func containsCopy(_ element: UIMenuElement) -> Bool {
            if let command = element as? UICommand { return command.action == #selector(UIResponderStandardEditActions.copy(_:)) }
            if let menu = element as? UIMenu { return menu.children.contains(where: containsCopy) }
            return false
        }
        var children = suggested
        let index = children.firstIndex(where: containsCopy).map { $0 + 1 } ?? 0
        children.insert(replyAction(), at: index)
        return UIMenu(children: children)
    }

    func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        editMenu(suggestedActions)
    }

    @available(iOS 26.0, *)
    func textView(_ textView: UITextView, editMenuForTextInRanges ranges: [NSValue], suggestedActions: [UIMenuElement]) -> UIMenu? {
        editMenu(suggestedActions)
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        // Long-pressing the text itself selects text; its edit menu carries Copy and Reply.
        for view in [textView, codeView] where !view.isHidden && !(view.superview?.isHidden ?? true) {
            let point = interaction.view!.convert(location, to: view)
            if view.bounds.contains(point) { return nil }
        }
        let text = copyText
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let copy = UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.string = text
            }
            return UIMenu(children: [copy, self?.replyAction() ?? UIAction(title: "Reply") { _ in }])
        }
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        let parameters = UIPreviewParameters()
        parameters.visiblePath = UIBezierPath(roundedRect: bubble.bounds, cornerRadius: Metrics.bubbleRadius)
        return UITargetedPreview(view: bubble, parameters: parameters)
    }
}
