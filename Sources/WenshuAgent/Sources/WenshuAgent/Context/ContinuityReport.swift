//
//  ContinuityReport.swift
//
//  What a book says about itself, in the shape the agent's turn can
//  carry.
//
//  Why: the consistency kernel and the thread-chain kernel both
//  produce findings, and nothing in the tree has ever handed one to
//  the agent. The context bundle carries two arrays for exactly this
//  (= `worldContext` and `foreshadowContext`) and they are empty on
//  every turn.
//
//  So this file holds the shape of what travels: the world's
//  conflicts, and the book's broken threads. Each row says what was
//  found AND where it is, because a report the writer cannot locate
//  is a report the writer cannot fix.
//
//  The report is a value type and reads no file: the book is read by
//  the layer that owns the book, and what that layer produces is this.
//

import Foundation

/// What a book says about itself, and where it says it.
public struct ContinuityReport: Sendable, Equatable {
    /// One conflict the world's claims and rules produced.
    public struct WorldConflict: Sendable, Equatable {
        /// What the conflict is about (= the subject and the property).
        public let subject: String
        /// The property the conflict is about.
        public let attribute: String
        /// How loudly the conflict is reported.
        public let severity: String
        /// The rule that found it, in one line (= the rule's own
        /// sentence, = = so the writer reads what was broken and not
        /// only that something was).
        public let rule: String
        /// The claims that met (= so the writer can go read them).
        public let claimIDs: [String]

        public init(
            subject: String,
            attribute: String,
            severity: String,
            rule: String,
            claimIDs: [String]
        ) {
            self.subject = subject
            self.attribute = attribute
            self.severity = severity
            self.rule = rule
            self.claimIDs = claimIDs
        }
    }

    /// One thread that does not close.
    public struct BrokenThread: Sendable, Equatable {
        /// The chapter the break happens in.
        public let chapter: Int
        /// What kind of break it is (= the kernel's own name for it).
        public let kind: String
        /// The break in one line (= what the writer has to do about it).
        public let detail: String

        public init(chapter: Int, kind: String, detail: String) {
            self.chapter = chapter
            self.kind = kind
            self.detail = detail
        }
    }

    /// The world's conflicts (= what the book's own claims contradict).
    public let worldConflicts: [WorldConflict]
    /// The book's broken threads (= what it plants and never pays off).
    public let brokenThreads: [BrokenThread]

    public init(
        worldConflicts: [WorldConflict] = [],
        brokenThreads: [BrokenThread] = []
    ) {
        self.worldConflicts = worldConflicts
        self.brokenThreads = brokenThreads
    }

    /// Whether the report says anything.
    public var isEmpty: Bool {
        worldConflicts.isEmpty && brokenThreads.isEmpty
    }

    /// The world's conflicts as the context bundle's rows.
    ///
    /// The bundle's `worldContext` holds one line per conflict, = =
    /// each naming the subject, the property, the rule that found it,
    /// and the claims that met. = = A writer who reads one line knows
    /// which two statements disagree and which rule says they cannot.
    public var worldContext: [String] {
        worldConflicts.map { conflict in
            let claims = conflict.claimIDs.joined(separator: ", ")
            return "[\(conflict.severity)] \(conflict.subject) / \(conflict.attribute): "
                + "\(conflict.rule) (claims: \(claims))"
        }
    }

    /// The broken threads as the context bundle's rows.
    ///
    /// The bundle's `foreshadowContext` holds one line per break, = =
    /// each naming the chapter and what is wrong there.
    public var foreshadowContext: [String] {
        brokenThreads.map { broken in
            "chapter \(broken.chapter): \(broken.detail) (\(broken.kind))"
        }
    }
}
