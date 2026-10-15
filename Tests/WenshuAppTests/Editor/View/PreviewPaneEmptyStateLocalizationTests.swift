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
            let catalogURL = try Self.catalogURL(language: language)
            let catalog = try PropertyListSerialization.propertyList(
                from: Data(contentsOf: catalogURL),
                options: [],
                format: nil
            ) as? [String: String]

            for key in keys {
                #expect(catalog?[key]?.isEmpty == false, "\(language) catalog must define \(key)")
            }
        }
    }

    @Test("Chinese preview empty-state values are user-facing copy")
    func chinesePreviewEmptyStateValues() throws {
        let catalogURL = try Self.catalogURL(language: "zh-Hans")
        let catalog = try PropertyListSerialization.propertyList(
            from: Data(contentsOf: catalogURL),
            options: [],
            format: nil
        ) as? [String: String]

        #expect(catalog?["preview.empty_state.book_with_folder"] == "这里还没有内容")
        #expect(catalog?["preview.empty_state.book_no_folder"] == "这本书还没有文档")
        #expect(catalog?["preview.empty.pick_book"] == "从左侧选择一个分类，或添加一个文档。")
    }

    @Test("PreviewPane uses localized reference empty state")
    func previewPaneUsesLocalizedReferenceEmptyState() throws {
        let sourceURL = try Self.catalogURL(
            relativePath: "Sources/WenshuApp/Views/Workspace/PreviewPane.swift"
        )
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("titleKey: \"preview.empty_state.reference_empty\""))
        #expect(source.contains("bodyKey: \"preview.empty.import_hint\""))
    }

    private static func catalogURL(language: String) throws -> URL {
        try Self.catalogURL(relativePath: "Sources/WenshuApp/Resources/\(language).lproj/Localizable.strings")
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
