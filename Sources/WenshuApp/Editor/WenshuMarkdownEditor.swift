// Sources/WenshuApp/Editor/WenshuMarkdownEditor.swift
//
// v0.39 ticket 001 -- wenshu-side wrapper for swift-markdown-engine
// (= wenshu-side wins pattern per AGENTS.md §11.3: library provides
// the SwiftUI bridge, wenshu wires the data layer). Pass-through
// SwiftUI View that delegates to the engine's `NativeTextViewWrapper`
// (= which is itself an `NSViewRepresentable`). We don't subclass or
// reimplement NSViewRepresentable (= that would require duplicating
// the coordinator machinery, which the engine already owns); we
// simply hold the engine's wrapper and forward every View lifecycle
// to it.
//
// Why a struct (not a re-wrapper of NSViewRepresentable): SwiftUI's
// `View` protocol is the canonical composition seam. A struct
// conforming to `View` can store an `NSViewRepresentable` as a
// property and return it from `body` -- SwiftUI then calls
// `makeNSView` on the inner representable directly. This is the
// same pattern wenshu uses elsewhere (e.g. DropAffordance wrapping
// the macOS-native drop indicator).
//
// Real API (verified 2026-09-04 from swift-markdown-engine 0.12.0 source):
//   NativeTextViewWrapper.init(
//     text: Binding<String>,
//     isWikiLinkActive: Binding<Bool> = .constant(false),
//     pendingInlineReplacement: Binding<InlineReplacementRequest?> = .constant(nil),
//     configuration: MarkdownEditorConfiguration = .default,
//     fontName: String = "SF Pro",
//     fontSize: CGFloat = 16,
//     documentId: String = "default",
//     ...
//   )
// Services are NOT a separate init parameter; they live inside
// MarkdownEditorConfiguration.services.

import SwiftUI
import MarkdownEngine

struct WenshuMarkdownEditor: View {
    @Binding var text: String
    let draftId: String  // stable per tab (= engine requires it for undo scoping)
    let configuration: MarkdownEditorConfiguration

    var body: some View {
        // Engine wrapper is itself a NSViewRepresentable (= returns
        // NSScrollView, the document's scroll view wrapping the
        // NSTextView). We forward the View's body to it -- SwiftUI
        // will call the inner wrapper's makeNSView + updateNSView at
        // the right moments, owning the full coordinator lifecycle.
        NativeTextViewWrapper(
            text: $text,
            configuration: configuration,
            documentId: draftId
        )
    }
}
