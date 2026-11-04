//
//  SubAgentResultAdopter.swift · Wenshu
//
//  Taking in a sub-agent's result that landed in the open
//  conversation.
//
//  The delivery writes the result to the session on disk. = The chat
//  that is showing that session holds a snapshot of its messages, =
//  and the snapshot was taken before the result landed. = So the
//  answer was on disk and nowhere else: = the user found it by
//  reopening the conversation, = and not before.
//
//  This is the half that closes it. = The delivery posts a
//  notification naming the session and the message; = the chat that
//  is showing that session takes that one message in.
//
//  Two rules, = and both of them are about the conversation being
//  honest:
//
//  - A reply belongs to the conversation that asked for it. = A
//    result for another session is ignored, = because a conversation
//    that is open has no business showing somebody else's answer.
//  - The same result shows up once. = Two notifications for the same
//    result arrive together, = both see that the message is not here
//    yet, = and both would append it.
//
//  The adopter is a type of its own, = rather than a pile of state on
//  the view model, = because the claim it holds (= the ids being
//  taken in right now) = is its own small piece of state, = and a
//  view model that is already over the file-size cap should not grow
//  another property.
//

import Foundation
import WenshuData

/// Takes in the results that land in one conversation.
@MainActor
final class SubAgentResultAdopter {

    /// The repository the messages are read from.
    let repository: any ChatRepositoryProtocol

    /// The ids being taken in right now.
    ///
    /// Two notifications for the same result arrive together, = both
    /// see that the message is not here yet, = and both would append
    /// it. = The claim makes the second one wait. = It is cleared
    /// when the adoption ends, = so a later notification for the same
    /// result (= the user reopened the conversation) still finds the
    /// message already here.
    private var adopting: Set<UUID> = []

    init(repository: any ChatRepositoryProtocol) {
        self.repository = repository
    }

    /// Take in one result.
    ///
    /// - Parameters:
    ///   - sessionID: the session the result landed in.
    ///   - messageID: the message that carries it.
    ///   - currentSessionID: the session this conversation is showing.
    ///   - currentBookID: the book this conversation is scoped to.
    ///   - alreadyPresent: whether the message is already shown
    ///     (= the caller holds the conversation's messages).
    ///   - append: how a message joins the conversation.
    func adopt(
        sessionID: String?,
        messageID: String?,
        currentSessionID: String,
        currentBookID: BookID?,
        alreadyPresent: (UUID) -> Bool,
        append: @escaping @MainActor (ChatMessage) -> Void
    ) async {
        guard let deliveredSession = sessionID,
              deliveredSession == currentSessionID,
              let messageIDString = messageID,
              let messageUUID = UUID(uuidString: messageIDString)
        else { return }

        // The message may already be here: = a reload that ran
        // between the write and this notification, = or a second
        // notification for the same result.
        if alreadyPresent(messageUUID) { return }
        // And it may be on its way: = two notifications for the same
        // result arrive together, = both see that the message is not
        // here yet, = and both would append it.
        guard !adopting.contains(messageUUID) else { return }
        adopting.insert(messageUUID)

        let repository = repository
        // The read and the append happen IN PLACE, = and not in a
        // task.
        //
        // A task put the adoption behind everything the main actor
        // had already queued, = and a busy main actor (= a test
        // suite running many conversations, = or an app under load)
        // delays it by seconds. = The result was on disk and nowhere
        // else for exactly that long, = and the conversation that
        // asked for it showed nothing.
        //
        // The caller awaits this, = so the conversation shows the
        // result by the time the call returns, = and a caller that
        // does not await it still gets the same work.
        let stored = (try? await repository.loadMessages(
            sessionId: SessionID(rawValue: currentSessionID),
            bookID: currentBookID
        )) ?? []
        let message = stored.first { $0.id == messageUUID }
        adopting.remove(messageUUID)
        if let message {
            append(message)
        }
    }
}
