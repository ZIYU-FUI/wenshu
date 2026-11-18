// Probe: the inspector card pages' load cost (= the trailing column's
// three card lists).
//
// WHY THIS FILE EXISTS
// The trailing column's three card pages (= the status page, the todo
// page and the board) each draw a list of cards, and each list's cost
// was paid for the WHOLE list on every body pass:
//
//   - the board's card column was an eager VStack (= every card's
//     body was built on every body pass, = even the cards off
//     screen), = and each card PARSED its task body's markdown
//     (= the board's real corpus carries 511 bodies with text).
//   - the status page's whole scroll content sat inside a 1 Hz
//     TimelineView (= every card on the page was rebuilt once a
//     second, = including the cards that show no time at all).
//   - the todo page's card list was an eager VStack (= every card's
//     body was built on every body pass, = even the cards off
//     screen).
//
// This probe measures that cost on the USER'S OWN library (=
// /Users/anbaiqiang/Documents/anbaiqiang.ws), and measures the
// ALTERNATIVE shape in the SAME binary (= so the comparison is
// like-for-like), because the two shapes must be priced against the
// same corpus on the same machine.
//
// The numbers are reported as MIN / MEDIAN / P95 over repeated
// samples (= never a mean: = a mean is the one statistic background
// CPU load inflates, = and the minimum over many reps is the
// load-independent floor).
//
// READ-ONLY: the library is never written. The corpus is read from
// the live SwiftData store with the sqlite3 CLI in -readonly mode,
// = and every body is decoded with an EXPLICIT utf-8 decode (= the
// column holds a BLOB on some stores).

import AppKit
import Foundation
import Observation
import SwiftUI

let name = "inspector_card_load_cost"

/// The commit the numbers describe. = = The probe prints it at run
/// time, = = so a re-run on a later tree prints that later commit, = =
/// and the numbers are unchanged as long as the app source is.
func sourceCommit() -> String {
    let r = Process()
    r.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    r.arguments = ["rev-parse", "--short=12", "HEAD"]
    r.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let pipe = Pipe()
    r.standardOutput = pipe
    try? r.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    r.waitUntilExit()
    let out = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    return out.isEmpty ? "unknown" : out
}

// MARK: - the production fragments this probe reproduces

/// The production fragments this probe reproduces, checked against the
/// LIVE source BEFORE any number is printed (= the house rule for a
/// probe that reproduces production shapes: = = a number that cannot be
/// tied to the source is worse than no number).
///
/// Each entry is (file, needle) = = a fragment the tree must STILL
/// have for the shape below to be the shape the app draws. = = The
/// needles are the production code's own lines, = = so a producer that
/// moves its clock out of the page, = = its card list out of an eager
/// stack, = = or its markdown parse to the load, = = breaks a needle
/// here instead of leaving the numbers describing a shape the tree no
/// longer has.
let FRAGMENTS: [(file: String, needle: String)] = [
    // The board's card column is a LAZY stack (= the eager column is
    // what this probe measures as BEFORE).
    (
        "Features/Kanban/View/KanbanView.swift",
        "LazyVStack(alignment: .leading, spacing: DesignTokens.spacingTight)"
    ),
    // The board's body is parsed at the LOAD (= the per-card parse is
    // what this probe measures as BEFORE).
    (
        "Features/Kanban/View/KanbanView.swift",
        "parsedBody = ChatTextPartView.parseMarkdown(body)"
    ),
    // The board's card draws the PARSED body (= = so a body pass
    // parses nothing).
    (
        "Features/Kanban/View/KanbanView.swift",
        "Text(parsedBody)"
    ),
    // The todo page's card list is a LAZY stack.
    (
        "Features/Editor/View/InspectorTodoPageView.swift",
        "LazyVStack(alignment: .leading, spacing: DesignTokens.spacingTight)"
    ),
    // The status page's clock lives in the ELAPSED LABEL (= the
    // page-level clock is what this probe measures as BEFORE).
    (
        "Features/Editor/View/InspectorStatusElapsedLabel.swift",
        "TimelineView(.periodic(from: .now, by: 1))"
    ),
    // The status page's card draws the ELAPSED LABEL (= = the page
    // carries no clock of its own, = = and this line ties the numbers
    // below to the production page: = = a tree that puts the clock back
    // on the page breaks the needle here).
    (
        "Features/Editor/View/InspectorStatusView.swift",
        "InspectorStatusElapsedLabel(task:"
    ),
    // The elapsed label is the ONE subtree that ticks (= = the page
    // carries no clock of its own).
    (
        "Features/Editor/View/InspectorStatusElapsedLabel.swift",
        "struct InspectorStatusElapsedLabel: View"
    ),
    // The board's card content is the parsed-at-the-load carrier.
    (
        "Features/Kanban/Model/KanbanCardContent.swift",
        "struct KanbanCardContent"
    ),
]

