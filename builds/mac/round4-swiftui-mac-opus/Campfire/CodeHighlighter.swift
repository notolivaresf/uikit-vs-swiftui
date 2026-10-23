import SwiftUI

/// A small tokenizer for the code blocks in the room, coloured with Campfire's (GitHub's) code palette.
enum CodeHighlighter {
    enum Kind { case plain, keyword, entity, constant, string, comment }

    private static let keywords: [String: Set<String>] = [
        "ruby": ["def", "end", "do", "if", "else", "elsif", "unless", "class", "module", "return", "while", "case",
                 "when", "then", "yield", "self", "nil", "true", "false", "begin", "rescue", "ensure"],
        "swift": ["let", "var", "func", "return", "if", "else", "for", "in", "struct", "class", "enum", "import",
                  "guard", "while", "switch", "case", "self", "nil", "true", "false"],
        "sh": ["if", "then", "else", "fi", "for", "do", "done", "while", "case", "esac", "export", "echo", "cd"],
        "sql": ["SELECT", "FROM", "WHERE", "ORDER", "BY", "DESC", "ASC", "LIMIT", "GROUP", "JOIN", "ON", "AND", "OR",
                "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE", "AS", "NOT", "NULL", "IS", "IN"],
    ]

    private static func language(_ name: String?, source: String) -> String {
        if let name, keywords[name] != nil { return name }
        return source.range(of: "SELECT") != nil ? "sql" : ""
    }

    static func tokens(_ source: String, language name: String?) -> [(String, Kind)] {
        let lang = language(name, source: source)
        let words = keywords[lang] ?? []
        let lineComment: String? = switch lang {
        case "ruby", "sh": "#"
        case "swift": "//"
        case "sql": "--"
        default: nil
        }
        var out: [(String, Kind)] = []
        let chars = Array(source)
        var i = 0
        var afterDef = false
        func isWord(_ c: Character) -> Bool { c.isLetter || c.isNumber || c == "_" }
        while i < chars.count {
            let c = chars[i]
            if let lc = lineComment, String(chars[i..<min(chars.count, i + lc.count)]) == lc,
               !(lang == "ruby" && i + 1 < chars.count && chars[i + 1] == "{") {
                var j = i
                while j < chars.count, chars[j] != "\n" { j += 1 }
                out.append((String(chars[i..<j]), .comment)); i = j; continue
            }
            if c == "\"" || c == "'" {
                var j = i + 1
                while j < chars.count, chars[j] != c, chars[j] != "\n" {
                    if chars[j] == "\\" { j += 1 }
                    j += 1
                }
                j = min(chars.count, j + 1)
                out.append((String(chars[i..<j]), .string)); i = j; continue
            }
            if c.isNumber {
                var j = i
                while j < chars.count, chars[j].isNumber || chars[j] == "." { j += 1 }
                out.append((String(chars[i..<j]), .constant)); i = j; continue
            }
            if isWord(c) {
                var j = i
                while j < chars.count, isWord(chars[j]) { j += 1 }
                let word = String(chars[i..<j])
                if afterDef {
                    out.append((word, .entity)); afterDef = false
                } else if words.contains(word) {
                    out.append((word, .keyword))
                    if word == "def" || word == "func" { afterDef = true }
                } else {
                    out.append((word, .plain))
                }
                i = j; continue
            }
            out.append((String(c), .plain))
            i += 1
        }
        return out
    }

    static func attributed(_ source: String, language: String?, theme: Theme) -> AttributedString {
        var result = AttributedString()
        for (text, kind) in tokens(source, language: language) {
            var piece = AttributedString(text)
            piece.foregroundColor = switch kind {
            case .plain: theme.text
            case .keyword: theme.codeKeyword
            case .entity: theme.codeEntity
            case .constant: theme.codeConstant
            case .string: theme.codeString
            case .comment: theme.codeComment
            }
            result += piece
        }
        return result
    }
}
