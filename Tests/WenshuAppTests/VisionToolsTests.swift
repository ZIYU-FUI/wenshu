//
//  VisionToolsTests.swift · Wenshu · v0.18 ticket 10 (vision tools)
//
//  单元测试 VisionTools. 只测错误路径 (图片加载失败), 不测真 Vision 跑 (避免 sandbox 限制).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("VisionTools (hermes replica)")
struct VisionToolsTests {
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
        // 文本文件不是图片 → 应该 imageLoadFailed
        let tools = VisionTools()
        let textPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".test-vision-\(UUID().uuidString.prefix(8)).txt").path
        try? "not an image".write(toFile: textPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: textPath) }
        await #expect(throws: (any Error).self) {
            _ = try await tools.recognizeText(imagePath: textPath)
        }
    }
}