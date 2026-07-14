//
//  EditorComponents.swift
//  API Tracker and Monitor - Debug
//  https://apps.apple.com/app/id6787642796
//
//  Copyright © 2026 bosseye app. All rights reserved.
//
//  Foundation layer for syntax-highlighted code editors. Provides the shared
//  lineNumberEditor NSViewRepresentable and HighlightToken model used by the
//  JSON, JavaScript, query parameter, and cURL editors throughout the app.
//

import SwiftUI

// MARK: - Highlight Token Model

struct HighlightToken {
    enum Kind {
        case key, string, number, boolean, null, punctuation, whitespace, plain
        case queryKey, queryValue, queryComment
        case scriptKeyword, scriptIdentifier, scriptString, scriptNumber, scriptComment, scriptOperator
    }

    let text: String
    let kind: Kind
}

// MARK: - Color Resolver (shared)

func resolveHighlightColor(for kind: HighlightToken.Kind, isDark: Bool) -> NSColor {
    switch kind {
    case .key:
        return isDark ? NSColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 1) : NSColor(red: 0.1, green: 0.5, blue: 0.1, alpha: 1)
    case .string:
        return isDark ? NSColor(red: 0.95, green: 0.85, blue: 0.35, alpha: 1) : NSColor(red: 0.7, green: 0.55, blue: 0.05, alpha: 1)
    case .number:
        return isDark ? NSColor(red: 0.7, green: 0.5, blue: 0.95, alpha: 1) : NSColor(red: 0.45, green: 0.2, blue: 0.8, alpha: 1)
    case .boolean, .null:
        return isDark ? NSColor(red: 0.7, green: 0.5, blue: 0.95, alpha: 1) : NSColor(red: 0.45, green: 0.2, blue: 0.8, alpha: 1)
    case .punctuation:
        return isDark ? NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1) : NSColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1)
    case .whitespace:
        return .clear
    case .plain:
        return isDark ? NSColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1) : NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1)
    case .queryKey:
        return isDark ? NSColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 1) : NSColor(red: 0.1, green: 0.5, blue: 0.1, alpha: 1)
    case .queryValue:
        return isDark ? NSColor(red: 0.95, green: 0.85, blue: 0.35, alpha: 1) : NSColor(red: 0.7, green: 0.55, blue: 0.05, alpha: 1)
    case .queryComment:
        return isDark ? NSColor(red: 0.5, green: 0.55, blue: 0.5, alpha: 1) : NSColor(red: 0.4, green: 0.45, blue: 0.4, alpha: 1)
    case .scriptKeyword:
        return isDark ? NSColor(red: 0.85, green: 0.45, blue: 0.65, alpha: 1) : NSColor(red: 0.55, green: 0.15, blue: 0.45, alpha: 1)
    case .scriptIdentifier:
        return isDark ? NSColor(red: 0.85, green: 0.85, blue: 0.5, alpha: 1) : NSColor(red: 0.45, green: 0.45, blue: 0.05, alpha: 1)
    case .scriptString:
        return isDark ? NSColor(red: 0.45, green: 0.75, blue: 0.45, alpha: 1) : NSColor(red: 0.15, green: 0.45, blue: 0.15, alpha: 1)
    case .scriptNumber:
        return isDark ? NSColor(red: 0.6, green: 0.85, blue: 0.6, alpha: 1) : NSColor(red: 0.15, green: 0.45, blue: 0.25, alpha: 1)
    case .scriptComment:
        return isDark ? NSColor(red: 0.5, green: 0.55, blue: 0.5, alpha: 1) : NSColor(red: 0.4, green: 0.45, blue: 0.4, alpha: 1)
    case .scriptOperator:
        return isDark ? NSColor(red: 0.85, green: 0.55, blue: 0.55, alpha: 1) : NSColor(red: 0.55, green: 0.15, blue: 0.15, alpha: 1)
    }
}

