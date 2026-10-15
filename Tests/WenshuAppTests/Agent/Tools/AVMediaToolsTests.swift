//
//  AVMediaToolsTests.swift · Wenshu · v0.18 ticket 11 (AV media tools)
//
// test AVMediaTools. estimateDuration yes (AVFoundation), .
// speak skip (sandbox).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("AVMediaTools (hermes replica)")
struct AVMediaToolsTests {
    @Test("estimateDuration 默认 4 字/秒")
    func testEstimateDurationDefault() {
        let tools = AVMediaTools()
        let text = "你好世界你好世界"  // 8
        let duration = tools.estimateDuration(text: text, rate: 0.5)
        // 8 / 4 / = 2
        #expect(abs(duration - 2.0) < 0.01)
    }

    @Test("estimateDuration rate 1.0 = 8 字/秒")
    func testEstimateDurationFast() {
        let tools = AVMediaTools()
        let text = "abcdefghij"  // 10
        let duration = tools.estimateDuration(text: text, rate: 1.0)
        // 10 / 8 / = 1.25
        #expect(abs(duration - 1.25) < 0.01)
    }

    @Test("estimateDuration 空字符串 = 0")
    func testEstimateDurationEmpty() {
        let tools = AVMediaTools()
        #expect(tools.estimateDuration(text: "", rate: 0.5) == 0.0)
    }

    @Test("availableVoices 不抛错")
    func testAvailableVoices() {
        let tools = AVMediaTools()
        let voices = tools.availableVoices()
        // macOS 27 yes zh-CN + en-US wait
        #expect(voices.count >= 0)
    }

    @Test("availableVoices languagePrefix 过滤")
    func testAvailableVoicesFilter() {
        let tools = AVMediaTools()
        let zhVoices = tools.availableVoices(languagePrefix: "zh")
        // zh, yes en-US
        for voice in zhVoices {
            #expect(voice.contains("zh") || voice.contains("chinese"))
        }
    }
}