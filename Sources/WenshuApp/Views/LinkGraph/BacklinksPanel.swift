//
// BacklinksPanel.swift · Wenshu · migrated from Core/LinkGraph/BacklinksPanel.swift in v1.28 A1.1
//

import Foundation
import SwiftUI

/// BacklinksPanel: SwiftUI View, show note backlinks
/// LayoutShellView [no longer defined post-v0.72 — AppRootScene + NavigationSplitView; = ADR-0007 pending ADR-0010; = type references kept as historical landmarks pending 老板 拍], standalone wait macOS
struct BacklinksPanel: View {
    @State private var viewModel: BacklinksViewModel

    init(viewModel: BacklinksViewModel = BacklinksViewModel()) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        // macOS 27 doc-alignment ((see OOB.md #2026-09-18) '全都改一下',
        // audit ticket 2): BacklinksPanel is a content-layer
        // (= Z1 in apple-hig-visual-z-axis-layer-model.md L29-31)
        // NOT a chrome surface. Per (see OOB.md #2026-09-02) OOB "默认不加
        // 液态玻璃效果的, 我们就不加", no `.glassEffect(.regular)`
        // (= per-pane glass specular is forbidden per
        // pane-chrome-canonic-pattern.md L88). The placeholder
        // background is `.background { Color.clear }` (= no fill;
        // the window's containerBackground = windowBackgroundColor
        // from audit ticket 1 shows through = canonical Apple
        // NSColor-managed window tone).
        VStack(alignment: .leading, spacing: 8) {
            Text(WenshuI18n.t("auto.backlinkspanel.l95.h69157839"))
                .font(.headline)
            if viewModel.isLoading {
                Text(WenshuI18n.t("auto.backlinkspanel.l98.h65489296"))
            } else if let _ = viewModel.error {
                Text(WenshuI18n.t("auto.backlinkspanel.l100.h25269061"))
                    .foregroundStyle(.red)
            } else {
                Text(WenshuI18n.t("backlinks.document_id"))
                    .font(.caption)
                Text(WenshuI18n.t("backlinks.links_count"))
                ForEach(viewModel.backlinks, id: \.offset) { link in
                    Text(WenshuI18n.t("b5.backlinkspanel.l107.h31356346"))
                        .font(.caption2)
                }
            }
        }
        .padding()
        // macOS 27 doc-alignment ((see OOB.md #2026-09-18) '全都改一下',
        // audit ticket 2): BacklinksPanel is a content-layer
        // (= Z1). No glass overlay (= (see OOB.md #2026-09-02) "默认不加
        // 液态玻璃效果的, 我们就不加"). The window's
        // containerBackground = windowBackgroundColor (set at
        // LibraryRootView, audit ticket 1) shows through.
        .background { Color.clear }
    }
}