/// The repo root (= the probe's own directory, = = up three levels).
func sourceRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // probes/
        .deletingLastPathComponent() // wenshu-devtool/
        .deletingLastPathComponent() // Tools/
        .deletingLastPathComponent() // the repo root
}

/// The fragments this probe reproduces, checked against the live
/// source. Returns the list of disagreements.
func checkFragments() -> [String] {
    var problems: [String] = []
    let base = sourceRoot()
        .appendingPathComponent("Sources/WenshuApp")
    for fragment in FRAGMENTS {
        let path = base.appendingPathComponent(fragment.file)
        guard let text = try? String(contentsOf: path, encoding: .utf8) else {
            problems.append("\(fragment.file): the file is not readable")
            continue
        }
        if !text.contains(fragment.needle) {
            problems.append("\(fragment.file) does not contain \(fragment.needle)")
        }
    }
    return problems
}

print("probe: \(name)  source_commit: \(sourceCommit())")

let disagreements = checkFragments()
if !disagreements.isEmpty {
    print("the production source no longer matches what this probe reproduces:")
    for problem in disagreements {
        print("  \(problem)")
    }
    print("NO NUMBER REPORTED (= the source moved)")
    exit(2)
}

print("source_fragments: \(FRAGMENTS.count)/\(FRAGMENTS.count) match")

// MARK: - the corpus (= the user's own library, READ-ONLY)

let LIB = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Documents/anbaiqiang.ws")
let STORE = LIB.appendingPathComponent("WenshuStore.store")

/// Runs the sqlite3 CLI and returns its stdout (= READ-ONLY: = the
/// store is opened with `-readonly`).
func sql(_ statement: String) -> String {
    let r = Process()
    r.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    r.arguments = ["-readonly", "-noheader", STORE.path, statement]
    let pipe = Pipe()
    r.standardOutput = pipe
    r.standardError = Pipe()
    try? r.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    r.waitUntilExit()
    return String(decoding: data, as: UTF8.self)
}

/// The hex bytes of one blob/text column value (= hex survives every
/// column type, = and the decode below is explicit).
func hexBytes(_ hex: String) -> [UInt8] {
    var bytes: [UInt8] = []
    bytes.reserveCapacity(hex.count / 2)
    var index = hex.startIndex
    while index < hex.endIndex {
        let next = hex.index(index, offsetBy: 2)
        if let byte = UInt8(hex[index ..< next], radix: 16) {
            bytes.append(byte)
        }
        index = next
    }
    return bytes
}

/// One task row's body (= the raw bytes, = decoded with an explicit
/// utf-8 decode).
struct TaskBody {
    let status: String
    let bytes: [UInt8]

    /// The body as text (= an EXPLICIT utf-8 decode).
    var text: String {
        String(decoding: bytes, as: UTF8.self)
    }
}

let taskCount = Int(
    sql("SELECT COUNT(*) FROM ZWSKANBANTASK;")
        .trimmingCharacters(in: .whitespacesAndNewlines)
) ?? 0

