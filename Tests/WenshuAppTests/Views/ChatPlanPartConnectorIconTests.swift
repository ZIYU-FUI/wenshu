//
//  ChatPlanPartConnectorIconTests.swift · Wenshu · T29-CONNECTOR-ICON (2026-09-18)
//
//  Verifies the connector slug -> SF Symbol mapping used by
//  ChatPlanPartView.connectorIcon. Each connector in AGENTS.md
//  §11.2 gets a distinctive icon (= brain for Anthropic, sparkles
//  for Gemini, etc.) + a fallback for unknown slugs.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatPlanPartView connector icon (T29)")
struct ChatPlanPartConnectorIconTests {

    /// T29 contract: anthropic -> brain.head.profile (= Claude).
    @Test func anthropic_icon() {
        #expect(ChatPlanPartView.connectorIcon("anthropic") == "brain.head.profile")
    }

    /// T29 contract: openai-codex -> circle.hexagongrid.fill.
    @Test func openai_codex_icon() {
        #expect(ChatPlanPartView.connectorIcon("openai-codex") == "circle.hexagongrid.fill")
    }

    /// T29 contract: gemini -> sparkles.
    @Test func gemini_icon() {
        #expect(ChatPlanPartView.connectorIcon("gemini") == "sparkles")
    }

    /// T29 contract: deepseek -> water.waves (= depth).
    @Test func deepseek_icon() {
        #expect(ChatPlanPartView.connectorIcon("deepseek") == "water.waves")
    }

    /// T29 contract: ollama -> laptopcomputer (= local).
    @Test func ollama_icon() {
        #expect(ChatPlanPartView.connectorIcon("ollama") == "laptopcomputer")
    }

    /// T29 contract: openrouter -> arrow.triangle.branch (= routing).
    @Test func openrouter_icon() {
        #expect(ChatPlanPartView.connectorIcon("openrouter") == "arrow.triangle.branch")
    }

    /// T29 contract: minimax-cn -> leaf.fill (= brand-ish).
    @Test func minimax_cn_icon() {
        #expect(ChatPlanPartView.connectorIcon("minimax-cn") == "leaf.fill")
    }

    /// T29 contract: minimax (non-cn alias) -> leaf.fill.
    @Test func minimax_alias_icon() {
        #expect(ChatPlanPartView.connectorIcon("minimax") == "leaf.fill")
    }

    /// T29 contract: unknown slug -> questionmark.circle (= fallback).
    @Test func unknown_slug_fallback() {
        #expect(ChatPlanPartView.connectorIcon("future-connector-3000") == "questionmark.circle")
    }
}