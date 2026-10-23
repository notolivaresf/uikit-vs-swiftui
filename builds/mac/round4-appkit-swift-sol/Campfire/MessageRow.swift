import AppKit
import CampfireKit

func boostFont(_ content: String) -> CGFloat { content.unicodeScalars.contains { $0.properties.isEmojiPresentation || $0.value == 0xFE0F } ? 17.6 : 16 }
struct DisplayBoost {
    let boosterID: Int
    let content: String
}
struct PillLayout {
    let rect: NSRect
    let boost: DisplayBoost?
}
struct RowLayout {
    let message: Message
    let presentation: MessagePresentation
    let header: NSAttributedString
    let body: NSAttributedString
    let code: NSAttributedString?
    let bubble: NSRect
    let bodyRect: NSRect
    let codeRect: NSRect?
    let imageRect: NSRect?
    let fileRect: NSRect?
    let pills: [PillLayout]
    let height: CGFloat
    let scale: CGFloat

    init(message m: Message, previous: Message?, users: [Int: User], width: CGFloat, scale: CGFloat, extraBoosts: [DisplayBoost] = []) {
        message = m; self.scale = scale
        let p = Grouping.presentation(of: m, after: previous, currentUserID: 1); presentation = p
        let author = users[m.creatorID]?.name ?? ""
        let headerAttrs = Style.attributes(size: 12.8 * scale, line: 19.2 * scale)
        let faded = Style.attributes(size: 12.8 * scale, line: 19.2 * scale, color: Style.text.withAlphaComponent(0.5))
        let h = NSMutableAttributedString()
        let name = NSAttributedString(string: author, attributes: Style.attributes(size: 12.8 * scale, line: 19.2 * scale, weight: .bold))
        let timestamp = NSAttributedString(string: Style.time.string(from: m.createdAt), attributes: faded)
        let dots = NSAttributedString(string: "   •••", attributes: faded)
        if p.isMine {
            h.append(NSAttributedString(string: "•••   ", attributes: faded)); h.append(timestamp)
            if !p.isThreaded { h.append(NSAttributedString(string: " ", attributes: headerAttrs)); h.append(name) }
        } else {
            if !p.isThreaded { h.append(name); h.append(NSAttributedString(string: " ", attributes: headerAttrs)) }
            h.append(timestamp); h.append(dots)
        }
        header = h
        let bodyAttrs = Style.attributes(size: (m.isEmojiOnly ? 38.4 : 16) * scale, line: (m.isEmojiOnly ? 53.76 : 22.4) * scale)
        let b = NSMutableAttributedString(); var c: NSAttributedString?
        for block in m.blocks {
            switch block {
            case .text(let t): b.append(NSAttributedString(string: t, attributes: bodyAttrs))
            case .mention(let id):
                var attrs = bodyAttrs; attrs[.font] = NSFont.systemFont(ofSize: 16 * scale, weight: .semibold); attrs[.backgroundColor] = Style.red.withAlphaComponent(0.15)
                b.append(NSAttributedString(string: users[id]?.name ?? "@", attributes: attrs))
            case .code(_, let source):
                let code = NSMutableAttributedString(string: source, attributes: Style.attributes(size: 12.8 * scale, line: 17.92 * scale, mono: true))
                for (pattern, light, dark) in [("\\b(def|end|let|SELECT|FROM|ORDER|BY|LIMIT)\\b", "D73A49", "FF7B72"), ("\"[^\"]*\"", "032F62", "79C0FF"), ("\\b(greet|print)\\b", "6F42C1", "D2A8FF")] {
                    if let regex = try? NSRegularExpression(pattern: pattern) { for match in regex.matches(in: source, range: NSRange(location: 0, length: (source as NSString).length)) { code.addAttribute(.foregroundColor, value: NSColor.adaptive(light, dark), range: match.range) } }
                }
                c = code
            }
        }
        body = b; code = c
        let available = max(90, width - (p.isMine ? 105.03 : 54.8))
        let pad: CGFloat = 15.12
        let maxText = available - pad * 2
        let headerSize = Style.measure(h, width: maxText)
        let bodySize = Style.measure(b, width: maxText)
        var bubbleWidth = min(available, max(headerSize.width, bodySize.width) + pad * 2)
        var contentY = 10.56 + 19.2 * scale + 2.76
        var bodyLocal = NSRect(x: pad, y: contentY, width: maxText, height: bodySize.height)
        if b.length > 0 { contentY += bodySize.height }
        var codeLocal: NSRect?
        if let c {
            if b.length > 0 { contentY += 10.56 }
            let codeSize = Style.measure(c, width: maxText - 25.6)
            bubbleWidth = min(available, max(bubbleWidth, codeSize.width + 25.6 + pad * 2))
            codeLocal = NSRect(x: pad, y: contentY, width: bubbleWidth - pad * 2, height: codeSize.height + 25.6)
            contentY += codeSize.height + 25.6
        }
        var imageLocal: NSRect?; var fileLocal: NSRect?
        if let attachment = m.attachment {
            switch attachment {
            case .image(let w, let h, _):
                bubbleWidth = min(300, available)
                contentY += 10.56
                imageLocal = NSRect(x: 1, y: contentY, width: bubbleWidth - 2, height: (bubbleWidth - 2) * CGFloat(h) / CGFloat(w))
                contentY += (bubbleWidth - 2) * CGFloat(h) / CGFloat(w)
            case .file:
                bubbleWidth = min(available, 283.11 * scale)
                fileLocal = NSRect(x: pad, y: contentY, width: bubbleWidth - pad * 2, height: 34 * scale)
                contentY += 34 * scale
            }
        }
        var pillLocal: [PillLayout] = []
        let boosts = m.boosts.map { DisplayBoost(boosterID: $0.boosterID, content: $0.content) } + extraBoosts
        if !boosts.isEmpty {
            contentY += 4
            let pillPad: CGFloat = imageLocal != nil ? 10.56 : pad
            var x = pillPad; var y = contentY
            for boost in boosts {
                let s = Style.measure(NSAttributedString(string: boost.content, attributes: Style.attributes(size: boostFont(boost.content) * scale, line: 22.4 * scale)), width: available)
                let w = min(bubbleWidth - 2 * pillPad, 26 + s.width + 6.4)
                if x + w > bubbleWidth - pillPad + 0.1 && x > pillPad { x = pillPad; y += 32.64 * scale }
                pillLocal.append(PillLayout(rect: NSRect(x: x, y: y, width: w, height: 28.64 * scale), boost: boost)); x += w + 5.6
            }
            let w = 28.64 * scale
            if x + w > bubbleWidth - pillPad + 0.1 && x > pillPad { x = pillPad; y += 32.64 * scale }
            pillLocal.append(PillLayout(rect: NSRect(x: x, y: y, width: w, height: w), boost: nil))
            contentY = y + w
        }
        contentY += 10.56
        let dayHeight: CGFloat = p.isFirstOfDay ? 68.8 : 0
        let origin = NSPoint(x: p.isMine ? width - 40.8 - bubbleWidth : 40.8, y: dayHeight + 1.6)
        bubble = NSRect(origin: origin, size: NSSize(width: bubbleWidth, height: contentY))
        bodyLocal.size.width = bubbleWidth - pad * 2
        bodyRect = bodyLocal.offsetBy(dx: origin.x, dy: origin.y)
        codeRect = codeLocal?.offsetBy(dx: origin.x, dy: origin.y)
        imageRect = imageLocal?.offsetBy(dx: origin.x, dy: origin.y)
        fileRect = fileLocal?.offsetBy(dx: origin.x, dy: origin.y)
        pills = pillLocal.map { PillLayout(rect: $0.rect.offsetBy(dx: origin.x, dy: origin.y), boost: $0.boost) }
        height = dayHeight + contentY + 3.2
    }
}

