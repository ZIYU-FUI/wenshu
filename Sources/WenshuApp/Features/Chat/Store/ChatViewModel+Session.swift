// ChatViewModel+Session.swift = part of ChatViewModel, = = moved out of ChatSessionViewModel.swift.
// The members below keep their own comments; = = the class's stored
// properties stay in ChatViewModel.swift (= = an extension cannot hold them).

import Foundation
import os.log
import WenshuAgent
import WenshuData

extension ChatViewModel {
    /// Starts a long-running goal via the agent's own context.
    func startNewSession() {
        // 1. Clear in-memory state (= visual reset).
        messages = []
        contextUsed = 0
        // 2. Generate new sessionId (= UUID-based).
        let newId = SessionID(rawValue: "s_" + UUID().uuidString.prefix(12).lowercased())
        sessionId = newId
        // NSLog audit trail (= verify in Console.app). Migrated from `NSLog` (=
        // the Swift 6 strict-concurrency model treats the variadic signature as
        // unavailable; = = use Logger instead per Apple's modern logging
        // guidance).
        let logger = Logger(subsystem: "com.wenshu.app", category: "chat")
        let sessionIdRaw = sessionId.rawValue
        let messageCount = messages.count
        let contextUsedLocal = contextUsed
        logger.info("[wenshu.chat] startNewSession: id=\(sessionIdRaw, privacy: .public) messages=\(messageCount, privacy: .public) contextUsed=\(contextUsedLocal, privacy: .public)")
    }

    func clear() {
        messages.removeAll()
        lastError = nil
    }

    /// valueForSessionId: used by ChatView .task to load history.
    func valueForSessionId() -> SessionID {
        sessionId
    } // @MainActor-isolated helper

    /// replaceMessages: ChatView .task loadcompletereplace (append)
    func replaceMessages(_ newMessages: [ChatMessage]) {
        messages = newMessages
    }

    /// Loads the chat history from the data layer. The rows that are not attached
    /// to a session are skipped: they are not global.
    func loadHistory() async {
        // Whether any provider holds a key.
        //
        // The persisted history is surfaced only once a key is configured
        // (= the call sites in `ChatView.task` also skip the load when no
        // key is configured), so the persisted rows are not shown behind the
        // empty-state overlay: they are ephemeral when the provider is not
        // configured.
        //
        // The lookup routes through WenshuAgent.shared (= the public facade).
        let isConfigured: Bool
        if let providersConfigured {
            isConfigured = await providersConfigured()
        } else {
            let configured = await WenshuAgent.shared.providersWithKeys()
            isConfigured = !configured.isEmpty
        }
        if !isConfigured {
            messages = []
            return
        }
        do {
            let loaded = try await repository.loadMessages(sessionId: sessionId, bookID: currentBookID)
            // The persisted rows kept the question and the answer out of
            // order (= the order they were rendered in, not the order they
            // were written). The sort is by
            // timestamp (= <1 ms apart on fast hardware).
            let sorted = loaded.sorted { a, b in
                if a.timestamp != b.timestamp {
                    return a.timestamp < b.timestamp
                }
                return a.id.uuidString < b.id.uuidString
            }
            messages = sorted
        } catch {
            // Silent no-op (= matches legacy behavior; = the view already handles
            // empty messages[] by showing the empty-state placeholder).
        }
    }

    /// Take in a sub-agent's result that landed in this session.
    ///
    /// Only ONE message is taken, = not the whole history. = Reloading
    /// the history would throw away what the user is typing, = and
    /// where they had scrolled to, = and the result is one message
    /// at the end.
    ///
    /// A notification for another session is ignored: = a reply
    /// belongs to the conversation that asked for it, = and not to
    /// whatever conversation happens to be open.
    /// Take in a result that landed in this conversation.
    ///
    /// Internal and not private, = because the adoption's contract is
    /// worth testing without the notification bus in the way. = The
    /// bus is global, = and a whole-suite run has dozens of open
    /// conversations on it, = so a test that goes through the bus
    /// measures the suite's contention and not the adoption. = The
    /// wiring between the bus and this method is pinned by
    /// `SubAgentResultAdoptionTests`, = and the delivery's own test
    /// pins that the delivery writes the row and names it.
    func adoptDeliveredSubAgentResult(sessionID: String?, messageID: String?) async {
        await resultAdopter.adopt(
            sessionID: sessionID,
            messageID: messageID,
            currentSessionID: sessionId.rawValue,
            currentBookID: currentBookID,
            alreadyPresent: { id in self.messages.contains { $0.id == id } },
            append: { message in self.messages.append(message) }
        )
    }
}
