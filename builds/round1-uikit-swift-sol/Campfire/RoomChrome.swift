import UIKit

enum SymbolArtwork {
    static let speech = UIGraphicsImageRenderer(size: CGSize(width: 28, height: 28)).image { _ in
        UIColor.black.setStroke()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 8, y: 22))
        path.addCurve(to: CGPoint(x: 4, y: 8), controlPoint1: CGPoint(x: -1, y: 20), controlPoint2: CGPoint(x: 0, y: 12))
        path.addCurve(to: CGPoint(x: 25, y: 10), controlPoint1: CGPoint(x: 10, y: 1), controlPoint2: CGPoint(x: 24, y: 3))
        path.addCurve(to: CGPoint(x: 12, y: 23), controlPoint1: CGPoint(x: 31, y: 20), controlPoint2: CGPoint(x: 20, y: 24))
        path.addLine(to: CGPoint(x: 4, y: 27)); path.addLine(to: CGPoint(x: 8, y: 22))
        path.lineWidth = 2; path.lineCapStyle = .round; path.lineJoinStyle = .round; path.stroke()
    }.withRenderingMode(.alwaysTemplate)

    static let notifications = UIGraphicsImageRenderer(size: CGSize(width: 28, height: 28)).image { renderer in
        UIColor.black.setFill()
        let bell = UIBezierPath()
        bell.move(to: CGPoint(x: 3, y: 22)); bell.addLine(to: CGPoint(x: 6, y: 18)); bell.addLine(to: CGPoint(x: 7, y: 12))
        bell.addCurve(to: CGPoint(x: 22, y: 12), controlPoint1: CGPoint(x: 8, y: 2), controlPoint2: CGPoint(x: 22, y: 3))
        bell.addLine(to: CGPoint(x: 23, y: 18)); bell.addLine(to: CGPoint(x: 25, y: 22)); bell.close(); bell.fill()
        UIBezierPath(ovalIn: CGRect(x: 12, y: 20, width: 6, height: 6)).fill()
        UIBezierPath(roundedRect: CGRect(x: 13, y: 2, width: 2, height: 5), cornerRadius: 1).fill()
        let triangle = UIBezierPath(); triangle.move(to: CGPoint(x: 20, y: 11)); triangle.addLine(to: CGPoint(x: 28, y: 27)); triangle.addLine(to: CGPoint(x: 11, y: 27)); triangle.close()
        renderer.cgContext.setBlendMode(.clear); triangle.lineWidth = 2; triangle.lineJoinStyle = .round; triangle.stroke()
        renderer.cgContext.setBlendMode(.normal); UIColor.black.setFill(); triangle.fill()
        renderer.cgContext.setBlendMode(.clear); UIBezierPath(roundedRect: CGRect(x: 19, y: 16, width: 2, height: 5), cornerRadius: 1).fill()
        UIBezierPath(ovalIn: CGRect(x: 19, y: 23, width: 2, height: 2)).fill()
    }.withRenderingMode(.alwaysTemplate)
}

func iconButton(_ symbol: String, label: String, size: CGFloat = 21) -> UIButton {
    let b = UIButton(type: .custom)
    b.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: .semibold)), for: .normal)
    b.tintColor = Style.text; b.backgroundColor = Style.background
    b.layer.borderWidth = 1; b.accessibilityLabel = label
    return b
}

