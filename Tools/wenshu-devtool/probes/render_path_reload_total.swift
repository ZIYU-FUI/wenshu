// Probe 4: the sweep's numbers, re-measured with a contention-ROBUST method.
//
// WHY THIS FILE EXISTS
// The 2026-11-13 sweep's numbers were recorded while three subagents
// were running `swiftc -O` compiles at the same time. The reviewer
// re-ran the same probe files on an idle machine and got 2-3x lower
// numbers. So the old harness's method is the defect, not the code
// paths it measures:
//
//   THE OLD HARNESS AVERAGED. `bench` ran N reps and divided the
//   TOTAL by N (= one mean). A mean is exactly the statistic that
//   background CPU load inflates: one 400 us scheduling hiccup
//   inside 400 reps adds 1 us to the mean.
//
//   THE NEW HARNESS REPORTS THE MINIMUM. The minimum over many
//   reps is the contention-free estimate (= the fastest the code
//   path actually ran). Contention can only ADD time, never remove
//   it, so the minimum is the load-independent floor. The median is
//   reported next to it so a reader can see the spread.
//
//   THE TWO TOGETHER say whether a number is trustworthy: a small
//   min-to-median gap means the machine was quiet; a large gap means
//   the median is contention-polluted and only the min should be
//   quoted.
//
// Everything below is the SAME production shape as the original
// probes (= the same replicas, the same corpus, the same counters).
// READ-ONLY: the library is never written.

import Foundation

let name = "render_path_reload_total"

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
print("probe: \(name)  source_commit: \(sourceCommit())")

let LIB = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Documents/anbaiqiang.ws")

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

// MARK: - the corpus (= the user's own library, READ-ONLY)

let shelvesRoot = LIB.appendingPathComponent("shelves")
let shelfDirs = (try? FileManager.default.contentsOfDirectory(atPath: shelvesRoot.path)) ?? []
var bookDirs: [URL] = []
for s in shelfDirs {
    let shelfURL = shelvesRoot.appendingPathComponent(s)
    let booksRoot = shelfURL.appendingPathComponent("books")
    for b in (try? FileManager.default.contentsOfDirectory(atPath: booksRoot.path)) ?? [] {
        bookDirs.append(booksRoot.appendingPathComponent(b))
    }
}
let bookFolders = ["world", "characters", "outlines", "chapters", "drafts", "ideas", "sessions"]
print("corpus: shelves=\(shelfDirs.count) books=\(bookDirs.count) bookFolders=\(bookFolders.count)")

// ============================================================
// A = the editor's per-keystroke word count (A1 + A2)
// ============================================================
print("\n[A] the editor's per-keystroke count (= A1 + A2 = the SAME walk twice)")
let docPath = LIB.appendingPathComponent("references/2D44E511-8DCC-4210-AD0F-857FFD9D72E0.md")
let s = (try? String(contentsOf: docPath, encoding: .utf8)) ?? ""
print("    document: \(docPath.lastPathComponent) chars=\(s.count)")

/// The EXACT production shape (= WordCounter.charactersNoSpaces).
func charactersNoSpaces(_ content: String) -> Int {
    var count = 0
    for character in content where character != " " && character != "\n" && character != "\t" { count += 1 }
    return count
}
bench("A1/A2 one walk of the 4,731-char document", 300) { charactersNoSpaces(s) }
bench("A1+A2 the same walk TWICE (= the editor + the status bar)", 300) {
    charactersNoSpaces(s) + charactersNoSpaces(s)
}

// ============================================================
// D1 = the sidebar's folder doc count
// ============================================================
print("\n[D1] the sidebar's folder doc count")

