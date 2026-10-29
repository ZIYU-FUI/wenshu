import Foundation
import Testing

/// The deployment floor and the SDK stamp are two different facts about the
/// same binary, and only the floor belongs in `Package.swift`.
///
/// SwiftPM derives `LC_BUILD_VERSION` from the platform declaration, so the
/// product used to carry `minos 18.0 / sdk 18.0` while it was compiled
/// against the iOS 27.1 SDK. A binary whose stamp names an older SDK than
/// the system it runs on is drawn as a legacy binary and scaled into a
/// phone-sized window, so the client loses the adaptive layout it is
/// written for. The linker stamp fixes that without moving the floor
/// (ADR-0002): the floor stays 18.0, the SDK names the SDK the build used.
///
/// The proof reads the BUILT product's load command. A test that asserted on
/// the text of `Package.swift` would keep passing while the stamp stayed
/// wrong, because the stamp is written by the linker, not by the manifest.
@Suite("DeploymentFloorTests")
struct DeploymentFloorTests {
    @Test func theProductCarriesTheDeploymentFloorAndTheSDKItCompiledAgainst() throws {
        let product = try Self.builtProduct()
        let versions = try Self.buildVersions(of: product)

        #expect(
            !versions.isEmpty,
            "No LC_BUILD_VERSION found in \(product.path)"
        )

        for version in versions {
            #expect(
                version.minimumOS == "18.0",
                "The deployment floor is iOS 18 (ADR-0002), the product says \(version.minimumOS)"
            )
            #expect(
                version.sdk != "18.0",
                "The SDK stamp must name the SDK the build used, not the floor: \(version.sdk)"
            )
        }
    }

    // MARK: - The built product

    /// The product the simulator build produces. The path follows the build
    /// settings of the repository, so a change to the derived data path has
    /// to change here too; `WENSHU_MOBILE_DERIVED_DATA` moves it without a
    /// code change.
    private static let derivedDataPath = ProcessInfo.processInfo
        .environment["WENSHU_MOBILE_DERIVED_DATA"] ?? "/tmp/wenshu-mobile-dd"

    private static func builtProduct() throws -> URL {
        let url = URL(
            fileURLWithPath: derivedDataPath
                + "/Build/Products/Debug-iphonesimulator/WenshuMobileApp"
        )

        try #require(
            FileManager.default.fileExists(atPath: url.path),
            """
            The built product is missing at \(url.path). Build it first: \
            xcodebuild -scheme WenshuMobile-Package \
            -destination 'generic/platform=iOS Simulator' \
            -derivedDataPath \(derivedDataPath) build
            """
        )

        return url
    }

    // MARK: - The load command

    /// One `LC_BUILD_VERSION` of one architecture of the product.
    struct BuildVersion {
        let minimumOS: String
        let sdk: String
    }

    /// `vtool -show-build` prints one load command per architecture, each
    /// with its own `minos` and `sdk` line. A fat product therefore has one
    /// of these per slice, and every slice carries the same stamp.
    private static func buildVersions(of product: URL) throws -> [BuildVersion] {
        let output = try run(
            URL(fileURLWithPath: "/usr/bin/xcrun"),
            arguments: ["vtool", "-show-build", product.path]
        )

        try #require(
            !output.isEmpty,
            "vtool printed nothing for \(product.path)"
        )

        var versions: [BuildVersion] = []
        var minimumOS: String?
        var sdk: String?

        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("minos ") {
                // A second `minos` line means a new architecture starts here.
                if let previousMinimum = minimumOS, let previousSDK = sdk {
                    versions.append(
                        BuildVersion(minimumOS: previousMinimum, sdk: previousSDK)
                    )
                }
                minimumOS = String(trimmed.dropFirst("minos ".count))
                sdk = nil
            } else if trimmed.hasPrefix("sdk ") {
                sdk = String(trimmed.dropFirst("sdk ".count))
            }
        }

        if let lastMinimum = minimumOS, let lastSDK = sdk {
            versions.append(BuildVersion(minimumOS: lastMinimum, sdk: lastSDK))
        }

        return versions
    }

    private static func run(_ executable: URL, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments

        // One pipe for both streams: a failing vtool has to show why.
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output

        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let text = String(decoding: data, as: UTF8.self)

        try #require(
            process.terminationStatus == 0,
            "\(executable.path) \(arguments.joined(separator: " ")) failed: \(text)"
        )

        return text
    }
}
