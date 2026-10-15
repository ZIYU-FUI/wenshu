//
//  ImportServiceHashing.swift
//
//  Hash + UUID-derivation helpers extracted from ImportService.swift
//  (= §6.6 god-class split: 2 static funcs = sha256 + uuidFromHash
//  = 61 LOC moved out of the main file into this dedicated module).
//
//  Why extracted (= §6.6 god-class split + discoverability): the main
//  `actor ImportService` is 1750 LOC = 3x the 600-LOC cap. The 2
//  hashing helpers are a single concern (= "compute the content hash
//  for dedup" + "derive a stable UUID from the hash for the on-disk
//  filename"). Putting them in a dedicated file named after the
//  concern (= ImportServiceHashing.swift) lets the next reader find
//  the hashing logic by name.
//
//  These 2 funcs are pure (= no instance state; = safe to call as
//  `ImportServiceHashing.sha256(...)` from any context).
//

import CryptoKit
import Foundation

/// Namespace container for the 2 hash + UUID-derivation helpers.
enum ImportServiceHashing {
    // MARK: - Crypto helpers (= Apple-native; = no third-party deps per AGENTS.md §11.1)

    /// SHA-256 of a String (= the body dedup key; = uses Apple's CryptoKit; =
    /// AGENTS.md §11.1 forbids third-party crypto).
    static func sha256(_ s: String) -> String {
        let data = Data(s.utf8)
        let digest = CryptoKit.SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }


    /// Derive a stable UUID from a SHA-256 hex string (= the on-disk filename
    /// for a body-hash). Takes the first 16 bytes (= 32 hex chars); = sets RFC
    /// 4122 version (= 4) and variant (= 10) bits so the UUID round-trips
    /// through `UUID(uuidString:)`. (= boss 2026-10-10 (see OOB.md #2026-10-10)
    /// (= `chars[i*2..<i*2+2]` index out of range at i=15; = the
    /// `Array._checkIndex` failure captured in the wenshu.ips crash report at
    /// 2026-10-10 10:44:08). The trigger: a stale cache entry (= the boss's
    /// `import-cache.json` from a previous wenshu version) had a `contentHash`
    /// shorter than 32 hex chars (= the older wenshu stored a UUID string or a
    /// truncated hash); = the `retryFailedTasksTitleOnly` flow ran
    /// `uuidFromHash` on that short string; = crash; = SIGTRAP → Trace/BPT trap
    /// → `termination.indicator = "Trace/BPT trap: 5"`). Fix: validate the hex
    /// length BEFORE indexing; = if too short, return a stable UUID derived
    /// from a hashed-padded version of the input (= the on-disk filename won't
    /// match the previously-imported file's path = the re-import will write a
    /// new .md at a new UUID; = the old cache entry is effectively invalidated;
    /// = this is the right behavior for a cache entry that was written by a
    /// wenshu version with a different hash format).
    static func uuidFromHash(_ hex: String) -> UUID {
        let chars = Array(hex.prefix(32))
        // validate the input length BEFORE indexing. If too short, re-hash the input to a
        // 32-char hex string (= the output is a deterministic UUID that
        // doesn't match any previously-imported file's path; = the re-import
        // writes a new .md at this UUID; = the old cache entry is effectively
        // orphaned).
        let safeHex: String
        if chars.count < 32 {
            safeHex = ImportServiceHashing.sha256(hex.isEmpty ? "wenshu-orphan-\(hex)" : hex)
                .prefix(32)
                .description
        } else {
            safeHex = hex
        }
        let safeChars = Array(safeHex.prefix(32))
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<16 {
            let byte = UInt8(String(safeChars[i*2..<i*2+2]), radix: 16) ?? 0
            bytes[i] = byte
        }
        // RFC 4122 version 4 + variant 10 (= a random-ish UUID that survives uuidString
        // round-tripping through Foundation).
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let uuid: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuid)
    }


}
