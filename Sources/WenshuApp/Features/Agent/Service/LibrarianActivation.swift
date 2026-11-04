//
//  LibrarianActivation.swift · Wenshu
//
//  How a librarian run is asked for.
//
//  The librarian is activated by an explicit input: = a `@librarian`
//  mention whose task names the procedure. That is the whole
//  activation surface, = and it is deliberately the only one: = the
//  librarian has no timer, = no background sweep, = and no way to
//  start itself.
//
//  The syntax is `@librarian <procedure> <arguments>`:
//
//    @librarian import /path/to/file.md
//    @librarian curate
//    @librarian import /path/to/file.md --dry-run
//
//  A mention that names no procedure is not a librarian task: = the
//  caller falls through to the ordinary path, = because a librarian
//  run without a procedure has no defined behaviour, = and a run with
//  no defined behaviour is how "the agent did something" happens.
//

import Foundation

/// Parses the librarian's activation text into a task.
enum LibrarianActivation {

    /// The outcome of reading an activation.
    enum Parsed: Sendable, Equatable {
        /// A runnable task.
        case task(LibrarianTask)

        /// The text named no procedure (= not a librarian task).
        case notALibrarianTask

        /// The text named a procedure the librarian does not run.
        case unknownProcedure(String)
    }

    /// Read an activation.
    ///
    /// - Parameter input: the text after `@librarian`.
    /// - Returns: the task, or why there is none.
    static func parse(_ input: String) -> Parsed {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .notALibrarianTask }

        // The first word names the procedure.
        let pieces = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let head = pieces.first else { return .notALibrarianTask }
        let procedureToken = head.lowercased()

        guard let procedure = LibrarianProcedure(rawValue: procedureToken) else {
            // A word that is not a procedure: = the caller may still
            // have meant a different role, = so this is not an error,
            // = it is a fall-through.
            //
            // Only an ASCII word can name a procedure: = the
            // procedure names are ASCII, = and a task written in any
            // other script is a task whose procedure the writer did
            // not name.
            if procedureToken.allSatisfy({ $0.isASCII && $0.isLetter }) && procedureToken.count <= 24 {
                return .unknownProcedure(procedureToken)
            }
            return .notALibrarianTask
        }

        var remainder = pieces.count > 1 ? String(pieces[1]) : ""
        var dryRun = false

        // The dry-run flag may sit anywhere in the arguments.
        for flag in ["--dry-run", "-n"] {
            if remainder.contains(flag) {
                dryRun = true
                remainder = remainder.replacingOccurrences(of: flag, with: " ")
            }
        }
        let sourcePaths = remainder
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }

        let task = LibrarianTask(
            procedure: procedure,
            requestID: requestID(for: procedure, sourcePaths: sourcePaths),
            sourcePaths: sourcePaths,
            scope: nil,
            dryRun: dryRun
        )
        return .task(task)
    }

    /// The text that carries a task to the runner.
    ///
    /// The procedure travels IN the task text, = because the
    /// delegation's task is a string and = the runner is what turns
    /// it into a procedure. The prefix is what makes the round trip
    /// lossless: = a task that came from an activation starts with
    /// it, = and a task written by hand does not, = so the runner
    /// knows the difference between "run this procedure" and "here is
    /// some text for the librarian".
    static func encodedTask(for task: LibrarianTask) -> String {
        var parts = ["[librarian:\(task.procedure.rawValue)]"]
        if task.dryRun { parts.append("--dry-run") }
        parts.append(contentsOf: task.sourcePaths)
        return parts.joined(separator: " ")
    }

    /// Read a procedure out of a task the runner received.
    ///
    /// - Returns: the procedure, or nil when the task carries none
    ///   (= the task was not written by an activation).
    static func procedure(fromTaskText text: String) -> LibrarianProcedure? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "[librarian:"
        guard trimmed.hasPrefix(prefix) else { return nil }
        guard let close = trimmed.firstIndex(of: "]") else { return nil }
        // The name sits between the prefix and the bracket (= the
        // prefix is longer than one character, = so the slice starts
        // after the WHOLE prefix).
        let nameStart = trimmed.index(trimmed.startIndex, offsetBy: prefix.count)
        guard nameStart <= close else { return nil }
        let name = String(trimmed[nameStart..<close])
        return LibrarianProcedure(rawValue: name.lowercased())
    }

    /// The request id for a task.
    ///
    /// The same inputs must produce the same id, = because the id is
    /// the idempotency key: = a retry after a failure must land the
    /// same document against the same source, = not a second copy.
    private static func requestID(
        for procedure: LibrarianProcedure,
        sourcePaths: [String]
    ) -> String {
        let material = ([procedure.rawValue] + sourcePaths).joined(separator: "|")
        return "\(procedure.rawValue)-\(stableDigest(material))"
    }

    /// A short stable digest of a string.
    ///
    /// The same string must always produce the same digest, = because
    /// the digest IS the identity of the request. A random id would
    /// make every retry a new request, = and the retry would land the
    /// documents twice.
    private static func stableDigest(_ material: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in material.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}
