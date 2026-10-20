import UIKit
import CampfireKit

final class AddBoostView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame); backgroundColor = Style.background; clipsToBounds = true; isOpaque = false
        layer.borderWidth = 1; isAccessibilityElement = true; accessibilityLabel = "Add boost"; accessibilityTraits = .button
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    override func layoutSubviews() { super.layoutSubviews(); layer.cornerRadius = bounds.height/2; layer.borderColor = Style.border.resolvedColor(with: traitCollection).cgColor; setNeedsDisplay() }
    override func draw(_ rect: CGRect) {
        let s = bounds.width / 28.64
        let ctx = UIGraphicsGetCurrentContext()!; ctx.saveGState(); defer { ctx.restoreGState() }; ctx.scaleBy(x: s, y: s)
        Style.text.setStroke(); Style.text.setFill()
        let face = UIBezierPath(arcCenter: CGPoint(x: 13.3, y: 13.2), radius: 7.4, startAngle: .pi * 0.15, endAngle: .pi * 1.95, clockwise: true)
        face.lineWidth = 1.5; face.stroke()
        for x in [10.5, 15.8] { UIBezierPath(ovalIn: CGRect(x: x-0.85, y: 10, width: 1.7, height: 2)).fill() }
        let smile = UIBezierPath(); smile.move(to: CGPoint(x: 9.7, y: 15.1)); smile.addQuadCurve(to: CGPoint(x: 15.8, y: 15.1), controlPoint: CGPoint(x: 13, y: 19.6)); smile.lineWidth = 1.4; smile.stroke()
        let plus = UIBezierPath(); plus.move(to: CGPoint(x: 20.5, y: 15.5)); plus.addLine(to: CGPoint(x: 20.5, y: 22)); plus.move(to: CGPoint(x: 17.25, y: 18.75)); plus.addLine(to: CGPoint(x: 23.75, y: 18.75)); plus.lineWidth = 1.5; plus.lineCapStyle = .round; plus.stroke()
    }
}

final class BoostPill: UIView {
    let avatar = AvatarView()
    let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame); addSubview(avatar); addSubview(label)
        backgroundColor = Style.background; layer.borderWidth = 1
        isAccessibilityElement = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    func configure(_ boost: DisplayBoost, user: User?, category: UIContentSizeCategory) {
        let emoji = boost.content.unicodeScalars.contains { $0.properties.isEmojiPresentation }
        label.text = boost.content; label.textColor = Style.text
        label.font = Style.font(emoji ? 17.6 : 12.8, category: category)
        avatar.configure(user: user, id: boost.userID, size: 22)
        accessibilityLabel = "\(user?.name ?? "Someone") boosted \(boost.content)"
    }
    override func layoutSubviews() {
        super.layoutSubviews(); layer.cornerRadius = bounds.height/2
        layer.borderColor = Style.border.resolvedColor(with: traitCollection).cgColor
        let d = bounds.height - 6.64
        avatar.frame = CGRect(x: 1.6, y: 3.32, width: d, height: d)
        label.frame = CGRect(x: d+8.4, y: 0, width: bounds.width-d-11.6, height: bounds.height)
    }
}

final class DayView: UIView {
    let line = UIView()
    let pill = UIView()
    let title = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame); addSubview(line); addSubview(pill); pill.addSubview(title)
        line.backgroundColor = Style.bubble; pill.backgroundColor = Style.bubble
        title.textColor = Style.text; title.textAlignment = .center
        isAccessibilityElement = true; accessibilityTraits = .header
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    func configure(date: Date, category: UIContentSizeCategory) {
        title.text = Style.day.string(from: date).uppercased()
        title.font = Style.font(12.8, weight: .semibold, category: category)
        accessibilityLabel = title.text
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        line.frame = CGRect(x: 0, y: bounds.midY-1, width: bounds.width, height: 2)
        let w = min(bounds.width, title.sizeThatFits(CGSize(width: .greatestFiniteMagnitude, height: bounds.height)).width + 38.2)
        pill.frame = CGRect(x: (bounds.width-w)/2, y: 0, width: w, height: bounds.height)
        pill.layer.cornerRadius = bounds.height/2; title.frame = pill.bounds
    }
}

