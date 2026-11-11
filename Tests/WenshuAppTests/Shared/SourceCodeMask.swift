//
//  SourceCodeMask.swift · WenshuAppTests
//
//  The CODE of a Swift source file, = = with every comment and every
//  string literal's contents blanked.
//
//  WHY IT EXISTS: = = a reader that scans a source tree for a call must
//  not be pointed at a call that lives in a comment or in a string, = =
//  and it must not miss a call that lives in an interpolation (= = =
//  which is CODE, = = not text).
//
//  ⇒ ⇒ AND IT IS ONE PASS: = = a `//` inside a string literal is not a
//  comment, = = and a quote inside a comment is not the start of a
//  literal, = = so masking the two in two separate passes lets either
//  one swallow the other.
//
//  ⇒ ⇒ AND IT WORKS ON BYTES: = = the tree carries hundreds of
//  production files, = = and a reader that reads them all must not cost
//  the suite its time.
//
//  ⇒ ⇒ AND AN INTERPOLATION IS CODE: = = the `\(...)` inside a string
//  literal is an EXPRESSION, = = so the expression stays (= = = a call
//  inside an interpolation is a call).
//
//  ⇒ ⇒ AND IT KEEPS THE LINE COUNT: = = a reader that reports WHERE a
//  = = call is needs the lines to mean the same thing after masking.
//
//

import Foundation

/// The CODE of a Swift source file.
enum SourceCodeMask {
    /// The source's code, = = with every comment and every string
    /// literal's contents blanked.
    static func code(of source: String) -> String {
        var masker = Masker(source)
        masker.maskCode(stopAtCloseParen: false)
        return masker.result
    }

    /// The one-pass masker.
    private struct Masker {
        private static let space: UInt8 = 0x20
        private static let newline: UInt8 = 0x0A
        private static let quote: UInt8 = 0x22
        private static let hash: UInt8 = 0x23
        private static let backslash: UInt8 = 0x5C
        private static let openParen: UInt8 = 0x28
        private static let closeParen: UInt8 = 0x29
        private static let slash: UInt8 = 0x2F
        private static let star: UInt8 = 0x2A

        private let bytes: [UInt8]
        private var out: [UInt8]
        private var index = 0

        init(_ source: String) {
            bytes = Array(source.utf8)
            out = Array(repeating: Self.space, count: bytes.count)
        }

        var result: String {
            String(decoding: out, as: UTF8.self)
        }

        /// Masks code, = = until the end of the source or until the
        /// paren that closes an interpolation.
        mutating func maskCode(stopAtCloseParen: Bool) {
            var parenDepth = 0
            while index < bytes.count {
                let byte = bytes[index]
                if stopAtCloseParen, byte == Self.closeParen, parenDepth == 0 {
                    return
                }
                switch byte {
                case Self.slash:
                    if peek(1) == Self.slash {
                        maskLineComment()
                    } else if peek(1) == Self.star {
                        maskBlockComment()
                    } else {
                        out[index] = byte
                        index += 1
                    }
                case Self.hash:
                    // ⇒ ⇒ A RAW STRING LITERAL: = = `#"..."#`, = =
                    // = = and its `#`s are part of its delimiter.
                    let hashes = countHashes(at: index)
                    if peek(hashes) == Self.quote {
                        index += hashes
                        index += 1
                        maskStringBody(rawHashes: hashes, multiline: false)
                    } else {
                        out[index] = byte
                        index += 1
                    }
                case Self.quote:
                    if peek(1) == Self.quote, peek(2) == Self.quote {
                        index += 3
                        maskStringBody(rawHashes: 0, multiline: true)
                    } else {
                        index += 1
                        maskStringBody(rawHashes: 0, multiline: false)
                    }
                case Self.openParen:
                    parenDepth += 1
                    out[index] = byte
                    index += 1
                case Self.closeParen:
                    parenDepth -= 1
                    out[index] = byte
                    index += 1
                default:
                    out[index] = byte
                    index += 1
                }
            }
        }

        private func peek(_ offset: Int) -> UInt8? {
            let position = index + offset
            guard position < bytes.count else { return nil }
            return bytes[position]
        }

        private func countHashes(at start: Int) -> Int {
            var hashes = 0
            var position = start
            while position < bytes.count, bytes[position] == Self.hash {
                hashes += 1
                position += 1
            }
            return hashes
        }

        private mutating func maskLineComment() {
            while index < bytes.count, bytes[index] != Self.newline {
                out[index] = Self.space
                index += 1
            }
        }

        private mutating func maskBlockComment() {
            var depth = 0
            while index < bytes.count {
                if peek(0) == Self.slash, peek(1) == Self.star {
                    depth += 1
                    out[index] = Self.space
                    out[index + 1] = Self.space
                    index += 2
                    continue
                }
                if peek(0) == Self.star, peek(1) == Self.slash {
                    depth -= 1
                    out[index] = Self.space
                    out[index + 1] = Self.space
                    index += 2
                    if depth == 0 {
                        return
                    }
                    continue
                }
                if bytes[index] != Self.newline {
                    out[index] = Self.space
                }
                index += 1
            }
        }

        /// Masks a string literal's BODY, = = with the opening delimiter
        /// already consumed.
        ///
        /// ⇒ ⇒ AND THE CLOSING DELIMITER IS WHAT ENDS IT: = = the
        /// = = opener has been read, = = so the body is everything up to
        /// = = the closer (= = `"`, = = `"""`, = = or `"#`).
        private mutating func maskStringBody(rawHashes: Int, multiline: Bool) {
            while index < bytes.count {
                let byte = bytes[index]
                if byte == Self.newline, !multiline {
                    return
                }
                if byte == Self.backslash {
                    // ⇒ ⇒ THE INTERPOLATION IS AN EXPRESSION: = = it is
                    // = = masked as code, = = so a call inside it is a
                    // = = call.
                    let hashes = rawHashes > 0 ? countHashes(at: index + 1) : 0
                    if peek(1 + hashes) == Self.openParen {
                        out[index] = Self.space
                        index += 1
                        for _ in 0 ..< hashes {
                            out[index] = Self.space
                            index += 1
                        }
                        out[index] = Self.openParen
                        index += 1
                        maskCode(stopAtCloseParen: true)
                        if index < bytes.count {
                            out[index] = Self.closeParen
                            index += 1
                        }
                        continue
                    }
                    out[index] = Self.space
                    index += 1
                    if rawHashes == 0, index < bytes.count {
                        if bytes[index] != Self.newline {
                            out[index] = Self.space
                        }
                        index += 1
                    }
                    continue
                }
                if terminatesLiteral(rawHashes: rawHashes, multiline: multiline) {
                    let terminator = literalTerminator(rawHashes: rawHashes, multiline: multiline)
                    for offset in 0 ..< terminator.count {
                        out[index + offset] = terminator[offset]
                    }
                    index += terminator.count
                    return
                }
                if byte != Self.newline {
                    out[index] = Self.space
                }
                index += 1
            }
        }

        private func literalTerminator(rawHashes: Int, multiline: Bool) -> [UInt8] {
            var terminator = [UInt8](repeating: Self.quote, count: multiline ? 3 : 1)
            terminator.append(contentsOf: [UInt8](repeating: Self.hash, count: rawHashes))
            return terminator
        }

        private func terminatesLiteral(rawHashes: Int, multiline: Bool) -> Bool {
            let terminator = literalTerminator(rawHashes: rawHashes, multiline: multiline)
            for offset in 0 ..< terminator.count {
                guard index + offset < bytes.count, bytes[index + offset] == terminator[offset] else {
                    return false
                }
            }
            return true
        }
    }
}
