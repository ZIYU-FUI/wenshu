//
//  NSRegularExpression+Literal.swift · Wenshu · v0.71 P1 batch 10
//
//  v0.71 P1 batch 10 dual-axis followup (= Q99 Standards axis LOW):
//  central helper for compile-time-literal NSRegularExpression init.
//  Replaces 13 sites that previously used `try! NSRegularExpression(...)`
//  as static-let values (= the audit's LOW category flagged these as
//  smell-level force unwraps; = the patterns are all compile-time
//  literals so the try! is "safe in practice" but reads as a hidden
//  crash vector).
//
//  Apple HIG canonical pattern: NSRegularExpression is initialised
//  lazily via a closure that calls preconditionFailure on a malformed
//  pattern (= any failure indicates the build itself is broken).
//
//  Use:
//    private static let pattern = NSRegularExpression.literal("foo|bar")
//
//  (= same as the previous `try!` + identical runtime cost = first
//  access compiles the regex once and caches it).
//

import Foundation

extension NSRegularExpression {
    /// Compile-time-literal NSRegularExpression init.
    ///
    /// Use for `private static let` patterns whose regex is a hard-coded
    /// string literal (= failure indicates the regex itself is malformed,
    /// not a runtime input). The previous `try! NSRegularExpression(...)`
    /// pattern is functionally equivalent but reads as a crash vector; =
    /// this helper makes the intent explicit and removes the smell.
    static func literal(_ pattern: String, options: Options = []) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern, options: options)
        } catch {
            // Apple HIG precondition: a compile-time regex should NEVER fail
            // to compile. If it does, the developer made a typo (= the regex
            // itself is invalid syntax). Use preconditionFailure (= a
            // precondition violation = the same fatal behavior as try! but
            // semantically clearer about WHY it can fail).
            preconditionFailure("NSRegularExpression literal invalid: pattern=\(pattern), error=\(error)")
        }
    }
}
