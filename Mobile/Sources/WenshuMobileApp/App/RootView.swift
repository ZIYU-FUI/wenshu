import SwiftUI

/// The root of the client.
///
/// The shell holds the shape: a tab bar with a stack in each tab on a
/// phone, and the split view where the regular width earns it. The
/// root names what the client is made of and nothing else.
struct RootView: View {
    @State private var store = ConnectionStore()

    var body: some View {
        ClientShell(store: store)
            .tint(DesignTokens.accentColor)
    }
}
