//
//  ImportSOPLoaderTests.swift · wenshu · round-73 (= boss 2026-10-10)
//
//  Unit tests for the SOP loader. The
//  test covers:
//
//    1. `sopName(for:)` trigger lookup
//    2. `loadRaw(named:)` from a real
//       bundle (= the .md file compiled in
//       via `.process("Resources")`)
//    3. `substitute(...)` placeholder
//       substitution
//
//  The test is intentionally hermetic:
//  no LLM, no actor, no async. Pure
//  synchronous lookup + string ops.
//

import XCTest
import Foundation
@testable import WenshuApp

final class ImportSOPLoaderTests: XCTestCase {

    // MARK: - sopName(for:) lookup

    func testSopNameForWorldReturnsImportWorldPrompt() {
        XCTAssertEqual(
            ImportSOPTrigger.sopName(for: .world),
            "ImportWorldPrompt"
        )
    }

    func testSopNameForEveryFolderWithAnImportTemplateReturnsItsProcedure() {
        // Every folder that declares an import template owns a
        // procedure file (= the six import folders; = the sheet
        // lets the user pick all six).
        XCTAssertEqual(
            ImportSOPTrigger.sopName(for: .characters),
            "ImportCharactersPrompt"
        )
        XCTAssertEqual(
            ImportSOPTrigger.sopName(for: .outlines),
            "ImportOutlinesPrompt"
        )
        XCTAssertEqual(
            ImportSOPTrigger.sopName(for: .chapters),
            "ImportChaptersPrompt"
        )
        XCTAssertEqual(
            ImportSOPTrigger.sopName(for: .drafts),
            "ImportDraftsPrompt"
        )
        XCTAssertEqual(
            ImportSOPTrigger.sopName(for: .ideas),
            "ImportIdeasPrompt"
        )
    }

    func testSopNameResolvesEveryFolderThatDeclaresAnImportTemplate() {
        // The lookup runs over the folder's own import-template
        // property (= the declared set of folders that own a
        // procedure); = so a template without a procedure file
        // shows up here instead of at runtime.
        for folder in BookFolder.allCases where folder.importTemplate != nil {
            XCTAssertNotNil(
                ImportSOPTrigger.sopName(for: folder),
                "Folder '\(folder.rawValue)' declares an import template, = so it needs a procedure."
            )
        }
    }

    func testSopNameForFolderWithoutImportTemplateReturnsNil() {
        // A folder with no import template has no document shape
        // to write (= sessions / foreshadowing / placeholders), = so
        // it has no procedure.
        XCTAssertNil(ImportSOPTrigger.sopName(for: .sessions))
        XCTAssertNil(ImportSOPTrigger.sopName(for: .foreshadowing))
        XCTAssertNil(ImportSOPTrigger.sopName(for: .placeholders))
    }

    // MARK: - loadRaw(named:) — needs the real bundle

    func testLoadRawReturnsSOPText() throws {
        // The .md file shipped via
        // `.process("Resources")` in
        // Package.swift should be
        // resolvable from `Bundle.module`.
        // Debug: print the bundle URL.
        let debugBundle = Bundle.module
        NSLog("[test] Bundle.module path = %@", debugBundle.bundlePath)
        for url in debugBundle.urls(forResourcesWithExtension: "md", subdirectory: nil) ?? [] {
            NSLog("[test] found md at: %@", url.lastPathComponent)
        }
        let loader = ImportSOPLoader(bundle: Bundle.module)
        let text = try loader.loadRaw(named: "ImportWorldPrompt")
        XCTAssertGreaterThan(
            text.count, 100,
            "ImportWorldPrompt.md should be a real SOP (= > 100 chars), not a stub."
        )
        // Sanity-check key SOP content
        // (= the SOP actually tells the
        // agent about 6 必填).
        XCTAssertTrue(text.contains("核心设定"))
        XCTAssertTrue(text.contains("地理或位置"))
        XCTAssertTrue(text.contains("体系或规则"))
        XCTAssertTrue(text.contains("历史脉络"))
        XCTAssertTrue(text.contains("与其他元素的关系"))
        XCTAssertTrue(text.contains("关键场景种子"))
    }

