import SwiftUI

/// The library's empty state.
///
/// The Mac owns the library, so a device that has not linked to one
/// has nothing to read. Apple's own empty view says so, and no sample
/// book stands in for the library that is not there yet.
struct LibraryEmptyState: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Library", systemImage: SFIcon.library.rawValue)
        } description: {
            Text("Your books arrive from the Mac once this device is linked.")
        }
        .navigationTitle("Library")
    }
}
