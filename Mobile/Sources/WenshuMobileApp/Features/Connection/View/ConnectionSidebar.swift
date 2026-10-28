import SwiftUI

/// The sidebar of the split layout: what the device is linked to.
struct ConnectionSidebar: View {
    let store: ConnectionStore

    var body: some View {
        List {
            Section("Link") {
                LabeledContent("State", value: store.statusLabel)
                if let companion = store.state.companion {
                    LabeledContent("Mac", value: companion.name)
                    LabeledContent("Revision", value: String(companion.revision))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Wenshu")
    }
}
