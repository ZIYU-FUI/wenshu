import Foundation

/// The chat-area receipt for a background task (= names the handle,
/// never the role; = the board and the activity feed keep the role).
enum ChatSubAgentReceipt {
    /// Receipt for a started task (= the handle is the user's only
    /// reference to the background task).
    static func dispatched(handleID: String, bundle: Bundle = .main) -> String {
        String.localizedStringWithFormat(
            String(localized: "chatview.subagent.dispatched", bundle: bundle),
            handleID
        )
    }

    /// Receipt for a failed task (= the cause is the role-free
    /// user-facing text; = the role stays on the board).
    static func failed(error: Error, bundle: Bundle = .main) -> String {
        let cause = UserFacingError.from(error).errorDescription
            ?? String(localized: "error.unknown", bundle: bundle)
        return String.localizedStringWithFormat(
            String(localized: "chatview.subagent.dispatch_failed", bundle: bundle),
            cause
        )
    }
}