final class RoomHeader: UIView {
    private let room = UIButton(type: .custom)
    private let more = iconButton("ellipsis", label: "Room options")
    private let bell = iconButton("bell.badge.fill", label: "Notifications paused")
    private let menu = iconButton("line.3.horizontal", label: "Menu", size: 24)
    override init(frame: CGRect) {
        super.init(frame: frame); backgroundColor = Style.background
        room.setTitle("General", for: .normal)
        room.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        room.backgroundColor = Style.text; room.setTitleColor(Style.background, for: .normal)
        room.layer.cornerRadius = 8
        bell.setImage(SymbolArtwork.notifications, for: .normal)
        for b in [room, more, bell, menu] { addSubview(b) }
        accessibilityIdentifier = "room.header"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    override func layoutSubviews() {
        super.layoutSubviews()
        room.frame = CGRect(x: 10, y: 8, width: 97, height: 42)
        more.frame = CGRect(x: 113, y: 8, width: 42, height: 42)
        bell.frame = CGRect(x: 160, y: 8, width: 42, height: 42)
        menu.frame = CGRect(x: bounds.width-53, y: 8, width: 42, height: 42)
        for b in [more, bell, menu] { b.layer.cornerRadius = 21; b.layer.borderColor = Style.outline.resolvedColor(with: traitCollection).cgColor }
        bell.layer.shadowColor = UIColor(hex: 0xFF7410).cgColor
        bell.layer.shadowOpacity = 1; bell.layer.shadowRadius = 0; bell.layer.shadowOffset = .zero
        bell.layer.shadowPath = UIBezierPath(ovalIn: bell.bounds.insetBy(dx: -3, dy: -3)).cgPath
    }
    override func traitCollectionDidChange(_ previous: UITraitCollection?) { super.traitCollectionDidChange(previous); setNeedsLayout() }
}

final class ComposerView: UIView {
    private let search = iconButton("magnifyingglass", label: "Search", size: 24)
    private let capsule = UIView()
    private let chat = iconButton("bubble", label: "Message", size: 24)
    private let attachment = iconButton("paperclip", label: "Attach file", size: 23)
    private let send = UIButton(type: .custom)
    override init(frame: CGRect) {
        super.init(frame: frame); backgroundColor = Style.background
        addSubview(search); addSubview(capsule)
        capsule.addSubview(chat); capsule.addSubview(attachment); capsule.addSubview(send)
        capsule.layer.borderWidth = 1
        chat.layer.borderWidth = 0; attachment.layer.borderWidth = 0
        chat.setImage(SymbolArtwork.speech, for: .normal)
        send.setImage(UIImage(systemName: "arrow.up", withConfiguration: UIImage.SymbolConfiguration(pointSize: 23, weight: .heavy)), for: .normal)
        send.backgroundColor = Style.text; send.tintColor = Style.background; send.accessibilityLabel = "Send"
        capsule.accessibilityLabel = "Message composer"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    override func layoutSubviews() {
        super.layoutSubviews()
        let y: CGFloat = 24
        search.frame = CGRect(x: 14, y: y, width: 42, height: 42); search.layer.cornerRadius = 21
        search.layer.borderColor = Style.outline.resolvedColor(with: traitCollection).cgColor
        capsule.frame = CGRect(x: 66, y: y, width: bounds.width-80, height: 42)
        capsule.layer.cornerRadius = 21; capsule.layer.borderColor = Style.outline.resolvedColor(with: traitCollection).cgColor
        chat.frame = CGRect(x: 8, y: 5, width: 32, height: 32)
        send.frame = CGRect(x: capsule.bounds.width-39, y: 4, width: 34, height: 34); send.layer.cornerRadius = 17
        attachment.frame = CGRect(x: capsule.bounds.width-81, y: 5, width: 32, height: 32)
    }
    override func traitCollectionDidChange(_ previous: UITraitCollection?) { super.traitCollectionDidChange(previous); setNeedsLayout() }
}

final class BenchmarkBar: UIView {
    let state = UILabel()
    let done = UILabel()
    var action: ((String) -> Void)?
    let names = ["Reset", "Jump to 2500", "Load older", "Start stream", "Text size +", "Boost burst"]
    private var buttons: [UIButton] = []
    override init(frame: CGRect) {
        super.init(frame: frame); backgroundColor = Style.bubble
        for name in names {
            let b = UIButton(type: .system)
            b.setTitle(name, for: .normal); b.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
            b.setTitleColor(Style.text, for: .normal); b.layer.cornerRadius = 6; b.backgroundColor = Style.background
            b.accessibilityIdentifier = name
            b.addAction(UIAction { [weak self] _ in self?.action?(name) }, for: .touchUpInside)
            addSubview(b); buttons.append(b)
        }
        state.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        state.textColor = Style.text; state.numberOfLines = 2
        state.accessibilityIdentifier = "benchmark.state"
        done.font = .systemFont(ofSize: 10, weight: .semibold); done.textColor = Style.text
        done.text = "Stream done"; done.isHidden = true; done.accessibilityIdentifier = "Stream done"
        addSubview(state); addSubview(done)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    override func layoutSubviews() {
        super.layoutSubviews()
        let w = (bounds.width-24)/3
        for (i,b) in buttons.enumerated() { b.frame = CGRect(x: 6+CGFloat(i%3)*(w+6), y: 4+CGFloat(i/3)*31, width: w, height: 27) }
        state.frame = CGRect(x: 6, y: 66, width: bounds.width-12, height: 28)
        done.frame = CGRect(x: 6, y: 94, width: bounds.width-12, height: 14)
    }
}

private final class InviteLabel: UILabel {
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: UIEdgeInsets(top: 0, left: 41, bottom: 0, right: 10))) }
}

