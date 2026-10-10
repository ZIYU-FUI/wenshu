//
//  ImportSOPLoader.swift · wenshu · round-73 (= boss 2026-10-10)
//
//  v2.7 round-73 (= boss 2026-10-10 "类似
//  一个技能, 导入文件按文枢规则拆解后
//  重新落库" + "我建议你导入世界观就
//  单独的一个提示词文件, 别和导入其
//  他的通用" + "无论哪本书, 只要是
//  选择了目标为世界观, 就适合当前的
//  这个 SOP" + "用户不可见").
//
//  ImportSOPLoader = the lookup + loader
//  for the SOP prompt files. Lives in
//  Services (= data-layer concern) so
//  ImportService (= caller) does the
//  lookup, not ImportAgentDriver (= agent-
//  side concern).
//
//  Two responsibilities:
//
//    1. `sopName(for folder:)` = the
//       per-folder SOP lookup (= the
//       trigger logic). Currently only
//       `.world` has a SOP file; = other
//       folders return `nil` (= future
//       work; = the orchestrator will
//       fall through to legacy multi-call
//       router if no SOP matches; = the
//       SOP coverage matrix grows with
//       each per-folder SOP file landed
//       in `Resources/SOPs/`).
//
//    2. `load(named:)` = read the SOP
//       .md file from the .app bundle (=
//       via `Bundle.module.url(forResource:)`);
//       = does placeholder substitution
//       for the SOP's `{filePath}`, `{body}`,
//       `{bookPath}`, `{bookTitle}` slots.
//
//  Bundle lookup uses `Bundle.module`
//  (= SPM's per-target bundle for the
//  WenshuApp target's Resources/). The
//  .md file is shipped via
//  `.process("Resources")` in Package.swift.
//
//  Not user-visible: SOP files compile into
//  the .app (= git tracked; = wenshu-
//  engineer maintained; = the user
//  cannot change them at runtime).
//

import Foundation

/// Lookup table for per-folder SOPs (= the
/// wenshu 文档管理员 view). One folder
/// → at most one SOP file. The mapping
/// is fixed (= wenshu-engineer
/// maintained; = not user-editable).
///
/// Trigger rule (= boss 2026-10-10):
/// `folder == .world` → `ImportWorldPrompt.md`.
/// Other folders → no SOP yet (= future
/// per-folder SOPs will be added the
/// same way).
enum ImportSOPTrigger {
    /// Map a target BookFolder to the
    /// SOP file name (= no extension).
    /// Returns `nil` if no SOP is defined
    /// for this folder (= the
    /// orchestrator decides what to do
    /// = e.g. fall through to legacy
    /// path).
    static func sopName(for folder: BookFolder) -> String? {
        switch folder {
        case .world:
            return "ImportWorldPrompt"
        // Per boss 2026-10-10 "我建议你
        // 导入世界观就单独的一个提示词
        // 文件, 别和导入其他的通用,
        // 有可能其他的有其他规则":
        // = each folder may eventually
        // get its own SOP file (= a
        // future round adds
        // ImportCharacterPrompt /
        // ImportOutlinePrompt / etc.).
        // For now, only world is
        // covered.
        default:
            return nil
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
                return "ImportSOPLoader: SOP file '\(n).md' is missing from the .app bundle (= build-wenshu.sh did not copy it; = check Package.swift `.process(\"Resources\")`)."
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
        // SPM `.process("Resources")`
        // flattens the SOPs/ subdir (= the
        // .md lands at
        // `<spm-bundle>/Contents/Resources/<name>.md`,
        // not at `<spm-bundle>/Contents/Resources/SOPs/<name>.md`).
        //
        // Bundle selection:
        // - In production: pass
        //   `Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Wenshu_WenshuApp.bundle")`
        //   (= the SPM-generated bundle
        //   sitting next to the binary).
        //   Alternatively, call sites
        //   should use the static
        //   `ImportSOPLoader.production()`
        //   factory (= same logic).
        // - In unit tests: `Bundle.module`
        //   resolves to the test target's
        //   own `WenshuAppTests.bundle`;
        //   the SPM resource bundle ships
        //   at the parent directory (= use
        //   `Bundle.module.bundleURL.deletingLastPathComponent()`).
        var triedPaths: [String] = []
        // Pass 1: subdirectory candidates
        // in the resolved bundle (= covers
        // direct .process("Resources")
        // where SOPs/ is preserved as a
        // subdirectory).
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
        // Pass 2: the SPM-generated bundle
        // (= `Wenshu_WenshuApp.bundle` for
        // the WenshuApp target; =
        // `WenshuAppTests.bundle` for
        // tests). Walk the parent directory
        // for any `*_*.bundle` that
        // contains the file.
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
        // Pass 3: look directly under the
        // bundle's resource path (= e.g.
        // test target's resource dir has
        // the SPM nested bundle in a flat
        // subdir).
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
        // Try direct bundle main first (= the
        // .app's top-level Resources/).
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
    ///   - `{today}` → ISO-8601 date
    ///     (= for the metadata footer in
    ///     the main INDEX)
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
        today: String = ISO8601DateFormatter().string(from: Date())
    ) -> String {
        var s = sop
        s = s.replacingOccurrences(of: "{filePath}", with: filePath)
        s = s.replacingOccurrences(of: "{body}", with: body)
        s = s.replacingOccurrences(of: "{bookPath}", with: bookPath)
        s = s.replacingOccurrences(of: "{bookTitle}", with: bookTitle)
        s = s.replacingOccurrences(of: "{today}", with: today)
        return s
    }
}