// ChatViewModel+Persistence.swift = part of ChatViewModel, = = moved out of
// ChatSessionViewModel.swift.
// The try-logging helper the persistence path uses, = = so a dropped row is
// reported instead of swallowed.

import os.log

// MARK: - Try-logging helper (= 12 standard P1-02 try?  scaffolding)

/// across Core/Agent and Core/Tools.
extension ChatViewModel {
    fileprivate static let persistLogger = Logger(subsystem: "com.wenshu.app", category: "chat.persist")

    static func logSwallowedPersistenceFailure(operation: String, error: Error) {
        let errorString = String(describing: error)
        persistLogger.error("[wenshu.chat.persist] operation=\(operation, privacy: .public) dropped-error=\(errorString, privacy: .public)")
    }
}