final class WelcomeCell: UICollectionViewCell {
    private let card = UIView()
    private let globe = iconButton("globe.americas.fill", label: "Public room", size: 18)
    private let title = UILabel()
    private let subtitle = UILabel()
    private let link = InviteLabel()
    private let inviteIcon = UIImageView(image: UIImage(systemName: "person.badge.plus.fill"))
    private let logo = CampfireMark()
    private let qr = iconButton("qrcode.viewfinder", label: "QR code")
    private let copy = iconButton("doc.on.clipboard", label: "Copy invite link")
    private let share = iconButton("square.and.arrow.up", label: "Share invite link")
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(card); contentView.addSubview(logo)
        card.backgroundColor = Style.bubble; card.layer.cornerRadius = 10.56
        for v in [globe,title,subtitle,link,qr,copy,share] { card.addSubview(v) }
        title.text = "Welcome to Campfire"; title.font = .systemFont(ofSize: 16, weight: .bold)
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
        paragraph.minimumLineHeight = 22.4; paragraph.maximumLineHeight = 22.4
        subtitle.attributedText = NSAttributedString(string: "To invite people to chat, share the join link below.", attributes: [.font: UIFont.systemFont(ofSize: 16), .paragraphStyle: paragraph, .foregroundColor: Style.text])
        subtitle.numberOfLines = 0
        globe.setImage(nil, for: .normal); globe.setTitle("🌎", for: .normal); globe.titleLabel?.font = .systemFont(ofSize: 16)
        for l in [title,subtitle,link] { l.textAlignment = .center; l.textColor = Style.text }
        link.text = "http://127.0.0.1:3055/join/GwHG-HbZN"; link.font = .systemFont(ofSize: 16)
        link.textAlignment = .left; link.addSubview(inviteIcon)
        inviteIcon.tintColor = Style.text; inviteIcon.contentMode = .scaleAspectFit
        link.adjustsFontSizeToFitWidth = true; link.minimumScaleFactor = 0.7
        link.backgroundColor = Style.background; link.layer.cornerRadius = 8; link.clipsToBounds = true; link.layer.borderWidth = 1
        title.accessibilityTraits = .header
    }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.frame = bounds
        card.frame = CGRect(x: 14, y: 109, width: bounds.width-28, height: 269)
        logo.frame = CGRect(x: (bounds.width-69)/2, y: 85, width: 69, height: 69)
        globe.frame = CGRect(x: 16, y: 16, width: 42, height: 42)
        title.frame = CGRect(x: 16, y: 76, width: card.bounds.width-32, height: 23)
        subtitle.frame = CGRect(x: 22, y: 97, width: card.bounds.width-44, height: 46)
        link.frame = CGRect(x: 16, y: 160, width: card.bounds.width-32, height: 40)
        inviteIcon.frame = CGRect(x: 14, y: 10, width: 18, height: 20)
        let start = (card.bounds.width-146)/2 - 5.2
        for (i,b) in [qr,copy,share].enumerated() { b.frame = CGRect(x: start+CGFloat(i)*52, y: 216, width: 42, height: 42) }
        for b in [globe,qr,copy,share] { b.layer.cornerRadius = 21; b.layer.borderColor = Style.outline.resolvedColor(with: traitCollection).cgColor }
        link.layer.borderColor = Style.outline.resolvedColor(with: traitCollection).cgColor
    }
}

/// A small vector mark, drawn in UIKit rather than bundling an unrelated bitmap.
final class CampfireMark: UIView {
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear; isOpaque = false }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    override func draw(_ rect: CGRect) {
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.saveGState(); defer { ctx.restoreGState() }
        let shape = UIBezierPath(roundedRect: bounds, cornerRadius: bounds.width*0.17)
        shape.addClip()
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor(hex: 0x721F83).cgColor, UIColor(hex: 0x230A2A).cgColor] as CFArray, locations: [0,1])!
        ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: bounds.width*0.8, y: bounds.height), options: [])
        ctx.scaleBy(x: bounds.width/69, y: bounds.height/69)
        let strokes: [(CGFloat,CGFloat,CGFloat,CGFloat)] = [(18,35,29,51),(20,30,33,54),(20,23,37,54),(21,16,41,54),(22,23,45,52),(26,24,48,49),(29,22,50,45),(31,28,52,42),(35,15,51,37),(38,22,51,40),(44,23,52,35)]
        let flame = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor(hex: 0xEF139A).cgColor,UIColor(hex: 0xFF3B36).cgColor,UIColor(hex: 0xFFBD15).cgColor,UIColor(hex: 0xFFF6A0).cgColor,UIColor(hex: 0x58C7FF).cgColor] as CFArray, locations: [0,0.4,0.65,0.8,1])!
        for (x1,y1,x2,y2) in strokes {
            UIColor.black.withAlphaComponent(0.65).setStroke()
            let shadow = UIBezierPath(); shadow.move(to: CGPoint(x: x1+1, y: y1+2)); shadow.addLine(to: CGPoint(x: x2+1, y: y2+2)); shadow.lineWidth = 2.7; shadow.lineCapStyle = .round; shadow.stroke()
            ctx.saveGState()
            let path = UIBezierPath(); path.move(to: CGPoint(x: x1, y: y1)); path.addLine(to: CGPoint(x: x2, y: y2))
            ctx.addPath(path.cgPath); ctx.setLineWidth(1.9); ctx.setLineCap(.round); ctx.replacePathWithStrokedPath(); ctx.clip()
            ctx.drawLinearGradient(flame, start: CGPoint(x: x1, y: y1), end: CGPoint(x: x2, y: y2), options: [.drawsBeforeStartLocation,.drawsAfterEndLocation])
            ctx.restoreGState()
        }
    }
}
