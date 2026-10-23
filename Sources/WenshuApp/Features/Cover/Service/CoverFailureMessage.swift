//
//  CoverFailureMessage.swift · Wenshu
//
//  Turns an error into a sentence a user can read.
//
//  The card shows the failure's message, so what lands in the record
//  is what the user sees. Measured 2026-10-24: a transport failure
//  wrote the raw dump of a Foundation error into the card
//
//      Error Domain=NSURLErrorDomain Code=-1001 "timed out"
//      UserInfo={_kCFStreamErrorCodeKey=-2102, ...}
//
//  which reads like a program error (= the standing requirement is the
//  opposite: the user must be told what happened, in a way they can
//  act on).
//

import Foundation

/// The message a card shows for a failure.
enum CoverFailureMessage {

    /// Describes an error for a person.
    ///
    /// The order matters:
    ///
    ///  1. the error's OWN message, when it has one (= a
    ///     LocalizedError, and every provider failure is one, so the
    ///     classification's sentence survives: "the account has no
    ///     quota left ...");
    ///  2. the localized description, when it does not (= a
    ///     Foundation transport error has one, and it is in the user's
    ///     language);
    ///  3. the raw description, only as the last resort.
    ///
    /// - Parameter error: what went wrong.
    /// - Returns: the message to write into the record and show.
    static func describe(_ error: Error) -> String {
        if let localized = error as? LocalizedError,
           let message = localized.errorDescription,
           !message.isEmpty {
            return message
        }
        let description = error.localizedDescription
        if !description.isEmpty, !description.hasPrefix("Error Domain=") {
            return description
        }
        return String(describing: error)
    }
}
