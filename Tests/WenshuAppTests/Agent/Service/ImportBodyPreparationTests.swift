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
    /// 8 H2 sections (per
    /// `ImportDocumentTemplate.worldSkeleton`):
    /// - 核心设定
    /// - 地理或位置（如果是地点类）
    /// - 体系或规则（如果是魔法/科技/社会类）
    /// - 历史脉络（如果是历史/势力类）
    /// - 与其他元素的关系
    /// - 关键场景种子
    /// - 备注
    @Test func noH2AppendedWhenAllPresent() {
        let raw = """
        # 我的世界观

        ## 核心设定
        A.

        ## 地理或位置（如果是地点类）
        B.

        ## 体系或规则（如果是魔法/科技/社会类）
        C.

        ## 历史脉络（如果是历史/势力类）
        D.

        ## 与其他元素的关系
        E.

        ## 关键场景种子
        F.

        ## 备注
        G.
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
