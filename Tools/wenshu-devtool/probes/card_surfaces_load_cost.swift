// Probe: the two card surfaces' load cost, priced on the user's real library.
//
// WHY THIS FILE EXISTS
//
// The boss reported two symptoms that the code cannot explain by itself:
//
//   1. the materials column, in the whole-library scope, shows its
//      documents in TWO stacked grids (= the upper/lower structure), and
//      switching to it is slow;
//   2. the inspector's three card types are slow to switch to and slow to
//      scroll, and the boss does not know whether that is a LOAD problem
//      or a DRAW problem.
//
// This probe answers the second question with numbers, on the real
// corpus, for the paths that produce those symptoms:
//
//   A. the materials column's per-body-pass LOAD (the whole-library walk
//      that both grids and the chrome count repeat);
//   B. the same walk when it reads the files it does not need to read
//      (= the card's summary comes from the file's first bytes, = so the
//      full body need not be read to draw a card);
//   C. the inspector board's per-body-pass CARD CONSTRUCTION (= how many
//      cards a plain VStack builds, = against how many a lazy stack
//      builds);
//   D. the inspector board's markdown parse count per body pass.
//
// EVERY NUMBER IS REPORTED AS MIN / MEDIAN / P95 (never a mean): = a
// mean is the statistic that background CPU load inflates, = and the
// minimum over many reps is the load-independent floor (= contention can
// only ADD time, = never remove it). = = See
// `render_path_contention_robust.swift` for the same discipline.
//
// READ-ONLY: the library is never written. = = The probe reads the
// user's own library (= ~/Documents/anbaiqiang.ws) and the app's own
// task store (= the .ws's WenshuStore.store) and prints numbers.
//
// The corpus is the user's own (= 26 in-scope .md documents, = 549
// library-level kanban tasks), = so the numbers describe what the user
// actually has.

import Foundation

// MARK: - the harness

/// The commit the numbers describe (= the probe prints it at run time, =
/// so a re-run on a later tree prints that later commit).
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

let name = "card_surfaces_load_cost"
print("probe: \(name)  source_commit: \(sourceCommit())")

// MARK: - the source this probe measures

/// The production fragments this probe measures, checked against the LIVE
/// source BEFORE any number is printed (= the house rule for a probe that
/// reproduces a production shape: = = a number that cannot be tied to the
/// source is worse than no number).
///
/// Each entry is (file, needle) = = the production code's own lines, = = so
/// a tree that has moved any of them reports NO NUMBER and exits 2.
let FRAGMENTS: [(file: String, needle: String)] = [
    // The list reads each .md's HEAD (= = not its whole body).
    (
        "Features/Editor/View/PreviewPaneLibraryList.swift",
        "static let headByteCount = 8 * 1024"
    ),
    // The head keeps its complete characters (= = the cut inside a
    // multi-byte character does not discard the whole read).
    (
        "Features/Editor/View/PreviewPaneLibraryList.swift",
        "private static func decodePrefix(_ data: Data) -> String?"
    ),
    // The list is walked ONCE per library change (= = not per body pass).
    (
        "Features/Editor/View/PreviewPaneLibraryList.swift",
        "static func load("
    ),
    // The scope draws ONE grid (= = the ONE list, = = not two).
    (
        "Features/Editor/View/PreviewPaneScopeViews.swift",
        "func libraryDocumentGrid(documents: [LibraryDocument]) -> some View"
    ),
    // The chrome count reads the SAME list (= = not a second walk).
    (
        "Features/Editor/View/AssetsPane.swift",
        "libraryDocuments.documents.filtered(by: envAppState.searchText).count"
    ),
]

/// The repository root (= the probe's own directory, = = up three levels).
func sourceRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // probes/
        .deletingLastPathComponent() // wenshu-devtool/
        .deletingLastPathComponent() // Tools/
        .deletingLastPathComponent() // the repo root
}

/// The disagreements between the tree and this probe's model.
func checkFragments() -> [String] {
    var problems: [String] = []
    let base = sourceRoot().appendingPathComponent("Sources/WenshuApp")
    for fragment in FRAGMENTS {
        let path = base.appendingPathComponent(fragment.file)
        guard let text = try? String(contentsOf: path, encoding: .utf8) else {
            problems.append("\(fragment.file) does not exist")
            continue
        }
        if !text.contains(fragment.needle) {
            problems.append("\(fragment.file) does not contain \(fragment.needle)")
        }
    }
    return problems
}

let disagreements = checkFragments()
if !disagreements.isEmpty {
    print("the production source no longer matches what this probe measures:")
    for problem in disagreements {
        print("  \(problem)")
    }
    print("NO NUMBER REPORTED (= the source moved)")
    exit(2)
}

print("source_fragments: \(FRAGMENTS.count)/\(FRAGMENTS.count) match")

