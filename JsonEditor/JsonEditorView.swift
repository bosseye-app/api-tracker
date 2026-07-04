import SwiftUI

/// A compact editor with line numbers and JSON syntax highlighting, supporting Pretty/Minified formatting.
/// Uses per-line highlighting with fault tolerance — a syntax error on one line won't block subsequent lines.
/// Fixed-width line-number gutter on the left, editable content on the right.
public struct JsonEditorView: View {
    @Binding var text: String

    @Environment(\.colorScheme) private var colorScheme

    public init(text: Binding<String>) {
        self._text = text
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            lineNumberEditor(
                text: $text,
                highlightProvider: JsonHighlightService.highlight
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppConst.defaultCornerRadius)
                    .stroke(AppTheme.border(for: colorScheme))
            )

            HStack(spacing: 8) {
                Button {
                    if let pretty = JsonHighlightService.prettyPrinted(text) {
                        text = pretty
                    }
                } label: {
                    Label("Pretty JSON", systemImage: "text.alignleft")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button {
                    if let minified = JsonHighlightService.minified(text) {
                        text = minified
                    }
                } label: {
                    Label("Minified JSON", systemImage: "arrow.down.right.and.arrow.up.left")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Preview

#if DEBUG
private struct JsonEditorPreview: View {
    @State private var jsonText = """
    {
      "name": "API Tracker",
      "version": "1.0.0",
      "features": ["http", "websocket", "graphql"],
      "active": true,
      "count": 42,
      "metadata": null
    }
    """

    var body: some View {
        JsonEditorView(text: $jsonText)
            .frame(minWidth: 500, minHeight: 400)
            .padding()
    }
}

#Preview("JSON Editor") {
    JsonEditorPreview()
}
#endif
