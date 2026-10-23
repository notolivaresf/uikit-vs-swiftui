import AppKit
import CampfireKit

/// Selectable, non-editable message text. TextKit 1, laid out exactly like `TextMeasurer`.
final class BodyTextView: NSTextView {
    weak var row: RowView?
    private static weak var lastActive: BodyTextView?
    /// The room-level selection currently shown in this view (as a temporary background).
    var shownSelection: NSRange?

    static func clearNativeSelection() {
        lastActive?.setSelectedRange(NSRange(location: lastActive?.selectedRange().location ?? 0, length: 0))
    }

    convenience init() {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: NSSize(width: 100, height: CGFloat.greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)
        self.init(frame: .zero, textContainer: container)
        isEditable = false
        isSelectable = true
        isRichText = true
        drawsBackground = false
        textContainerInset = .zero
        isVerticallyResizable = false
        isHorizontallyResizable = false
        usesFontPanel = false
        usesFindBar = false
        isAutomaticLinkDetectionEnabled = false
        displaysLinkToolTips = false
        importsGraphics = false
        allowsUndo = false
        focusRingType = .none
        setAccessibilityRole(.staticText)
    }

    func show(_ string: NSAttributedString) {
        if textStorage?.isEqual(to: string) != true {
            setSelectedRange(NSRange(location: 0, length: 0))
            textStorage?.setAttributedString(string)
            shownSelection = nil
        }
    }

    func showSelection(_ range: NSRange?) {
        guard range != shownSelection, let lm = layoutManager, let storage = textStorage else { return }
        lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: NSRange(location: 0, length: storage.length))
        if let r = range { lm.addTemporaryAttribute(.backgroundColor, value: NSColor.selectedTextBackgroundColor, forCharacterRange: r) }
        shownSelection = range
    }

    /// Single-click drags select across messages (handled by the room); double and triple clicks select a word or
    /// line here.
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 1, let doc = row?.document {
            doc.trackSelection(with: event)
        } else {
            row?.document?.clearSelection()
            if window?.firstResponder !== self { window?.makeFirstResponder(self) }
            super.mouseDown(with: event)
        }
    }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok, let previous = BodyTextView.lastActive, previous !== self {
            previous.setSelectedRange(NSRange(location: previous.selectedRange().location, length: 0))
        }
        if ok { BodyTextView.lastActive = self }
        return ok
    }

    override func menu(for event: NSEvent) -> NSMenu? { row?.messageMenu() }

    /// Copies the selection as plain text (mention avatars dropped).
    override func copy(_ sender: Any?) {
        let range = selectedRange()
        guard range.length > 0, let storage = textStorage else { return }
        let text = (storage.string as NSString).substring(with: range).replacingOccurrences(of: "\u{FFFC}", with: "")
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    override func scrollWheel(with event: NSEvent) { nextResponder?.scrollWheel(with: event) }

    /// Text views scroll their selection into view when it changes; in the room only a drag-select may scroll.
    private var isDragging: Bool { NSApp.currentEvent?.type == .leftMouseDragged }
    override func scrollRangeToVisible(_ range: NSRange) { if isDragging { super.scrollRangeToVisible(range) } }
    override func scrollToVisible(_ rect: NSRect) -> Bool { isDragging ? super.scrollToVisible(rect) : false }
}

/// One message row: draws the separator, avatar, bubble, header, image, file, code boxes and boost pills; the
/// text is in `BodyTextView`s on top.
final class RowView: NSView {
    private(set) var messageID: MessageID = 0
    private(set) var layout: RowLayout?
    private var textViews: [BodyTextView] = []
    weak var controller: RoomController?
    weak var document: RoomDocumentView?

    func textView(at piece: Int) -> BodyTextView? { piece < textViews.count && !textViews[piece].isHidden ? textViews[piece] : nil }

    func applySelection() {
        guard let L = layout else { return }
        for (k, tv) in textViews.enumerated() where k < L.texts.count {
            tv.showSelection(document?.selectedRange(id: messageID, piece: k, length: L.texts[k].string.length))
        }
    }