    func testLoadRawMissingFileThrows() {
        let loader = ImportSOPLoader(bundle: Bundle.module)
        XCTAssertThrowsError(
            try loader.loadRaw(named: "ImportDefinitelyDoesNotExist")
        ) { error in
            // The error must be the
            // `fileMissing` case (= not a
            // generic Swift error).
            guard let loaderError = error as? ImportSOPLoader.LoaderError else {
                XCTFail("Expected ImportSOPLoader.LoaderError, got \(error)")
                return
            }
            switch loaderError {
            case .fileMissing:
                break // expected
            default:
                XCTFail("Expected .fileMissing, got \(loaderError)")
            }
        }
    }

    // MARK: - substitute(...) — placeholder replacement

    func testSubstituteReplacesAllPlaceholders() {
        let input = """
        path: {filePath}
        body len: {body}
        book: {bookTitle}
        bookPath: {bookPath}
        date: {today}
        """

        let out = ImportSOPLoader.substitute(
            input,
            filePath: "/tmp/a.md",
            body: "hello world content here",
            bookPath: "/ws/twelve-immortals",
            bookTitle: "twelve-immortals",
            folder: .world
        )

        XCTAssertTrue(out.contains("/tmp/a.md"))
        XCTAssertTrue(out.contains("hello world content here"))
        XCTAssertTrue(out.contains("/ws/twelve-immortals"))
        XCTAssertTrue(out.contains("twelve-immortals"))
        // today should be filled with a
        // non-empty ISO-8601 date string.
        XCTAssertFalse(out.contains("{today}"))
        // None of the original
        // placeholders remain.
        XCTAssertFalse(out.contains("{filePath}"))
        XCTAssertFalse(out.contains("{body}"))
        XCTAssertFalse(out.contains("{bookPath}"))
        XCTAssertFalse(out.contains("{bookTitle}"))
    }

    func testSubstituteLeavesUnknownPlaceholdersIntact() {
        let input = "known: {filePath}, unknown: {mystery}"
        let out = ImportSOPLoader.substitute(
            input,
            filePath: "/tmp/a.md",
            body: "x",
            bookPath: "/ws",
            bookTitle: "T",
            folder: .world
        )
        XCTAssertTrue(out.contains("known: /tmp/a.md"))
        XCTAssertTrue(
            out.contains("{mystery}"),
            "Unknown placeholders must be left intact (= caller's bug; = SOP loader does NOT silently drop)."
        )
    }

    func testSubstitutePreservesRealBracesInBodyContent() {
        // Body content may legitimately
        // contain `{...}` (= e.g.
        // template syntax, code, JSON).
        // The loader must replace ONLY the
        // known placeholders; = not the
        // literal `{` characters in the
        // body.
        let body = "JSON snippet: {\"key\": \"value\"}"
        let out = ImportSOPLoader.substitute(
            "{body}",
            filePath: "/x",
            body: body,
            bookPath: "/y",
            bookTitle: "z",
            folder: .world
        )
        XCTAssertEqual(out, body)
    }

    // MARK: - substitute(...) — the folder's own name + sections

    func testSubstituteFillsTheTargetFolderNameAndItsMandatorySections() {
        // The procedure names its own folder and carries the
        // folder's mandatory sections (= read from the folder's
        // document template at run time; = the procedure file
        // itself never spells them out).
        for folder in BookFolder.allCases where folder.importTemplate != nil {
            let input = "folder: {folderName}\nsections:\n{sectionHeadings}"
            let out = ImportSOPLoader.substitute(
                input,
                filePath: "/tmp/a.md",
                body: "body",
                bookPath: "/ws",
                bookTitle: "T",
                folder: folder
            )
            XCTAssertTrue(
                out.contains(folder.directoryName),
                "The procedure must name the target folder '\(folder.directoryName)'."
            )
            let sections = ImportSOPTrigger.mandatorySections(for: folder)
            XCTAssertFalse(
                sections.isEmpty,
                "Folder '\(folder.rawValue)' declares an import template, = so it has mandatory sections."
            )
            for section in sections {
                XCTAssertTrue(
                    out.contains(section.title),
                    "The procedure must carry the mandatory section '\(section.title)' of folder '\(folder.rawValue)'."
                )
            }
            XCTAssertFalse(out.contains("{folderName}"))
            XCTAssertFalse(out.contains("{sectionHeadings}"))
        }
    }

