//
//  SubAgentRunner+Storage.swift · Wenshu
//
//  The two storage-dispatch sub-agents.
//
//  The archivist and the auditor are not the crew's live agents: = =
//  they run when the book is swept, = = they answer a fixed question,
//  = = and they write their own verdict as JSON. That is a different
//  concern from the live sub-agent turn (= = the one that streams its
//  words into the card, = = and the one this file's sibling runs), = =
//  so the two live in their own file.
//
//  They are extensions of the runner (= = not a second type), = =
//  because they are the runner's own jobs: = = they use the runner's
//  storage adapters, = = and the runner's own dispatch calls them.
//

import Foundation

extension SubAgentRunner {
    // MARK: - Storage-dispatch sub-agents (v2.7d)

    /// Runs the archivist sub-agent and returns its summary. The run
    /// reports a typed error on a transport, decode or provider failure.
    func runArchivistSubAgent(
        handle: BackgroundDelegationHandle,
        slug: String
    ) async throws -> String {
        guard let storage = archivistStorage else {
            // No storage adapter injected (= misconfigured runner). Per §11
            // baseline 'no fake success', we throw so the handle ends up.failed
            // (not.completed with a fake summary).
            throw SubAgentRunnerError.subAgentLLMFailed(
                handleID: handle.id,
                agentName: slug,
                message: "ArchivistStorage not injected (= runner misconfigured; = production should pass LiveArchivistStorage)"
            )
        }

        let task = handle.userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = task.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let action = parts.first.map(String.init) else {
            return #"{"stored":0,"action":"noop","reason":"empty task"}"#
        }

        let restAfterAction = parts.count > 1 ? String(parts[1]) : ""

        switch action {
        case "backup":
            // "backup <label> <contents>" — split restAfterAction on first space.
            let backupParts = restAfterAction.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard backupParts.count == 2 else {
                return #"{"stored":0,"action":"backup","reason":"expected: backup <label> <contents>"}"#
            }
            let label = String(backupParts[0])
            let contents = String(backupParts[1])
            let url = try await storage.writeBackup(label: label, contents: contents)
            return #"{"stored":1,"action":"backup","path":"\#(url.path)"}"#

        default:
            return #"{"stored":0,"action":"noop","reason":"unknown action: \#(action)"}"#
        }
    }

    /// Runs the Auditor sub-agent (= read-only memory access via the auditor's
    /// storage). A `skip` verdict means there was no memory snippet, so there is
    /// nothing to verify against.
    func runAuditorSubAgent(
        handle: BackgroundDelegationHandle,
        slug: String
    ) async throws -> String {
        guard let storage = auditorStorage else {
            throw SubAgentRunnerError.subAgentLLMFailed(
                handleID: handle.id,
                agentName: slug,
                message: "AuditorStorage not injected (= runner misconfigured)"
            )
        }

        let memory = await storage.readMemory(forUserMessage: handle.userMessage)
        let trimmed = memory.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return #"{"verdict":"skip","memory_snippet_count":0,"first_snippet":null}"#
        }

        let snippetCount = trimmed
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count

        let firstSnippet = String(trimmed.prefix(80))
        return #"{"verdict":"pass","memory_snippet_count":\#(snippetCount),"first_snippet":"\#(firstSnippet)"}"#
    }
}
