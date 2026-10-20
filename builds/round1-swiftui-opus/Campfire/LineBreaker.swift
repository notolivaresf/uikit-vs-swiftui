import CoreText
import Foundation
import SwiftUI

/// SwiftUI's Text avoids a one-word last line by pulling a word down from the line above ("push out"). Campfire
/// (Chrome) wraps greedily, so where greedy wrapping would leave a lone last word we force that break ourselves.
@MainActor
enum LineBreaker {
    private static var cache: [Key: String] = [:]

    private struct Key: Hashable {
        let text: String
        let width: CGFloat
        let size: CGFloat
    }

    static func greedy(_ text: String, width: CGFloat, fontSize: CGFloat) -> String {
        guard width > 0, text.contains(" ") else { return text }
        let key = Key(text: text, width: width, size: fontSize)
        if let hit = cache[key] { return hit }
        if cache.count > 4000 { cache.removeAll() }
        let font = CTFontCreateUIFontForLanguage(.system, fontSize, nil)!
        let out = text.components(separatedBy: "\n").map { fix($0, width: width, font: font) }.joined(separator: "\n")
        cache[key] = out
        return out
    }

    private static func fix(_ paragraph: String, width: CGFloat, font: CTFont) -> String {
        guard paragraph.contains(" ") else { return paragraph }
        let ns = paragraph as NSString
        let attr = NSAttributedString(string: paragraph, attributes: [kCTFontAttributeName as NSAttributedString.Key: font])
        let typesetter = CTTypesetterCreateWithAttributedString(attr)
        var start = 0
        var lastStart = 0
        var lines = 0
        while start < ns.length {
            let count = CTTypesetterSuggestLineBreak(typesetter, start, Double(width))
            if count <= 0 { break }
            lastStart = start
            start += count
            lines += 1
        }
        guard lines >= 2 else { return paragraph }
        let last = ns.substring(from: lastStart).trimmingCharacters(in: .whitespaces)
        guard !last.isEmpty, !last.contains(" ") else { return paragraph }
        let head = ns.substring(to: lastStart).replacingOccurrences(of: " +$", with: "", options: .regularExpression)
        return head + "\u{2028}" + last
    }
}

private struct TextWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Width of the room list's content (safe area excluded); rows derive their text column width from it.
    var listWidth: CGFloat {
        get { self[TextWidthKey.self] }
        set { self[TextWidthKey.self] = newValue }
    }
}
