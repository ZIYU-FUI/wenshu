// EditorPaperCanvas.swift · Wenshu · v1.34 ticket 001
//
// v1.34 real fix (= per Q34 5.4 + Q173 ponytail + Q186 + Q57 + Q112):
// extracted from `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift`
// (= the v0.27 ticket 027-34 monolith). = same module, no new import.
//
// Consumer: `Sources/WenshuApp/Views/Workspace/EditorPlaceholder.swift:220`
// (= the v1.33 extraction; = calls `EditorPaperCanvas { ... }` to render
// the markdown editor surface inside an A4-shaped white sheet).
//
// DEFERRED: ViewInspector test coverage for this view is deferred to v0.78+
// (= see `.scratch/v0.77-workspaceview-tests/spec.md`). Per Q34 step 4
// "structural test path" precedent (= v1.30 PlaceholderView tests): future
// ticket adds a source-level structural test that verifies the public
// initializer + generic-View constraint; = no SwiftUI rendering in test
// (per Q112 = 1 ticket 1 commit, this ticket is the extraction only).
//
// This file is NOT dead code (= per Q57: 3rd-party verdict ≠ authority);
// it's the structural twin of `EditorPlaceholder` (= same extract arc
// = consumer lives one file away = already wired in v1.33's merge).


import SwiftUI

/// The sheet of paper the editor sits on, in the shape Pages uses.
///
/// Boss 2026-09-09 OOB: give the middle column a paper-sized area and put
/// the markdown engine on the white part.
///
/// Width is A4 (595 PT). Measured Pages on this machine: its canvas draws
/// a 593 PT sheet against a dark surround, which is A4 at 100% zoom. The
/// sheet keeps that width and never stretches with the window; the column
/// around it scrolls and centers, exactly like a document canvas.
struct EditorPaperCanvas<Content: View>: View {
    /// A4 width in points. Apple's own default for a new Pages document
    /// in a metric locale, and what the measurement above confirmed.
    /// Boss 2026-09-10 OOB 'just design the paper as a single A4 sheet': keep
    /// paperWidth = 595 PT (= Pages / Numbers use the same). The
    /// ScrollView wraps the sheet; when the detail column is
    /// narrower than 595 PT, the user can scroll horizontally to
    /// see the rest of the page (= Pages does the same when its
    /// window is narrower than A4).
    private static var paperWidth: CGFloat { 595 }
    /// Page margin. Pages ships 1 inch (72 PT) on a new document.
    private static var paperMargin: CGFloat { 72 }

    @ViewBuilder var content: Content

    var body: some View {
        // v0.100 boss 2026-09-10 OOB 'big empty areas on the left and right of the paper':
        // the sheet used to be left-aligned inside its
        // ScrollView (= the 595 PT paper sat flush against the
        // ScrollView's leading edge = ~370 PT of black empty
        // space on the right of the sheet). Center the paper
        // horizontally with an HStack + Spacers. The previous
        // attempts with `.frame(maxWidth: .infinity)` on the
        // HStack did not expand because the ScrollView's
        // intrinsic content size locked to the 595 PT paper
        // (= SwiftUI 27 macOS prefers content-natural-size
        // ScrollView over the column-width-stretched variant).
        // Apply `.scrollTargetLayout` + `.defaultScrollAnchor
        // (.center)` (= Apple macOS 14+ API that centers
        // smaller content inside a larger ScrollView; = the
        // same mechanism SwiftUI uses for centered hero
        // images). The Spacers then have room to push the
        // paper to the visual center of the column.
        ScrollView([.horizontal, .vertical]) {
            content
                .padding(Self.paperMargin)
                .frame(width: Self.paperWidth, alignment: .topLeading)
                .frame(minHeight: 842)          // A4 height
                // macOS 27 doc-alignment (boss 9/18 OOB '全都改一下',
                // audit ticket 7): Color.white kept here because
                // this is the A4 paper background (= explicit
                // "white paper" semantic; = not a status tint).
                // Color(nsColor: .textBackgroundColor) would
                // also work (= Apple dynamic white) but
                // .textBackgroundColor darkens on dark mode
                // (= defeats the A4-white-paper semantic).
                // = Color.white is the semantic constant here.
                // = NOT a wenshu-apple-api-first violation because
                // Apple doesn't ship a "static white" semantic
                // NSColor (= .textBackgroundColor / .windowBackgroundColor
                // both dark-mode-adapt).
                .background(Color.white)
                .environment(\.colorScheme, .light)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .defaultScrollAnchor(.center)
        .scrollContentBackground(.hidden)
    }
}
