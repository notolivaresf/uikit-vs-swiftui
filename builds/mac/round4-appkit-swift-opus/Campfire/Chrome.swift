import AppKit

/// Passes scroll-wheel events over chrome that floats on the room through to the room.
class PassThroughView: NSView {
    weak var scrollTarget: NSScrollView?
    override var isFlipped: Bool { true }
    override func scrollWheel(with event: NSEvent) {
        if let t = scrollTarget { t.scrollWheel(with: event) } else { super.scrollWheel(with: event) }
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

/// Room header: "General", the actions and notification buttons, and the menu button, over a fade.
final class HeaderView: PassThroughView {
    override func draw(_ dirtyRect: NSRect) {
        // Solid for the top 11 pt, then fades out by the header's bottom edge.
        let solid: CGFloat = 11
        Palette.background.setFill()
        CGRect(x: 0, y: 0, width: bounds.width, height: solid).fill()
        if let bg = Palette.background.usingColorSpace(.sRGB),
           let gradient = NSGradient(starting: bg, ending: bg.withAlphaComponent(0)) {
            gradient.draw(in: CGRect(x: 0, y: solid, width: bounds.width, height: bounds.height - solid), angle: 90)
        }

        // "General"
        let pill = CGRect(x: 10, y: 8, width: 96.7, height: 41.3)
        Palette.strong.setFill()
        NSBezierPath(roundedRect: pill, xRadius: 10.56, yRadius: 10.56).fill()
        let font = NSFont.systemFont(ofSize: 16, weight: .heavy)
        let title = NSAttributedString(string: "General", attributes: [.font: font, .foregroundColor: Palette.onStrong])
        let ts = title.size()
        title.draw(at: CGPoint(x: pill.midX - ts.width / 2, y: pill.midY - font.lineBoxHeight / 2 + 0.6))

        // Actions
        let actions = CGRect(x: 113.3, y: 8.2, width: 41, height: 41)
        circleButton(actions)
        Draw.dots(at: CGPoint(x: actions.midX - 8.25 * 1.15, y: actions.minY), height: actions.height, color: Palette.text, scale: 1.15)

        // Notifications (with the orange alert ring)
        let bell = CGRect(x: 160, y: 8.2, width: 41, height: 41)
        Palette.alert.setStroke()
        let ring = NSBezierPath(ovalIn: bell.insetBy(dx: -1.5, dy: -1.5))
        ring.lineWidth = 3
        ring.stroke()
        circleButton(bell)
        Symbols.draw("bell.fill", size: 15, weight: .bold, color: Palette.text, center: CGPoint(x: bell.midX - 3, y: bell.midY - 2.5))
        let badgeCenter = CGPoint(x: bell.midX + 4.4, y: bell.midY + 3.2)
        Symbols.draw("triangle.fill", size: 16, weight: .black, color: Palette.background, center: badgeCenter)
        Symbols.draw("triangle.fill", size: 12.5, weight: .black, color: Palette.text, center: badgeCenter)
        Symbols.draw("exclamationmark", size: 7, weight: .black, color: Palette.background, center: CGPoint(x: badgeCenter.x, y: badgeCenter.y + 1))

        // Menu
        let menu = CGRect(x: bounds.width - 52.5, y: 8.2, width: 41, height: 41)
        circleButton(menu)
        Palette.text.setFill()
        for i in 0..<3 {
            NSBezierPath(roundedRect: CGRect(x: menu.midX - 9.6, y: menu.midY - 7.4 + CGFloat(i) * 6.3, width: 19.2, height: 2.6),
                         xRadius: 1.3, yRadius: 1.3).fill()
        }
    }

    private func circleButton(_ r: CGRect) {
        Draw.circle(r, fill: Palette.background)
        Draw.ring(r, stroke: Palette.borderDarker)
    }
}

/// The composer: search, message field with attach and send. Drawn only.
final class ComposerView: PassThroughView {
    override func draw(_ dirtyRect: NSRect) {
        Palette.background.setFill()
        bounds.fill()
        let top: CGFloat = 24
        let search = CGRect(x: 14, y: top, width: 41.6, height: 41.6)
        Draw.circle(search, fill: Palette.background)
        Draw.ring(search, stroke: Palette.borderDarker)
        Symbols.draw("magnifyingglass", size: 19, weight: .bold, color: Palette.text, center: CGPoint(x: search.midX, y: search.midY))

        let field = CGRect(x: 66, y: top, width: bounds.width - 66 - 14, height: 41.6)
        let path = NSBezierPath(roundedRect: field.insetBy(dx: 0.5, dy: 0.5), xRadius: field.height / 2, yRadius: field.height / 2)
        Palette.background.setFill(); path.fill()
        Palette.borderDarker.setStroke(); path.lineWidth = 1; path.stroke()
        Symbols.draw("bubble.left", size: 19, weight: .medium, color: Palette.text, center: CGPoint(x: field.minX + 25, y: field.midY))
        let send = CGRect(x: field.maxX - 4 - 34, y: field.midY - 17, width: 34, height: 34)
        Symbols.draw("paperclip", size: 18, weight: .medium, color: Palette.text, center: CGPoint(x: send.minX - 23.5, y: field.midY))
        Draw.circle(send, fill: Palette.strong)
        Symbols.draw("arrow.up", size: 16, weight: .heavy, color: Palette.onStrong, center: CGPoint(x: send.midX, y: send.midY))
    }
}

/// Top of the room's history: Campfire's welcome card.
final class WelcomeView: NSView {
    override var isFlipped: Bool { true }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let W = bounds.width
        let card = CGRect(x: 14, y: 109, width: W - 28.3, height: 269)
        Palette.bubble.setFill()
        NSBezierPath(roundedRect: card, xRadius: 12.8, yRadius: 12.8).fill()

        drawLogo(CGRect(x: card.midX - 34, y: 85, width: 68, height: 69))

        let globe = CGRect(x: 29.8, y: 125, width: 41.6, height: 41.6)
        Draw.circle(globe, fill: Palette.background)
        Draw.ring(globe, stroke: Palette.borderDarker)
        let g = NSAttributedString(string: "🌎", attributes: [.font: NSFont.systemFont(ofSize: 15)])
        let gs = g.size()
        g.draw(at: CGPoint(x: globe.midX - gs.width / 2, y: globe.midY - gs.height / 2))

        let titleFont = NSFont.systemFont(ofSize: 16.2, weight: .bold)
        let title = NSAttributedString(string: "Welcome to Campfire", attributes: [.font: titleFont, .foregroundColor: Palette.text])
        let tsz = title.size()
        title.draw(at: CGPoint(x: card.midX - tsz.width / 2, y: 195.8 - titleFont.lineBoxHeight / 2 + 1))

        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.minimumLineHeight = 23
        para.maximumLineHeight = 23
        let bodyFont = NSFont.systemFont(ofSize: 16)
        let body = NSAttributedString(string: "To invite people to chat, share the join link below.",
                                      attributes: [.font: bodyFont, .foregroundColor: Palette.text, .paragraphStyle: para,
                                                   .baselineOffset: TextStyle.baselineLift(font: bodyFont, lineHeight: 23)])
        body.draw(with: CGRect(x: card.minX + 20, y: 207.5, width: card.width - 40, height: 50),
                  options: [.usesLineFragmentOrigin])

        let field = CGRect(x: card.minX + 15, y: 269, width: card.width - 30, height: 40)
        let fp = NSBezierPath(roundedRect: field.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        Palette.background.setFill(); fp.fill()
        Palette.borderDarker.setStroke(); fp.lineWidth = 1; fp.stroke()
        Symbols.draw("person.fill.badge.plus", size: 17, weight: .regular, color: Palette.text, center: CGPoint(x: field.minX + 23, y: field.midY))
        let url = NSAttributedString(string: "http://127.0.0.1:3055/join/GwHG-HbZN", attributes: [.font: bodyFont, .foregroundColor: Palette.text])
        NSGraphicsContext.saveGraphicsState()
        CGRect(x: field.minX + 40, y: field.minY, width: field.width - 50, height: field.height).clip()
        url.draw(at: CGPoint(x: field.minX + 42.5, y: field.midY - bodyFont.lineBoxHeight / 2))
        NSGraphicsContext.restoreGraphicsState()

        let symbols = ["qrcode.viewfinder", "list.clipboard", "square.and.arrow.up"]
        for (i, name) in symbols.enumerated() {
            let c = CGPoint(x: card.midX - 4.85 + CGFloat(i - 1) * 52.5, y: 346.5)
            let r = CGRect(x: c.x - 21, y: c.y - 21, width: 42, height: 42)
            Draw.circle(r, fill: Palette.background)
            Draw.ring(r, stroke: Palette.borderDarker)
            Symbols.draw(name, size: 18, weight: .medium, color: Palette.text, center: CGPoint(x: c.x, y: c.y - (i == 2 ? 1.5 : 0)))
        }
    }

    /// Campfire's app icon: a purple tile with a bundle of bright strokes.
    private func drawLogo(_ r: CGRect) {
        let tile = NSBezierPath(roundedRect: r, xRadius: 14, yRadius: 14)
        NSGraphicsContext.saveGraphicsState()
        tile.addClip()
        NSGradient(colors: [NSColor(hex: 0x8C2284), NSColor(hex: 0x5A1060), NSColor(hex: 0x2E0631)])?
            .draw(in: tile, relativeCenterPosition: NSPoint(x: -0.3, y: -0.4))
        // A ball of slanted strokes, magenta on the left through orange, with a pale blue and white core.
        let colors: [UInt32] = [0xD8127A, 0xE8186A, 0xF02D55, 0xF5473F, 0xF8E6C8, 0x8FD0F5, 0xFA8A2A, 0xF8662F, 0xF9A03A]
        let c = CGPoint(x: r.midX, y: r.midY - 1)
        let radius: CGFloat = 15
        for (i, hex) in colors.enumerated() {
            let dx = -radius + 3 + CGFloat(i) * (2 * radius - 6) / CGFloat(colors.count - 1)
            let half = max(4, (radius * radius - dx * dx).squareRoot())
            let p = NSBezierPath()
            p.move(to: CGPoint(x: c.x + dx + half * 0.32, y: c.y - half))
            p.line(to: CGPoint(x: c.x + dx - half * 0.32, y: c.y + half))
            p.lineWidth = 2.5
            p.lineCapStyle = .round
            NSColor(hex: hex).setStroke()
            p.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
    }
}

/// Round "jump to bottom" button shown when new messages arrive while scrolled up.
final class JumpButton: NSButton {
    override init(frame: NSRect) {
        super.init(frame: frame)
        isBordered = false
        title = ""
        setAccessibilityLabel("Jump to bottom")
        setButtonType(.momentaryChange)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 1, dy: 1)
        Draw.circle(r, fill: Palette.background)
        Draw.ring(r, stroke: Palette.borderDarker)
        Symbols.draw("arrow.down", size: 16, weight: .bold, color: Palette.text, center: CGPoint(x: r.midX, y: r.midY))
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

/// The benchmark bar, shown only with `-uvsBenchmark YES`.
final class DebugBar: NSView {
    static let titles = ["Reset", "Jump to 2500", "Load older", "Start stream", "Text size +", "Boost burst"]
    let stateLabel = NSTextField(labelWithString: "")
    let doneLabel = NSTextField(labelWithString: "Stream done")
    private(set) var buttons: [NSButton] = []
    private let onClick: (String) -> Void

    override var isFlipped: Bool { true }

    init(onClick: @escaping (String) -> Void) {
        self.onClick = onClick
        super.init(frame: .zero)
        for title in DebugBar.titles {
            let b = NSButton(title: title, target: self, action: #selector(clicked(_:)))
            b.bezelStyle = .push
            b.controlSize = .small
            b.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            b.sizeToFit()
            addSubview(b)
            buttons.append(b)
        }
        doneLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        doneLabel.isHidden = true
        addSubview(doneLabel)
        stateLabel.font = .monospacedDigitSystemFont(ofSize: 10.5, weight: .regular)
        stateLabel.lineBreakMode = .byClipping
        addSubview(stateLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func clicked(_ sender: NSButton) { onClick(sender.title) }

    static let height: CGFloat = 74

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
        NSColor.separatorColor.setFill()
        CGRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1).fill()
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        var x: CGFloat = 4, y: CGFloat = 3
        let rowH: CGFloat = 23
        for b in buttons {
            let w = b.frame.width
            if x + w > bounds.width - 4, x > 4 { x = 4; y += rowH }
            b.frame.origin = CGPoint(x: x, y: y)
            x += w + 2
        }
        doneLabel.sizeToFit()
        if x + doneLabel.frame.width > bounds.width - 4 { x = 4; y += rowH }
        doneLabel.frame.origin = CGPoint(x: x + 4, y: y + 4)
        y += rowH
        stateLabel.frame = CGRect(x: 8, y: y + 2, width: bounds.width - 12, height: 16)
    }
}
