import SwiftUI

/// JavaScript/script syntax highlighting service.
/// Supports: keywords (const/let/var/function/if/return etc.), strings (single/double/template),
/// numbers, comments (// and /* */), operators, identifiers.
/// Per-line parsing with fault tolerance.
public enum ScriptHighlightService {

    private static let keywords: Set<String> = [
        "const", "let", "var", "function", "if", "else", "for", "while", "do",
        "return", "break", "continue", "switch", "case", "default", "new",
        "typeof", "instanceof", "void", "delete", "in", "of", "class",
        "extends", "super", "this", "async", "await", "try", "catch", "finally",
        "throw", "yield", "import", "export", "from", "as", "debugger",
        "true", "false", "null", "undefined",
    ]

    private static let builtinIdentifiers: Set<String> = [
        "console", "Object", "Array", "String", "Number", "Boolean", "Date",
        "Math", "JSON", "Promise", "Error", "Map", "Set", "RegExp",
        "parseInt", "parseFloat", "isNaN", "isFinite",
        "request", "response", "variables", "result", "insomnia", "history",
        "log", "environment", "get", "set", "unset", "text", "json",
        "headers", "cookies", "url", "method", "body", "statusCode",
        "push", "keys", "now", "toString",
    ]

    // MARK: - Highlight

    public static func highlight(_ text: String, _ colorScheme: ColorScheme) -> [HighlightToken] {
        guard !text.isEmpty else { return [] }

        var tokens: [HighlightToken] = []
        let lines = text.components(separatedBy: .newlines)

        var inBlockComment = false

        for (lineIndex, line) in lines.enumerated() {
            if lineIndex > 0 {
                tokens.append(HighlightToken(text: "\n", kind: .whitespace))
            }
            highlightLine(line, inBlockComment: &inBlockComment, into: &tokens)
        }

        return tokens
    }

    private static func highlightLine(
        _ line: String,
        inBlockComment: inout Bool,
        into tokens: inout [HighlightToken]
    ) {
        let chars = Array(line)
        var i = 0

        while i < chars.count {
            let c = chars[i]

            // Whitespace
            if c == " " || c == "\t" || c == "\r" {
                var ws = ""
                while i < chars.count && (chars[i] == " " || chars[i] == "\t" || chars[i] == "\r") {
                    ws.append(chars[i])
                    i += 1
                }
                tokens.append(HighlightToken(text: ws, kind: .whitespace))
                continue
            }

            // Block comment continuation
            if inBlockComment {
                let remaining = String(chars[i...])
                if let endIdx = remaining.firstIndex(of: "*") {
                    let endPos = remaining.distance(from: remaining.startIndex, to: endIdx)
                    let nextIdx = endPos + 1
                    if nextIdx < remaining.count && remaining[remaining.index(remaining.startIndex, offsetBy: nextIdx)] == "/" {
                        let commentPart = String(remaining[...remaining.index(remaining.startIndex, offsetBy: nextIdx)])
                        tokens.append(HighlightToken(text: commentPart, kind: .scriptComment))
                        i += commentPart.count
                        inBlockComment = false
                        continue
                    }
                }
                tokens.append(HighlightToken(text: String(chars[i...]), kind: .scriptComment))
                i = chars.count
                continue
            }

            // Line comment //
            if c == "/" && i + 1 < chars.count && chars[i + 1] == "/" {
                tokens.append(HighlightToken(text: String(chars[i...]), kind: .scriptComment))
                i = chars.count
                continue
            }

            // Block comment start /*
            if c == "/" && i + 1 < chars.count && chars[i + 1] == "*" {
                inBlockComment = true
                let remaining = String(chars[i...])
                if let endIdx = remaining.firstIndex(of: "*") {
                    let endPos = remaining.distance(from: remaining.startIndex, to: endIdx)
                    let nextIdx = endPos + 1
                    if nextIdx < remaining.count && remaining[remaining.index(remaining.startIndex, offsetBy: nextIdx)] == "/" {
                        let commentPart = String(remaining[...remaining.index(remaining.startIndex, offsetBy: nextIdx)])
                        tokens.append(HighlightToken(text: commentPart, kind: .scriptComment))
                        i += commentPart.count
                        inBlockComment = false
                        continue
                    }
                }
                tokens.append(HighlightToken(text: String(chars[i...]), kind: .scriptComment))
                i = chars.count
                continue
            }

            // String (double quote)
            if c == "\"" {
                let (text, endIndex) = consumeString(chars: chars, from: i, quote: "\"")
                tokens.append(HighlightToken(text: text, kind: .scriptString))
                i = endIndex
                continue
            }

            // String (single quote)
            if c == "'" {
                let (text, endIndex) = consumeString(chars: chars, from: i, quote: "'")
                tokens.append(HighlightToken(text: text, kind: .scriptString))
                i = endIndex
                continue
            }

            // Template literal
            if c == "`" {
                let (text, endIndex) = consumeString(chars: chars, from: i, quote: "`")
                tokens.append(HighlightToken(text: text, kind: .scriptString))
                i = endIndex
                continue
            }

            // Number
            if c.isNumber || (c == "." && i + 1 < chars.count && chars[i + 1].isNumber) {
                let (text, endIndex) = consumeScriptNumber(chars: chars, from: i)
                tokens.append(HighlightToken(text: text, kind: .scriptNumber))
                i = endIndex
                continue
            }

            // Operator
            if isOperator(c) {
                // Two-character operator
                if c == "=" && i + 1 < chars.count {
                    let next = chars[i + 1]
                    if next == "=" || next == ">" {
                        tokens.append(HighlightToken(text: String([c, next]), kind: .scriptOperator))
                        i += 2
                        continue
                    }
                }
                if c == "!" && i + 1 < chars.count && chars[i + 1] == "=" {
                    tokens.append(HighlightToken(text: "!=", kind: .scriptOperator))
                    i += 2
                    continue
                }
                if c == ">" && i + 1 < chars.count && chars[i + 1] == "=" {
                    tokens.append(HighlightToken(text: ">=", kind: .scriptOperator))
                    i += 2
                    continue
                }
                if c == "<" && i + 1 < chars.count && chars[i + 1] == "=" {
                    tokens.append(HighlightToken(text: "<=", kind: .scriptOperator))
                    i += 2
                    continue
                }
                if c == "&" && i + 1 < chars.count && chars[i + 1] == "&" {
                    tokens.append(HighlightToken(text: "&&", kind: .scriptOperator))
                    i += 2
                    continue
                }
                if c == "|" && i + 1 < chars.count && chars[i + 1] == "|" {
                    tokens.append(HighlightToken(text: "||", kind: .scriptOperator))
                    i += 2
                    continue
                }
                if c == "+" && i + 1 < chars.count && chars[i + 1] == "+" {
                    tokens.append(HighlightToken(text: "++", kind: .scriptOperator))
                    i += 2
                    continue
                }
                if c == "-" && i + 1 < chars.count && chars[i + 1] == "-" {
                    tokens.append(HighlightToken(text: "--", kind: .scriptOperator))
                    i += 2
                    continue
                }
                if c == "=" && i + 1 < chars.count && chars[i + 1] == ">" {
                    tokens.append(HighlightToken(text: "=>", kind: .scriptOperator))
                    i += 2
                    continue
                }

                tokens.append(HighlightToken(text: String(c), kind: .scriptOperator))
                i += 1
                continue
            }

            // Dot (property access)
            if c == "." {
                tokens.append(HighlightToken(text: ".", kind: .scriptOperator))
                i += 1
                continue
            }

            // Brackets/braces/semicolons
            if "(){}[];,".contains(c) {
                tokens.append(HighlightToken(text: String(c), kind: .punctuation))
                i += 1
                continue
            }

            // Identifier/keyword
            let (word, nextIdx) = consumeWord(chars: chars, from: i)
            if keywords.contains(word) {
                tokens.append(HighlightToken(text: word, kind: .scriptKeyword))
            } else if builtinIdentifiers.contains(word) {
                tokens.append(HighlightToken(text: word, kind: .scriptIdentifier))
            } else {
                tokens.append(HighlightToken(text: word, kind: .plain))
            }
            i = nextIdx
        }
    }

