//
//  ChatSlashCommandAutocompleteTests.swift · Wenshu · T18-SLASH-AUTOCOMPLETE (2026-09-18)
//
//  Verifies the slash command autocomplete engine:
//    - prefixFromInput extracts the text after "/"
//    - shouldShow gates visibility (= only when input is /-prefixed
//      AND no args yet)
//    - filter returns hub commands matching the prefix
//    - empty prefix returns the top N commands
//    - case-insensitive match
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatSlashCommandAutocomplete engine (T18)")
struct ChatSlashCommandAutocompleteTests {

    /// T18 contract: prefixFromInput returns "" for non-slash input
    /// and the text after "/" for slash-prefixed input.
    @Test func prefix_extraction() {
        #expect(ChatSlashCommandAutocompleteEngine.prefixFromInput("") == "")
        #expect(ChatSlashCommandAutocompleteEngine.prefixFromInput("hello") == "")
        #expect(ChatSlashCommandAutocompleteEngine.prefixFromInput("/") == "")
        #expect(ChatSlashCommandAutocompleteEngine.prefixFromInput("/rev") == "rev")
        #expect(ChatSlashCommandAutocompleteEngine.prefixFromInput("/review") == "review")
    }

    /// T18 contract: shouldShow = true when input starts with "/" AND
    /// has no whitespace (= the user is still typing the command name,
    /// not the args).
    @Test func should_show_only_when_slash_prefix_no_args() {
        #expect(ChatSlashCommandAutocompleteEngine.shouldShow(input: "/") == true)
        #expect(ChatSlashCommandAutocompleteEngine.shouldShow(input: "/rev") == true)
        #expect(ChatSlashCommandAutocompleteEngine.shouldShow(input: "/review some text") == false)
        #expect(ChatSlashCommandAutocompleteEngine.shouldShow(input: "hello") == false)
        #expect(ChatSlashCommandAutocompleteEngine.shouldShow(input: "") == false)
    }

    /// T18 contract: filter with empty prefix returns the first
    /// maxResults commands (= the default top-8 surface).
    @Test func empty_prefix_returns_top_commands() {
        let all = SkillAdapter.hubCommands
        let rows = ChatSlashCommandAutocompleteEngine.filter(
            prefix: "", allCommands: all
        )
        #expect(rows.count == 8)
        #expect(rows[0].id == all[0].name)
    }

    /// T18 contract: filter with non-empty prefix returns only
    /// commands whose name starts with the prefix (case-insensitive).
    @Test func prefix_filter_matches_by_prefix() {
        let all = SkillAdapter.hubCommands
        let rows = ChatSlashCommandAutocompleteEngine.filter(
            prefix: "rev", allCommands: all
        )
        // "review" starts with "rev"; "rewrite" starts with "rew".
        #expect(rows.count == 1)
        #expect(rows[0].name == "review")
    }

    /// T18 contract: filter is case-insensitive (= "REV" matches
    /// the same rows as "rev").
    @Test func prefix_filter_is_case_insensitive() {
        let all = SkillAdapter.hubCommands
        let lower = ChatSlashCommandAutocompleteEngine.filter(
            prefix: "rev", allCommands: all
        )
        let upper = ChatSlashCommandAutocompleteEngine.filter(
            prefix: "REV", allCommands: all
        )
        let mixed = ChatSlashCommandAutocompleteEngine.filter(
            prefix: "ReV", allCommands: all
        )
        #expect(lower.count == upper.count)
        #expect(upper.count == mixed.count)
        #expect(lower.map { $0.id } == upper.map { $0.id })
        #expect(upper.map { $0.id } == mixed.map { $0.id })
    }

    /// T18 contract: filter with non-matching prefix returns empty
    /// (= popup hides).
    @Test func no_match_returns_empty() {
        let rows = ChatSlashCommandAutocompleteEngine.filter(
            prefix: "zzznomatch", allCommands: SkillAdapter.hubCommands
        )
        #expect(rows.isEmpty)
    }

    /// T18 contract: maxResults cap is respected (= even when many
    /// matches exist).
    @Test func max_results_cap() {
        let all = SkillAdapter.hubCommands
        // "c" matches several commands (character, chapter, conflict, citation, cite, continue, cron, code).
        let rows = ChatSlashCommandAutocompleteEngine.filter(
            prefix: "c", allCommands: all, maxResults: 3
        )
        #expect(rows.count == 3)
    }

    /// T18 contract: prefix with leading/trailing whitespace is
    /// trimmed (= so typing "/rev " still matches "rev").
    @Test func prefix_trimming() {
        let rows = ChatSlashCommandAutocompleteEngine.filter(
            prefix: "  rev  ", allCommands: SkillAdapter.hubCommands
        )
        #expect(rows.count == 1)
        #expect(rows[0].name == "review")
    }
}