// ImportSOPLoader.swift · wenshu · [archived-round] (= boss 2026-10-10 (see OOB.md #2026-10-10)
// v2.7 [archived-round] (= boss 2026-10-10 (see OOB.md #2026-10-10) 这个 SOP" + "用户不可见").
// ImportSOPLoader = the lookup + loader for the SOP prompt files. Lives in Services (=
// data-layer concern) so ImportService (= caller) does the lookup, not
// ImportAgentDriver (= agent- side concern). Three responsibilities: 1. `sopName(for
// folder:)` = the per-folder SOP lookup (= the trigger logic). Every folder that
// declares an import template resolves to its own SOP file; = a folder without a
// template returns `nil` (= the orchestrator decides what to do = e.g. fall through
// to legacy multi-call router if no SOP matches). 2. `mandatorySections(for:)` =
// read the folder's mandatory document structure out of its document template (= the
// template owns the skeleton; = a procedure never restates a heading; = so a
// skeleton change reaches the procedure without editing the procedure). 3.
// `load(named:)` = read the SOP .md file from the .app bundle (= via
// `Bundle.module.url(forResource:)`); = does placeholder substitution for the SOP's
// `{filePath}`, `{body}`, `{bookPath}`, `{bookTitle}`, `{folderName}`,
// `{sectionHeadings}` slots. Bundle lookup uses `Bundle.module` (= SPM's per-target
// bundle for the WenshuApp target's Resources/). The .md file is shipped via
// `.process("Resources")` in Package.swift. Not user-visible: SOP files compile into
// the .app (= git tracked; = wenshu- engineer maintained; = the user cannot change
// them at runtime).

import Foundation

/// One mandatory item of a folder's documents.
///
/// A folder's document template (= its markdown skeleton) declares
/// what a document in that folder must carry. Two shapes appear
/// there: a section the document body holds (= an `## ` line),
/// and a separate file the folder must carry (= a `.md` the
/// template declares under one of its sections). Both are
/// mandatory, = so both are read.
enum ImportSOPSection: Equatable {
    /// A section the document body must carry (= an `## ` line of
    /// the folder's skeleton).
    case heading(String)
    /// A separate file the folder must carry (= a `.md` the
    /// folder's skeleton declares under one of its sections).
    case document(String)

    /// The text that names this section (= what a procedure text
    /// and its folder's documents both spell).
    var title: String {
        switch self {
        case .heading(let title): return title
        case .document(let fileName): return fileName
        }
    }

    /// The line this section contributes to a procedure text.
    var rendered: String {
        switch self {
        case .heading(let title): return "## \(title)"
        case .document(let fileName): return "- \(fileName)"
        }
    }
}

/// Lookup table for per-folder SOPs (= the
/// wenshu 文档管理员 view). One folder
/// → at most one SOP file. The mapping
/// is fixed (= wenshu-engineer
/// maintained; = not user-editable).
///
/// Trigger rule: the set of folders that
/// own a procedure is the set that
/// declares an import template (= the
/// folder enum's own import-template
/// property; = a folder without one has
/// no document shape to write, = so no
/// procedure).
enum ImportSOPTrigger {
    /// Map a target BookFolder to the
    /// SOP file name (= no extension).
    /// Returns `nil` if the folder carries
    /// no import template (= the
    /// orchestrator decides what to do
    /// = e.g. fall through to legacy
    /// path).
    ///
    /// The switch runs over the folder's
    /// import template (= not over a
    /// hand-listed folder set; = so a
    /// template without a procedure file
    /// cannot compile, = and a folder
    /// without a template needs no
    /// entry).
    static func sopName(for folder: BookFolder) -> String? {
        switch folder.importTemplate {
        case .some(.world):      return "ImportWorldPrompt"
        case .some(.characters): return "ImportCharactersPrompt"
        case .some(.outlines):   return "ImportOutlinesPrompt"
        case .some(.chapters):   return "ImportChaptersPrompt"
        case .some(.drafts):     return "ImportDraftsPrompt"
        case .some(.ideas):      return "ImportIdeasPrompt"
        case .none:              return nil
        }
    }

    /// The mandatory sections of a folder's documents.
    ///
    /// Read from the folder's own document
    /// template (= the template owns the
    /// skeleton; = the procedure text never
    /// restates a heading; = so a skeleton
    /// change reaches the procedure
    /// without editing the procedure).
    ///
    /// A skeleton section that declares its
    /// own `.md` files contributes those
    /// files (= the world template declares
    /// its six mandatory files under one
    /// heading; = its own procedure is
    /// frozen and already names them; =
    /// this reader keeps the two in step).
    /// Every other section contributes its
    /// own heading.
    static func mandatorySections(for folder: BookFolder) -> [ImportSOPSection] {
        folder.importTemplate?.mandatorySections ?? []
    }

