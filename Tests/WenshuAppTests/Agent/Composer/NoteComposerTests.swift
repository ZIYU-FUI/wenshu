//
//  NoteComposerTests.swift · Wenshu · v0.19 ticket 16
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("NoteComposer (Obsidian replica)")
struct NoteComposerTests {

    @Test("rename 简单替换 [[old]] → [[new]]")
    func renameSimple() {
        let content = "林黛玉 进贾府 [[贾宝玉]] 初见"
        let result = NoteComposer.rename(oldName: "贾宝玉", newName: "宝玉", content: content)
        #expect(result.contains("[[宝玉]]"))
        #expect(!result.contains("[[贾宝玉]]"))
    }

    @Test("rename 带 alias [[old|alias]] → [[new|alias]]")
    func renameWithAlias() {
        let content = "见 [[林黛玉|黛玉]]"
        let result = NoteComposer.rename(oldName: "林黛玉", newName: "黛玉", content: content)
        #expect(result.contains("[[黛玉|黛玉]]"))
        #expect(!result.contains("[[林黛玉"))
    }

    @Test("rename 多链接全部替换")
    func renameMultiple() {
        let content = "[[林黛玉]] 与 [[林黛玉|黛玉]] 和 [[林黛玉]] 同时出现"
        let result = NoteComposer.rename(oldName: "林黛玉", newName: "黛玉", content: content)
        let occurrences = result.components(separatedBy: "[[黛玉").count - 1
        #expect(occurrences == 3, "应有 3 处替换 (含 alias)")
    }

    @Test("rename 旧名不在内容里原样返回")
    func renameNotFound() {
        let content = "没有链接"
        let result = NoteComposer.rename(oldName: "林黛玉", newName: "黛玉", content: content)
        #expect(result == content)
    }

    @Test("rename 相同名不替换")
    func renameSameName() {
        let content = "[[林黛玉]]"
        let result = NoteComposer.rename(oldName: "林黛玉", newName: "林黛玉", content: content)
        #expect(result == content)
    }

    @Test("rename 中文含 special 字符 (regex escape)")
    func renameSpecialChars() {
        let content = "[[林.黛玉]]"
        let result = NoteComposer.rename(oldName: "林.黛玉", newName: "黛玉", content: content)
        #expect(result == "[[黛玉]]")
    }

    @Test("merge 多个 source 拼接")
    func mergeMultiple() {
        let sources: [(name: String, content: String)] = [
            ("旧名1", "第一段 [[旧名1]]"),
            ("旧名2", "第二段 [[旧名2]]"),
        ]
        let result = NoteComposer.merge(targetName: "新名", sourceContents: sources)
        #expect(result.contains("第一段 [[新名]]"))
        #expect(result.contains("第二段 [[新名]]"))
        #expect(!result.contains("[[旧名1]]"))
        #expect(!result.contains("[[旧名2]]"))
    }

    @Test("split 按行范围拆")
    func splitByRange() throws {
        let content = "line 0\nline 1\nline 2\nline 3\nline 4"
        let (first, second) = try NoteComposer.split(content: content, startLine: 1, endLine: 3)
        #expect(first.contains("line 0"))
        #expect(first.contains("line 1"))
        #expect(first.contains("line 2"))
        #expect(first.contains("line 3"))
        #expect(second.contains("line 1"))
        #expect(second.contains("line 4"))
    }

    @Test("split 越界抛错")
    func splitOutOfRange() {
        #expect(throws: ComposerError.self) {
            _ = try NoteComposer.split(content: "line 0\nline 1", startLine: 5, endLine: 10)
        }
    }
}
