import SwiftUI

/// The root of the client.
///
/// One layout serves iPhone, iPad and a foldable: the regular width
/// gets a split view, the compact width gets a stack. The split is
/// decided by the size class, not by the device, so a foldable that
/// unfolds into a wide screen gets the same split an iPad gets.
struct RootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var store = ConnectionStore()

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                ConnectionView(store: store)
            } else {
                NavigationSplitView {
                    ConnectionSidebar(store: store)
                } detail: {
                    ConnectionView(store: store)
                }
            }
        }
        .tint(DesignTokens.accentColor)
    }
}
