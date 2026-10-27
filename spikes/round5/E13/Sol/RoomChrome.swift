import UIKit

final class RoomHeader: UIView {
    let title = UIButton(type: .system)
    let more = Style.button("ellipsis", size: 23)
    let alerts = Style.button("bell.badge.fill", size: 22)
    let menu = Style.button("line.3.horizontal", size: 24)
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Style.background
        title.setTitle("General", for: .normal); title.titleLabel?.font = Style.font(16, .bold)
        title.setTitleColor(Style.background, for: .normal); title.backgroundColor = Style.text; title.layer.cornerRadius = 8
        title.accessibilityLabel = "General room"
        more.accessibilityLabel = "Room options"; alerts.accessibilityLabel = "Notifications"; menu.accessibilityLabel = "Menu"
        [title, more, alerts, menu].forEach(addSubview)
        alerts.layer.borderWidth = 3; alerts.layer.borderColor = UIColor.systemOrange.cgColor; alerts.layer.cornerRadius = 23.5
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        title.frame = CGRect(x: 10, y: 8, width: 97, height: 42)
        more.frame = CGRect(x: 113, y: 8, width: 42, height: 42)
        alerts.frame = CGRect(x: 157, y: 5, width: 47, height: 47)
        menu.frame = CGRect(x: bounds.width - 52, y: 8, width: 42, height: 42)
        more.layer.borderColor = Style.outline.resolvedColor(with: traitCollection).cgColor
        menu.layer.borderColor = Style.outline.resolvedColor(with: traitCollection).cgColor
    }
}
final class ComposerView: UIView {
    let search = Style.button("magnifyingglass", size: 24)
    let field = UIView()
    let speech = Style.button("bubble", size: 23)
    let attachment = Style.button("paperclip", size: 22)
    let send = Style.button("arrow.up", size: 23)
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Style.background
        addSubview(search); addSubview(field)
        [speech, attachment, send].forEach(field.addSubview)
        field.layer.borderWidth = 1; field.layer.cornerRadius = 21
        speech.layer.borderWidth = 0; attachment.layer.borderWidth = 0
        send.layer.borderWidth = 0; send.backgroundColor = Style.text; send.tintColor = Style.background
        search.accessibilityLabel = "Search"; speech.accessibilityLabel = "Message composer"; attachment.accessibilityLabel = "Attach file"; send.accessibilityLabel = "Send"
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        search.frame = CGRect(x: 14.01, y: 24, width: 42, height: 42)
        field.frame = CGRect(x: 66, y: 24, width: bounds.width-80, height: 42)
        speech.frame = CGRect(x: 6, y: 2, width: 38, height: 38)
        attachment.frame = CGRect(x: field.bounds.width - 85, y: 2, width: 38, height: 38)
        send.frame = CGRect(x: field.bounds.width - 39, y: 4, width: 34, height: 34); send.layer.cornerRadius = 17
        field.layer.borderColor = Style.outline.resolvedColor(with: traitCollection).cgColor
        search.layer.borderColor = Style.outline.resolvedColor(with: traitCollection).cgColor
    }
}

final class WelcomeCell: UICollectionViewCell {
    let card = UIView()
    let heading = UILabel()
    let subtitle = UILabel()
    let globe = Style.button("globe.americas.fill", size: 20)
    let link = UILabel()
    let qr = Style.button("qrcode.viewfinder", size: 22)
    let copy = Style.button("document.on.clipboard", size: 22)
    let share = Style.button("square.and.arrow.up", size: 22)
    let flame = FlameView()
    override init(frame: CGRect) {
        super.init(frame: frame)
        card.backgroundColor = Style.bubble; card.layer.cornerRadius = 10.56
        contentView.addSubview(card)
        [heading, subtitle, globe, link, qr, copy, share].forEach(card.addSubview)
        contentView.addSubview(flame)
        heading.text = "Welcome to Campfire"; heading.font = Style.font(16, .bold); heading.textAlignment = .center; heading.textColor = Style.text
        subtitle.text = "To invite people to chat, share the join link\nbelow."; subtitle.numberOfLines = 2; subtitle.font = Style.font(16); subtitle.textAlignment = .center; subtitle.textColor = Style.text
        link.text = "  ♟  http://127.0.0.1:3055/join/GwHG-HbZN"; link.font = Style.font(15); link.backgroundColor = Style.background; link.textColor = Style.text; link.layer.borderWidth = 1; link.layer.cornerRadius = 8; link.clipsToBounds = true
        flame.backgroundColor = .clear
        globe.setImage(nil, for: .normal); globe.setTitle("🌎", for: .normal); globe.titleLabel?.font = Style.font(16)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        card.frame = CGRect(x: 14, y: 109, width: bounds.width-28, height: 269)
        globe.frame = CGRect(x: 16, y: 16, width: 42, height: 42); globe.tintColor = .systemGreen
        flame.frame = CGRect(x: bounds.midX - 34.5, y: 85, width: 69, height: 69)
        heading.frame = CGRect(x: 10, y: 77, width: card.bounds.width-20, height: 23)
        subtitle.frame = CGRect(x: 10, y: 100, width: card.bounds.width-20, height: 46)
        link.frame = CGRect(x: 16, y: 160, width: card.bounds.width-32, height: 40)
        let middle = card.bounds.midX
        qr.frame = CGRect(x: middle - 78, y: 216, width: 42, height: 42)
        copy.frame = CGRect(x: middle - 26, y: 216, width: 42, height: 42)
        share.frame = CGRect(x: middle + 26, y: 216, width: 42, height: 42)
        [qr,copy,share,globe].forEach { $0.layer.borderColor = Style.outline.resolvedColor(with: traitCollection).cgColor }
        link.layer.borderColor = Style.outline.resolvedColor(with: traitCollection).cgColor
    }
}
final class FlameView: UIView {
    override func draw(_ rect: CGRect) {
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: 11)
        Style.color(0x310B3C).setFill(); path.fill()
        let colors: [UInt32] = [0xE71A96,0xEF3054,0xF77312,0xF5C935,0x55CFE9]
        for i in 0..<13 {
            let p = UIBezierPath(); p.lineWidth = 2.4; p.lineCapStyle = .round
            let x = CGFloat(i)*2.2 + 16
            p.move(to: CGPoint(x: x, y: 19 + CGFloat(abs(i-5))*2))
            p.addCurve(to: CGPoint(x: x + 10, y: 53 - CGFloat(abs(i-6))), controlPoint1: CGPoint(x: x+24, y: 45), controlPoint2: CGPoint(x: x+6, y: 43))
            Style.color(colors[min(4, i/3)]).setStroke(); p.stroke()
        }
    }
}
