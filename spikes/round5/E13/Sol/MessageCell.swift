import UIKit
import CampfireKit

final class BoostStrip: UIView {
    var pills: [BoostGeometry] = []
    var scale: CGFloat = 1
    override func draw(_ rect: CGRect) {
        for pill in pills {
            let frame = pill.frame
            let path = UIBezierPath(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), cornerRadius: frame.height / 2)
            Style.background.setFill(); path.fill()
            Style.border.setStroke(); path.lineWidth = 1; path.stroke()
            if let boost = pill.boost {
                let a = CGRect(x: frame.minX + 2.3, y: frame.minY + 2.3, width: frame.height - 4.6, height: frame.height - 4.6)
                Style.avatar(boost.boosterID).setFill(); UIBezierPath(ovalIn: a).fill()
                let initial = String(pill.name.prefix(1)) as NSString
                let attrs: [NSAttributedString.Key: Any] = [.font: Style.font(12.8, .bold, scale: scale), .foregroundColor: UIColor.white]
                let size = initial.size(withAttributes: attrs)
                initial.draw(at: CGPoint(x: a.midX - size.width/2, y: a.midY - size.height/2), withAttributes: attrs)
                let content = boost.content as NSString
                let contentAttrs: [NSAttributedString.Key: Any] = [.font: Style.font(17.6, scale: scale), .foregroundColor: Style.text]
                let size2 = content.size(withAttributes: contentAttrs)
                content.draw(at: CGPoint(x: a.maxX + 4, y: frame.midY - size2.height/2), withAttributes: contentAttrs)
            } else {
                let image = CampfireIcons.image("face.smiling", size: 20*scale)?.withTintColor(Style.text.resolvedColor(with: traitCollection), renderingMode: .alwaysOriginal)
                image?.draw(in: frame.insetBy(dx: 4.32*scale, dy: 4.32*scale))
            }
        }
    }
}

