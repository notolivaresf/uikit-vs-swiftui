import SwiftUI

/// A small highlighter in the spirit of Campfire's code blocks: keywords, definitions, strings, numbers
/// and comments.
enum CodeHighlighter {
    enum Kind { case plain, keyword, entity, constant, string, comment }

    private static let keywords: [String: Set<String>] = [
        "ruby": ["def", "end", "do", "if", "else", "elsif", "unless", "while", "class", "module", "return", "yield",
                 "self", "nil", "true", "false", "then", "case", "when", "begin", "rescue"],
        "swift": ["let", "var", "func", "if", "else", "guard", "return", "struct", "class", "enum", "import", "for",
                  "in", "while", "true", "false", "nil", "self"],
        "sh": ["if", "then", "else", "fi", "for", "do", "done", "case", "esac", "export"],
        "sql": ["select", "from", "where", "order", "by", "desc", "asc", "limit", "and", "or", "insert", "into",
                "update", "delete", "join", "on", "group", "as", "values", "set"],
    ]

    static func tokens(_ source: String, language: String?) -> [(String, Kind)] {
        let lang = language?.lowercased() ?? (looksLikeSQL(source) ? "sql" : "")
        let words = keywords[lang] ?? []
        let caseInsensitive = lang == "sql"
        let commentPrefix: String? = switch lang {
        case "ruby", "sh": "#"
        case "swift": "//"
        case "sql": "--"
        default: nil
        }

        var result: [(String, Kind)] = []
        var chars = Array(source)
        var i = 0
        var expectEntity = false
        func emit(_ s: String, _ k: Kind) {
            if let last = result.last, last.1 == k { result[result.count - 1].0 += s } else { result.append((s, k)) }
        }
        while i < chars.count {
            let c = chars[i]
            if let prefix = commentPrefix, String(chars[i..<min(chars.count, i + prefix.count)]) == prefix {
                var j = i
                while j < chars.count && chars[j] != "\n" { j += 1 }
                emit(String(chars[i..<j]), .comment)
                i = j
            } else if c == "\"" || c == "'" {
                var j = i + 1
                while j < chars.count && chars[j] != c && chars[j] != "\n" {
                    if chars[j] == "\\" { j += 1 }
                    j += 1
                }
                j = min(chars.count, j + 1)
                emit(String(chars[i..<j]), .string)
                i = j
            } else if c.isNumber {
                var j = i
                while j < chars.count && (chars[j].isNumber || chars[j] == ".") { j += 1 }
                emit(String(chars[i..<j]), .constant)
                i = j
            } else if c.isLetter || c == "_" {
                var j = i
                while j < chars.count && (chars[j].isLetter || chars[j].isNumber || chars[j] == "_" || chars[j] == "?" || chars[j] == "!") { j += 1 }
                let word = String(chars[i..<j])
                let key = caseInsensitive ? word.lowercased() : word
                if expectEntity {
                    emit(word, .entity)
                    expectEntity = false
                } else if words.contains(key) {
                    emit(word, .keyword)
                    expectEntity = ["def", "func", "class", "struct", "enum", "module"].contains(key)
                } else {
                    emit(word, .plain)
                }
                i = j
            } else {
                emit(String(c), .plain)
                i += 1
            }
        }
        chars.removeAll()
        return result
    }

    static func color(for kind: Kind) -> Color {
        switch kind {
        case .plain: Palette.ink
        case .keyword: Palette.codeKeyword
        case .entity: Palette.codeEntity
        case .constant: Palette.codeConstant
        case .string: Palette.codeString
        case .comment: Palette.codeComment
        }
    }

    private static func looksLikeSQL(_ source: String) -> Bool {
        source.uppercased().hasPrefix("SELECT ")
    }
}
