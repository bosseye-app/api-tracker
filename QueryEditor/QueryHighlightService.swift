//
//  QueryHighlightService.swift
//  API Tracker and Monitor - Debug
//  https://apps.apple.com/app/id6787642796
//
//  Copyright © 2026 bosseye app. All rights reserved.
//
//  Syntax highlighting engine for URL query strings. Highlights keys (green),
//  values (yellow), and comment lines (`#`) — a small but sharp tool for
//  keeping your API parameters readable while monitoring live traffic.
//

import SwiftUI

/// Query parameter syntax highlighting service (key=value format).
/// - `key` (before `=`) -> queryKey color (green)
/// - `value` (after `=`) -> queryValue color (yellow)
/// - `&` separates multiple key=value pairs
/// - Lines starting with `#` -> queryComment color
/// Per-line parsing with no cross-line state.
public enum QueryHighlightService {

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

    private static func highlightLine(_ line: String, into tokens: inout [HighlightToken]) {
        let chars = Array(line)
        var i = 0

        // Comment line
        if line.hasPrefix("#") {
            tokens.append(HighlightToken(text: line, kind: .queryComment))
            return
        }

        // Empty line
        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            tokens.append(HighlightToken(text: line, kind: .whitespace))
            return
        }

        while i < chars.count {
            // Whitespace
            if chars[i] == " " || chars[i] == "\t" {
                var ws = ""
                while i < chars.count && (chars[i] == " " || chars[i] == "\t") {
                    ws.append(chars[i])
                    i += 1
                }
                tokens.append(HighlightToken(text: ws, kind: .whitespace))
                continue
            }

            // & separator
            if chars[i] == "&" {
                tokens.append(HighlightToken(text: "&", kind: .punctuation))
                i += 1
                continue
            }

            // Read one key=value segment (until & or end of line)
            var segment = ""
            while i < chars.count && chars[i] != "&" {
                segment.append(chars[i])
                i += 1
            }

            // Parse key=value
            if let eqIndex = segment.firstIndex(of: "=") {
                let key = String(segment[..<eqIndex])
                let value = String(segment[segment.index(after: eqIndex)...])
                tokens.append(HighlightToken(text: key, kind: .queryKey))
                tokens.append(HighlightToken(text: "=", kind: .punctuation))
                tokens.append(HighlightToken(text: value, kind: .queryValue))
            } else {
                tokens.append(HighlightToken(text: segment, kind: .queryKey))
            }
        }
    }
}
