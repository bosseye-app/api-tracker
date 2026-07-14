//
//  JsonHighlightService.swift
//  API Tracker and Monitor - Debug
//  https://apps.apple.com/app/id6787642796
//
//  Copyright © 2026 bosseye app. All rights reserved.
//
//  Per-line JSON syntax highlighting with graceful error recovery. A broken
//  bracket or misplaced comma won't cascade — each line resets independently,
//  so you can keep reading API responses even when the payload is malformed.
//

import SwiftUI

/// JSON syntax highlighting service with per-line fault tolerance.
/// If one line has a syntax error (e.g., missing bracket, extra comma),
/// subsequent lines are re-evaluated independently without cascading state.
public enum JsonHighlightService {

    // MARK: - Highlight

    /// Split text into highlight tokens. Fault-tolerant: parse line by line without carrying state across lines.
    public static func highlight(_ text: String, _ colorScheme: ColorScheme) -> [HighlightToken] {
        guard !text.isEmpty else { return [] }

        var tokens: [HighlightToken] = []
        let lines = text.components(separatedBy: .newlines)

        for (lineIndex, line) in lines.enumerated() {
            if lineIndex > 0 {
                tokens.append(HighlightToken(text: "\n", kind: .whitespace))
            }
            highlightLine(line, into: &tokens)
        }

        return tokens
    }

    /// Per-line highlighting: each line parsed independently, no cross-line state accumulation.
    private static func highlightLine(_ line: String, into tokens: inout [HighlightToken]) {
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

            // String (check if key or value)
            if c == "\"" {
                let (text, endIndex) = consumeString(chars: chars, from: i)
                var peek = endIndex
                while peek < chars.count && (chars[peek] == " " || chars[peek] == "\t") {
                    peek += 1
                }
                let kind: HighlightToken.Kind = (peek < chars.count && chars[peek] == ":") ? .key : .string
                tokens.append(HighlightToken(text: text, kind: kind))
                i = endIndex
                continue
            }

            // Number
            if c == "-" || c.isNumber {
                let (text, endIndex) = consumeNumber(chars: chars, from: i)
                if text.count > 1 || c.isNumber {
                    tokens.append(HighlightToken(text: text, kind: .number))
                    i = endIndex
                    continue
                }
            }

            // boolean / null keywords
            let remaining = String(chars[i...])
            if remaining.hasPrefix("true") && isWordBoundary(chars: chars, at: i + 4) {
                tokens.append(HighlightToken(text: "true", kind: .boolean))
                i += 4
                continue
            }
            if remaining.hasPrefix("false") && isWordBoundary(chars: chars, at: i + 5) {
                tokens.append(HighlightToken(text: "false", kind: .boolean))
                i += 5
                continue
            }
            if remaining.hasPrefix("null") && isWordBoundary(chars: chars, at: i + 4) {
                tokens.append(HighlightToken(text: "null", kind: .null))
                i += 4
                continue
            }

            // Punctuation
            if isJSONPunctuation(c) {
                tokens.append(HighlightToken(text: String(c), kind: .punctuation))
                i += 1
                continue
            }

            // Plain text (possibly a key or malformed content)
            let (word, nextIdx) = consumeWord(chars: chars, from: i)
            if nextIdx < chars.count {
                var peek = nextIdx
                while peek < chars.count && (chars[peek] == " " || chars[peek] == "\t") {
                    peek += 1
                }
                if peek < chars.count && chars[peek] == ":" {
                    tokens.append(HighlightToken(text: word, kind: .key))
                    i = nextIdx
                    continue
                }
            }

            tokens.append(HighlightToken(text: word, kind: .plain))
            i = nextIdx
        }
    }

    // MARK: - Consume helpers

    private static func consumeString(chars: [Character], from start: Int) -> (String, Int) {
        var result = "\""
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

            if c == "\"" {
                i += 1
                break
            }

            i += 1
        }

        return (result, i)
    }

    private static func consumeNumber(chars: [Character], from start: Int) -> (String, Int) {
        var result = ""
        var i = start

        if i < chars.count && chars[i] == "-" {
            result.append("-")
            i += 1
        }

        while i < chars.count && chars[i].isNumber {
            result.append(chars[i])
            i += 1
        }

        if i < chars.count && chars[i] == "." {
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
        while i < chars.count && !isWordStop(chars[i]) {
            result.append(chars[i])
            i += 1
        }
        return (result, i)
    }

    private static func isWordStop(_ c: Character) -> Bool {
        c == " " || c == "\t" || c == "\r" || c == "\"" || isJSONPunctuation(c)
    }

    private static func isJSONPunctuation(_ c: Character) -> Bool {
        switch c {
        case ":", ",", "{", "}", "[", "]":
            return true
        default:
            return false
        }
    }

    private static func isWordBoundary(chars: [Character], at index: Int) -> Bool {
        guard index <= chars.count else { return true }
        if index == chars.count { return true }
        return isWordStop(chars[index])
    }

    // MARK: - Formatting

    /// Normalize quotes: replace curly/smart quotes with standard ASCII double quotes
    private static func normalizeQuotes(_ text: String) -> String {
        var result = text
        let replacements: [(String, String)] = [
            ("\u{201C}", "\""), // "
            ("\u{201D}", "\""), // "
            ("\u{2018}", "'"),  // '
            ("\u{2019}", "'"),  // '
        ]
        for (from, to) in replacements {
            result = result.replacingOccurrences(of: from, with: to)
        }
        return result
    }

    /// Attempt to format text as pretty-printed JSON.
    public static func prettyPrinted(_ text: String) -> String? {
        let normalized = normalizeQuotes(text)
        guard let data = normalized.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let pretty = String(data: prettyData, encoding: .utf8) else {
            return nil
        }
        return pretty
    }

    /// Attempt to format text as minified JSON.
    public static func minified(_ text: String) -> String? {
        let normalized = normalizeQuotes(text)
        guard let data = normalized.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let minData = try? JSONSerialization.data(withJSONObject: json, options: []),
              let min = String(data: minData, encoding: .utf8) else {
            return nil
        }
        return min
    }
}