    func testMandatorySectionsComeFromTheFolderTemplate() {
        // The sections are the template's own (= the template owns
        // the skeleton; = a template change reaches the procedure
        // without editing the procedure).
        for folder in BookFolder.allCases where folder.importTemplate != nil {
            let sections = ImportSOPTrigger.mandatorySections(for: folder)
            XCTAssertFalse(sections.isEmpty)
            for section in sections {
                XCTAssertTrue(
                    folder.importTemplate?.skeleton.contains(section.title) ?? false,
                    "Section '\(section.title)' must come from the folder's template."
                )
            }
        }
    }

    // MARK: - The procedure files themselves

    func testEveryProcedureFileCarriesItsFolderMandatorySections() throws {
        // One procedure file per folder that has an import
        // template (= the file ships in the bundle via
        // `.process("Resources")`); = after substitution the
        // procedure text carries that folder's own mandatory
        // sections (= read from the folder's template at run
        // time; = the procedure file itself never spells them
        // out).
        for folder in BookFolder.allCases where folder.importTemplate != nil {
            guard let sopName = ImportSOPTrigger.sopName(for: folder) else {
                XCTFail("Folder '\(folder.rawValue)' has an import template but no procedure name.")
                continue
            }
            let raw = try ImportSOPLoader(bundle: Bundle.module)
                .loadRaw(named: sopName)
            let out = ImportSOPLoader.substitute(
                raw,
                filePath: "/tmp/a.md",
                body: "body",
                bookPath: "/ws",
                bookTitle: "T",
                folder: folder
            )
            for section in ImportSOPTrigger.mandatorySections(for: folder) {
                XCTAssertTrue(
                    out.contains(section.title),
                    "The procedure for '\(folder.rawValue)' must carry the mandatory section '\(section.title)'."
                )
            }
            // The folder-scoped slots are filled in (= no marker
            // survives the substitution). The world procedure is
            // frozen and has no such slot, = so it carries none
            // either.
            XCTAssertFalse(
                out.contains("{folderName}"),
                "The procedure for '\(folder.rawValue)' still carries an unresolved folder slot."
            )
            XCTAssertFalse(
                out.contains("{sectionHeadings}"),
                "The procedure for '\(folder.rawValue)' still carries an unresolved section slot."
            )
        }
    }

    func testNewProcedureFilesCarryNoChineseCharacters() throws {
        // The five new procedure files are English-only (= this
        // project's rule: every tracked file and every prompt
        // carries no Chinese characters). The world procedure is
        // the one file of its kind that predates that rule, = so
        // it is not checked here.
        let newProcedures = [
            "ImportCharactersPrompt",
            "ImportOutlinesPrompt",
            "ImportChaptersPrompt",
            "ImportDraftsPrompt",
            "ImportIdeasPrompt"
        ]
        for name in newProcedures {
            let text = try ImportSOPLoader(bundle: Bundle.module)
                .loadRaw(named: name)
            let chinese = text.unicodeScalars.filter { scalar in
                (0x4E00...0x9FFF).contains(scalar.value)
                    || (0x3000...0x303F).contains(scalar.value)
                    || (0xFF00...0xFFEF).contains(scalar.value)
            }
            XCTAssertTrue(
                chinese.isEmpty,
                "The procedure file '\(name).md' must be English-only, = but it carries \(chinese.count) Chinese characters."
            )
        }
    }
}