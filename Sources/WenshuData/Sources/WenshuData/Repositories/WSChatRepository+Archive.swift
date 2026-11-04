//
//  WSChatRepository+Archive.swift · Wenshu
//
//  The archive's writes.
//
//  The repository grew past its cap with the archive's read path, =
//  so the archive's WRITES live here, = in an extension of their
//  own, = the way the rest of the tree splits a file that outgrew
//  itself. = The methods are about one thing (= what happens to the
//  archive's rows), = and they are here because of that, = not
//  because of where they sit in a file.
//
//  What they do:
//
//  - Delete one run's row. = The archive's delete action.
//  - Delete the runs that fell out of the retention window. = The
//    purge the retention setting triggers.
//
//  Neither touches the user's own conversations. = A conversation is
//  the user's, = and the archive's setting says how long the AGENT'S
//  work is kept. = A purge that reached the user's words would be
//  the archive deleting something it was never given.
//

import Foundation
import SwiftData

extension WSChatRepository {

    /// Delete one run's row (= the archive's delete action).
    ///
    /// The row is found by its source, = not by session id alone, =
    /// because a session id is unique per BOOK, = and the archive's
    /// list spans the books. = The row goes with its run rows, = because
    /// the relationship cascades.
    ///
    /// - Returns: whether a row was deleted.
    @discardableResult
    public func deleteRun(sessionID: String) throws -> Bool {
        let sessionIDLocal = sessionID
        let descriptor = FetchDescriptor<WSSession>(
            predicate: #Predicate { session in
                session.source != nil && session.sessionID == sessionIDLocal
            }
        )
        guard let session = try store.context.fetch(descriptor).first else { return false }
        store.context.delete(session)
        try store.context.save()
        return true
    }

    /// Delete the run rows that are older than the retention window.
    ///
    /// The archive keeps the record of what the agents did, = and a
    /// record that grows forever is not a record, = it is a leak. = So
    /// the archive has a retention window, = the same shape the memory
    /// pane has (= a closed set of days, = a change to the setting
    /// purges), = and this is the purge.
    ///
    /// Only rows that carry a source go. = A chat session is the
    /// user's conversation, = and a conversation is not the archive's
    /// to delete: = the setting says how long the AGENT'S WORK is
    /// kept, = and the user's own words are not agent work.
    ///
    /// The run rows go with their session, = because the relationship
    /// cascades (= a run without its session is a row nobody can
    /// reach).
    ///
    /// - Parameter retentionDays: how many days of run history to
    ///   keep. Zero or less = keep everything (= the setting's own
    ///   lower bound is the closed set's first value, = but the
    ///   method does not assume the caller chose one).
    /// - Returns: how many run sessions were deleted.
    @discardableResult
    public func purgeRuns(olderThanDays retentionDays: Int) throws -> Int {
        guard retentionDays > 0 else { return 0 }
        let cutoff = Date().addingTimeInterval(-Double(retentionDays) * 24 * 3600)
        let cutoffLocal = cutoff
        let descriptor = FetchDescriptor<WSSession>(
            predicate: #Predicate { session in
                session.source != nil && session.updatedAt < cutoffLocal
            }
        )
        let stale = try store.context.fetch(descriptor)
        for session in stale {
            store.context.delete(session)
        }
        try store.context.save()
        return stale.count
    }
}
