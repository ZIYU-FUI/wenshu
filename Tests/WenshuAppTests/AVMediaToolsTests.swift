//
//  AVMediaToolsTests.swift · Wenshu · v0.18 ticket 11 (AV media tools)
//
//  单元测试 AVMediaTools. estimateDuration 是纯函数 (不起 AVFoundation), 测核心.
//  speak 跳过真播放 (sandbox 限制).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("AVMediaTools (hermes replica)")
struct AVMediaToolsTests {
    @Test("estimateDuration 默认 4 字/秒")
    func testEstimateDurationDefault() {
        let tools = AVMediaTools()
        let text = "你好世界你好世界"  // 8 字符
        let duration = tools.estimateDuration(text: text, rate: 0.5)
        // 8 字 / 4 字/秒 = 2 秒
        #expect(abs(duration - 2.0) < 0.01)
    }

    @Test("estimateDuration rate 1.0 = 8 字/秒")
    func testEstimateDurationFast() {
        let tools = AVMediaTools()
        let text = "abcdefghij"  // 10 字符
        let duration = tools.estimateDuration(text: text, rate: 1.0)
        // 10 字 / 8 字/秒 = 1.25 秒
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
        // macOS 27 系统是有 zh-CN + en-US 等
        #expect(voices.count >= 0)
    }

    @Test("availableVoices languagePrefix 过滤")
    func testAvailableVoicesFilter() {
        let tools = AVMediaTools()
        let zhVoices = tools.availableVoices(languagePrefix: "zh")
        // 如果有 zh 语音, 是不返 en-US
        for voice in zhVoices {
            #expect(voice.contains("zh") || voice.contains("chinese"))
        }
    }
}