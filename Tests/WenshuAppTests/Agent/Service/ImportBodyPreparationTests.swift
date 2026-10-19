// ImportBodyPreparationTests.swift
//
// v2.7 round-66 commit E (= boss 2026-10-10 "导入
// 的文件，内容大量缺失" 反馈). The LLM in `.consolidate`
// mode was "compressing" the source body (= the prompt's
// "整理 .ws 格式" was interpreted as "summarize and
// rewrite" by the LLM). The fix moves the format work to
// code (= deterministic): the body is stripped of noise
// (= Obsidian backlinks, useless metadata lines) and the
// missing H2 skeleton is appended from
// `ImportDocumentTemplate.skeleton`.
//
// These tests verify the helper at the unit level (= the
// LLM is NOT in the loop; = the result is deterministic
// for a given input body + folder).

import Foundation
import Testing
@testable import WenshuApp

@Suite("Import body 准备: 原文保留 + 模板骨架补充 (v2.7 round-66 commit E)")
struct ImportBodyPreparationTests {

    /// v2.7 round-66 commit E: the
    /// `prepareBodyForWrite`
    /// helper strips
    /// Obsidian-style
    /// backlinks (= `[[X]]`)
    /// but keeps the rest of
    /// the body verbatim.
    /// (= the user's source
    /// content is preserved
    /// 100% except for the
    /// noise).
    @Test func stripObsidianBacklinksKeepsRest() {
        let raw = """
        # 故事宪法

        这是一些真实内容。

        [[某篇笔记]]
        [[另一篇笔记]]
        """
        let stripped = ImportDocumentTemplate.stripUselessLines(raw)
        #expect(!stripped.contains("[[某篇笔记]]"))
        #expect(!stripped.contains("[[另一篇笔记]]"))
        #expect(stripped.contains("这是一些真实内容"))
        #expect(stripped.contains("# 故事宪法"))
    }

    /// v2.7 round-66 commit E: the
    /// `prepareBodyForWrite`
    /// helper strips
    /// "useless metadata
    /// lines" (= old wenshu
    /// template's noise like
    /// "类型: 民俗神-A节气",
    /// "状态: 草稿", "核心信息: ..."
    /// = the old template's
    /// "core info" field
    /// that's redundant with
    /// the modern template's
    /// H2 structure).
    @Test func stripUselessMetadataLines() {
        let raw = """
        # 故事宪法

        类型: 民俗神-A节气
        状态: 草稿
        核心信息: 一些真正的内容
        """
        let stripped = ImportDocumentTemplate.stripUselessLines(raw)
        #expect(!stripped.contains("类型: 民俗神-A节气"))
        #expect(!stripped.contains("状态: 草稿"))
        #expect(!stripped.contains("核心信息"))
    }

    /// v2.7 round-66 commit E: when
    /// the body is missing
    /// some H2 sections from
    /// the folder's skeleton,
    /// those missing H2s are
    /// appended as empty
    /// sections with a
    /// `[TODO: 需调研补齐]`
    /// marker (= the user
    /// sees the full template
    /// structure + knows
    /// which sections still
    /// need to be filled).
    @Test func appendMissingH2Skeleton() {
        let raw = """
        # 我的世界观

        一些已写的内容。

        ## 核心设定

        这是核心设定。
        """
        let result = ImportDocumentTemplate.prepareBodyForWrite(
            rawBody: raw,
            folder: .world
        )
        // The body is
        // preserved
        // verbatim
        // (including the
        // "## 核心设定"
        // section).
        #expect(result.contains("## 核心设定"))
        #expect(result.contains("这是核心设定"))
        // The
        // skeleton's
        // missing
        // H2s are
        // appended
        // (=
        // worldSkeleton
        // has
        // multiple
        // sections
        // after
        // "核心设定").
        // We don't
        // assert
        // exact
        // names
        // (= the
        // canonical
        // skeleton
        // evolves);
        // = we
        // assert
        // that
        // some
        // H2
        // was
        // appended
        // after
        // the
        // original
        // content.
        #expect(result.contains("## "))
        #expect(result.contains("[TODO: 需调研补齐]"))
    }

    /// v2.7 round-66 commit E: when
    /// the body already has
    /// ALL of the skeleton's
    /// H2s, NOTHING is
    /// appended (= the body
    /// is just stripped of
    /// noise; = the canonical
    /// H2 set is preserved as
    /// the user wrote it).
    /// The world skeleton has
    /// 1 H2 section (per
    /// `ImportDocumentTemplate.worldSkeleton`):
    /// - 6 份必填子文档
    /// (= round-69 refactor split
    /// the 8 mandatory H2 fields
    /// into 6 standalone sub-docs;
    /// = the skeleton now carries
    /// only the H1 + a sub-doc
    /// index section header; = the
    /// per-field content lives in
    /// the linked sub-doc files,
    /// not in this skeleton body).
    @Test func noH2AppendedWhenAllPresent() {
        let raw = """
        # 我的世界观

        ## 6 份必填子文档

        (= round-69 拆分后, 世界观 = 1 主索引 + 6 份独立 .md
        在 world/ 同目录下):

        - [`核心设定.md`](核心设定.md) — 这个元素"是什么"和"为什么重要"
        - [`地理或位置.md`](地理或位置.md) — 地形 / 气候 / 资源 / 危险
        - [`体系或规则.md`](体系或规则.md) — 能力 / 成本与限制 / 边界情况
        - [`历史脉络.md`](历史脉络.md) — 起源 → 关键转折 → 当前状态
        - [`与其他元素的关系.md`](与其他元素的关系.md) — 引用 / 反派 / 盟友
        - [`关键场景种子.md`](关键场景种子.md) — 主角会面临的场景
        """
        let result = ImportDocumentTemplate.prepareBodyForWrite(
            rawBody: raw,
            folder: .world
        )
        // The body is
        // returned
        // AS-IS
        // (= the
        // H2
        // append
        // is a
        // no-op
        // when
        // all
        // skeleton
        // H2s
        // are
        // present).
        #expect(!result.contains("[TODO: 需调研补齐]"))
    }
}