/// The EXACT production shape (= AppleSidebarView.loadFolderDocCount).
func loadFolderDocCount(bookId: String, folderName: String) -> Int {
    guard FileManager.default.fileExists(atPath: shelvesRoot.path),
          let shelfDirs = try? FileManager.default.contentsOfDirectory(
            at: shelvesRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
    else { return 0 }
    for shelfDir in shelfDirs {
        let folderDir = shelfDir
            .appendingPathComponent("books")
            .appendingPathComponent(bookId)
            .appendingPathComponent(folderName)
        if FileManager.default.fileExists(atPath: folderDir.path),
           let contents = try? FileManager.default.contentsOfDirectory(
            at: folderDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            return contents.filter { $0.pathExtension == "md" }.count
        }
    }
    return 0
}
bench("D1 one loadFolderDocCount call", 200) {
    loadFolderDocCount(bookId: bookDirs[0].lastPathComponent, folderName: "world")
}
bench("D1 the whole reload (books x 5 user-facing folders)", 100) {
    var total = 0
    for b in bookDirs {
        for f in ["world", "characters", "chapters", "drafts", "ideas"] {
            total += loadFolderDocCount(bookId: b.lastPathComponent, folderName: f)
        }
    }
    return total
}

// The REAL row count (= the multiplier D2's row multiplies by).
// The sweep's doc said "12 distinct tags plus 6 categories = 18 ids";
// the probe measured only the TAG SET, and read the tag set from the
// entities directory's .json files (= only ONE file, `entities.json`,
// which is a LIST, so the probe's dict cast found 0 tags).
//
// The truth: the entities layer is 6 `.md` files PLUS one
// `entities.json`, and `entities.json` is a 6-item LIST whose items
// carry the `tags` array. = = 12 distinct tags. = = The category rows
// come from `EntityClassifier`, = = so their count is a classifier
// output, = = not a stored field.
let entitiesDir = LIB.appendingPathComponent("reference-library/entities")
let entitiesJSON = entitiesDir.appendingPathComponent("entities.json")
var tags = Set<String>()
var jsonCount = 0
if let data = try? Data(contentsOf: entitiesJSON),
   let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
    jsonCount = list.count
    for item in list {
        for t in (item["tags"] as? [String] ?? []) { tags.insert(t) }
    }
}
print("    entities.json=\(jsonCount) items, distinct tags=\(tags.count)")

// A REAL corpus tag, read from the library (= = not a literal, = = so the
// probe carries no non-ASCII text and the hashed string is the shape
// production hashes). = = The tag's CONTENT does not affect the cost
// (= = the Hasher hashes any string of that length), = = but its LENGTH
// does, = = so a corpus tag is the faithful input.
let sampleTag = tags.sorted().first ?? "tag"

// ============================================================
// D2 = the reference-library row id (Hasher + 16 String(format:))
// ============================================================
print("\n[D2] the reference-library row id")

/// The EXACT production shape (= SidebarService.stableReferenceTagId).
func stableTagId(_ tag: String) -> UUID {
    let raw = "wenshu.sidebar.reftag.\(tag)"
    var hasher = Hasher()
    hasher.combine(raw)
    let hash = hasher.finalize()
    let bytes = withUnsafeBytes(of: hash.bigEndian) { Array($0) }
    var uuidBytes = Array(bytes)
    while uuidBytes.count < 16 { uuidBytes.append(0) }
    uuidBytes = Array(uuidBytes.prefix(16))
    uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x40
    uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80
    let u = uuidBytes.map { String(format: "%02x", $0) }.joined()
    let formatted = "\(u.prefix(8))-\(u.dropFirst(8).prefix(4))-\(u.dropFirst(12).prefix(4))-\(u.dropFirst(16).prefix(4))-\(u.dropFirst(20).prefix(12))"
    return UUID(uuidString: formatted) ?? UUID()
}
bench("D2 one id (Hasher + 16 x String(format:))", 2000) { stableTagId(sampleTag).uuidString.count }
bench("D2 the 16 x String(format:) alone", 2000) {
    (0 ..< 16).reduce(0) { acc, i in acc + String(format: "%02x", UInt8(i)).count }
}
bench("D2 the Hasher alone", 5000) {
    var h = Hasher(); h.combine("wenshu.sidebar.reftag.\(sampleTag)"); return Int(h.finalize() & 0xff)
}

bench("D2 the real 12-tag set's id cost", 500) {
    var n = 0
    for t in tags { n += stableTagId(t).uuidString.count }
    return n
}
bench("D2 one id x 12 (the multiplier the doc quotes)", 500) {
    var n = 0
    for _ in 0 ..< 12 { n += stableTagId(sampleTag).uuidString.count }
    return n
}

// ============================================================
// D3 = the CoverReconciler's full shelves walk
// ============================================================
print("\n[D3] the cover reconciler's shelves walk")