    /// The mandatory sections of a folder's documents, rendered
    /// as the list a procedure text shows (= one section per
    /// line).
    static func renderedSectionHeadings(for folder: BookFolder) -> String {
        folder.importTemplate?.renderedMandatorySections ?? ""
    }
}

/// The structure a document template declares for the documents
/// in its folder.
///
/// The template owns the skeleton (= the single source of truth
/// for what a document in that folder must carry). A procedure
/// never restates a heading; = it asks the template at run
/// time, = so a skeleton change reaches the procedure without
/// editing the procedure.
///
/// (= the template service reads its
/// own skeleton here; = the same
/// skeleton, = the same `## ` titles, = the
/// same source of truth as the service's
/// own body preparation. The service keeps
/// that reader file-private and the two
/// source-of-truth files are frozen for the
/// card that asked for this, = so the
/// structure is read here rather than by a
/// third copy of the same reader.)
extension ImportDocumentTemplate {
    /// The mandatory items of a document in this template.
    ///
    /// Two shapes appear in a skeleton: a section the document
    /// body holds (= an `## ` line), and a separate file the
    /// folder must carry (= a `.md` the template declares under
    /// one of its sections). Both are mandatory, = so both are
    /// read.
    var mandatorySections: [ImportSOPSection] {
        var collected: [ImportSOPSection] = []
        var title = ""
        var documents: [String] = []
        for rawLine in skeleton.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("## ") {
                collected.append(contentsOf: sections(
                    under: title,
                    documents: documents
                ))
                title = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                documents = []
                continue
            }
            documents.append(contentsOf: documentsDeclared(in: line))
        }
        collected.append(contentsOf: sections(under: title, documents: documents))
        return collected
    }

    /// The mandatory items of a document in this template,
    /// rendered as the list a procedure text shows (= one item
    /// per line).
    var renderedMandatorySections: String {
        mandatorySections
            .map(\.rendered)
            .joined(separator: "\n")
    }

    /// The sections one skeleton section contributes.
    private func sections(
        under title: String,
        documents: [String]
    ) -> [ImportSOPSection] {
        guard !title.isEmpty else { return [] }
        if documents.isEmpty {
            return [.heading(title)]
        }
        return documents.map { .document($0) }
    }

    /// The `.md` files one skeleton line declares (= a
    /// markdown link whose target ends in `.md`).
    private func documentsDeclared(in line: String) -> [String] {
        let pattern = #"\]\(([^()\s]+\.md)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(line.startIndex..., in: line)
        return regex.matches(in: line, range: range).compactMap { match in
            guard let targetRange = Range(match.range(at: 1), in: line) else { return nil }
            return String(line[targetRange])
        }
    }
}

/// Bundle-side loader for SOP .md files.
/// Resolves the file via `Bundle.module`
/// (= SPM's per-target bundle for
/// `Sources/WenshuApp/Resources/`).
struct ImportSOPLoader {
    let bundle: Bundle

    init(bundle: Bundle = Bundle.module) {
        self.bundle = bundle
    }

    enum LoaderError: Error, LocalizedError {
        case fileMissing(name: String)
        case decodeFailed(name: String, underlying: String)

        var errorDescription: String? {
            switch self {
            case .fileMissing(let n):
                return "ImportSOPLoader: SOP file '\(n).md' is missing from the .app bundle (= the bundle step did not copy it; = check Package.swift `.process(\"Resources\")`)."
            case .decodeFailed(let n, let u):
                return "ImportSOPLoader: SOP file '\(n).md' decode failed: \(u)"
            }
        }
    }

