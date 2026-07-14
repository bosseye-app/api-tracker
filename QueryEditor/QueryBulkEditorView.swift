//
//  QueryBulkEditorView.swift
//  API Tracker and Monitor - Debug
//  https://apps.apple.com/app/id6787642796
//
//  Copyright © 2026 bosseye app. All rights reserved.
//
//  Bulk editor for URL query parameters in key=value format. Distinct
//  coloring separates parameter names from values, making it easy to tweak
//  pagination, filters, and search terms when testing REST endpoints.
//

import SwiftUI

/// Query parameter editor: key=value format with distinct colors for key and value; `#` starts a comment.
/// Per-line parsing with fault tolerance: a syntax error on one line won't affect subsequent lines.
public struct QueryBulkEditorView: View {
    @Binding var text: String

    @Environment(\.colorScheme) private var colorScheme

    public init(text: Binding<String>) {
        self._text = text
    }

    public var body: some View {
        lineNumberEditor(
            text: $text,
            highlightProvider: QueryHighlightService.highlight,
            wrapLines: true
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppConst.defaultCornerRadius)
                .stroke(AppTheme.border(for: colorScheme))
        )
    }
}

// MARK: - Preview

#if DEBUG
private struct QueryBulkEditorPreview: View {
    @State private var queryText = """
    page=1&limit=20&sort=created_at
    # This is a comment
    filter=active&tags=api,rest
    include=author,comments
    """

    var body: some View {
        QueryBulkEditorView(text: $queryText)
            .frame(minWidth: 500, minHeight: 200)
            .padding()
    }
}

#Preview("Query Editor") {
    QueryBulkEditorPreview()
}
#endif
