//
//  CommandPaletteHost.swift · Wenshu · CHATBOX-002 (2026-09-04)
//
//  Wrapper view that hosts the ⌘K command palette sheet. Attached to
//  the WindowGroup root so the sheet inherits the active window's
//  focus + key state (= Apple HIG canonical pattern).
//
//  The .commands block in App.swift posts
//  .wenshuShowCommandPalette (= no SwiftUI environment access from
//  Commands). This view listens and toggles the sheet via a
//  @State model.
//

import SwiftUI

/// View wrapper that hosts the ⌘K palette sheet (= App.swift attaches
/// it to the WindowGroup root).
public struct CommandPaletteHost<Content: View>: View {
    @State private var model = CommandPaletteModel()
    @State private var sheetVisible: Bool = false
    private let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        content()
            // CHATBOX-002: present the palette as a modal sheet when
            // ⌘K is pressed. The sheet binds to this view's lifetime
            // (= the WindowGroup instance, not the inner content tree).
            // Apple HIG: .sheet with .medium / .large presentation
            // detents = canonical modal sheet on macOS 27.
            .sheet(isPresented: $sheetVisible) {
                CommandPaletteView(model: model)
                    // v0.40 apple-001 HIG absent batch: .navigationTitle
                    // (= Apple HIG standard for sheet title). Set on
                    // the sheet content (= outside the inner view)
                    // since the CommandPaletteView itself doesn't use
                    // NavigationStack. The title is suppressed by the
                    // macOS sheet chrome by default for short-lived
                    // modals, but it's available for VoiceOver / menu
                    // metadata (= Apple HIG accessibility standard).
                    .navigationTitle(WenshuI18n.t("command_palette.title"))
            }
            .onReceive(NotificationCenter.default.publisher(for: .wenshuShowCommandPalette)) { _ in
                sheetVisible = true
                model.show()
            }
    }
}
