import UIKit

/// A tiny highlighter in the GitHub colours Campfire uses: keywords, function names, strings, numbers, comments.
enum CodeHighlighter {
    private static let keywords: [String: Set<String>] = [
        "ruby": ["def", "end", "class", "module", "if", "else", "elsif", "unless", "do", "return", "yield", "nil", "true", "false", "self"],
        "swift": ["let", "var", "func", "return", "if", "else", "guard", "for", "in", "struct", "class", "import", "nil", "true", "false", "self"],
        "sql": ["SELECT", "FROM", "WHERE", "ORDER", "BY", "DESC", "ASC", "LIMIT", "AND", "OR", "INSERT", "UPDATE", "DELETE", "JOIN", "ON", "AS"],
        "sh": ["if", "then", "fi", "for", "do", "done", "echo", "export"],
    ]
    private static let definers: Set<String> = ["def", "func", "function", "class", "struct"]

    static func highlight(_ blocks: [(language: String?, source: String)], scale: TypeScale) -> NSAttributedString {
        let out = NSMutableAttributedString()
        for (i, block) in blocks.enumerated() {
            if i > 0 { out.append(NSAttributedString(string: "\n\n", attributes: base(scale))) }
            out.append(highlight(block.source, language: block.language, scale: scale))
        }
        return out
    }

    private static func base(_ scale: TypeScale) -> [NSAttributedString.Key: Any] {
        LineBox.attributes(font: scale.code, lineHeight: scale.codeLine, color: Palette.text, breakMode: .byCharWrapping)
    }

    private static func highlight(_ source: String, language: String?, scale: TypeScale) -> NSAttributedString {
        let lang = language ?? (source.uppercased().hasPrefix("SELECT") ? "sql" : "")
        let words = keywords[lang] ?? []
        let comment = lang == "swift" ? "//" : (lang == "sql" ? "--" : "#")
        let out = NSMutableAttributedString(string: source, attributes: base(scale))
        let chars = Array(source.unicodeScalars)
        var offsets: [Int] = []   // UTF-16 offset of each scalar
        var o = 0
        for c in chars { offsets.append(o); o += c.utf16.count }
        offsets.append(o)
        func color(_ from: Int, _ to: Int, _ c: UIColor) {
            out.addAttribute(.foregroundColor, value: c, range: NSRange(location: offsets[from], length: offsets[to] - offsets[from]))
        }
        func isWord(_ c: Unicode.Scalar) -> Bool { CharacterSet.alphanumerics.contains(c) || c == "_" }

        var i = 0
        var previousWord = ""
        var lineStart = true
        let commentScalars = Array(comment.unicodeScalars)
        while i < chars.count {
            let c = chars[i]
            if c == "\n" { lineStart = true; i += 1; continue }
            if c == "\"" || c == "'" {
                var j = i + 1
                while j < chars.count && chars[j] != c && chars[j] != "\n" { j += 1 }
                j = min(j + 1, chars.count)
                color(i, j, Palette.codeString)
                i = j; lineStart = false; continue
            }
            if lang != "", Array(chars[i..<min(chars.count, i + commentScalars.count)]) == commentScalars,
               !(comment == "#" && i + 1 < chars.count && chars[i + 1] == "{") {
                var j = i
                while j < chars.count && chars[j] != "\n" { j += 1 }
                color(i, j, Palette.codeComment)
                i = j; continue
            }
            if isWord(c) {
                var j = i
                while j < chars.count && isWord(chars[j]) { j += 1 }
                let word = String(String.UnicodeScalarView(chars[i..<j]))
                if word.allSatisfy(\.isNumber) {
                    color(i, j, Palette.codeConstant)
                } else if words.contains(word) {
                    color(i, j, Palette.codeKeyword)
                } else if definers.contains(previousWord) || (lang == "sh" && lineStart) {
                    color(i, j, Palette.codeEntity)
                }
                previousWord = word
                lineStart = false
                i = j; continue
            }
            if c == "-" && lang == "sh" && i + 1 < chars.count && isWord(chars[i + 1]) {
                var j = i + 1
                while j < chars.count && isWord(chars[j]) { j += 1 }
                color(i, j, Palette.codeConstant)
                i = j; continue
            }
            if c != " " { lineStart = false }
            i += 1
        }
        return out
    }
}