    // MARK: - Consume helpers

    private static func consumeString(chars: [Character], from start: Int, quote: Character) -> (String, Int) {
        var result = String(quote)
        var i = start + 1
        var escaped = false

        while i < chars.count {
            let c = chars[i]
            result.append(c)

            if escaped {
                escaped = false
                i += 1
                continue
            }

            if c == "\\" {
                escaped = true
                i += 1
                continue
            }

            if c == quote {
                i += 1
                break
            }

            i += 1
        }

        return (result, i)
    }

    private static func consumeScriptNumber(chars: [Character], from start: Int) -> (String, Int) {
        var result = ""
        var i = start
        var hasDot = false

        if i < chars.count && chars[i] == "." {
            result.append(".")
            i += 1
        }

        while i < chars.count && chars[i].isNumber {
            result.append(chars[i])
            i += 1
        }

        if i < chars.count && chars[i] == "." && !hasDot {
            hasDot = true
            result.append(".")
            i += 1
            while i < chars.count && chars[i].isNumber {
                result.append(chars[i])
                i += 1
            }
        }

        if i < chars.count && (chars[i] == "e" || chars[i] == "E") {
            result.append(chars[i])
            i += 1
            if i < chars.count && (chars[i] == "+" || chars[i] == "-") {
                result.append(chars[i])
                i += 1
            }
            while i < chars.count && chars[i].isNumber {
                result.append(chars[i])
                i += 1
            }
        }

        return (result, i)
    }

    private static func consumeWord(chars: [Character], from start: Int) -> (String, Int) {
        var result = ""
        var i = start
        while i < chars.count && chars[i].isLetter || (i < chars.count && chars[i].isNumber) || (i < chars.count && chars[i] == "_" || chars[i] == "$") {
            break
        }
        while i < chars.count {
            let c = chars[i]
            if c.isLetter || c.isNumber || c == "_" || c == "$" {
                result.append(c)
                i += 1
            } else {
                break
            }
        }
        return (result.isEmpty ? (String(chars[start]), start + 1) : (result, i))
    }

    private static func isOperator(_ c: Character) -> Bool {
        switch c {
        case "+", "-", "*", "/", "%", "=", "!", "<", ">", "&", "|", "^", "~", "?", ":":
            return true
        default:
            return false
        }
    }
}