final class MessageTextView: NSTextView {
    var messageText = ""
    override func menu(for event: NSEvent) -> NSMenu? { messageMenu(text: messageText, target: self) }
    @objc func copyMessage(_ sender: Any?) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(messageText, forType: .string) }
    @objc func reply(_ sender: Any?) {}
}
func messageMenu(text: String, target: AnyObject) -> NSMenu {
    let menu = NSMenu()
    let copy = NSMenuItem(title: "Copy", action: #selector(MessageTextView.copyMessage(_:)), keyEquivalent: ""); copy.target = target
    let reply = NSMenuItem(title: "Reply", action: #selector(MessageTextView.reply(_:)), keyEquivalent: ""); reply.target = target
    menu.addItem(copy); menu.addItem(reply); return menu
}
final class MessageRow: FlippedView {
    var layout: RowLayout
    let users: [Int: User]
    init(layout: RowLayout, users: [Int: User], width: CGFloat) {
        self.layout = layout; self.users = users
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: layout.height))
        if layout.body.length > 0 { addText(layout.body, rect: layout.bodyRect) }
        if let code = layout.code, let rect = layout.codeRect { addText(code, rect: rect.insetBy(dx: 12.8, dy: 12.8)) }
        setAccessibilityElement(true); setAccessibilityRole(.group); setAccessibilityLabel("Message \(layout.message.id), \(users[layout.message.creatorID]?.name ?? ""), \(plainText)")
    }
    required init?(coder: NSCoder) { fatalError() }
    var plainText: String {
        layout.message.blocks.map { block in switch block { case .text(let s): return s; case .mention(let id): return users[id]?.name ?? "@"; case .code(_, let s): return s } }.joined()
    }
    func addText(_ text: NSAttributedString, rect: NSRect) {
        let view = MessageTextView(frame: rect)
        view.isEditable = false; view.isSelectable = true; view.drawsBackground = false
        view.textContainerInset = .zero; view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.containerSize = NSSize(width: rect.width, height: .greatestFiniteMagnitude)
        view.isHorizontallyResizable = false; view.isVerticallyResizable = false
        view.textStorage?.setAttributedString(text); view.messageText = plainText
        view.setAccessibilityLabel(plainText); addSubview(view)
    }
    override func menu(for event: NSEvent) -> NSMenu? { messageMenu(text: plainText, target: self) }
    @objc func copyMessage(_ sender: Any?) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(plainText, forType: .string) }
    @objc func reply(_ sender: Any?) {}
    override func draw(_ dirtyRect: NSRect) {
        let l = layout; let m = l.message; let p = l.presentation
        if p.isFirstOfDay {
            Style.bubble.setFill(); NSRect(x: 14, y: 34.4, width: bounds.width - 28, height: 2).fill()
            let title = Style.day.string(from: m.createdAt).uppercased()
            let size = (title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 12.8, weight: .semibold)])
            let r = NSRect(x: (bounds.width - size.width - 47) / 2, y: 17.02, width: size.width + 47, height: 35)
            fillRound(r, radius: 18, color: Style.bubble)
            drawText(title, rect: r.insetBy(dx: 0, dy: 8.5), size: 12.8, weight: .semibold, centered: true)
        }
        if !m.isEmojiOnly { fillRound(l.bubble, radius: 10.56, color: p.mentionsMe ? Style.mention : Style.bubble) }
        if !p.isThreaded {
            let r = NSRect(x: p.isMine ? bounds.width - 49.27 : 14.01, y: l.bubble.minY, width: 35.27, height: 35.27)
            fillRound(r.insetBy(dx: -2, dy: -2), radius: 20, color: Style.background)
            avatar(m.creatorID, rect: r, size: 16)
        }
        let headerWidth = l.bubble.width - 30.24
        let headerSize = Style.measure(l.header, width: headerWidth)
        l.header.draw(in: NSRect(x: p.isMine ? l.bubble.maxX - 15.12 - headerSize.width : l.bubble.minX + 15.12, y: l.bubble.minY + 10.56, width: headerSize.width + 0.1, height: 19.2 * l.scale))
        if let rect = l.codeRect { fillRound(rect, radius: 6.4, color: Style.background) }
        if let rect = l.imageRect, case .image(_, _, let color) = m.attachment {
            NSColor(srgbRed: CGFloat(color.r)/255, green: CGFloat(color.g)/255, blue: CGFloat(color.b)/255, alpha: 1).setFill(); rect.fill()
        }
        if let rect = l.fileRect, case .file(let name, _) = m.attachment {
            drawSymbol("doc.text.fill", in: NSRect(x: rect.minX, y: rect.minY + 3, width: 20 * l.scale, height: 24 * l.scale))
            drawText(name, rect: NSRect(x: rect.minX + 27 * l.scale, y: rect.minY + 4, width: rect.width - 79 * l.scale, height: 25 * l.scale), size: 16 * l.scale)
            drawSymbol("arrow.down.to.line", in: NSRect(x: rect.maxX - 49 * l.scale, y: rect.minY + 6, width: 20 * l.scale, height: 21 * l.scale), weight: .semibold)
            drawSymbol("square.and.arrow.up", in: NSRect(x: rect.maxX - 20 * l.scale, y: rect.minY + 6, width: 17 * l.scale, height: 21 * l.scale), weight: .semibold)
        }
        for pill in l.pills {
            let r = pill.rect; fillRound(r, radius: r.height / 2, color: Style.background); strokeRound(r, radius: r.height / 2, color: Style.border)
            if let boost = pill.boost {
                let a = NSRect(x: r.minX + 2.4, y: r.minY + 2.4, width: 23.2 * l.scale, height: 23.2 * l.scale)
                avatar(boost.boosterID, rect: a, size: 11 * l.scale)
                drawText(boost.content, rect: NSRect(x: a.maxX + 4, y: r.minY + 3 * l.scale, width: r.width - a.width - 7, height: 24 * l.scale), size: boostFont(boost.content) * l.scale)
            } else { drawSymbol("face.smiling", in: r.insetBy(dx: 6, dy: 6)); drawText("+", rect: NSRect(x: r.maxX - 13, y: r.maxY - 17, width: 11, height: 12), size: 12, weight: .bold) }
        }
    }
    func avatar(_ id: Int, rect: NSRect, size: CGFloat) {
        fillRound(rect, radius: rect.width / 2, color: Style.avatar(id))
        drawText(String(users[id]?.name.prefix(1) ?? "?"), rect: NSRect(x: rect.minX, y: rect.midY - size * 0.62, width: rect.width, height: size * 1.4), size: size, weight: .bold, color: .white, centered: true)
    }
}
