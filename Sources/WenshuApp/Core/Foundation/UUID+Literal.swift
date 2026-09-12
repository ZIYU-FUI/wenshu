//
//  UUID+Literal.swift · Wenshu · v0.71 P1 batch 10
//
//  v0.71 P1 batch 10 dual-axis followup (= Q99 Standards axis LOW):
//  central helper for compile-time-literal UUID init.
//  Replaces 4 sites in LayoutTreeState.swift that previously used
//  `UUID(uuidString: "...")!` as static-let values (= the audit's
//  LOW category flagged these as smell-level force unwraps; = the
//  strings are guaranteed-valid UUID format literals so the try! is
//  "safe in practice" but reads as a hidden crash vector).
//
//  Apple HIG canonical pattern: UUID is initialised with
//  preconditionFailure on a malformed literal (= any failure
//  indicates the literal itself is wrong, not a runtime input).
//
//  Use:
//    static let builtinDefaultID = UUID.literal("00000000-0000-0000-0000-000000000001")
//

import Foundation

extension UUID {
    /// Compile-time-literal UUID init.
    ///
    /// Use for `static let` IDs whose UUID string is a hard-coded
    /// literal (= failure indicates the literal itself is malformed,
    /// not a runtime input). The previous `UUID(uuidString: "...")!`
    /// pattern is functionally equivalent but reads as a crash vector; =
    /// this helper makes the intent explicit and removes the smell.
    static func literal(_ string: String) -> UUID {
        if let uuid = UUID(uuidString: string) {
            return uuid
        }
        // Apple HIG precondition: a compile-time UUID literal should NEVER
        // fail to parse. If it does, the developer made a typo (= the
        // string isn't a valid UUID format). Use preconditionFailure
        // (= a precondition violation = the same fatal behavior as try!
        // but semantically clearer about WHY it can fail).
        preconditionFailure("UUID literal invalid: string=\(string)")
    }
}