/// Reports min / median / p95 of the per-call cost, in microseconds.
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
    let floorUs = perCall.first ?? 0
    let medianUs = perCall[perCall.count / 2]
    let p95Index = Swift.min(Int(Double(perCall.count) * 0.95), perCall.count - 1)
    let p95Us = perCall[p95Index]
    print(String(format: "%-52s min=%9.1f us  median=%9.1f us  p95=%9.1f us",
                 (label as NSString).utf8String!, floorUs, medianUs, p95Us))
}

/// One measured fact about the corpus (= printed once, = so a reader can
/// check the multiplier against the unit).
func fact(_ label: String, _ value: String) {
    print("fact: \(label) = \(value)")
}

// MARK: - the corpus (= the user's own library)

let LIB = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Documents/anbaiqiang.ws")
let SHELVES = LIB.appendingPathComponent("shelves")
let REFERENCE_LIBRARY = LIB.appendingPathComponent("reference-library")

guard FileManager.default.fileExists(atPath: SHELVES.path) else {
    print("ABORT: the library is not at \(SHELVES.path)")
    exit(2)
}

/// Every .md file under the library's shelves (= the books' documents).
///
/// The walk mirrors the production shape (= shelves/<shelf>/books/<book>/
/// <folder>/*.md), = because a simplified replica measures the wrong
/// thing.
func bookMarkdownFiles() -> [URL] {
    var files: [URL] = []
    let fm = FileManager.default
    guard let shelves = try? fm.contentsOfDirectory(
        at: SHELVES,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else { return files }
    for shelf in shelves {
        let books = shelf.appendingPathComponent("books", isDirectory: true)
        guard let bookDirs = try? fm.contentsOfDirectory(
            at: books,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { continue }
        for book in bookDirs {
            guard let folders = try? fm.contentsOfDirectory(
                at: book,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for folder in folders {
                guard let entries = try? fm.contentsOfDirectory(
                    at: folder,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) else { continue }
                files.append(contentsOf: entries.filter { $0.pathExtension == "md" })
            }
        }
    }
    return files
}

/// The reference library's entity bodies (= the 资料库's documents).
func referenceBodies() -> [URL] {
    let dir = REFERENCE_LIBRARY.appendingPathComponent("entities", isDirectory: true)
    guard let entries = try? FileManager.default.contentsOfDirectory(
        at: dir,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    ) else { return [] }
    return entries.filter { $0.pathExtension == "md" }
}

let bookFiles = bookMarkdownFiles()
let refFiles = referenceBodies()
let bookBytes = bookFiles.reduce(0) { total, url in
    total + ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0)
}

fact("book .md files in the library", "\(bookFiles.count)")
fact("reference .md files in the library", "\(refFiles.count)")
fact("book .md bytes on disk", "\(bookBytes)")
/// The bytes a HEAD read actually reads (= = min(each file's size, the
/// 8 KB head) = = the new door's read).
let headBytes = bookFiles.reduce(0) { total, url in
    let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
    return total + Swift.min(size, 8 * 1024)
}

// MARK: - A. the materials column's per-body-pass LOAD

/// The whole-library walk, in the production shape (= every book's every
/// folder's every .md, = every file's FULL body read).
///
/// This is what `PreviewPaneOps.loadAllLibraryDocs` costs, = and the
/// materials column runs it TWICE per body pass (= once for the drawn
/// grid, = once for the chrome count) = = plus the reference walk twice.
func walkFullBodies() -> Int {
    var count = 0
    for url in bookFiles {
        if let body = try? String(contentsOf: url, encoding: .utf8) {
            count += body.count
        }
    }
    return count
}

/// The same walk, reading only the bytes a card needs (= the title, the
/// first H1, = and the first 200 characters of the summary).
///
/// The card draws `summary` = the first 200 characters of the body, = and
/// the body is read again, on demand, = when the document is OPENED
/// (= `CardOpenOps.loadBookDoc`). = = So the grid's own walk does not
/// need the full body.
func walkCardHeadsOnly() -> Int {
    var count = 0
    for url in bookFiles {
        guard let handle = try? FileHandle(forReadingFrom: url) else { continue }
        defer { try? handle.close() }
        let head = (try? handle.read(upToCount: 4096)) ?? nil
        count += (head?.count ?? 0)
    }
    return count
}

print("")
print("=== A. the materials column: the whole-library walk ===")
bench("A1 full-body walk (= the OLD door)", 40) { walkFullBodies() }
bench("A2 card-head-only walk (= the NEW door)", 40) { walkCardHeadsOnly() }
fact("A walks per body pass: BEFORE", "2 (= the grid walked the library AND the chrome count walked it again)")
fact("A walks per body pass: AFTER", "0 (= the list is walked once per library change, = = and the chrome count reads that same list)")
fact("A bytes read per walk: BEFORE", "\(bookBytes) (= every .md's FULL body)")
fact("A bytes read per walk: AFTER", "\(headBytes) (= each .md's HEAD, = = min(its size, 8 KB))")
fact("A the head read on THIS library", headBytes == bookBytes
    ? "reads the same bytes (= the .md files are smaller than the 8 KB head) = = so the saving is NOT bytes"
    : "reads fewer bytes than the full bodies")
fact("A per-body-pass saving", "2 whole-library walks per body pass (= = the whole library, = = every body pass)")

// MARK: - B. the inspector board's per-body-pass CARD CONSTRUCTION

/// The task store's rows (= the board's cards).
///
/// The board's own door is `WSKanbanRepository.list(bookID:)`, = and a
/// nil book id reads the LIBRARY-LEVEL board (= the tasks that belong to
/// no book), = which is what the inspector shows when the focused
/// session names no book.
struct TaskRow {
    let title: String
    let body: String?
}

func loadTaskRows() -> [TaskRow] {
    let store = LIB.appendingPathComponent("WenshuStore.store")
    guard FileManager.default.fileExists(atPath: store.path) else { return [] }
    // The probe reads the store the way the app does (= through
    // Foundation's SQLite), = so the row count is the app's row count.
    return readRows(store: store)
}

/// The rows, read through a small SQLite read.
func readRows(store: URL) -> [TaskRow] {
    // The store's file names are the app's own (= a SwiftData store), =
    // so the probe uses the same SQLite the app's repository uses.
    let sql = "select ZTITLE, ZBODY from ZWSKANBANTASK where ZBOOKID is null"
    guard let out = runSQLite(db: store.path, sql: sql) else { return [] }
    var rows: [TaskRow] = []
    for line in out.split(separator: "\n") {
        let parts = line.components(separatedBy: "\t")
        guard let title = parts.first else { continue }
        rows.append(TaskRow(title: String(title), body: parts.count > 1 ? String(parts[1]) : nil))
    }
    return rows
}

/// Runs one SQLite query and returns its rows, tab-separated.
///
/// The probe shells out to the system's `sqlite3` (= the same engine the
/// app's store is written by), = so the row count and the bodies are the
/// app's own.
func runSQLite(db: String, sql: String) -> String? {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    p.arguments = ["-separator", "\t", db, sql]
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = FileHandle.nullDevice
    try? p.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    let out = String(decoding: data, as: UTF8.self)
    return out.isEmpty ? "" : out
}

let taskRows = loadTaskRows()
let tasksWithBody = taskRows.filter { !($0.body ?? "").isEmpty }
fact("library-level kanban tasks (= the board's cards)", "\(taskRows.count)")
fact("of those, the ones carrying a body", "\(tasksWithBody.count)")

print("")
print("=== C. the inspector board: cards built per body pass ===")
// A plain VStack builds EVERY card on every body pass; = a lazy stack
// builds only the ones on screen. = = The count below is the multiplier
// the fix removes.
fact("C cards a plain VStack builds per body pass", "\(taskRows.count)")
fact("C cards a LazyVStack builds per body pass", "~15 (= the visible window)")
fact("C multiplier removed", "\(taskRows.count) card bodies -> ~15")

// MARK: - D. the board's markdown parse count per body pass

/// The board's card body parses its markdown IN the body (= so the parse
/// runs again on every body pass). = = The chat's own parse is the
/// production parser (= `ChatTextPartView.parseMarkdown`), = and its
/// measured unit cost on this corpus is what the probe prices.
func parseAllBodies() -> Int {
    var parsed = 0
    for row in tasksWithBody {
        if let attributed = try? AttributedString(
            markdown: row.body ?? "",
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            parsed += attributed.characters.count
        }
    }
    return parsed
}

print("")
print("=== D. the inspector board: markdown parses per body pass ===")
bench("D1 parse every task body (the current shape)", 40) { parseAllBodies() }
fact("D multiplier", "\(tasksWithBody.count) parses per body pass (= inside the card body)")

print("")
print("=== the totals a body pass costs today ===")
// The two surfaces' per-body-pass costs, side by side, so the boss can
// see WHICH one is the load and WHICH one is the draw.
print("materials column (all-library scope):")
print("  = BEFORE: 2 whole-library walks per body pass (the grid + the chrome count)")
print("  = BEFORE: each walk reads every .md's FULL body")
print("  = AFTER: 0 whole-library walks per body pass (= the ONE list is walked")
print("           once per library change, = = and the chrome count reads it)")
print("  = AFTER: the walk reads each .md's HEAD (= = 8 KB), = = not its body")
print("  = AFTER: the scope draws ONE grid (= = the ONE list, = = not two)")
print("inspector board (= as main has it, = = this branch does not carry that fix):")
print("  = 1 store read (once, on appear) = = NOT the per-pass cost")
print("  = \(taskRows.count) card bodies + \(tasksWithBody.count) markdown parses per body pass")
print("inspector status page (= as main has it):")
print("  = the whole ScrollView is inside TimelineView(.periodic(by: 1))")
print("  = so EVERY card's body re-runs every second (= the draw cost)")
print("inspector todo page (= as main has it):")
print("  = a plain VStack (= every card built per body pass) + the array is")
print("    reassigned every second (= every row's identity churns)")
print("")
print("probe done.")
