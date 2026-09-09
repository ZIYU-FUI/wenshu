//
//  PreviewTabBackground.swift · Wenshu · v0.40 apple-001 Q2 slice 9b
//
//  Extracted from WorkspaceView.swift (formerly inline private
// struct at line 1862). Q2 boss split WorkspaceView. Slice 9b
//  = the empty Color.clear placeholder for the preview pane tab
//  background. Pane background uniformity is now applied by
//  ZonePerRegionChrome.
//
//  Apple HIG = one view per file. PreviewTabBackground is the
//  smallest extractable view left (= 5 LOC, pure stateless).
//  No params, no @State, no @Binding, no @Environment.
//

import SwiftUI

struct PreviewTabBackground: View {
    var body: some View {
        Color.clear
    }
}
