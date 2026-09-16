// ShellPlaceholder.swift · Wenshu · v1.34 ticket 001
//
// Extracted from NavigationSplitShell.swift (= v0.46 boss OOB).
//
// Per boss OOB 2026-09-14 '要修，继续' + repowise
// get_health directive (NavigationSplitShell = top #2 untested
// hotspot = 1564 NLOC, 10 deps, score 4.5).
//
// v1.34 continues the WorkspaceView split pattern (= v1.32
// ZoneModuleView + v1.33 EditorPlaceholder) by splitting
// NavigationSplitShell. The smallest struct (= ShellPlaceholder
// = 22 lines) is the SAFE first split.
//
// v1.34 aligns with boss's v1.x 'remove Lucide, use SF Symbols 6'
// decision (= merged 2026-09-15). After boss's deprecation
// canonical icon layer = Apple SF Symbols 6 built into macOS 27
// (= zero SPM dependency). This extracted file uses the SF
// Symbols version via `Image(systemName:)`.
//
// Per Q34 5.2 + Q173 ponytail + Q186 + Q57 + Q112: extract
// ShellPlaceholder to its own file. This is the SAFE first split
// because:
//   1. ShellPlaceholder is `public` (= accessible from WenshuApp module)
//   2. Dependency = `Image(systemName:)` (= built into SwiftUI;
//      no third-party icon library)
//   3. ShellPlaceholder is a leaf component (= no other structs
//      in NavigationSplitShell depend on it in a complex way;
//      just instantiation via ShellPlaceholder(name:icon:hint:))

import SwiftUI

struct ShellPlaceholder: View {
    let name: String
    let icon: String
    let hint: String

    var body: some View {
        // Canonical SF Symbols 6 icon layer (= boss 2026-09-15 OOB).
        ContentUnavailableView {
            // 38 PT matches the glyph height Apple's own
            // ContentUnavailableView renders, measured on this machine.
            Label { Text(name) } icon: { Image(systemName: icon).font(.system(size: 38, weight: .regular)) }
        } description: {
            Text(hint)
        }
    }
}

