import UIKit
import CampfireKit

/// The message row both views show: day separator, avatar, name and time, bubble with a text view, an image or a file,
/// and the boost pills. Frames come from `RowGeometry`; there is no Auto Layout inside.
public final class RowView: UIView {
    private let separator = UILabel()
    private let avatar = UILabel()
    private let name = UILabel()
    private let time = UILabel()
    private let bubble = UIView()
    public let textView = UITextView()
    private let imageBox = UIView()
    private let fileLabel = UILabel()
    private var pills: [PillView] = []
    private let addBoost = UILabel()
    private var geometry = RowGeometry()
    public private(set) var itemID = 0
    private var lastItem: RowItem?
    private var lastUsers: [UserID: User] = [:]
    private var lastStyle = RowStyle(width: 0, category: .large)

    public override init(frame: CGRect) {
        super.init(frame: frame)
        separator.textAlignment = .center
        separator.layer.cornerRadius = 11; separator.layer.masksToBounds = true
        separator.backgroundColor = .tertiarySystemFill; separator.textColor = .secondaryLabel
        avatar.textAlignment = .center; avatar.textColor = .white
        avatar.layer.masksToBounds = true
        time.textColor = .label; time.alpha = 0.5
        bubble.layer.cornerRadius = 10.56; bubble.layer.masksToBounds = true
        textView.isEditable = false; textView.isSelectable = true; textView.isScrollEnabled = false
        textView.textContainerInset = .zero; textView.textContainer.lineFragmentPadding = 0
        textView.backgroundColor = .clear
        textView.adjustsFontForContentSizeCategory = false
        fileLabel.textColor = .label
        addBoost.text = "+"; addBoost.textAlignment = .center; addBoost.textColor = .secondaryLabel
        addBoost.backgroundColor = .tertiarySystemFill; addBoost.layer.cornerRadius = 14; addBoost.layer.masksToBounds = true
        for v in [separator, avatar, name, time, bubble, imageBox, fileLabel, textView, addBoost] { addSubview(v) }
        bubble.backgroundColor = .secondarySystemBackground
        backgroundColor = .clear
    }
    public required init?(coder: NSCoder) { fatalError() }

    /// Fills the row from its geometry. Cost: one geometry pass (the text, the frames) plus setting the views.
    public func configure(_ item: RowItem, users: [UserID: User], style: RowStyle) {
        let g = RowGeometry.make(item, users: users, style: style)
        apply(g, item, users: users, style: style)
    }

    /// What a self-sizing cell answers when the system asks how tall it is at `width`: measured now, nothing saved.
    public func fittingHeight(width: CGFloat) -> CGFloat {
        guard let item = lastItem else { return 44 }
        var style = lastStyle
        style.width = width
        return HeightStore.measure(item, users: lastUsers, style: style)
    }

    func apply(_ g: RowGeometry, _ item: RowItem, users: [UserID: User], style: RowStyle) {
        geometry = g
        lastItem = item; lastUsers = users; lastStyle = style
        let m = item.message
        itemID = m.id
        let f = RowFonts.forCategory(style.category)
        func place(_ v: UIView, _ r: CGRect?) { v.isHidden = r == nil; if let r { v.frame = r } }
        if let s = g.separator { separator.font = f.separator; separator.text = RowGeometry.dayString(m.createdAt) ; place(separator, s) } else { separator.isHidden = true }
        if let a = g.avatar {
            let u = users[m.creatorID]
            avatar.font = .systemFont(ofSize: 15, weight: .semibold)
            avatar.text = String(u?.name.first ?? "?")
            let c = u?.avatar ?? RGB(r: 128, g: 128, b: 128)
            avatar.backgroundColor = UIColor(red: CGFloat(c.r) / 255, green: CGFloat(c.g) / 255, blue: CGFloat(c.b) / 255, alpha: 1)
            avatar.layer.cornerRadius = a.width / 2
            place(avatar, a)
        } else { avatar.isHidden = true }
        if let n = g.name { name.font = f.author; name.text = users[m.creatorID]?.name; place(name, n) } else { name.isHidden = true }
        if let t = g.time { time.font = f.time; time.text = RowGeometry.timeString(m.createdAt); place(time, t) } else { time.isHidden = true }
        if let b = g.bubble {
            bubble.isHidden = false; bubble.frame = b
            bubble.backgroundColor = item.presentation.mentionsMe ? UIColor.systemRed.withAlphaComponent(0.15) : .secondarySystemBackground
        } else { bubble.isHidden = true }
        if let t = g.text { textView.attributedText = g.attributedText; place(textView, t) } else { textView.isHidden = true }
        if let i = g.image, case .image(_, _, let c)? = m.attachment {
            imageBox.backgroundColor = UIColor(red: CGFloat(c.r) / 255, green: CGFloat(c.g) / 255, blue: CGFloat(c.b) / 255, alpha: 1)
            place(imageBox, i)
        } else { imageBox.isHidden = true }
        if let r = g.file, case .file(let fname, let bytes)? = m.attachment {
            fileLabel.font = f.body; fileLabel.text = "  \(fname)  (\(bytes / 1024) KB)"; place(fileLabel, r)
        } else { fileLabel.isHidden = true }
        while pills.count < g.pills.count { let p = PillView(); addSubview(p); pills.append(p) }
        for (i, p) in pills.enumerated() {
            if i < g.pills.count {
                let b = m.boosts[i]
                p.set(booster: users[b.boosterID], emoji: b.content, font: f.boost)
                p.isHidden = false; p.frame = g.pills[i]
            } else { p.isHidden = true }
        }
        place(addBoost, g.addBoost)
    }
}

final class PillView: UIView {
    private let avatar = UILabel()
    private let emoji = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .tertiarySystemFill; layer.cornerRadius = 14; layer.masksToBounds = true
        avatar.textAlignment = .center; avatar.font = .systemFont(ofSize: 11, weight: .semibold); avatar.textColor = .white
        avatar.layer.cornerRadius = 10; avatar.layer.masksToBounds = true
        addSubview(avatar); addSubview(emoji)
    }
    required init?(coder: NSCoder) { fatalError() }
    func set(booster: User?, emoji text: String, font: UIFont) {
        avatar.text = String(booster?.name.first ?? "?")
        let c = booster?.avatar ?? RGB(r: 128, g: 128, b: 128)
        avatar.backgroundColor = UIColor(red: CGFloat(c.r) / 255, green: CGFloat(c.g) / 255, blue: CGFloat(c.b) / 255, alpha: 1)
        emoji.text = text; emoji.font = font
    }
    override func layoutSubviews() {
        avatar.frame = CGRect(x: 8, y: 4, width: 20, height: 20)
        emoji.frame = CGRect(x: 32, y: 0, width: bounds.width - 40, height: bounds.height)
    }
}