final class MessageCell: UICollectionViewCell, UITextViewDelegate, UIContextMenuInteractionDelegate {
    private let bubble = UIView()
    private let avatar = AvatarView()
    private let author = UILabel()
    private let time = UILabel()
    private let dots = UILabel()
    private let day = DayView()
    private var bodyViews: [UIView] = []
    private var boostViews: [UIView] = []
    private var metrics: MessageMetrics?
    private var copyText = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(day); contentView.addSubview(bubble); contentView.addSubview(avatar)
        bubble.layer.cornerRadius = 10.56; bubble.clipsToBounds = true
        for label in [author, time, dots] { bubble.addSubview(label); label.textColor = Style.text }
        time.alpha = 0.5; dots.alpha = 0.5; dots.text = "•••"
        bubble.addInteraction(UIContextMenuInteraction(delegate: self))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }

    func configure(_ m: MessageMetrics, users: [Int: User]) {
        let keepBody = metrics.map { $0.message.id == m.message.id && $0.category == m.category && $0.bubble.width == m.bubble.width } ?? false
        metrics = m
        accessibilityIdentifier = "message.\(m.message.id)"
        let p = m.presentation
        bubble.backgroundColor = m.message.isEmojiOnly ? .clear : (p.mentionsMe ? Style.mention : Style.bubble)
        author.text = users[m.message.creatorID]?.name
        author.font = Style.font(12.8, weight: .bold, category: m.category)
        author.isHidden = p.isThreaded
        time.text = Style.time.string(from: m.message.createdAt)
        time.font = Style.font(12.8, category: m.category)
        dots.font = Style.font(12.8, weight: .bold, category: m.category)
        avatar.configure(user: users[m.message.creatorID], id: m.message.creatorID, size: 35.27, bordered: true)
        avatar.isHidden = p.isThreaded
        day.isHidden = m.day == nil
        day.configure(date: m.message.createdAt, category: m.category)
        if !keepBody { bodyViews.forEach { $0.removeFromSuperview() }; bodyViews.removeAll() }
        boostViews.forEach { $0.removeFromSuperview() }; boostViews.removeAll()
        copyText = m.message.blocks.map { block in
            switch block {
            case .text(let t): return t
            case .mention(let id): return users[id]?.name ?? "Unknown"
            case .code(_, let source): return source
            }
        }.joined()
        if case .file(let name, _)? = m.message.attachment { copyText = name }
        for part in keepBody ? [] : m.parts {
            let view: UIView
            switch part.content {
            case .text(let text), .code(let text):
                let tv = UITextView(usingTextLayoutManager: false)
                tv.isEditable = false; tv.isSelectable = true; tv.isScrollEnabled = false
                tv.textContainer.lineFragmentPadding = 0
                tv.textContainerInset = .zero
                tv.backgroundColor = .clear; tv.delegate = self
                tv.attributedText = text
                tv.tintColor = Style.color(0x0066EF, 0x43ABFF)
                tv.accessibilityIdentifier = "text.\(m.message.id)"
                if case .code = part.content {
                    tv.backgroundColor = Style.background
                    tv.layer.cornerRadius = 6.4
                    tv.textContainerInset = UIEdgeInsets(top: 13.8, left: 13.8, bottom: 13.8, right: 13.8)
                }
                view = tv
            case .image(let color):
                // CampfireKit documents a solid fill as equivalent to Placeholder.pngData.
                view = UIView(); view.backgroundColor = UIColor(rgb: color)
                view.isAccessibilityElement = true; view.accessibilityLabel = "Image attachment"
            case .file(let name, let bytes):
                let file = FileView(); file.configure(name: name, bytes: bytes, category: m.category); view = file
            }
            view.frame = part.frame; bubble.addSubview(view); bodyViews.append(view)
        }
        for (i, boost) in m.boosts.enumerated() {
            let pill = BoostPill(frame: m.boostFrames[i])
            pill.configure(boost, user: users[boost.userID], category: m.category)
            bubble.addSubview(pill); boostViews.append(pill)
        }
        if let frame = m.addBoostFrame {
            let add = AddBoostView(frame: frame); bubble.addSubview(add); boostViews.append(add)
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.frame = bounds
        guard let m = metrics else { return }
        bubble.frame = m.bubble; avatar.frame = m.avatar; day.frame = m.day ?? .zero
        let rect = m.header
        let nameW = min(author.intrinsicContentSize.width, max(0, rect.width - time.intrinsicContentSize.width - 42))
        let timeW = min(time.intrinsicContentSize.width, rect.width)
        let dotsW: CGFloat = 24
        if m.presentation.isMine {
            var x = rect.maxX
            if !m.presentation.isThreaded { x -= nameW; author.frame = CGRect(x: x, y: rect.minY, width: nameW, height: rect.height); x -= 4 }
            x -= timeW; time.frame = CGRect(x: x, y: rect.minY, width: timeW, height: rect.height)
            dots.frame = CGRect(x: x-10-dotsW, y: rect.minY, width: dotsW, height: rect.height)
        } else {
            var x = rect.minX
            if !m.presentation.isThreaded { author.frame = CGRect(x: x, y: rect.minY, width: nameW, height: rect.height); x += nameW + 4 }
            time.frame = CGRect(x: x, y: rect.minY, width: timeW, height: rect.height)
            dots.frame = CGRect(x: x+timeW+10, y: rect.minY, width: dotsW, height: rect.height)
        }
    }

    func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        let copy = UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { [weak textView] _ in
            guard let textView else { return }
            let range = textView.selectedRange
            UIPasteboard.general.string = range.length > 0 ? (textView.text as NSString).substring(with: range) : textView.text
        }
        let reply = UIAction(title: "Reply", image: UIImage(systemName: "arrowshape.turn.up.left")) { _ in }
        return UIMenu(children: [copy, reply] + suggestedActions.filter { $0 is UIMenu })
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        // TextKit owns selection and range handles over text. The rest of a message has the same actions.
        if bodyViews.contains(where: { $0 is UITextView && $0.frame.contains(location) }) { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            UIMenu(children: [UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in UIPasteboard.general.string = self?.copyText }, UIAction(title: "Reply", image: UIImage(systemName: "arrowshape.turn.up.left")) { _ in }])
        }
    }
}

