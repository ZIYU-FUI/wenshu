//
//  ChatToolUsePartViewIconTests.swift · Wenshu · T43-TOOL-ICON-SF (2026-09-18)
//
//  Verifies the iconName(for:) helper on ChatToolUsePartView:
//    - Read tools → magnifyingglass
//    - Write/edit tools → square.and.pencil
//    - Shell / process → terminal
//    - Calculator / math → function
//    - Web / fetch → globe
//    - Image / media → photo
//    - Unknown tools → wrench.and.screwdriver (fallback)
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatToolUsePartView tool icon SF (T43)")
struct ChatToolUsePartViewIconTests {

    // --- Read tools (= magnifying glass) ---

    @Test func read_tool_returns_magnifyingglass() {
        #expect(ChatToolUsePartView.iconName(for: "ReadFileTool") == "magnifyingglass")
        #expect(ChatToolUsePartView.iconName(for: "list_dir") == "magnifyingglass")
        #expect(ChatToolUsePartView.iconName(for: "SearchTool") == "magnifyingglass")
        #expect(ChatToolUsePartView.iconName(for: "FindFilesTool") == "magnifyingglass")
        #expect(ChatToolUsePartView.iconName(for: "query_database") == "magnifyingglass")
        #expect(ChatToolUsePartView.iconName(for: "grep_logs") == "magnifyingglass")
    }

    // --- Write / edit tools (= square.and.pencil) ---

    @Test func write_tool_returns_square_and_pencil() {
        #expect(ChatToolUsePartView.iconName(for: "WriteFileTool") == "square.and.pencil")
        #expect(ChatToolUsePartView.iconName(for: "edit_file") == "square.and.pencil")
        #expect(ChatToolUsePartView.iconName(for: "AppendTextTool") == "square.and.pencil")
        #expect(ChatToolUsePartView.iconName(for: "create_document") == "square.and.pencil")
        #expect(ChatToolUsePartView.iconName(for: "delete_file") == "square.and.pencil")
        #expect(ChatToolUsePartView.iconName(for: "move_file") == "square.and.pencil")
    }

    // --- Shell / process (= terminal) ---

    @Test func shell_tool_returns_terminal() {
        #expect(ChatToolUsePartView.iconName(for: "RunShellTool") == "terminal")
        #expect(ChatToolUsePartView.iconName(for: "ShellExec") == "terminal")
        #expect(ChatToolUsePartView.iconName(for: "process_run") == "terminal")
        #expect(ChatToolUsePartView.iconName(for: "exec_command") == "terminal")
        #expect(ChatToolUsePartView.iconName(for: "bash_script") == "terminal")
    }

    // --- Calculator / math (= function) ---

    @Test func math_tool_returns_function() {
        #expect(ChatToolUsePartView.iconName(for: "CalculatorTool") == "function")
        #expect(ChatToolUsePartView.iconName(for: "math_eval") == "function")
    }

    // --- Web / fetch (= globe) ---

    @Test func web_tool_returns_globe() {
        #expect(ChatToolUsePartView.iconName(for: "WebFetchTool") == "globe")
        #expect(ChatToolUsePartView.iconName(for: "fetch_url") == "globe")
        #expect(ChatToolUsePartView.iconName(for: "http_request") == "globe")
    }

    // --- Image / media (= photo) ---

    @Test func media_tool_returns_photo() {
        #expect(ChatToolUsePartView.iconName(for: "ImageGenTool") == "photo")
        #expect(ChatToolUsePartView.iconName(for: "media_play") == "photo")
        #expect(ChatToolUsePartView.iconName(for: "photo_edit") == "photo")
    }

    // --- Fallback (= wrench.and.screwdriver) ---

    @Test func unknown_tool_returns_wrench() {
        #expect(ChatToolUsePartView.iconName(for: "UnknownTool") == "wrench.and.screwdriver")
        #expect(ChatToolUsePartView.iconName(for: "FooBarBaz") == "wrench.and.screwdriver")
        #expect(ChatToolUsePartView.iconName(for: "") == "wrench.and.screwdriver")
    }

    // --- Case insensitive (= the helper lowercases the input) ---

    @Test func case_insensitive() {
        #expect(ChatToolUsePartView.iconName(for: "READFILE") == "magnifyingglass")
        #expect(ChatToolUsePartView.iconName(for: "WriteFile") == "square.and.pencil")
        #expect(ChatToolUsePartView.iconName(for: "SHELL") == "terminal")
    }
}