class MessageCell: UICollectionViewCell, UITextViewDelegate, UIContextMenuInteractionDelegate {
    class var kind: String { "text" }
    class var hasBoosts: Bool { false }
    let bubble = UIView()
    let avatar = AvatarView()
    let header = UILabel()
    let body = MessageCell.textView()
    let dayLine = UIView()
    let dayPill = UILabel()
    var code: UITextView?
    var imagePlaceholder: UIView?
    var file: FileView?
    var strip: BoostStrip?
    private var geometry: MessageGeometry?
    static func textView() -> UITextView {
        let view = UITextView(usingTextLayoutManager: false)
        view.isEditable = false; view.isSelectable = true; view.isScrollEnabled = false
        view.textContainerInset = .zero; view.textContainer.lineFragmentPadding = 0
        view.backgroundColor = .clear
        view.dataDetectorTypes = []
        view.clipsToBounds = false
        view.contentInsetAdjustmentBehavior = .never
        return view
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        Probe.cellsCreated += 1
        contentView.addSubview(dayLine); contentView.addSubview(dayPill)
        contentView.addSubview(bubble); contentView.addSubview(avatar)
        bubble.addSubview(header); bubble.addSubview(body)
        body.delegate = self
        header.isAccessibilityElement = false
        header.numberOfLines = 0
        bubble.layer.cornerRadius = 10.56
        bubble.clipsToBounds = true
        dayLine.backgroundColor = Style.bubble
        dayPill.backgroundColor = Style.bubble; dayPill.textColor = Style.text
        dayPill.textAlignment = .center; dayPill.clipsToBounds = true
        if Self.kind == "code" { let v = Self.textView(); v.delegate = self; v.backgroundColor = Style.background; v.layer.cornerRadius = 6.4; bubble.addSubview(v); code = v }
        if Self.kind == "image" { let v = UIView(); bubble.addSubview(v); imagePlaceholder = v }
        if Self.kind == "file" { let v = FileView(); v.backgroundColor = .clear; v.isOpaque = false; bubble.addSubview(v); file = v }
        if Self.hasBoosts { let v = BoostStrip(); v.backgroundColor = .clear; v.isUserInteractionEnabled = false; bubble.addSubview(v); strip = v }
        bubble.addInteraction(UIContextMenuInteraction(delegate: self))
    }
    required init?(coder: NSCoder) { fatalError() }
    #if ONE_CELL
    /// One reuse pool: the rarely used parts are made the first time a message needs them.
    private func ensureViews(_ g: MessageGeometry) {
        for part in g.parts {
            switch part.kind {
            case .code where code == nil:
                let v = Self.textView(); v.delegate = self; v.backgroundColor = Style.background; v.layer.cornerRadius = 6.4; bubble.addSubview(v); code = v
            case .image where imagePlaceholder == nil:
                let v = UIView(); bubble.addSubview(v); imagePlaceholder = v
            case .file where file == nil:
                let v = FileView(); v.backgroundColor = .clear; v.isOpaque = false; bubble.addSubview(v); file = v
            default: break
            }
        }
        if !g.boosts.isEmpty, strip == nil {
            let v = BoostStrip(); v.backgroundColor = .clear; v.isUserInteractionEnabled = false; bubble.addSubview(v); strip = v
        }
        strip?.isHidden = g.boosts.isEmpty
    }
    #endif
    func configure(_ g: MessageGeometry, user: User?, scale: CGFloat) {
        geometry = g
        #if ONE_CELL
        ensureViews(g)
        #endif
        accessibilityIdentifier = "message-\(g.id)"
        bubble.frame = g.bubble
        bubble.backgroundColor = g.emojiOnly ? .clear : (g.presentation.mentionsMe ? Style.mention : Style.bubble)
        avatar.frame = g.avatar; avatar.isHidden = g.presentation.isThreaded
        avatar.show(id: user?.id ?? 1, name: user?.name ?? "?")
        header.attributedText = g.header; header.frame = g.headerFrame
        body.isHidden = true; code?.isHidden = true; file?.isHidden = true; imagePlaceholder?.isHidden = true
        for part in g.parts {
            switch part.kind {
            case .text:
                body.isHidden = false; body.frame = part.frame; body.attributedText = part.text
                body.accessibilityIdentifier = "text-\(g.id)"
            case .code:
                code?.isHidden = false
                code?.frame = part.frame
                code?.textContainerInset = UIEdgeInsets(top: 12.8*scale, left: 12.8*scale, bottom: 12.8*scale, right: 12.8*scale)
                code?.attributedText = part.text
            case .image(let color):
                imagePlaceholder?.isHidden = false; imagePlaceholder?.frame = part.frame; imagePlaceholder?.backgroundColor = Style.rgb(color)
                imagePlaceholder?.isAccessibilityElement = true; imagePlaceholder?.accessibilityLabel = "Image attachment"
            case .file(let name, let bytes):
                file?.isHidden = false; file?.frame = part.frame; file?.name = name; file?.bytes = bytes; file?.scale = scale; file?.setNeedsDisplay()
                file?.isAccessibilityElement = true; file?.accessibilityLabel = "\(name), \(bytes) bytes"
            }
        }
        if let strip, !strip.isHidden {
            strip.frame = bubble.bounds
            strip.pills = g.boosts; strip.scale = scale; strip.setNeedsDisplay()
        }
        dayLine.isHidden = g.day == nil; dayPill.isHidden = g.day == nil
        if let day = g.day {
            dayLine.frame = CGRect(x: 14.01, y: g.dayFrame.midY - 1, width: bounds.width - 28.02, height: 2)
            dayPill.font = Style.font(12.8, .semibold, scale: scale); dayPill.text = day
            let w = min(g.dayFrame.width, (day as NSString).size(withAttributes: [.font: dayPill.font!]).width + 47*scale)
            dayPill.frame = CGRect(x: (bounds.width-w)/2, y: g.dayFrame.minY, width: w, height: g.dayFrame.height)
            dayPill.layer.cornerRadius = g.dayFrame.height/2
        }
    }
    func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        let reply = UIAction(title: "Reply", image: UIImage(systemName: "arrowshape.turn.up.left")) { _ in }
        return UIMenu(children: [reply] + suggestedActions)
    }
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        for textView in [body, code].compactMap({ $0 }) where !textView.isHidden {
            if textView.frame.contains(location) { return nil }
        }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            UIMenu(children: [UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in UIPasteboard.general.string = self?.geometry?.plainText }, UIAction(title: "Reply", image: UIImage(systemName: "arrowshape.turn.up.left")) { _ in }])
        }
    }
    override func prepareForReuse() { super.prepareForReuse(); body.selectedRange = NSRange(location: 0, length: 0); code?.selectedRange = NSRange(location: 0, length: 0) }
}
final class CodeCell: MessageCell { override class var kind: String { "code" } }
final class ImageCell: MessageCell { override class var kind: String { "image" } }
final class FileCell: MessageCell { override class var kind: String { "file" } }
final class BoostCell: MessageCell { override class var hasBoosts: Bool { true } }
final class CodeBoostCell: MessageCell { override class var kind: String { "code" }; override class var hasBoosts: Bool { true } }
final class ImageBoostCell: MessageCell { override class var kind: String { "image" }; override class var hasBoosts: Bool { true } }
final class FileBoostCell: MessageCell { override class var kind: String { "file" }; override class var hasBoosts: Bool { true } }

final class FileView: UIView {
    var name = ""
    var bytes = 0
    var scale: CGFloat = 1
    override func draw(_ rect: CGRect) {
        let color = Style.text.resolvedColor(with: traitCollection)
        UIImage(systemName: "doc.text.fill")?.withTintColor(color, renderingMode: .alwaysOriginal).draw(in: CGRect(x: 0, y: 2*scale, width: 20*scale, height: 24*scale))
        (name as NSString).draw(in: CGRect(x: 27*scale, y: 3*scale, width: bounds.width-77*scale, height: 27*scale), withAttributes: [.font: Style.font(16, scale: scale), .foregroundColor: color])
        UIImage(systemName: "square.and.arrow.down", withConfiguration: UIImage.SymbolConfiguration(weight: .semibold))?.withTintColor(color, renderingMode: .alwaysOriginal).draw(in: CGRect(x: bounds.width - 44*scale, y: 4*scale, width: 18*scale, height: 20*scale))
        UIImage(systemName: "square.and.arrow.up", withConfiguration: UIImage.SymbolConfiguration(weight: .semibold))?.withTintColor(color, renderingMode: .alwaysOriginal).draw(in: CGRect(x: bounds.width - 18*scale, y: 4*scale, width: 15*scale, height: 20*scale))
    }
}
