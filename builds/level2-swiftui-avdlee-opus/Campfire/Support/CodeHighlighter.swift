import SwiftUI

/// A small GitHub-style highlighter for the code blocks CampfireKit produces (ruby, swift, sh, SQL).
enum CodeHighlighter {
    enum Kind { case plain, keyword, entity, constant, string, comment }

    private static let keywords: [String: Set<String>] = [
        "ruby": ["def", "end", "if", "else", "elsif", "unless", "do", "class", "module", "return", "yield", "while",
                 "begin", "rescue", "self", "then", "case", "when"],
        "swift": ["let", "var", "func", "return", "if", "else", "for", "in", "import", "struct", "class", "enum",
                  "case", "guard", "self", "switch", "while", "try", "await", "async", "throws"],
        "sh": ["if", "then", "else", "fi", "for", "do", "done", "while", "case", "esac", "function", "export"],
        "sql": ["SELECT", "FROM", "WHERE", "ORDER", "BY", "DESC", "ASC", "LIMIT", "AND", "OR", "JOIN", "ON", "AS",
                "GROUP", "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE"],
    ]
    private static let constants: Set<String> = ["true", "false", "nil", "null", "NULL"]
    private static let definers: Set<String> = ["def", "func", "class", "struct", "enum", "module", "function"]

    static func tokens(_ source: String, language: String?) -> [(String, Kind)] {
        let lang = language ?? "sql"
        let words = keywords[lang] ?? []
        let commentPrefix: String = switch lang {
        case "swift": "//"
        case "sql": "--"
        default: "#"
        }
        var out: [(String, Kind)] = []
        let chars = Array(source)
        var i = 0
        var afterDefiner = false
        func emit(_ s: String, _ k: Kind) {
            if let last = out.last, last.1 == k { out[out.count - 1].0 += s } else { out.append((s, k)) }
        }
        while i < chars.count {
            let c = chars[i]
            // Comments run to the end of the line (not "#{" interpolation, which only appears inside strings).
            if String(chars[i...].prefix(commentPrefix.count)) == commentPrefix {
                var j = i
                while j < chars.count, chars[j] != "\n" { j += 1 }
                emit(String(chars[i..<j]), .comment); i = j; continue
            }
            if c == "\"" || c == "'" {
                var j = i + 1
                while j < chars.count, chars[j] != c, chars[j] != "\n" { j += chars[j] == "\\" ? 2 : 1 }
                j = min(j + 1, chars.count)
                emit(String(chars[i..<j]), .string); i = j; continue
            }
            if c.isLetter || c == "_" {
                var j = i
                while j < chars.count, chars[j].isLetter || chars[j].isNumber || chars[j] == "_" { j += 1 }
                let word = String(chars[i..<j])
                if afterDefiner {
                    emit(word, .entity); afterDefiner = false
                } else if words.contains(word) {
                    emit(word, .keyword); afterDefiner = definers.contains(word)
                } else if constants.contains(word) {
                    emit(word, .constant)
                } else {
                    emit(word, .plain)
                }
                i = j; continue
            }
            if c.isNumber {
                var j = i
                while j < chars.count, chars[j].isNumber || chars[j] == "." { j += 1 }
                emit(String(chars[i..<j]), .constant); i = j; continue
            }
            if !c.isWhitespace { afterDefiner = false }
            emit(String(c), .plain); i += 1
        }
        return out
    }

    static func attributed(_ source: String, language: String?, palette: Palette) -> AttributedString {
        var result = AttributedString()
        for (text, kind) in tokens(source, language: language) {
            var piece = AttributedString(text)
            piece.foregroundColor = switch kind {
            case .plain: palette.text
            case .keyword: palette.codeKeyword
            case .entity: palette.codeEntity
            case .constant: palette.codeConstant
            case .string: palette.codeString
            case .comment: palette.codeComment
            }
            result += piece
        }
        return result
    }
}
