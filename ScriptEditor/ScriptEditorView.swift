//
//  ScriptEditorView.swift
//  API Tracker and Monitor - Debug
//  https://apps.apple.com/app/id6787642796
//
//  Copyright © 2026 bosseye app. All rights reserved.
//
//  JavaScript editor for pre-request and post-response scripting. Write
//  dynamic logic that modifies headers, transforms payloads, or chains
//  multiple API calls — all within the API Tracker debugging workflow.
//

import SwiftUI

/// JavaScript/script syntax-highlighting editor with keyword, string, number, comment, and identifier coloring.
/// Per-line parsing with fault tolerance: a syntax error on one line won't affect highlighting of later lines.
public struct ScriptEditorView: View {
    @Binding var text: String
    var placeholder: String = ""

    @Environment(\.colorScheme) private var colorScheme

    public init(text: Binding<String>, placeholder: String = "") {
        self._text = text
        self.placeholder = placeholder
    }

    public var body: some View {
        lineNumberEditor(
            text: $text,
            highlightProvider: ScriptHighlightService.highlight,
            wrapLines: true,
            placeholder: placeholder
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppConst.defaultCornerRadius)
                .stroke(AppTheme.border(for: colorScheme))
        )
    }
}

// MARK: - Preview

#if DEBUG
private struct ScriptEditorPreview: View {
    @State private var scriptText = """
    // Pre-request Script
    const timestamp = Date.now();
    const token = generateAuthToken();

    request.headers["Authorization"] = `Bearer ${token}`;
    request.headers["X-Timestamp"] = timestamp;

    function generateAuthToken() {
        const secret = variables.get("api_secret");
        return btoa(secret + ":" + timestamp);
    }
    """

    var body: some View {
        ScriptEditorView(text: $scriptText, placeholder: "Write your pre-request script here...")
            .frame(minWidth: 500, minHeight: 300)
            .padding()
    }
}

#Preview("Script Editor") {
    ScriptEditorPreview()
}
#endif
