import SwiftUI

/// The connect destination's list: the link's own rows, and the way
/// into the connection screen.
///
/// The split layout's sidebar is the shell's destination list, so this
/// list carries the link's state, and the connection screen is pushed
/// onto the stack from it.
struct ConnectionListView: View {
    let store: ConnectionStore

    var body: some View {
        List {
            Section("Link") {
                LabeledContent("State", value: store.statusLabel)
                if let companion = store.state.companion {
                    LabeledContent("Mac", value: companion.name)
                    LabeledContent("Revision", value: String(companion.revision))
                }
                NavigationLink {
                    ConnectionView(store: store)
                } label: {
                    Label("Connection", systemImage: SFIcon.link.rawValue)
                }
            }
        }
        .navigationTitle("Connect")
    }
}