let corpus: [TaskBody] = {
    let rows = sql("SELECT ZSTATUS, hex(ZBODY) FROM ZWSKANBANTASK ORDER BY ZCREATEDAT;")
        .split(separator: "\n")
    return rows.compactMap { row in
        let cells = row.split(separator: "|", maxSplits: 1).map(String.init)
        guard cells.count == 2 else { return nil }
        let hex = cells[1].trimmingCharacters(in: .whitespaces)
        guard !hex.isEmpty else { return nil }
        return TaskBody(status: cells[0], bytes: hexBytes(hex))
    }
}()

let bodies = corpus.filter { !$0.bytes.isEmpty }
let bodyTypes = sql("SELECT typeof(ZBODY), COUNT(*) FROM ZWSKANBANTASK GROUP BY typeof(ZBODY);")
    .split(separator: "\n")
    .map { $0.replacingOccurrences(of: "|", with: " x ") }
    .joined(separator: ", ")

/// How many cards each status holds (= the board's group sizes).
var groupSizes: [(status: String, count: Int)] = []
for row in sql("SELECT ZSTATUS, COUNT(*) FROM ZWSKANBANTASK GROUP BY ZSTATUS;")
    .split(separator: "\n")
{
    let cells = row.split(separator: "|").map(String.init)
    guard cells.count == 2, let count = Int(cells[1]) else { continue }
    groupSizes.append((cells[0], count))
}

print("corpus: library=\(LIB.path)")
print("        store=\(STORE.path)")
print("        tasks=\(taskCount)  bodies_with_text=\(bodies.count)")
print("        body_column_types=[\(bodyTypes)]")
print("        groups=\(groupSizes.map { "\($0.status):\($0.count)" }.joined(separator: " "))")

// MARK: - the contention-robust bench

/// Reports min / median / p95 of the per-call cost, in microseconds.
/// The minimum is the load-independent floor (= the number to quote).
func bench(_ label: String, _ reps: Int, _ body: () -> Int) {
    _ = body() // warm-up, discarded
    var perCall: [Double] = []
    perCall.reserveCapacity(reps)
    for _ in 0 ..< reps {
        let t0 = DispatchTime.now().uptimeNanoseconds
        _ = body()
        let t1 = DispatchTime.now().uptimeNanoseconds
        perCall.append(Double(t1 - t0) / 1000.0)
    }
    perCall.sort()
    let floor = perCall[0]
    let median = perCall[reps / 2]
    let p95 = perCall[min(reps - 1, Int(Double(reps) * 0.95))]
    print(String(format: "  %-58s min %9.3f us | median %9.3f us | p95 %9.3f us",
                 (label as NSString).utf8String!, floor, median, p95))
}

/// Reports min / median / p95 of a per-sample COUNT (= e.g. the cards
/// a body pass built).
func benchCount(_ label: String, _ reps: Int, _ body: () -> Int) {
    var counts: [Int] = []
    counts.reserveCapacity(reps)
    for _ in 0 ..< reps {
        counts.append(body())
    }
    counts.sort()
    let floor = counts[0]
    let median = counts[reps / 2]
    let p95 = counts[min(reps - 1, Int(Double(reps) * 0.95))]
    print(String(format: "  %-58s min %9d    | median %9d    | p95 %9d",
                 (label as NSString).utf8String!, floor, median, p95))
}

// MARK: - the markdown parse (= the board's one markdown pipeline)

/// The EXACT production parse (= ChatTextPartView.parseMarkdown: = the
/// same inline-only markdown interpretation, = the same fallback).
func parseMarkdown(_ raw: String) -> AttributedString {
    (try? AttributedString(
        markdown: raw,
        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    )) ?? AttributedString(raw)
}

/// The corpus's body texts (= decoded once, = so the parse bench
/// measures the PARSE and not the decode).
let bodyTexts = bodies.map { $0.text }

print("\n[A] the board's markdown parse")

bench("the corpus parsed once (= the load's one-shot cost)", 30) {
    var sink = 0
    for text in bodyTexts {
        sink &+= parseMarkdown(text).characters.count
    }
    return sink
}

print("  parses per body pass: BEFORE \(bodies.count) (= one per card) | AFTER 0 (= parsed at the load)")

// MARK: - the card bodies a body pass builds (= the real board shape)

