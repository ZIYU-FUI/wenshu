//
//  PreviewPane+AdaptiveColumns.swift · Wenshu · v1.28 C3.3.1
//
//  v1.28 C3.3.1: extract the `adaptiveColumns(width:)` pure function from
//  PreviewPane.swift into a focused extension file.
//
//  Originally at PreviewPane.swift:1335-1350 (= 15 LOC including docstring).
//  The function is a pure helper (= depends only on the `width` parameter
//  and the static `twoColumnBreakpoint` constant; = no PreviewPane state).
//
//  Behavior preserved (= same 2-column / 1-column breakpoint logic; = same
//  GridItem.flexible + spacing: 16 + alignment: .topLeading).
//

import SwiftUI

extension PreviewPane {
    /// Compute the grid column count based on the available width.
    /// - 2 columns when width >= `twoColumnBreakpoint` (= wide layout;
    ///   = the canonical iPad split-view and macOS dual-pane layout)
    /// - 1 column when width < `twoColumnBreakpoint` (= narrow layout;
    ///   = the canonical iPhone stack and macOS single-pane layout)
    ///
    /// v0.25.1 boss OOB: the breakpoint is 600 PT (= the Apple HIG
    /// compact-vs-regular size class threshold).
    func adaptiveColumns(width: CGFloat) -> [GridItem] {
        if width >= Self.twoColumnBreakpoint {
            // 2 fixed columns (= 50/50 split with spacing in between)
            return [
                GridItem(.flexible(), spacing: 16, alignment: .topLeading),
                GridItem(.flexible(), spacing: 16, alignment: .topLeading),
            ]
        } else {
            // 1 column (= full width)
            return [GridItem(.flexible(), spacing: 16, alignment: .topLeading)]
        }
    }
}