    /// Read + decode the SOP .md file.
    /// Returns the raw text content (= no
    /// placeholder substitution yet = the
    /// caller calls `substitute(...)`).
    func loadRaw(named name: String) throws -> String {
        // SPM `.process("Resources")` flattens the SOPs/ subdir (= the .md lands at
        // `<spm-bundle>/Contents/Resources/<name>.md`, not at `<spm-
        // bundle>/Contents/Resources/SOPs/<name>.md`). Bundle selection: - In
        // production: pass
        // `Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Wenshu_WenshuApp.bundle")`
        // (= the SPM-generated bundle sitting next to the binary).
        // Alternatively, call sites should use the static
        // `ImportSOPLoader.production()` factory (= same logic). - In unit
        // tests: `Bundle.module` resolves to the test target's own
        // `WenshuAppTests.bundle`; the SPM resource bundle ships at the parent
        // directory (= use
        // `Bundle.module.bundleURL.deletingLastPathComponent()`).
        var triedPaths: [String] = []
        // Pass 1: subdirectory candidates in the resolved bundle (= covers direct
        // .process("Resources") where SOPs/ is preserved as a subdirectory).
        for sub in [nil, "SOPs", "Resources/SOPs"] {
            if let url = bundle.url(
                forResource: name,
                withExtension: "md",
                subdirectory: sub
            ) {
                do {
                    return try String(
                        contentsOf: url,
                        encoding: .utf8
                    )
                } catch {
                    throw LoaderError.decodeFailed(
                        name: name,
                        underlying: String(describing: error)
                    )
                }
            }
        }
        // Pass 2: the SPM-generated bundle (= `Wenshu_WenshuApp.bundle` for the WenshuApp
        // target; = `WenshuAppTests.bundle` for tests). Walk the parent
        // directory for any `*_*.bundle` that contains the file.
        let parentDir = bundle.bundleURL.deletingLastPathComponent()
        if let entries = try? FileManager.default.contentsOfDirectory(
            at: parentDir,
            includingPropertiesForKeys: nil
        ) {
            for entry in entries where entry.pathExtension == "bundle" {
                if let innerBundle = Bundle(url: entry),
                   let url = innerBundle.url(
                    forResource: name,
                    withExtension: "md",
                    subdirectory: nil
                   ) {
                    do {
                        return try String(
                            contentsOf: url,
                            encoding: .utf8
                        )
                    } catch {
                        throw LoaderError.decodeFailed(
                            name: name,
                            underlying: String(describing: error)
                        )
                    }
                }
            }
            triedPaths.append(contentsOf: entries.map { $0.path })
        }
        // Pass 3: look directly under the bundle's resource path (= e.g. test target's
        // resource dir has the SPM nested bundle in a flat subdir).
        let directSub = bundle.url(
            forResource: name,
            withExtension: "md",
            subdirectory: nil
        )
        if let url = directSub {
            do {
                return try String(
                    contentsOf: url,
                    encoding: .utf8
                )
            } catch {
                throw LoaderError.decodeFailed(
                    name: name,
                    underlying: String(describing: error)
                )
            }
        }
        throw LoaderError.fileMissing(
            name: "\(name) (tried: \(triedPaths))"
        )
    }

    /// Production factory (= used at
    /// runtime by ImportService). Walks
    /// `Bundle.main`'s resource dir for
    /// the SPM-generated nested bundle
    /// (= the same logic as the test
    /// path; = spelled out explicitly so
    /// production code does not depend on
    /// `Bundle.module`).
    static func production() throws -> ImportSOPLoader {
        // Try direct bundle main first (= the .app's top-level Resources/).
        let candidates: [Bundle] = {
            var result: [Bundle] = [.main]
            let mainResources = Bundle.main.resourceURL
            if let mainResources = mainResources {
                let spmBundle = mainResources
                    .appendingPathComponent("Wenshu_WenshuApp.bundle")
                if let b = Bundle(url: spmBundle) {
                    result.append(b)
                }
            }
            return result
        }()
        guard let chosen = candidates.first else {
            throw LoaderError.fileMissing(name: "no candidate bundle")
        }
        return ImportSOPLoader(bundle: chosen)
    }

    /// Substitute SOP placeholders with
    /// the actual values from the
    /// ImportSheet (= the orchestrator
    /// fills these in before the SOP is
    /// injected into the agent's turn
    /// context).
    ///
    /// Supported placeholders (= verbatim
    /// strings inside `{...}`):
    ///   - `{filePath}` → absolute path to
    ///     the source file (= A)
    ///   - `{body}` → the full text of A
    ///   - `{bookPath}` → absolute path to
    ///     the current book's directory
    ///     (= UUID-based filesystem root)
    ///   - `{bookTitle}` → the user's
    ///     book display title
    ///   - `{folderName}` → the target
    ///     folder's on-disk directory name
    ///     (= the procedure names its own
    ///     folder; = one body serves every
    ///     folder)
    ///   - `{sectionHeadings}` → the
    ///     mandatory sections of the target
    ///     folder's document template (= read
    ///     from the template at run time)
    ///   - `{today}` → ISO-8601 date
    ///     (= for the metadata footer in
    ///     the main INDEX)
    ///
    /// `folder` = the target folder (= the
    /// folder the procedure writes into; =
    /// its own name and its own mandatory
    /// sections fill the two folder-scoped
    /// slots).
    ///
    /// Unknown placeholders (= leave them
    /// in place; = caller's bug to fix;
    /// = do NOT silently drop the line).
    static func substitute(
        _ sop: String,
        filePath: String,
        body: String,
        bookPath: String,
        bookTitle: String,
        folder: BookFolder,
        today: String = ISO8601DateFormatter().string(from: Date())
    ) -> String {
        var s = sop
        s = s.replacingOccurrences(of: "{filePath}", with: filePath)
        s = s.replacingOccurrences(of: "{body}", with: body)
        s = s.replacingOccurrences(of: "{bookPath}", with: bookPath)
        s = s.replacingOccurrences(of: "{bookTitle}", with: bookTitle)
        s = s.replacingOccurrences(of: "{folderName}", with: folder.directoryName)
        s = s.replacingOccurrences(
            of: "{sectionHeadings}",
            with: ImportSOPTrigger.renderedSectionHeadings(for: folder)
        )
        s = s.replacingOccurrences(of: "{today}", with: today)
        return s
    }
}