/// Counts the card bodies a body pass builds (= the production shape:
/// the groups' cards in an eager stack (= BEFORE) or a lazy stack
/// (= AFTER), = inside the board's own glass container + scroll view).
final class BodyCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func bump() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    func reset() {
        lock.lock()
        count = 0
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}

let counter = BodyCounter()

/// One card (= the board's card: = a title + the parsed body).
struct ProbeCard: View {
    let title: String
    let parsed: AttributedString

    var body: some View {
        counter.bump()
        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.body.weight(.medium))
                .lineLimit(3)
            Text(parsed)
                .font(.callout)
                .lineLimit(3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One group (= the board's group: = a disclosure + its cards).
///
/// The group is its own view with its own expansion state (= the
/// production shape), = so the disclosure opens exactly as the board's
/// group opens.
struct ProbeGroup: View {
    let cards: [(String, AttributedString)]
    let lazy: Bool

    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if lazy {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                        ProbeCard(title: card.0, parsed: card.1)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                        ProbeCard(title: card.0, parsed: card.1)
                    }
                }
            }
        } label: {
            Text("group \(cards.count)")
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The board's shape (= the real per-status groups).
struct ProbeBoard: View {
    let groups: [[(String, AttributedString)]]
    let lazy: Bool

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            GlassEffectContainer(spacing: 4) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { _, cards in
                        ProbeGroup(cards: cards, lazy: lazy)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

/// The board's groups (= the real per-status counts, = with the real
/// bodies, = parsed once so the parse is not what this section
/// measures).
let parsedBodies = bodyTexts.map(parseMarkdown)
var boardGroups: [[(String, AttributedString)]] = []
var cursor = 0
for group in groupSizes {
    var cards: [(String, AttributedString)] = []
    for _ in 0 ..< group.count {
        let parsed = cursor < parsedBodies.count ? parsedBodies[cursor] : AttributedString("")
        cursor += 1
        cards.append(("task \(cursor)", parsed))
    }
    boardGroups.append(cards)
}

func runLoop(_ seconds: Double) {
    let end = Date().addingTimeInterval(seconds)
    while Date() < end {
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
    }
}

/// Hosts a board shape offscreen (= the trailing column's width) and
/// returns how many card bodies its first body pass built.
@MainActor
func cardBodiesPerBodyPass(lazy: Bool) -> Int {
    counter.reset()
    let size = NSSize(width: 320, height: 600)
    let window = NSWindow(
        contentRect: NSRect(origin: .zero, size: size),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    let host = NSHostingView(rootView: ProbeBoard(groups: boardGroups, lazy: lazy))
    window.contentView = host
    window.setFrame(NSRect(origin: .zero, size: size), display: true)
    window.orderBack(nil)
    runLoop(1.5)
    let built = counter.value
    window.orderOut(nil)
    return built
}

print("\n[B] the board's card bodies built per body pass (= the real board shape)")

benchCount("BEFORE: eager card column (every card on the board)", 5) {
    MainActor.assumeIsolated { cardBodiesPerBodyPass(lazy: false) }
}

benchCount("AFTER: lazy card column (only the cards on screen)", 5) {
    MainActor.assumeIsolated { cardBodiesPerBodyPass(lazy: true) }
}

// MARK: - the status page's clock

/// The clock the probe drives (= one tick = one second).
///
/// The tick is driven through an observable instead of a TimelineView
/// because a headless probe's timeline schedule does not fire without
/// an app run loop, = and the INVALIDATION BREADTH is what this
/// section measures (= how many card bodies a tick rebuilds).
@Observable
final class ProbeClock {
    var now: Int = 0
}

/// The status page's card bodies (= the counter this section reads).
///
/// The counter is PER SAMPLE (= so a window left over from an earlier
/// sample cannot add its rebuilds to this sample's count).
let statusCounter = BodyCounter()

/// The elapsed label's own bodies (= the counter this section reads
/// beside the cards').
let labelCounter = BodyCounter()

/// The elapsed label (= the ONE subtree that shows a time).
///
/// The label reads the clock from the ENVIRONMENT (= so the card
/// neither holds nor reads it, = and a tick rebuilds the label and
/// nothing else).
struct ProbeElapsedLabel: View {
    @Environment(ProbeClock.self) private var clock

    var body: some View {
        labelCounter.bump()
        return Text("\(clock.now)")
    }
}

/// BEFORE: the page's clock reaches EVERY card (= the old page-level
/// TimelineView handed every card the current date).
struct ProbeStatusCardPageClock: View {
    let index: Int
    let now: Int

    var body: some View {
        statusCounter.bump()
        return HStack {
            Text("agent \(index)")
            Text("\(now)")
        }
    }
}

/// AFTER: the card does not read the clock (= only the elapsed label
/// does, = so a tick rebuilds the label and nothing else).
struct ProbeStatusCardLabelClock: View {
    let index: Int

    var body: some View {
        statusCounter.bump()
        return HStack {
            Text("agent \(index)")
            ProbeElapsedLabel()
        }
    }
}

/// BEFORE: the page's content closure reads the clock (= the old
/// page-level TimelineView's context.date).
struct ProbeStatusPagePageClock: View {
    let cards: Int
    let clock: ProbeClock

    var body: some View {
        // The page reads the clock (= the old page-level TimelineView
        // handed every card the current date).
        let now = clock.now
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(0 ..< cards, id: \.self) { index in
                    ProbeStatusCardPageClock(index: index, now: now)
                }
            }
        }
    }
}

/// AFTER: the page does not read the clock (= only the elapsed label
/// does, = so a tick rebuilds the label and nothing else).
struct ProbeStatusPageLabelClock: View {
    let cards: Int

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(0 ..< cards, id: \.self) { index in
                    ProbeStatusCardLabelClock(index: index)
                }
            }
        }
    }
}