final class FileView: UIView {
    private let icon = UIImageView(image: UIImage(systemName: "doc.text.fill"))
    private let name = UILabel()
    private let download = UIImageView(image: UIImage(systemName: "arrow.down.to.line", withConfiguration: UIImage.SymbolConfiguration(weight: .bold)))
    private let share = UIImageView(image: UIImage(systemName: "square.and.arrow.up", withConfiguration: UIImage.SymbolConfiguration(weight: .semibold)))
    override init(frame: CGRect) {
        super.init(frame: frame)
        for v in [icon, name, download, share] { addSubview(v); v.tintColor = Style.text }
        icon.contentMode = .scaleAspectFit; download.contentMode = .scaleAspectFit; share.contentMode = .scaleAspectFit
        name.textColor = Style.text; name.lineBreakMode = .byTruncatingMiddle
        isAccessibilityElement = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    func configure(name: String, bytes: Int, category: UIContentSizeCategory) {
        self.name.text = name; self.name.font = Style.font(16, category: category)
        accessibilityLabel = "\(name), \(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))"
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        icon.frame = CGRect(x: 0, y: 3, width: 20, height: 24)
        share.frame = CGRect(x: bounds.width-24, y: 3, width: 20, height: 24)
        download.frame = CGRect(x: bounds.width-64, y: 4, width: 20, height: 22)
        name.frame = CGRect(x: 27, y: 0, width: max(10, bounds.width-102.4), height: bounds.height)
    }
}
