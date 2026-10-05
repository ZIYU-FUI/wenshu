//
// BacklinksPanel.swift
//

import Foundation
import SwiftUI

/// BacklinksPanel: SwiftUI View, show note backlinks
/// AppRootScene, standalone wait macOS
struct BacklinksPanel: View {
    @State private var viewModel: BacklinksViewModel

    init(viewModel: BacklinksViewModel = BacklinksViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        // macOS 27 doc-alignment ((see OOB.md #2026-09-18) '全都改一下',
        // ): BacklinksPanel is a content-layer
        // (= Z1 in apple-hig-visual-z-axis-layer-model.md L29-31)
        // NOT a chrome surface. Per (see OOB.md #2026-09-02) OOB "默认不加
        // 液态玻璃效果的, 我们就不加", no `.glassEffect(.regular)`
        // (= per-pane glass specular is forbidden per
        // pane-chrome-canonic-pattern.md L88). The placeholder
        // background is `.background { Color.clear }` (= no fill;
        // the window's containerBackground = windowBackgroundColor
        // from  shows through = canonical Apple
        // NSColor-managed window tone).
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "auto.backlinkspanel.l95.h69157839"))
                .font(.headline)
            if viewModel.isLoading {
                Text(String(localized: "auto.backlinkspanel.l98.h65489296"))
            } else if let _ = viewModel.error {
                Text(String(localized: "auto.backlinkspanel.l100.h25269061"))
                    .foregroundStyle(.red)
            } else {
                Text(String(localized: "backlinks.document_id"))
                    .font(.caption)
                Text(String(localized: "backlinks.links_count"))
                ForEach(viewModel.backlinks, id: \.offset) { link in
                    Text(String(localized: "b5.backlinkspanel.l107.h31356346"))
                        .font(.caption2)
                }
            }
        }
        .padding()
        // macOS 27 doc-alignment ((see OOB.md #2026-09-18) '全都改一下',
        // ): BacklinksPanel is a content-layer
        // (= Z1). No glass overlay (= (see OOB.md #2026-09-02) "默认不加
        // 液态玻璃效果的, 我们就不加"). The window's
        // containerBackground = windowBackgroundColor (set at
        // LibraryRootView, ) shows through.
        .background { Color.clear }
    }
}
