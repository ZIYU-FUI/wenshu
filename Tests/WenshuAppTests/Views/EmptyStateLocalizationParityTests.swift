import Foundation
import Testing
@testable import WenshuApp

@Suite("Empty-state localization parity")
struct EmptyStateLocalizationParityTests {
    private static let catalogKeys = [
        "preview.empty.scope_hint",
        "preview.empty.shelf_no_books",
        "preview.empty_state.book_with_folder",
        "preview.empty_state.book_no_folder",
        "preview.empty_state.category_empty",
        "preview.empty_state.pick_book",
        "preview.empty_state.reference_empty",
        "preview.empty_state.shelf_empty",
        "preview.empty.import_hint",
        "preview.empty.pick_book",
    ]

    @Test("all preview empty-state keys exist in both locales")
    func allPreviewEmptyStateKeysExist() throws {
        for language in ["en", "zh-Hans"] {
            let catalog = try Self.catalog(language: language)
            for key in Self.catalogKeys {
                #expect(catalog[key]?.isEmpty == false, "\(language) catalog must define \(key)")
            }
        }
    }

    @Test("Chinese preview empty-state copy contains no raw keys")
    func chinesePreviewEmptyStateCopyContainsNoRawKeys() throws {
        let catalog = try Self.catalog(language: "zh-Hans")
        for key in Self.catalogKeys {
            let value = try #require(catalog[key])
            #expect(value != key)
            #expect(!value.contains("preview."))
        }
    }

    private static func catalog(language: String) throws -> [String: String] {
        let url = try repositoryURL(
            relativePath: "Sources/WenshuApp/Resources/\(language).lproj/Localizable.strings"
        )
        let object = try PropertyListSerialization.propertyList(
            from: Data(contentsOf: url),
            options: [],
            format: nil
        )
        return try #require(object as? [String: String])
    }

    private static func repositoryURL(relativePath: String) throws -> URL {
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
