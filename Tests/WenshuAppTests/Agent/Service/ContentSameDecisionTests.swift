// ContentSameDecisionTests.swift
//
// v2.7 round-66 commit F (= boss 2026-10-10 "我
// 选故事宪法，直接跳到了
// 步骤 3，没有重新分
// 析是不是内容相
// 同" 反馈). The Phase 2
// LLM content-same decision (= the
// orchestrator's 2-stage dedup; = the
// first stage checks the title + the
// second stage lets the LLM compare
// the source body against the
// existing body before deciding
// between skip and overwrite).
//
// These tests verify the threshold
// constant + the shouldSkip
// decision logic (= the LLM
// call itself is integration-
// tested in the live run; = the
// threshold + the boolean
// decision are the deterministic
// surface the tests can lock
// down).

import Foundation
import Testing
@testable import WenshuApp

@Suite("Content-same decision (v2.7 round-66 commit F)")
struct ContentSameDecisionTests {

    /// v2.7 round-66 commit F: the
    /// confidence threshold
    /// constant exists and
    /// has a sane default
    /// value (= 0.7; = the
    /// boss's "你来定, 现在
    /// 反正是拍脑袋"
    /// directive; = easy to
    /// tune later without
    /// touching the import
    /// service).
    @Test func thresholdIsAccessible() {
        let threshold = ImportDocumentTemplate.contentSameConfidenceThreshold
        #expect(threshold > 0)
        #expect(threshold <= 1.0)
        // The current value is
        // 0.7; = this is
        // explicitly captured
        // (= a future tuning
        // commit will change
        // it; = the test
        // should be updated
        // to match).
        #expect(threshold == 0.7)
    }

    /// v2.7 round-66 commit F: when
    /// the LLM says
    /// `isContentSame == true`
    /// with `confidence >=
    /// threshold`, the
    /// decision is "skip"
    /// (= the orchestrator
    /// marks the task
    /// `.skipped` and the
    /// existing file is
    /// kept).
    @Test func shouldSkipWhenSameAndConfident() {
        let result = ContentSameResult(
            isContentSame: true,
            confidence: 0.95,
            reasoning: "两段完全相同"
        )
        #expect(WenshuConductorImportRouter.shouldSkip(result: result) == true)
    }

    /// v2.7 round-66 commit F: when
    /// the LLM says
    /// `isContentSame == true`
    /// but `confidence <
    /// threshold` (= the LLM
    /// is uncertain), the
    /// decision is
    /// "overwrite" (= the
    /// user gets the new
    /// content rather than
    /// a false skip; = the
    /// conservative
    /// default).
    @Test func shouldNotSkipWhenSameButUnconfident() {
        let result = ContentSameResult(
            isContentSame: true,
            confidence: 0.5,
            reasoning: "可能是同的, 但 confidence 低"
        )
        #expect(WenshuConductorImportRouter.shouldSkip(result: result) == false)
    }

    /// v2.7 round-66 commit F: when
    /// the LLM says
    /// `isContentSame == false`
    /// (= clearly different
    /// content), the decision
    /// is "overwrite"
    /// regardless of
    /// confidence (= the LLM
    /// has high or low
    /// confidence in "they're
    /// different" = both
    /// outcomes are the
    /// same).
    @Test func shouldNotSkipWhenDifferent() {
        let highConfDifferent = ContentSameResult(
            isContentSame: false,
            confidence: 0.99,
            reasoning: "完全不同的内容"
        )
        let lowConfDifferent = ContentSameResult(
            isContentSame: false,
            confidence: 0.3,
            reasoning: "可能是不同的"
        )
        #expect(WenshuConductorImportRouter.shouldSkip(result: highConfDifferent) == false)
        #expect(WenshuConductorImportRouter.shouldSkip(result: lowConfDifferent) == false)
    }

    /// v2.7 round-66 commit F: edge
    /// case at the threshold
    /// (= confidence == 0.7
    /// exactly). The ">"
    /// vs ">=" comparison
    /// matters here; = the
    /// threshold uses
    /// `>=` (= a confidence
    /// exactly at 0.7 is
    /// trusted enough to
    /// skip).
    @Test func shouldSkipAtExactThreshold() {
        let result = ContentSameResult(
            isContentSame: true,
            confidence: ImportDocumentTemplate.contentSameConfidenceThreshold,
            reasoning: "刚好达到阈值"
        )
        #expect(WenshuConductorImportRouter.shouldSkip(result: result) == true)
    }
}
