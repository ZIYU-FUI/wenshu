import SwiftUI

/// The root of the client.
///
/// One layout serves iPhone, iPad and a foldable: the width picks the
/// shape, and the foldable-native arrangement refines how the two columns
/// are drawn where the system offers it. The container holds that choice,
/// so the root only names what the client is made of.
struct RootView: View {
    @State private var store = ConnectionStore()

    var body: some View {
        AdaptiveLayoutContainer(
            compact: ConnectionView(store: store),
            sidebar: ConnectionSidebar(store: store),
            detail: ConnectionView(store: store)
        )
        .tint(DesignTokens.accentColor)
    }
}
