//
//  VisionToolsTests.swift · Wenshu · v0.18 ticket 10 (vision tools)
//
// test VisionTools. errorpath (load), Vision (sandbox).
//

import Testing
import Foundation
import AppKit
@testable import WenshuApp

@Suite("VisionTools (hermes replica)")
struct VisionToolsTests {
    /// Writes a real PNG to a temporary file and hands back its path.
    ///
    /// The file lives in the temporary directory, not in the working
    /// directory: `NSImage(contentsOfFile:)` on a path inside the
    /// checkout root does a blocking metadata query, which under load
    /// can block a test run for minutes.
    private func writePNG(size: NSSize, text: String? = nil) throws -> String {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        if let text {
            NSColor.black.setFill()
            (text as NSString).draw(
                at: NSPoint(x: 12, y: size.height / 2 - 22),
                withAttributes: [
                    .font: NSFont.systemFont(ofSize: 36),
                    .foregroundColor: NSColor.black
                ]
            )
        }
        image.unlockFocus()
        var rect = CGRect(origin: .zero, size: size)
        let cgImage = try #require(image.cgImage(forProposedRect: &rect, context: nil, hints: nil))
        let rep = NSBitmapImageRep(cgImage: cgImage)
        let data = try #require(rep.representation(using: .png, properties: [:]))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wenshu-vision-\(UUID().uuidString).png")
        try data.write(to: url)
        return url.path
    }

    @Test("recognizeText 无效图片抛错")
    func testRecognizeTextInvalidImage() async {
        let tools = VisionTools()
        await #expect(throws: (any Error).self) {
            _ = try await tools.recognizeText(imagePath: "/nonexistent/path.png")
        }
    }

    @Test("classify 无效图片抛错")
    func testClassifyInvalidImage() async {
        let tools = VisionTools()
        await #expect(throws: (any Error).self) {
            _ = try await tools.classify(imagePath: "/nonexistent/path.png")
        }
    }

    @Test("recognizeText 文本文件不抛 throw 而是 imageLoadFailed")
    func testRecognizeTextTextFile() async {
        // fileyes → yes imageLoadFailed
        let tools = VisionTools()
        let textPath = SourceLocator.repoRoot
            .appendingPathComponent(".test-vision-\(UUID().uuidString.prefix(8)).txt").path
        try? "not an image".write(toFile: textPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: textPath) }
        await #expect(throws: (any Error).self) {
            _ = try await tools.recognizeText(imagePath: textPath)
        }
    }

    @Test("recognizeText reads a real image and returns its text")
    func testRecognizeTextRealImage() async throws {
        let path = try writePNG(size: NSSize(width: 480, height: 120), text: "Hello Vision 2026")
        defer { try? FileManager.default.removeItem(atPath: path) }
        let tools = VisionTools()
        let results = try await tools.recognizeText(imagePath: path)
        #expect(results.count == 1)
        #expect(results.first?.text == "Hello Vision 2026")
        #expect(results.first?.boundingBox != .zero)
    }

    @Test("classify reads a real image and returns its labels")
    func testClassifyRealImage() async throws {
        let path = try writePNG(size: NSSize(width: 200, height: 200))
        defer { try? FileManager.default.removeItem(atPath: path) }
        let tools = VisionTools()
        let results = try await tools.classify(imagePath: path, limit: 5)
        #expect(!results.isEmpty)
        #expect(results.count <= 5)
        #expect(results.allSatisfy { !$0.identifier.isEmpty })
    }

    @Test("a request the framework rejects ends the call instead of the process")
    func testRecognizeTextRejectedImageReturnsInsteadOfTrapping() async throws {
        // Vision rejects an image this small and reports the failure on
        // the request itself. The call must come back (= throw or
        // return); it must not take the process down with it.
        let path = try writePNG(size: NSSize(width: 1, height: 1))
        defer { try? FileManager.default.removeItem(atPath: path) }
        let tools = VisionTools()
        // Reaching the next line = the process survived the call.
        let outcome: Result<[VisionTextResult], Error>
        do {
            outcome = .success(try await tools.recognizeText(imagePath: path))
        } catch {
            outcome = .failure(error)
        }
        switch outcome {
        case .success(let results):
            #expect(results.isEmpty)
        case .failure(let error):
            // The file was readable, so a failure here is the
            // framework's, not a load error of ours.
            #expect(!(error is VisionToolsError))
        }
    }
}