/// Hosts a status page offscreen and drives ten ticks through it,
/// returning how many card bodies the ticks rebuilt (= the mount's
/// own pass is excluded, = so the number is the ticks' cost alone).
@MainActor
func statusCardRebuildsPerTick(pageLevelClock: Bool) -> Int {
    statusCounter.reset()
    labelCounter.reset()
    // The clock is PER SAMPLE (= so a window left over from an earlier
    // sample cannot be re-ticked by this sample).
    let clock = ProbeClock()
    let size = NSSize(width: 320, height: 600)
    let window = NSWindow(
        contentRect: NSRect(origin: .zero, size: size),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    let view = pageLevelClock
        ? AnyView(ProbeStatusPagePageClock(cards: 8, clock: clock))
        : AnyView(ProbeStatusPageLabelClock(cards: 8).environment(clock))
    let host = NSHostingView(rootView: view)
    window.contentView = host
    window.setFrame(NSRect(origin: .zero, size: size), display: true)
    window.orderBack(nil)
    runLoop(0.8)
    statusCounter.reset() // the mount's pass is not a tick's cost
    labelCounter.reset()
    for tick in 1 ... 10 {
        clock.now = tick
        runLoop(0.08)
    }
    let rebuilt = statusCounter.value
    let labelBodies = labelCounter.value
    // The window is CLOSED (= not just hidden), = because a window that
    // still observes the clock keeps rebuilding its cards when the NEXT
    // sample drives the clock (= and the sample would measure the
    // previous sample's windows too).
    window.close()
    print("      (= the elapsed label's own bodies over the same ten ticks: \(labelBodies))")
    return rebuilt
}

print("\n[C] the status page's card rebuilds over ten clock ticks (= 8 cards on the page)")

benchCount("BEFORE: the page-level 1 Hz clock (every card rebuilds)", 5) {
    MainActor.assumeIsolated { statusCardRebuildsPerTick(pageLevelClock: true) }
}

benchCount("AFTER: the clock on the elapsed label alone", 5) {
    MainActor.assumeIsolated { statusCardRebuildsPerTick(pageLevelClock: false) }
}

print("\npath classes:")
print("  [A] the markdown parse = PER BODY PASS (before) / ONCE PER LOAD (after)")
print("  [B] the card bodies built = PER BODY PASS")
print("  [C] the status page's rebuilds = PER SECOND")
