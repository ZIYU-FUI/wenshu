import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
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
        relativePath: "Sources/WenshuApp/Shared/UI/LibraryRootView.swift"
    )

    @Test("importer accepts the exported Wenshu workspace type")
    func importerAcceptsWorkspaceType() throws {
        let source = try String(contentsOf: Self.libraryRootSourcePath, encoding: .utf8)

        #expect(source.contains("allowedContentTypes: [UTType(exportedAs: \"com.wenshu.workspace\")]"))
        #expect(!source.contains("allowedContentTypes: [UTType.folder]"))
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

    /// The welcome page's calligraphy is the white artwork in the dark
    /// theme and the gold one in the light theme (= a white brush
    /// stroke on the cream window reads as a watermark, not as the
    /// product's name). The choice follows the scheme the page renders
    /// in, so the system scheme counts when the setting follows the
    /// system.
    @Test("the welcome page's wordmark follows the effective color scheme")
    func welcomeWordmarkFollowsEffectiveColorScheme() throws {
        #expect(WenshuWordmark.assetName(for: .dark) == WenshuWordmark.whiteAssetName)
        #expect(WenshuWordmark.assetName(for: .dark) == "wenshu-original-fanbai")
        #expect(WenshuWordmark.assetName(for: .light) == WenshuWordmark.goldAssetName)
        #expect(WenshuWordmark.assetName(for: .light) == "wenshu-gold-v3-warm")

        // The picked artwork must exist in the bundle's asset folder,
        // otherwise the page falls back to the SF Symbol and the theme
        // choice is a no-op.
        let assetsFolder = Self.repositoryURL(
            relativePath: "Sources/WenshuApp/Resources/AppIcon.icon/Assets"
        )
        for assetName in [WenshuWordmark.whiteAssetName, WenshuWordmark.goldAssetName] {
            let artwork = assetsFolder.appendingPathComponent("\(assetName).png")
            #expect(
                FileManager.default.fileExists(atPath: artwork.path),
                "\(assetName).png must ship in the bundle's asset folder"
            )
        }

        // Both artworks are the same calligraphy on the same canvas
        // (= the gold one drops in beside the white one with no size
        // work), and each one is the colour it claims: the white one
        // is neutral, the gold one is warm.
        for assetName in [WenshuWordmark.whiteAssetName, WenshuWordmark.goldAssetName] {
            let artwork = assetsFolder.appendingPathComponent("\(assetName).png")
            let artworkImage = try Self.decodedImage(at: artwork)
            let image = artworkImage.image
            #expect(image.width == 1280, "\(assetName).png must be 1280 wide")
            #expect(image.height == 1920, "\(assetName).png must be 1920 tall")
            #expect(artworkImage.hasAlpha, "\(assetName).png must carry an alpha channel")

            let mean = try Self.meanOpaqueRGB(of: image)
            if assetName == WenshuWordmark.goldAssetName {
                #expect(mean.red > mean.green, "the gold artwork's red must lead its green")
                #expect(mean.green > mean.blue, "the gold artwork's green must lead its blue")
                #expect(mean.blue < mean.red / 2, "the gold artwork must read as gold, not as white")
            } else {
                #expect(
                    max(mean.red, mean.green, mean.blue) - min(mean.red, mean.green, mean.blue) < 30,
                    "the white artwork must read as neutral"
                )
            }
        }

        // The scheme reaches the wordmark, and the toolbar rides on the
        // library pages only (= the welcome page has no library, so the
        // kanban and export buttons have nothing to act on).
        let source = try String(contentsOf: Self.libraryRootSourcePath, encoding: .utf8)
        #expect(source.contains("@Environment(\\.colorScheme) private var colorScheme"))
        #expect(source.contains("loadWenshuLogo(named: WenshuWordmark.assetName(for: colorScheme))"))
        #expect(source.contains("if isOnboarding {"))
        #expect(source.contains("content.toolbar {"))
        #expect(
            source.components(separatedBy: ".toolbar {").count == 2,
            "the toolbar must be attached in exactly one place (= inside the onboarding-aware modifier)"
        )
        #expect(
            source.components(separatedBy: "ChromeMainToolbar(openWindow: openWindow, sheetRequests: sheetRequests)").count == 2,
            "the library toolbar must be attached once (= inside the onboarding-aware modifier)"
        )
    }

    /// The PNG at `url`, decoded through ImageIO (= the same reader the
    /// boss measured the artwork with), plus the file's own alpha flag.
    private static func decodedImage(at url: URL) throws -> (image: CGImage, hasAlpha: Bool) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let hasAlpha = (properties?[kCGImagePropertyHasAlpha] as? Bool) ?? false
        return (image, hasAlpha)
    }

    /// The mean colour of the opaque pixels of `image` (= the alpha
    /// channel is read, so the transparent canvas does not weigh in).
    private static func meanOpaqueRGB(of image: CGImage) throws -> (red: Double, green: Double, blue: Double) {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var red = 0.0
        var green = 0.0
        var blue = 0.0
        var count = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = pixels[index + 3]
            guard alpha >= 250 else { continue }
            red += Double(pixels[index])
            green += Double(pixels[index + 1])
            blue += Double(pixels[index + 2])
            count += 1
        }
        guard count > 0 else { throw CocoaError(.fileReadCorruptFile) }
        return (red / count, green / count, blue / count)
    }
}