/// The EXACT production shape (= CoverReconciler.bookDocIds).
func bookDocIds(shelvesRoot: URL) -> Int {
    guard FileManager.default.fileExists(atPath: shelvesRoot.path) else { return 0 }
    guard let shelves = try? FileManager.default.contentsOfDirectory(at: shelvesRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return 0 }
    var ids = 0
    for shelf in shelves {
        let shelfURL = shelf
        let booksRoot = shelfURL.appendingPathComponent("books", isDirectory: true)
        guard let books = try? FileManager.default.contentsOfDirectory(at: booksRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
        for book in books {
            let bookURL = booksRoot.appendingPathComponent(book.lastPathComponent)
            guard let folders = try? FileManager.default.contentsOfDirectory(at: bookURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for folder in folders {
                let folderURL = bookURL.appendingPathComponent(folder.lastPathComponent)
                guard let files = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
                ids += files.filter { $0.pathExtension == "md" }.count
            }
        }
    }
    return ids
}
bench("D3 the full shelves walk", 100) { bookDocIds(shelvesRoot: shelvesRoot) }

// ============================================================
// F1 = BookDocumentIndex.scan (the OPEN-1 question's cost)
// ============================================================
print("\n[F1] BookDocumentIndex.scan")

/// The EXACT production shape (= BookDocumentIndex.scan).
func scanBook(_ root: URL) -> Int {
    var found = 0
    for f in bookFolders {
        let folder = root.appendingPathComponent(f, isDirectory: true)
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        found += entries.filter { $0.hasSuffix(".md") }.count
    }
    return found
}
for b in bookDirs {
    bench("F1 scanBook(\(b.lastPathComponent.prefix(8)))", 200) { scanBook(b) }
}
bench("F1 scanBook with a NIL directory (= today's production path)", 200) {
    let nilDirectory: URL? = nil
    let docs = nilDirectory.map { _ in [1] } ?? []
    return docs.count
}

// ============================================================
// the OPEN-1 production cost: the factory's own construction
// ============================================================
print("\n[OPEN-1] the editor factory's per-body-pass construction")
bench("OPEN-1 the 22 Notification.Name allocations", 5000) {
    let names: [Notification.Name] = [
        Notification.Name("com.wenshu.editor.applyBoldRequest"),
        Notification.Name("com.wenshu.editor.applyItalicRequest"),
        Notification.Name("com.wenshu.editor.applyHeadingRequest"),
        Notification.Name("com.wenshu.editor.applyHighlightRequest"),
        Notification.Name("com.wenshu.editor.applyStrikethroughRequest"),
        Notification.Name("com.wenshu.editor.applyInlineCodeRequest"),
        Notification.Name("com.wenshu.editor.applyBlockquoteRequest"),
        Notification.Name("com.wenshu.editor.applyUnorderedListRequest"),
        Notification.Name("com.wenshu.editor.applyOrderedListRequest"),
        Notification.Name("com.wenshu.editor.applyLinkRequest"),
        Notification.Name("com.wenshu.editor.applyCodeBlockRequest"),
        Notification.Name("com.wenshu.editor.applyHorizontalRuleRequest"),
        Notification.Name("com.wenshu.editor.applyImageRequest"),
        Notification.Name("com.wenshu.editor.selectionBoldDidChange"),
        Notification.Name("com.wenshu.editor.selectionItalicDidChange"),
        Notification.Name("com.wenshu.editor.selectionHighlightDidChange"),
        Notification.Name("com.wenshu.editor.findScrollToRange"),
        Notification.Name("com.wenshu.editor.findClearHighlights"),
        Notification.Name("com.wenshu.editor.findQuery"),
        Notification.Name("com.wenshu.editor.findResults"),
        Notification.Name("com.wenshu.editor.replaceCurrent"),
        Notification.Name("com.wenshu.editor.replaceAll")
    ]
    return names.count
}


// ============================================================
// D4 = ONE WHOLE SIDEBAR RELOAD (= what reload() actually pays)
// ============================================================
// WHY THIS EXISTS: the sweep's path-class table lists the reload
// class as 759.958 us, = = but that is D1's TEN folder-doc-count calls
// ALONE. = = The SAME reload() also runs the cover reconciler's
// shelves walk (D3 = 755.000 us), = = because reload() calls
// CoverReconciler.live().sweep(...) at SidebarService.swift:120 and
// folderChildren(for:) (= = D1) at :153. = = So the reload class's
// total is the SUM, = = and the table understates it by ~2x.
print("\n[D4] one whole sidebar reload (= D1's ten counts + D3's shelves walk)")
bench("D4 one reload = D1's ten counts + D3's shelves walk", 100) {
    var total = 0
    for b in bookDirs {
        for f in ["world", "characters", "chapters", "drafts", "ideas"] {
            total += loadFolderDocCount(bookId: b.lastPathComponent, folderName: f)
        }
    }
    total += bookDocIds(shelvesRoot: shelvesRoot)
    return total
}
