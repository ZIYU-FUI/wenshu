import Foundation
import Testing
import UniformTypeIdentifiers
@testable import WenshuApp

@Suite("Library onboarding workspace importer")
struct LibraryOnboardingWorkspaceImporterTests {
    private static func repositoryURL(relativePath: String) -> URL {
        var current = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while current.path != "/" {
            if FileManager.default.fileExists(
                atPath: current.appendingPathComponent("Package.swift").path
            ) {
                return current.appendingPathComponent(relativePath)
            }
            current.deleteLastPathComponent()
        }
        preconditionFailure("Wenshu repository root not found")
    }

    private static let libraryRootSourcePath = Self.repositoryURL(
        relativePath: "Sources/WenshuApp/Views/Onboarding/LibraryRootView.swift"
    )

    @Test("importer accepts the exported Wenshu workspace type")
    func importerAcceptsWorkspaceType() throws {
        let source = try String(contentsOf: Self.libraryRootSourcePath, encoding: .utf8)

        #expect(source.contains("allowedContentTypes: [UTType(exportedAs: \"com.wenshu.workspace\")]"))
        #expect(!source.contains("allowedContentTypes: [UTType.folder]"))
    }

    private static let foreshadowingGraphSourcePath = Self.repositoryURL(
        relativePath: "Sources/WenshuApp/Views/Windows/ForeshadowingGraphWindow.swift"
    )

    @Test("foreshadowing graph window constructs its own BookStore")
    func foreshadowingGraphConstructsOwnBookStore() throws {
        let source = try String(contentsOf: Self.foreshadowingGraphSourcePath, encoding: .utf8)

        #expect(source.contains("@State private var bookStore: BookStore?"))
        #expect(source.contains("LibraryLifecycleHook(wsRoot: wsRoot).runLaunch()"))
        #expect(!source.contains("@Environment(BookStore.self)"))
    }

    @Test("selection updates observable route after bookmark persistence")
    func selectionUpdatesObservableRoute() throws {
        let source = try String(contentsOf: Self.libraryRootSourcePath, encoding: .utf8)

        #expect(source.contains("@State private var activeLibrarySelection: String?"))
        #expect(source.contains("activeLibrarySelection ?? ActiveLibrary.path"))
        #expect(source.contains("activeLibrarySelection = url.path"))
    }

    @Test("exported workspace type is registered as a custom package")
    func workspaceTypeIsCustomPackage() throws {
        let infoPlistURL = Self.repositoryURL(
            relativePath: "Sources/WenshuApp/Resources/Info.plist"
        )
        let data = try Data(contentsOf: infoPlistURL)
        var format = PropertyListSerialization.PropertyListFormat.xml
        let plistObject = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: &format
        )
        let plist = plistObject as? [String: Any]
        let declarations = plist?["UTExportedTypeDeclarations"] as? [[String: Any]]
        let workspace = declarations?.first {
            ($0["UTTypeIdentifier"] as? String) == "com.wenshu.workspace"
        }

        #expect(workspace != nil)
        #expect(workspace?["UTTypeConformsTo"] as? [String] == ["com.apple.package"])
        #expect((workspace?["UTTypeTagSpecification"] as? [String: Any])?["public.filename-extension"] as? [String] == ["ws"])
    }
}
