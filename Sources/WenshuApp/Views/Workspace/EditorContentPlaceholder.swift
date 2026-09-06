//
//  EditorContentPlaceholder.swift · Wenshu · v0.40 apple-001 Q2 slice 9a
//
//  Extracted from WorkspaceView.swift (formerly inline private
//  struct at line 887). Q2 boss拍 split WorkspaceView. Slice 9a
//  = the empty Color.clear placeholder for the editor pane.
//  Pane background uniformity is now applied by ZonePerRegionChrome
//  (= the editor placeholder is just empty since v0.28 Boss UX
//  round 37 removed the Color.white.opacity(0.55) overlay).
//
//  Apple HIG = one view per file. EditorContentPlaceholder is the
//  smallest extractable view left (= 11 LOC, pure stateless).
//  No params, no @State, no @Binding, no @Environment.
//

import SwiftUI

struct EditorContentPlaceholder: View {
    var body: some View {
        // v0.28 followup Boss UX round 37: REMOVED the
        // Color.white.opacity(0.55) overlay (= was making the editor
        // pane appear LIGHTER than the other 5 panes = boss noticed
        // "is the editor background white? all the brightness looks different"). Now the
        // editor placeholder is just empty (= the background is
        // now applied uniformly by ZonePerRegionChrome).
        Color.clear
    }
}
