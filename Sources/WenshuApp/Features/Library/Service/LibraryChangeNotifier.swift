//
//  Features/Library/Service/LibraryChangeNotifier.swift
//
//   : LibraryChangeNotifier.
//  One place that says "the library changed on disk".
//
//  The material zone reloads when the library changes, and the
//  automatic cover pass asks the policy about the documents it then
//  sees. So a write that changes the library has to say so, or the
//  documents that write brought in stay invisible to both.
//
//  The agent's writes are the case that needs this: the tool writes
//  the file and returns, and nothing in the app reloads afterwards.
//  The import says so once per batch, and the sidebar's delete says
//  so, but the agent's own writes said nothing.
//
//  The notifier is a SEPARATION, not a behaviour change: the tool
//  still writes files and returns. It does not start a generation,
//  and it does not know that covers exist.
//
//  The SOURCE rides along as the notification's object. The app's
//  listeners watch the NAME (= every change reloads), but a test
//  that proves one path announces can watch for its own source and
//  ignore the others.
//

import Foundation

/// Tells the app that the library's contents changed on disk.
enum LibraryChangeNotifier {

    /// Where a change came from.
    ///
    /// The app does not branch on this: every change reloads the same
    /// way. The source is here so that a test can prove ONE path
    /// announces without counting the others.
    ///
    /// A class, not an enum: the notification matches its object by
    /// identity, and an enum case has no identity of its own.
    final class Source: NSObject, @unchecked Sendable {

        /// The agent wrote a reference.
        static let agentReference = Source()

        /// The agent wrote a book document.
        static let agentBookDoc = Source()

        private override init() { super.init() }
    }

    /// Announces that the library changed.
    ///
    /// The listeners are the sidebar (reload the tree) and the
    /// material zone (re-read the documents, and ask the cover policy
    /// about the ones that arrived).
    ///
    /// - Parameter source: where the change came from.
    static func notifyLibraryChanged(source: Source? = nil) {
        NotificationCenter.default.post(
            name: .wenshuLibraryDidChange,
            object: source
        )
    }
}
