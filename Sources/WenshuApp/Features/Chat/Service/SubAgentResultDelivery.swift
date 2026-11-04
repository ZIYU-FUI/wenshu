//
//  SubAgentResultDelivery.swift · Wenshu
//
//  Where a sub-agent's finished work goes.
//
//  The result used to go nowhere. = The delegation marked itself
//  completed, = the result sat in the registry's in-memory record, =
//  and the chat that asked for it showed a dispatch receipt and then
//  nothing. = The comment on the chat message source said the result
//  "goes through the WSKanbanRepository board", = and the board's card
//  never changed state, = so the path was broken at both ends.
//
//  This is the end that works: = the finished result is written into
//  the conversation that asked for it, = as a message with its own
//  source (= `agentResult`, = which is neither the user's, = nor the
//  main agent's, = nor a system error).
//
//  Three properties the delivery must have, and why:
//
//  - It lands in the ASKING conversation, = not in whatever session
//    happens to be open when the run finishes. = A background run can
//    finish minutes later, = and by then the user may have moved on.
//  - It lands ONCE. = A retried delivery, = or a delivery that runs
//    twice because the registry was drained twice, = must not show the
//    user the same result twice. = The message's id is derived from
//    the run's id, = so the second attempt writes the SAME row, = and
//    the unique constraint refuses it. = The check before the write is
//    what keeps that refusal from being an error.
//  - It does not block the run. = A delivery that fails leaves the run
//    finished, = because the run's own outcome is already recorded in
//    the ledger.
//

import Foundation
import WenshuData

/// Writes a finished sub-agent's result back into the conversation
/// that asked for it.
@MainActor
struct SubAgentResultDelivery {

    /// The repository the delivery writes through.
    let repository: any ChatRepositoryProtocol

    init(repository: any ChatRepositoryProtocol) {
        self.repository = repository
    }

    /// The outcome of one delivery.
    enum Outcome: Sendable, Equatable {
        /// The result landed (= it was written, = or it was already
        /// there from an earlier attempt, = which is the same state).
        case delivered

        /// There was nowhere to deliver to (= the run carried no
        /// scope, = so nobody asked for it).
        case noDestination

        /// The write failed (= the result stays in the ledger, = and
        /// the conversation does not show it).
        case failed(String)
    }

    /// Deliver one finished run's result.
    ///
    /// - Parameters:
    ///   - handle: the run's handle (= its id names the run, = its
    ///     scope says where the result goes).
    ///   - result: what the run produced.
    /// - Returns: what happened.
    func deliver(handle: BackgroundDelegationHandle, result: String) async -> Outcome {
        guard let scope = handle.scope else { return .noDestination }

        let messageID = Self.messageID(for: handle.id)
        let sessionID = SessionID(rawValue: scope.sessionID.rawValue)
        let bookID = scope.bookID

        // The delivery is once-only, = and the check is what makes the
        // second attempt a no-op instead of a unique-constraint
        // failure. = The id is derived from the run, = so "the same
        // run" and "the same row" are the same fact.
        if await alreadyDelivered(
            messageID: messageID,
            sessionID: sessionID,
            bookID: bookID
        ) {
            return .delivered
        }

        let message = ChatMessage(
            id: messageID,
            role: .agentResult,
            source: .agentResult,
            content: Self.body(for: handle, result: result),
            timestamp: Date()
        )
        do {
            try await repository.append(message, sessionId: sessionID, bookID: bookID)
            // The conversation that is showing this session holds a
            // snapshot of its messages, = and the snapshot was taken
            // before this result landed. = Without the notification
            // the result is on disk and nowhere else: = the user
            // finds it by reopening the conversation, = and not before.
            NotificationCenter.default.post(
                name: Notification.Name(AppStateEvents.subAgentResultDelivered.rawValue),
                object: nil,
                userInfo: [
                    "sessionID": sessionID.rawValue,
                    "messageID": messageID.uuidString
                ]
            )
            return .delivered
        } catch {
            return .failed(String(describing: error))
        }
    }

    // MARK: - The row

    /// The message id for a run (= derived, = so a second delivery
    /// writes the same row).
    ///
    /// The id must be a UUID (= the read path drops a row whose id is
    /// not one, = so a plain string would make the result
    /// unreadable).
    ///
    /// This is pure arithmetic over the run's id, = so it does not
    /// need the main actor. = Keeping it `nonisolated` also lets a
    /// test check the derivation without hopping actors.
    nonisolated static func messageID(for runID: String) -> UUID {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in runID.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        // Fold the hash into 16 bytes and set the version + variant
        // bits (= the shape a UUIDv4 has, = so nothing downstream
        // treats it as a special kind of id).
        var bytes = [UInt8](repeating: 0, count: 16)
        for index in 0..<8 {
            bytes[index] = UInt8((hash >> (8 * UInt64(index))) & 0xFF)
            bytes[index + 8] = UInt8((hash >> (8 * UInt64(index + 8))) & 0xFF)
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    /// The text the conversation shows.
    ///
    /// The result is shown as it came, = under a heading that says
    /// which agent produced it, = because the user asked an agent and
    /// the answer should say who answered.
    static func body(for handle: BackgroundDelegationHandle, result: String) -> String {
        let label = SubAgentRoleRegistry.role(forSlug: handle.agentName)?.displayLabel
            ?? handle.agentName
        return "\(label)\n\n\(result)"
    }

    // MARK: - The once check

    /// Whether this run's result is already in the conversation.
    private func alreadyDelivered(
        messageID: UUID,
        sessionID: SessionID,
        bookID: BookID?
    ) async -> Bool {
        let existing = (try? await repository.loadMessages(sessionId: sessionID, bookID: bookID)) ?? []
        return existing.contains { $0.id == messageID }
    }
}