    override func mouseDown(with event: NSEvent) {
        if let doc = document { doc.trackSelection(with: event) } else { super.mouseDown(with: event) }
    }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(id: MessageID, layout: RowLayout) {
        guard layout !== self.layout else { return }
        messageID = id
        self.layout = layout
        while textViews.count < layout.texts.count {
            let tv = BodyTextView()
            tv.row = self
            addSubview(tv)
            textViews.append(tv)
        }
        for (i, tv) in textViews.enumerated() {
            if i < layout.texts.count {
                let piece = layout.texts[i]
                tv.isHidden = false
                tv.frame = piece.frame
                tv.show(piece.string)
            } else {
                tv.isHidden = true
                tv.textStorage?.setAttributedString(NSAttributedString())
            }
        }
        toolTip = nil
        if let f = layout.file { addToolTip(f.icon.union(f.share), owner: f.tooltip as NSString, userData: nil) }
        needsDisplay = true
        setAccessibilityLabel(layout.plainText)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func menu(for event: NSEvent) -> NSMenu? { messageMenu() }

    func messageMenu() -> NSMenu {
        let menu = NSMenu()
        let copy = NSMenuItem(title: "Copy", action: #selector(copyMessage(_:)), keyEquivalent: "")
        copy.target = self
        menu.addItem(copy)
        let reply = NSMenuItem(title: "Reply", action: #selector(reply(_:)), keyEquivalent: "")
        reply.target = self
        menu.addItem(reply)
        return menu
    }

    @objc private func copyMessage(_ sender: Any?) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(layout?.plainText ?? "", forType: .string)
    }

    @objc private func reply(_ sender: Any?) {}

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let L = layout else { return }
        let s = L.scale

        if let pill = L.separatorPill, let text = L.separatorText {
            Palette.border.setFill()
            CGRect(x: Metrics.screenPaddingX, y: L.separatorLineY - Metrics.separatorLine / 2,
                   width: bounds.width - 2 * Metrics.screenPaddingX, height: Metrics.separatorLine).fill()
            Palette.bubble.setFill()
            NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
            let size = text.size()
            let font = text.attribute(.font, at: 0, effectiveRange: nil) as! NSFont
            text.draw(at: CGPoint(x: pill.midX - size.width / 2, y: pill.midY - font.lineBoxHeight / 2))
        }

        let bubblePath = NSBezierPath(roundedRect: L.bubble, xRadius: Metrics.bubbleRadius, yRadius: Metrics.bubbleRadius)
        switch L.bubbleStyle {
        case .normal: Palette.bubble.setFill(); bubblePath.fill()
        case .mention: Palette.mentionBubble.setFill(); bubblePath.fill()
        case .none: break
        }

        if let r = L.image {
            NSGraphicsContext.saveGraphicsState()
            bubblePath.addClip()
            if let img = controller?.placeholderImage(for: messageID, attachment: L.imageAttachment) {
                NSGraphicsContext.current?.imageInterpolation = .none
                img.draw(in: r, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            } else {
                L.imageColor.setFill()
                r.fill()
            }
            NSGraphicsContext.restoreGraphicsState()
        }

        for box in L.codeBoxes {
            Palette.codeBox.setFill()
            NSBezierPath(roundedRect: box, xRadius: Metrics.codeRadius, yRadius: Metrics.codeRadius).fill()
        }

        L.header.draw(at: L.headerOrigin)
        Draw.dots(at: L.dotsOrigin, height: L.dotsHeight, color: Palette.dimText, scale: s)

        if let a = L.avatar {
            Draw.circle(a.insetBy(dx: -Metrics.avatarRing, dy: -Metrics.avatarRing), fill: Palette.background)
            Draw.avatar(a, color: L.avatarColor, initial: L.avatarInitial, fontSize: 16.5)
        }

        if let f = L.file { drawFile(f) }

        for pill in L.pills {
            let path = NSBezierPath(roundedRect: pill.frame.insetBy(dx: 0.5, dy: 0.5), xRadius: pill.frame.height / 2, yRadius: pill.frame.height / 2)
            Palette.boostPill.setFill(); path.fill()
            Palette.borderDark.setStroke(); path.lineWidth = 1; path.stroke()
            Draw.avatar(pill.avatar, color: pill.avatarColor, initial: pill.initial, fontSize: 11.5 * s)
            pill.content.draw(at: pill.contentOrigin)
        }
        if let add = L.addBoost {
            Draw.circle(add, fill: Palette.boostPill)
            Draw.ring(add, stroke: Palette.borderDark)
            drawAddBoostIcon(center: CGPoint(x: add.midX, y: add.midY), scale: s)
        }
    }

    private func drawFile(_ f: FileLayout) {
        // Document icon: a filled page with a folded corner and three lines.
        let r = f.icon
        let fold: CGFloat = 5.5
        let page = NSBezierPath()
        page.move(to: CGPoint(x: r.minX + 2, y: r.minY))
        page.line(to: CGPoint(x: r.maxX - fold, y: r.minY))
        page.line(to: CGPoint(x: r.maxX, y: r.minY + fold))
        page.line(to: CGPoint(x: r.maxX, y: r.maxY - 2))
        page.appendArc(withCenter: CGPoint(x: r.maxX - 2, y: r.maxY - 2), radius: 2, startAngle: 0, endAngle: 90)
        page.line(to: CGPoint(x: r.minX + 2, y: r.maxY))
        page.appendArc(withCenter: CGPoint(x: r.minX + 2, y: r.maxY - 2), radius: 2, startAngle: 90, endAngle: 180)
        page.line(to: CGPoint(x: r.minX, y: r.minY + 2))
        page.appendArc(withCenter: CGPoint(x: r.minX + 2, y: r.minY + 2), radius: 2, startAngle: 180, endAngle: 270)
        page.close()
        Palette.text.setFill()
        page.fill()
        Palette.background.setFill()
        let lineX = r.minX + 4.2
        for (i, w) in [9.5, 9.5, 6.0].enumerated() {
            NSBezierPath(roundedRect: CGRect(x: lineX, y: r.minY + 9 + CGFloat(i) * 3.6, width: w, height: 1.9), xRadius: 0.95, yRadius: 0.95).fill()
        }
        f.name.draw(at: f.nameOrigin)
        Symbols.draw("arrow.down.to.line", size: 15, weight: .heavy, color: Palette.text, center: CGPoint(x: f.download.midX, y: f.download.midY))
        Symbols.draw("square.and.arrow.up", size: 15, weight: .bold, color: Palette.text, center: CGPoint(x: f.share.midX, y: f.share.midY - 1))
    }

    /// Smiley with a small plus: Campfire's add-boost button.
    private func drawAddBoostIcon(center c: CGPoint, scale s: CGFloat) {
        let r = 7.2 * s
        let face = NSBezierPath()
        face.appendArc(withCenter: c, radius: r, startAngle: 60, endAngle: 20, clockwise: false)
        face.lineWidth = 1.6 * s
        Palette.text.setStroke()
        face.stroke()
        Palette.text.setFill()
        for dx in [-2.6, 2.6] {
            NSBezierPath(ovalIn: CGRect(x: c.x + dx * s - 1.1 * s, y: c.y - 2.8 * s, width: 2.2 * s, height: 2.4 * s)).fill()
        }
        let smile = NSBezierPath()
        smile.appendArc(withCenter: CGPoint(x: c.x, y: c.y + 0.6 * s), radius: 3.4 * s, startAngle: 20, endAngle: 160)
        smile.lineWidth = 1.5 * s
        smile.lineCapStyle = .round
        smile.stroke()
        let p = CGPoint(x: c.x + 6.2 * s, y: c.y + 6.0 * s)
        let plus = NSBezierPath()
        plus.move(to: CGPoint(x: p.x - 3 * s, y: p.y)); plus.line(to: CGPoint(x: p.x + 3 * s, y: p.y))
        plus.move(to: CGPoint(x: p.x, y: p.y - 3 * s)); plus.line(to: CGPoint(x: p.x, y: p.y + 3 * s))
        plus.lineWidth = 1.6 * s
        plus.lineCapStyle = .round
        plus.stroke()
    }
}