// MARK: - Syntax Highlighting Editor (NSViewRepresentable)

/// Native NSTextView-based editor with line numbers and syntax highlighting.
/// Fixed-width line-number gutter on the left, editable content area on the right,
/// with real-time coloring via NSTextStorageDelegate.
struct lineNumberEditor: NSViewRepresentable {
    @Binding var text: String
    let highlightProvider: (String, ColorScheme) -> [HighlightToken]
    var wrapLines: Bool = false
    var placeholder: String = ""

    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, highlightProvider: highlightProvider, colorScheme: colorScheme, wrapLines: wrapLines, placeholder: placeholder)
    }

    func makeNSView(context: Context) -> NSView {
        let coord = context.coordinator
        let container = coord.containerView
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        let coord = context.coordinator
        let textView = coord.textView

        // Only sync when external text differs
        if textView.string != text {
            textView.string = text
            coord.applyHighlighting()
        }

        // Re-highlight when color mode changes
        if coord.colorScheme != colorScheme {
            coord.colorScheme = colorScheme
            coord.applyHighlighting()
        }

        // Update placeholder visibility
        coord.updatePlaceholder()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextStorageDelegate {
        var text: Binding<String>
        let highlightProvider: (String, ColorScheme) -> [HighlightToken]
        var colorScheme: ColorScheme
        let wrapLines: Bool
        let placeholder: String

        let containerView: NSView
        let textView: NSTextView
        let lineNumberTextView: NSTextView
        let editorScrollView: NSScrollView
        let lineNumberScrollView: NSScrollView
        let placeholderTextView: NSTextView

        private var isApplyingHighlight = false
        private let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        private let lineNumberWidth: CGFloat = 42

        init(text: Binding<String>, highlightProvider: @escaping (String, ColorScheme) -> [HighlightToken], colorScheme: ColorScheme, wrapLines: Bool, placeholder: String) {
            self.text = text
            self.highlightProvider = highlightProvider
            self.colorScheme = colorScheme
            self.wrapLines = wrapLines
            self.placeholder = placeholder

            // ---- Container View ----
            let container = NSView()
            self.containerView = container

            // ---- Line Number View (fixed left) ----
            let ln = NSTextView()
            ln.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            ln.textColor = NSColor.secondaryLabelColor.withAlphaComponent(0.6)
            ln.isEditable = false
            ln.isSelectable = false
            ln.drawsBackground = false
            ln.alignment = .right
            ln.textContainerInset = NSSize(width: 4, height: 4)
            ln.textContainer?.widthTracksTextView = true
            ln.textContainer?.heightTracksTextView = false
            self.lineNumberTextView = ln

            // ---- Main Editor (right, editable) ----
            let tv = NSTextView()
            tv.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            tv.textColor = NSColor.labelColor
            tv.isEditable = true
            tv.isSelectable = true
            tv.textContainerInset = NSSize(width: 8, height: 4)
            if wrapLines {
                // Wrap mode: width tracks container, vertical scroll only
                tv.textContainer?.widthTracksTextView = true
                tv.isHorizontallyResizable = false
                tv.autoresizingMask = [.width]
            } else {
                // No-wrap mode: horizontal infinite expansion
                tv.textContainer?.widthTracksTextView = false
                tv.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                tv.isHorizontallyResizable = true
                tv.autoresizingMask = [.width, .height]
            }
            // Disable smart quote substitution to prevent " from becoming curly quotes
            tv.isAutomaticQuoteSubstitutionEnabled = false
            tv.isAutomaticDashSubstitutionEnabled = false
            tv.isAutomaticTextReplacementEnabled = false
            tv.smartInsertDeleteEnabled = false
            self.textView = tv

            // ---- Placeholder View (overlaid on editor) ----
            let ph = NSTextView()
            ph.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            ph.textColor = NSColor.tertiaryLabelColor
            ph.isEditable = false
            ph.isSelectable = false
            ph.drawsBackground = false
            ph.textContainerInset = NSSize(width: 8, height: 4)
            ph.textContainer?.widthTracksTextView = true
            ph.textContainer?.heightTracksTextView = false
            ph.string = placeholder
            self.placeholderTextView = ph

            // ---- Editor Scroll View ----
            let editorSV = NSScrollView()
            editorSV.documentView = tv
            editorSV.hasVerticalScroller = true
            editorSV.hasHorizontalScroller = false
            editorSV.autohidesScrollers = true
            editorSV.borderType = .noBorder
            editorSV.drawsBackground = false
            editorSV.translatesAutoresizingMaskIntoConstraints = false
            self.editorScrollView = editorSV

            // ---- Line Number Scroll View (hidden scroller, synced with editor) ----
            let lnSV = NSScrollView()
            lnSV.documentView = ln
            lnSV.hasVerticalScroller = false
            lnSV.hasHorizontalScroller = false
            lnSV.borderType = .noBorder
            lnSV.drawsBackground = false
            lnSV.translatesAutoresizingMaskIntoConstraints = false
            lnSV.verticalScrollElasticity = .none
            self.lineNumberScrollView = lnSV

            super.init()

            // ---- Assemble Container Layout ----
            container.addSubview(lnSV)
            container.addSubview(editorSV)

            // Placeholder overlay on top of editor content area
            ph.translatesAutoresizingMaskIntoConstraints = false
            ph.isHidden = !text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            container.addSubview(ph)

            NSLayoutConstraint.activate([
                lnSV.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                lnSV.topAnchor.constraint(equalTo: container.topAnchor),
                lnSV.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                lnSV.widthAnchor.constraint(equalToConstant: lineNumberWidth),

                editorSV.leadingAnchor.constraint(equalTo: lnSV.trailingAnchor),
                editorSV.topAnchor.constraint(equalTo: container.topAnchor),
                editorSV.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                editorSV.bottomAnchor.constraint(equalTo: container.bottomAnchor),

                ph.leadingAnchor.constraint(equalTo: editorSV.leadingAnchor),
                ph.trailingAnchor.constraint(equalTo: editorSV.trailingAnchor),
                ph.topAnchor.constraint(equalTo: editorSV.topAnchor),
            ])

            // ---- Set up textStorage delegate ----
            tv.textStorage?.delegate = self

            // ---- Observe text changes → sync Binding ----
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(textDidChange(_:)),
                name: NSText.didChangeNotification,
                object: tv
            )

            // ---- Observe editor scroll → sync line numbers ----
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(editorDidScroll(_:)),
                name: NSView.boundsDidChangeNotification,
                object: editorSV.contentView
            )

            // ---- Observe editor frame changes → sync line number height ----
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(editorLayoutChanged(_:)),
                name: NSView.frameDidChangeNotification,
                object: tv
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc private func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView, tv === textView else { return }
            let newValue = tv.string
            if text.wrappedValue != newValue {
                text.wrappedValue = newValue
            }
            updatePlaceholder()
        }

        @objc private func editorDidScroll(_ notification: Notification) {
            // Sync line number scroll: map editor scrollView contentOffset to line number scrollView
            let editorOffset = editorScrollView.contentView.bounds.origin
            lineNumberScrollView.contentView.scroll(NSPoint(x: 0, y: editorOffset.y))
        }

        @objc private func editorLayoutChanged(_ notification: Notification) {
            // Sync line number height
            let editorHeight = textView.frame.height
            if lineNumberTextView.frame.size.height != editorHeight {
                lineNumberTextView.frame.size.height = editorHeight
            }
        }

        // MARK: - Placeholder

        func updatePlaceholder() {
            let isEmpty = textView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            placeholderTextView.isHidden = !isEmpty
        }

        // MARK: - NSTextStorageDelegate

        func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
            guard editedMask.contains(.editedCharacters) else { return }
            applyHighlighting()
            updateLineNumbers()
        }

        // MARK: - Highlighting

        func applyHighlighting() {
            guard !isApplyingHighlight else { return }
            isApplyingHighlight = true
            defer { isApplyingHighlight = false }

            let fullText = textView.string
            let tokens = highlightProvider(fullText, colorScheme)

            let attributed = NSMutableAttributedString()
            let isDark = colorScheme == .dark
            let defaultFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

            for token in tokens {
                let color = resolveHighlightColor(for: token.kind, isDark: isDark)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: defaultFont,
                    .foregroundColor: color,
                ]
                attributed.append(NSAttributedString(string: token.text, attributes: attrs))
            }

            // Preserve cursor position
            let selectedRanges = textView.selectedRanges

            textView.textStorage?.setAttributedString(attributed)

            textView.selectedRanges = selectedRanges
        }

        // MARK: - Line Numbers

        func updateLineNumbers() {
            if wrapLines {
                // Defer to next runloop to avoid querying layoutManager during textStorage editing
                DispatchQueue.main.async { [weak self] in
                    self?.updateLineNumbersWithWrap()
                }
            } else {
                let lines = textView.string.components(separatedBy: .newlines)
                lineNumberTextView.string = lines.enumerated().map { "\($0.offset + 1)" }.joined(separator: "\n")
            }
        }

        /// Word-wrap mode: line numbers only reflect logical lines (separated by \n). Soft-wrapped visual lines are not numbered.
        private func updateLineNumbersWithWrap() {
            guard let layoutManager = textView.layoutManager else { return }

            let textString = textView.string as NSString
            let fullLength = textString.length
            var visualLineNumbers: [String] = []
            var charIndex = 0
            var logicalLineNumber = 1

            while charIndex < fullLength {
                // Find end of current logical line (next \n or end of text)
                var lineEnd = charIndex
                while lineEnd < fullLength {
                    let ch = textString.character(at: lineEnd)
                    if ch == 0x0A { // \n
                        break
                    }
                    lineEnd += 1
                }

                let charRange = NSRange(location: charIndex, length: lineEnd - charIndex)
                let glyphRange = layoutManager.glyphRange(forCharacterRange: charRange, actualCharacterRange: nil)

                // Count visual lines this logical line occupies
                var visualLineCount = 0
                if glyphRange.length > 0 {
                    var rangeStart = glyphRange.location
                    let rangeEnd = NSMaxRange(glyphRange)
                    while rangeStart < rangeEnd {
                        var effectiveRange = NSRange(location: 0, length: 0)
                        layoutManager.lineFragmentRect(forGlyphAt: rangeStart, effectiveRange: &effectiveRange)
                        visualLineCount += 1
                        rangeStart = NSMaxRange(effectiveRange)
                    }
                } else {
                    visualLineCount = 1 // Empty lines occupy at least one visual row
                }

                // First visual line shows the number; subsequent soft-wrapped lines are blank
                visualLineNumbers.append("\(logicalLineNumber)")
                for _ in 1..<visualLineCount {
                    visualLineNumbers.append("")
                }

                logicalLineNumber += 1
                charIndex = lineEnd + 1 // Skip \n
            }

            // If text ends with \n, the trailing newline counts as one more logical line
            if fullLength > 0 && textString.character(at: fullLength - 1) == 0x0A {
                visualLineNumbers.append("\(logicalLineNumber)")
            }

            lineNumberTextView.string = visualLineNumbers.joined(separator: "\n")

            // Sync line number height and scroll offset
            let editorHeight = textView.frame.height
            if lineNumberTextView.frame.size.height != editorHeight {
                lineNumberTextView.frame.size.height = editorHeight
            }
            let editorOffset = editorScrollView.contentView.bounds.origin
            lineNumberScrollView.contentView.scroll(NSPoint(x: 0, y: editorOffset.y))
        }
    }
}
