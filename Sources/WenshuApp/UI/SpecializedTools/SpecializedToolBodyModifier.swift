//
//  SpecializedToolBodyModifier.swift · Wenshu · v1.28 Tier C
//
//  v1.28 C3.7.1: View modifier that wraps the 6 SpecializedTools view bodies' verbatim duplicated pattern:
//    VStack(alignment: .leading, spacing: DesignTokens.chromePaddingMedium) {
//        if activeBookId == nil {
//            emptyState
//        } else {
//            contentBody
//        }
//    }
//    .padding(DesignTokens.chromePaddingMedium)
//  (= 8 LOC × 6 files = 48 LOC verbatim copy-paste; = R1 audit "Pervasive Duplications" entry).
//
//  Usage (= at the body site):
//    var body: some View {
//        specializedToolBody(activeBookId: activeBookId) {
//            emptyState
//        } mainContent: {
//            contentBody
//        }
//        .task(id: activeBookId) { await reload() }
//    }
//
//  Each of the 6 SpecializedTools view files retains its own `emptyState` and `contentBody`
//  computed properties (= they have specialized content); = the modifier only abstracts the
//  VStack + if/else + chromePadding chain.
//
//  This is NOT the full "SpecializedToolsViewTemplate<ActorType, RowType, AddInput>" generic
//  view wrapper (= that was spec'd but the per-tool view bodies diverge too much for a single
//  generic abstraction; = the right-sized C3.7.1 step is the modifier only).
//

import SwiftUI

extension View {
    /// v1.28 C3.7.1: wrap a SpecializedTool view body in the canonical
    /// chromePadding + if-activeBookId-is-nil-else-contentBody pattern.
    public func specializedToolBody(
        activeBookId: UUID?,
        @ViewBuilder emptyContent: () -> some View,
        @ViewBuilder mainContent: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.chromePaddingMedium) {
            if activeBookId == nil {
                emptyContent()
            } else {
                mainContent()
            }
        }
        .padding(DesignTokens.chromePaddingMedium)
    }
}
