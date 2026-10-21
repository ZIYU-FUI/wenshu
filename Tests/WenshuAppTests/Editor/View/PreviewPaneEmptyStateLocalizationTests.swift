import Foundation
import Testing
@testable import WenshuApp

@Suite("Preview pane empty-state localization")
struct PreviewPaneEmptyStateLocalizationTests {
    @Test("preview empty-state keys resolve in both supported locales")
    func previewEmptyStateKeysResolve() throws {
        let keys = [
            "preview.empty_state.book_with_folder",
            "preview.empty_state.book_no_folder",
            "preview.empty.pick_book",
        ]

        for language in ["en", "zh-Hans"] {
            let catalog = StringCatalogReader.strings(language: language)
            for key in keys {
                #expect(catalog[key]?.isEmpty == false, "\(language) catalog must define \(key)")
            }
        }
    }

    @Test("Chinese preview empty-state values are user-facing copy")
    func chinesePreviewEmptyStateValues() throws {
        let catalog = StringCatalogReader.strings(language: "zh-Hans")

        #expect(catalog["preview.empty_state.book_with_folder"] == "这里还没有内容")
        #expect(catalog["preview.empty_state.book_no_folder"] == "这本书还没有文档")
        #expect(catalog["preview.empty.pick_book"] == "从左侧选择一个分类，或添加一个文档。")
    }

    @Test("PreviewPane uses localized reference empty state")
    func previewPaneUsesLocalizedReferenceEmptyState() throws {
        // The empty-state calls live in the `extension PreviewPane`
        // grid helpers (= PreviewPaneGrids.swift), not in
        // PreviewPane.swift itself. The A79 god-class split
        // (7c445f3fb) moved the 6 grid view helpers out, and this
        // assertion was not repointed at the new home (= it has
        // been red since that split).
        let sourceURL = try Self.catalogURL(
            relativePath: "Sources/WenshuApp/Features/Editor/View/PreviewPaneGrids.swift"
        )
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("titleKey: \"preview.empty_state.reference_empty\""))
        #expect(source.contains("bodyKey: \"preview.empty.import_hint\""))
    }


    private static func catalogURL(relativePath: String) throws -> URL {
        var current = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while current.path != "/" {
            if FileManager.default.fileExists(
                atPath: current.appendingPathComponent("Package.swift").path
            ) {
                return current.appendingPathComponent(relativePath)
            }
            current.deleteLastPathComponent()
        }
        throw CocoaError(.fileNoSuchFile)
    }
}
