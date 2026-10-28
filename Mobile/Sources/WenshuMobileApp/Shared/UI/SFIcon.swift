import SwiftUI

/// The one icon factory.
///
/// Every glyph in the app is named here once, so a symbol that Apple
/// renames is changed in one file, and a view can never spell a system
/// name on its own. The enum is the symbol list; the `View` conformance is
/// what a call site renders.
enum SFIcon: String, CaseIterable, Sendable, View {
    case link
    case library = "books.vertical"
    case stateEmpty = "tray"
    case stateOnline = "checkmark.circle"
    case stateOffline = "wifi.slash"
    case stateError = "exclamationmark.triangle"

    var body: some View {
        Image(systemName: rawValue)
    }
}
