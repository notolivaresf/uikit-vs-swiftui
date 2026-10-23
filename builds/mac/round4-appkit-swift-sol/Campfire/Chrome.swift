import AppKit

final class IconButton: NSButton {
    var symbol: String
    var filled = false
    var orangeRing = false
    init(_ symbol: String, label: String) {
        self.symbol = symbol
        super.init(frame: .zero)
        title = label; isBordered = false; setAccessibilityLabel(label)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: orangeRing ? 2 : 0, dy: orangeRing ? 2 : 0)
        fillRound(rect, radius: rect.height / 2, color: filled ? Style.text : Style.background)
        if !filled { strokeRound(rect, radius: rect.height / 2, color: Style.outline) }
        if orangeRing { strokeRound(bounds.insetBy(dx: -1, dy: -1), radius: bounds.height / 2, color: .systemOrange, width: 2.5) }
        let ink = filled ? Style.background : Style.text
        if symbol == "line.3.horizontal" {
            for y in [CGFloat(14), 21, 28] { fillRound(NSRect(x: rect.midX - 9.5, y: y, width: 19, height: 2.5), radius: 1.25, color: ink) }
        } else if symbol == "ellipsis" {
            for x in [-7.0, 0, 7] { fillRound(NSRect(x: rect.midX + x - 2.5, y: rect.midY - 2.5, width: 5, height: 5), radius: 2.5, color: ink) }
        } else if symbol == "bell.badge.fill" {
            drawSymbol("bell.fill", in: NSRect(x: rect.midX - 11, y: rect.midY - 12, width: 18, height: 23), color: ink, weight: .semibold)
            drawSymbol("exclamationmark.triangle.fill", in: NSRect(x: rect.midX - 1, y: rect.midY - 3, width: 13, height: 14), color: ink)
        } else { drawSymbol(symbol, in: rect.insetBy(dx: filled ? 9 : 11, dy: filled ? 9 : 11), color: ink, weight: filled ? .heavy : .semibold) }
    }
}
final class HeaderView: FlippedView {
    let room = NSButton(title: "General", target: nil, action: nil)
    let more = IconButton("ellipsis", label: "Room options")
    let bell = IconButton("bell.badge.fill", label: "Notifications")
    let menuButton = IconButton("line.3.horizontal", label: "Menu")
    override init(frame: NSRect) {
        super.init(frame: frame)
        room.isBordered = false; room.font = .systemFont(ofSize: 16, weight: .bold)
        room.wantsLayer = true; room.layer?.cornerRadius = 8
        bell.orangeRing = true
        [room, more, bell, menuButton].forEach { addSubview($0) }
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() {
        super.layout()
        room.frame = NSRect(x: 10, y: 8, width: 97, height: 42)
        more.frame = NSRect(x: 113, y: 8, width: 42, height: 42)
        bell.frame = NSRect(x: 160, y: 8, width: 42, height: 42)
        menuButton.frame = NSRect(x: bounds.width - 53, y: 8, width: 42, height: 42)
    }
    override func draw(_ dirtyRect: NSRect) {
        Style.background.setFill(); bounds.fill()
        room.layer?.backgroundColor = Style.text.cgColor
        room.attributedTitle = NSAttributedString(string: "General", attributes: [.font: NSFont.systemFont(ofSize: 16, weight: .bold), .foregroundColor: Style.background])
    }
}
final class ComposerView: FlippedView {
    let search = IconButton("magnifyingglass", label: "Search")
    let send = IconButton("arrow.up", label: "Send message")
    let attachment = NSButton(title: "Attach file", target: nil, action: nil)
    override init(frame: NSRect) {
        super.init(frame: frame); send.filled = true
        addSubview(search); addSubview(send)
        attachment.isBordered = false; attachment.image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "Attach file"); attachment.image = attachment.image?.withSymbolConfiguration(.init(pointSize: 22, weight: .semibold)); attachment.imagePosition = .imageOnly; attachment.contentTintColor = Style.text; addSubview(attachment)
        setAccessibilityLabel("Message composer")
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() {
        super.layout()
        search.frame = NSRect(x: 14, y: 24, width: 42, height: 42)
        send.frame = NSRect(x: bounds.width - 53, y: 28, width: 34, height: 34)
        attachment.frame = NSRect(x: bounds.width - 95, y: 27, width: 33, height: 35)
    }
    override func draw(_ dirtyRect: NSRect) {
        Style.background.setFill(); bounds.fill()
        strokeRound(NSRect(x: 66, y: 24, width: bounds.width - 80, height: 42), radius: 22, color: Style.outline)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 83, y: 52)); path.line(to: NSPoint(x: 81, y: 56)); path.line(to: NSPoint(x: 88, y: 53))
        path.curve(to: NSPoint(x: 101, y: 44), controlPoint1: NSPoint(x: 99, y: 55), controlPoint2: NSPoint(x: 104, y: 48))
        path.curve(to: NSPoint(x: 81, y: 42), controlPoint1: NSPoint(x: 98, y: 33), controlPoint2: NSPoint(x: 80, y: 33))
        path.curve(to: NSPoint(x: 83, y: 52), controlPoint1: NSPoint(x: 79, y: 47), controlPoint2: NSPoint(x: 80, y: 50))
        Style.text.setStroke(); path.lineWidth = 1.8; path.lineJoinStyle = .round; path.stroke()
    }
}
final class WelcomeView: FlippedView {
    override func draw(_ dirtyRect: NSRect) {
        let r = NSRect(x: 14, y: 109, width: bounds.width - 28, height: 269)
        fillRound(r, radius: 10.56, color: Style.bubble)
        let icon = NSRect(x: bounds.midX - 34.5, y: 85, width: 69, height: 69)
        fillRound(icon, radius: 12, color: NSColor(hex: "4C105A"))
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: icon, xRadius: 12, yRadius: 12).addClip()
        NSGradient(starting: NSColor(hex: "721A7B"), ending: NSColor(hex: "210B29"))?.draw(in: icon, angle: 70)
        let colors = ["FF2BA0", "F12E93", "E5335E", "F94B20", "FF8611", "FFBF10", "FFE241", "F7E47B", "FFFFFF", "75D8E0", "36AAD3"]
        for i in 0..<11 {
            let x = icon.minX + 19 + CGFloat(i) * 2.8
            let y = icon.minY + 16 + CGFloat(abs(i - 4)) * 1.1
            let path = NSBezierPath(); path.move(to: NSPoint(x: x, y: y))
            path.curve(to: NSPoint(x: x + 11, y: icon.minY + 51 - CGFloat(abs(i - 5)) * 0.8), controlPoint1: NSPoint(x: x - 10, y: y - 15), controlPoint2: NSPoint(x: x + 26, y: icon.minY + 65))
            NSColor(hex: colors[i]).setStroke(); path.lineWidth = 1.7; path.lineCapStyle = .round; path.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
        let globe = NSRect(x: 30, y: 125, width: 42, height: 42)
        fillRound(globe, radius: 21, color: Style.background); strokeRound(globe, radius: 21, color: Style.outline)
        drawText("🌐", rect: globe.insetBy(dx: 10, dy: 11), size: 16, centered: true)
        drawText("Welcome to Campfire", rect: NSRect(x: 25, y: 189, width: bounds.width - 50, height: 25), size: 16, weight: .bold, centered: true)
        drawText("To invite people to chat, share the join link\nbelow.", rect: NSRect(x: 25, y: 212, width: bounds.width - 50, height: 50), size: 16, centered: true)
        let link = NSRect(x: 30, y: 269, width: bounds.width - 60, height: 40)
        fillRound(link, radius: 8, color: Style.background); strokeRound(link, radius: 8, color: Style.outline)
        drawSymbol("person.badge.plus.fill", in: NSRect(x: link.minX + 14, y: link.minY + 10, width: 17, height: 20))
        drawText("http://127.0.0.1:3055/join/GwHG-HbZN", rect: NSRect(x: link.minX + 42, y: link.minY + 10, width: link.width - 50, height: 25), size: min(16, (bounds.width - 75) / 22))
        for (i, symbol) in ["qrcode", "doc.on.clipboard", "square.and.arrow.up"].enumerated() {
            let r = NSRect(x: bounds.midX - 78 + CGFloat(i) * 52, y: 325, width: 42, height: 42)
            fillRound(r, radius: 21, color: Style.background); strokeRound(r, radius: 21, color: Style.outline); drawSymbol(symbol, in: r.insetBy(dx: 11, dy: 11))
        }
    }
}
