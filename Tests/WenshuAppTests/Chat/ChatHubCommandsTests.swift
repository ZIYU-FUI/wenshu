//  ChatHubCommandsTests.swift · Wenshu · v2.4
//
//  Verifies the wenshu chat slash command catalog (= the 35 hub
//  commands) preserves the contract: 35 entries, category buckets
//  match the canonical hermes parity list, lookup by name works,
//  and no name duplicates the slash itself (= `/review` would be
//  ambiguous if `review` and `/review` both existed; = the list
//  only stores bare names).

import Testing
@testable import WenshuApp

@Suite("ChatHubCommands")
struct ChatHubCommandsTests {

    @Test("catalog has exactly 35 entries")
    func catalogCount() {
        #expect(ChatHubCommands.all.count == 35)
    }

    @Test("all names are unique")
    func namesUnique() {
        let names = ChatHubCommands.all.map(\.name)
        #expect(Set(names).count == names.count)
    }

    @Test("none of the names start with a slash")
    func noLeadingSlash() {
        for cmd in ChatHubCommands.all {
            #expect(!cmd.name.hasPrefix("/"),
                    "name \(cmd.name) must not include the leading slash")
        }
    }

    @Test("category filter is exact")
    func categoryFilter() {
        let writing = ChatHubCommands.commands(in: "writing")
        #expect(writing.count == 7)
        let allWriting = writing.allSatisfy { $0.category == "writing" }
        #expect(allWriting)
    }

    @Test("unknown category returns empty")
    func unknownCategoryEmpty() {
        let empty = ChatHubCommands.commands(in: "nonexistent")
        #expect(empty.isEmpty)
    }

    @Test("command lookup by name returns the matching entry")
    func lookupByName() {
        #expect(ChatHubCommands.command(named: "review")?.description == "Review chapter")
        #expect(ChatHubCommands.command(named: "cron")?.category == "ops")
        #expect(ChatHubCommands.command(named: "missing") == nil)
    }

    @Test("each entry has non-empty description and category")
    func nonEmptyMetadata() {
        for cmd in ChatHubCommands.all {
            #expect(!cmd.description.isEmpty,
                    "\(cmd.name) description must be non-empty")
            #expect(!cmd.category.isEmpty,
                    "\(cmd.name) category must be non-empty")
        }
    }

    @Test("canonical hermes parity categories present")
    func canonicalCategoriesPresent() {
        let categories = Set(ChatHubCommands.all.map(\.category))
        for expected in ["writing", "story", "prose", "mechanics", "code", "research", "discovery", "ops"] {
            #expect(categories.contains(expected),
                    "missing canonical category: \(expected)")
        }
    }
}
