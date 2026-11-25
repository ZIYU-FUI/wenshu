//
//  chat_context_gauge_durability.swift
//
//  Measure the chat meter's stored reading across a REAL process boundary.
//
//  WHAT IT MEASURES
//    Whether the reading the chat bar shows outlives the process that took
//    it: = = one run writes the reading into a SwiftData store, = = and a
//    SECOND run (= = a different process) opens the same store and reads
//    the reading back.
//
//      write_readback_same_process   what the writing run reads back from
//                                   its own store
//      read_across_processes        what a different process reads from the
//                                   store the first one wrote
//      read_unwritten_session       what a session that was never written
//                                   reads (= = nil)
//
//  HOW IT MEASURES
//    It links the SHIPPING data layer (= = `WenshuData`'s own
//    `WSChatRepository` and `WSPersistenceContainer`), = = so what it
//    prints is the shipping code's behaviour, = = and it writes into the
//    store path the caller names (= = outside the repository).
//
//    The tree it names is the tree whose data layer it measured, = = and
//    every number it prints carries that tree's HEAD, = = so a number can
//    never be read without the tree it belongs to.
//
//  ITS EXIT CODES
//    0 when the reading crossed the process boundary, = = 1 when it did
//    not (= = the writing run read back something else, = = the reading
//    was not there for the second run, = = or a session that was never
//    written had a reading), = = and 2 when the run took no number at all
//    (= = unusable arguments, = = an unknown mode, = = no usable tree, = =
//    or a store that would not open). = = A failure to measure is never
//    reported as a pass, = = and never as a plain 1: = = a reader who sees
//    2 knows no number was taken.
//

import Foundation
import WenshuData

let arguments = CommandLine.arguments

guard arguments.count >= 5 else {
    print("usage: chat_context_gauge_durability <mode> <tree> <store-path> <session-id> [payload]")
    print("       mode is one of: write, read, read-absent")
    exit(2)
}

let mode = arguments[1]
let treePath = arguments[2]
let storePath = arguments[3]
let sessionId = arguments[4]
let storeURL = URL(fileURLWithPath: storePath)
let treeURL = URL(fileURLWithPath: treePath)

/// The HEAD of the tree whose data layer this binary measured.
func sourceCommit() -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = ["-C", treeURL.path, "rev-parse", "--short=12", "HEAD"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do {
        try process.run()
    } catch {
        return nil
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { return nil }
    let text = String(decoding: data, as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? nil : text
}

@MainActor
func measure() throws -> Int32 {
    guard let commit = sourceCommit() else {
        print("NO-SOURCE-COMMIT tree=\(treePath)")
        return 2
    }
    let container = try WSPersistenceContainer.makeContainer(at: storeURL)
    let repository = WSChatRepository(container: container)

    switch mode {
    case "write":
        let payload = arguments.count >= 6 ? arguments[5] : "probe-payload"
        try repository.saveContextUsage(payload, sessionId: sessionId, bookID: nil)
        let readBack = try repository.loadContextUsage(sessionId: sessionId, bookID: nil)
        guard readBack == payload else {
            print("WRITE-FAILED source_commit=\(commit) readBackInSameProcess=\(readBack ?? "nil")")
            return 1
        }
        print("WRITE-OK source_commit=\(commit) readBackInSameProcess=\(readBack ?? "nil")")
        return 0

    case "read":
        guard let found = try repository.loadContextUsage(sessionId: sessionId, bookID: nil) else {
            print("READ-EMPTY source_commit=\(commit) payload=nil")
            return 1
        }
        print("READ-OK source_commit=\(commit) payload=\(found)")
        return 0

    case "read-absent":
        if let found = try repository.loadContextUsage(sessionId: sessionId, bookID: nil) {
            print("READ-UNEXPECTED source_commit=\(commit) payload=\(found)")
            return 1
        }
        print("READ-EMPTY source_commit=\(commit) payload=nil")
        return 0

    default:
        print("UNKNOWN-MODE mode=\(mode)")
        return 2
    }
}

// The store opening and the reads are main-actor work, = = so the entry
// assumes isolation on the main thread (= = the same shape
// `chat_bubble_metrics.swift` uses at its own last line). A failure to
// open the store is reported as MEASURE-ERROR and exits 2 (= = a number
// that could not be taken is not a pass), = = so a reader can never see a
// silent zero where a measurement should have been.
exit(MainActor.assumeIsolated {
    do {
        return try measure()
    } catch {
        print("MEASURE-ERROR mode=\(mode) detail=\(error.localizedDescription)")
        return 2
    }
})
