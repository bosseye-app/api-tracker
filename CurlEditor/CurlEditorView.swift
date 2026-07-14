//
//  CurlEditorView.swift
//  API Tracker and Monitor - Debug
//  https://apps.apple.com/app/id6787642796
//
//  Copyright © 2026 bosseye app. All rights reserved.
//
//  Paste any cURL command and instantly turn it into a structured API request.
//  Handles everything from Bearer tokens to multipart forms — a handy bridge
//  between terminal workflows and the API Tracker debugging environment.
//

import SwiftUI

/// A self-contained cURL command importer. Validates and parses cURL commands
/// into structured API request components (URL, headers, query params, body, auth).
public struct CurlEditorView: View {
    public static let editorMinHeight: CGFloat = 330

    @Binding var commandText: String
    let service: CurlEditorService
    let onCancel: () -> Void
    let onImport: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme

    public init(
        commandText: Binding<String>,
        onCancel: @escaping () -> Void,
        onImport: @escaping (String) -> Void
    ) {
        self._commandText = commandText
        self.service = CurlEditorService()
        self.onCancel = onCancel
        self.onImport = onImport
    }

    private var validation: CurlEditorValidation {
        service.validateCommand(commandText)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste a cURL command to split it into URL, Query Parameters, Headers, and Body.")
                .foregroundStyle(AppTheme.secondaryText(for: colorScheme))

            TextEditor(text: $commandText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: Self.editorMinHeight, alignment: .topLeading)
                .overlay {
                    RoundedRectangle(cornerRadius: AppConst.defaultCornerRadius)
                        .stroke(AppTheme.border(for: colorScheme))
                }

            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: validation.isValid ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    Text(validation.statusText)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(validation.isValid ? AppTheme.success(for: colorScheme) : AppTheme.error(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("Cancel", role: .cancel, action: onCancel)

                Button {
                    onImport(commandText)
                } label: {
                    Label("Import cURL", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!validation.isValid)
            }
        }
        .padding(20)
        .frame(minWidth: 760)
    }
}

// MARK: - Preview

#if DEBUG
private struct CurlEditorPreview: View {
    @State private var curlText = """
    curl -X POST https://api.example.com/v1/users \\
      -H "Content-Type: application/json" \\
      -H "Authorization: Bearer token123" \\
      -d '{"name": "John", "email": "john@example.com"}'
    """

    var body: some View {
        CurlEditorView(
            commandText: $curlText,
            onCancel: { print("Cancel") },
            onImport: { print("Import: \($0)") }
        )
        .frame(width: 800, height: 500)
    }
}

#Preview("cURL Editor") {
    CurlEditorPreview()
}
#endif
