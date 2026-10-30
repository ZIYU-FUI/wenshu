//
//  InspectorCardSurfaceTests.swift · Wenshu
//
//  The trailing inspector column's three pages (= the todos, the
//  sub-agent tasks, the task board) draw their own cards. These tests
//  hold them to ONE card surface, so the column's cards stay one
//  family instead of three sets that drift apart.
//
//  The tests read the source, because the property they hold is a
//  property of the CODE (= three call sites wearing one surface), not
//  a property of a rendered frame (= a frame can look the same by
//  accident). A page that draws its own background fails here.
//
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("The inspector column's one card surface")
struct InspectorCardTests {

    /// The three pages that draw cards in the trailing column.
    private static let cardPages = [
        "Sources/WenshuApp/Features/Editor/View/InspectorTodoPageView.swift",
        "Sources/WenshuApp/Features/Editor/View/InspectorStatusView.swift",
        "Sources/WenshuApp/Features/Kanban/View/KanbanView.swift",
    ]

    @Test("The shared card is Apple's Liquid Glass (= the glassEffect modifier)")
    func sharedCardIsLiquidGlass() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Shared/UI/InspectorCard.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains(".glassEffect("),
                "the shared card must be Apple's Liquid Glass (= .glassEffect)")
        #expect(content.contains(".regular"),
                "the shared card must use Apple's regular glass variant")
        #expect(!content.contains(".background("),
                "the shared card must not hand-draw a background (= the system draws the glass)")
        #expect(!content.contains(".stroke("),
                "the shared card must not hand-draw an edge (= the system draws the glass edge)")
    }

    @Test("The glass is tinted white (= the glass scatters white light)")
    func theGlassIsTinted() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Shared/UI/InspectorCard.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains(".tint(.white.opacity(0.30))"),
                "the glass must be tinted white (= an untinted glass over a flat ground leaves the ground showing through and the card disappears into it)")
    }

    @Test("The shared card is the system's own shape (= Apple's shape factory)")
    func sharedCardUsesApplesShape() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Shared/UI/InspectorCard.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains(".rect(cornerRadius:"),
                "the glass must wear Apple's own shape factory (= .rect(cornerRadius:))")
        #expect(content.contains("DesignTokens.surfaceCornerRadiusCard"),
                "the card's radius must come from the design tokens")
    }

    @Test("Every page's cards wear the shared surface")
    func everyPageWearsTheSharedSurface() throws {
        for page in Self.cardPages {
            let url = SourceLocator.url(page)
            let content = try String(contentsOf: url, encoding: .utf8)
            #expect(content.contains("InspectorCard("),
                    "\(page) must draw its cards with the shared surface")
        }
    }

    @Test("No page hand-draws a card background (= the pages cannot drift apart)")
    func noPageHandDrawsACardBackground() throws {
        for page in Self.cardPages {
            let url = SourceLocator.url(page)
            let content = try String(contentsOf: url, encoding: .utf8)
            #expect(!content.contains("controlBackgroundColor"),
                    "\(page) must not hand-draw a card fill (= the shared glass draws it)")
            #expect(!content.contains(".stroke(.separator"),
                    "\(page) must not hand-draw a card edge (= the shared glass draws it)")
        }
    }

    @Test("Each page's glass sits in one container (= the system's grouping for glass)")
    func eachPageWrapsItsGlassInAContainer() throws {
        for page in Self.cardPages {
            let url = SourceLocator.url(page)
            let content = try String(contentsOf: url, encoding: .utf8)
            #expect(content.contains("GlassEffectContainer("),
                    "\(page) must group its glass in one container (= Apple's guidance)")
        }
    }

    @Test("Every marker of the plan wears one symbol set (= one size, = one column)")
    func everyMarkerWearsOneSymbolSet() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/InspectorTodoPageView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        // Every MARKER is an SFIcon (= the one factory, = one point
        // size, = one column). A ProgressView draws its own spinner at
        // its own size and centres it in the space it is offered, so a
        // spinner sat in the middle of the column while the symbols sat
        // at its edge, and the rows read ragged.
        //
        // The check reads the marker function, not the whole file (= the
        // page's own loading spinner is a ProgressView, = and that one
        // is not a marker).
        let marker = try #require(
            content.range(of: "private var stateMarker"),
            "the plan's page must carry a stateMarker"
        )
        let markerBody = String(content[marker.lowerBound...])
        // The call, not the word (= the marker carries the word in its
        // own comment, = and the comment says why).
        #expect(!markerBody.contains("ProgressView("),
                "the plan's markers must all be SFIcon (= a ProgressView draws its own spinner at its own size)")
        // The column and its edge live in the shared card (= the page
        // only hands the card its marker).
        let card = try #require(
            SourceLocator.url("Sources/WenshuApp/Shared/UI/InspectorCard.swift"),
            "the shared card must exist"
        )
        let cardSource = try String(contentsOf: card, encoding: .utf8)
        #expect(cardSource.contains(".frame(width: DesignTokens.inspectionMarkerColumnWidth, alignment: .leading)"),
                "the markers must sit at the column's leading edge (= so every symbol's ink starts at the same place)")
    }

    @Test("The marker column holds the widest symbol the plan wears")
    func theMarkerColumnHoldsTheWidestSymbol() throws {
        let url = SourceLocator.url("Sources/WenshuApp/DesignTokens.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("static let inspectionMarkerColumnWidth: CGFloat = 16"),
                "the marker column must be 16 PT (= the widest inline-small symbol's ink is 15 PT at the 14 PT point size, = measured with NSImage)")
    }

    @Test("The plan's cards do not indent (= one card, one column)")
    func thePlanDoesNotIndent() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/InspectorTodoPageView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        // The plan names each item's parent (= the plan is a tree, =
        // and the depth is real data), = but the CARD does not indent
        // by it: = every card in the column is one card in one column,
        // = and the plan's own words carry the step.
        let card = try #require(
            content.range(of: "private struct InspectorTodoCard"),
            "the plan's card must exist"
        )
        let cardSource = String(content[card.lowerBound...])
        #expect(!cardSource.contains("todo.depth"),
                "the plan's card must not indent by the depth (= the same control must look the same in every card)")
    }

    @Test("The board's groups are accordions with their name as the label")
    func theBoardGroupsAreAccordions() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Kanban/View/KanbanView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        // The group's name and its count ARE the disclosure label (= the
        // system draws the triangle beside the label, = so the group
        // reads as one accordion row). A group with an empty label
        // leaves a bare row with a stray triangle beside it.
        let group = try #require(
            content.range(of: "private struct KanbanGroup"),
            "the board's group must exist"
        )
        let groupSource = String(content[group.lowerBound...])
        #expect(groupSource.contains("DisclosureGroup(isExpanded:"),
                "the board's group must fold (= the accordion the chat's panels use)")
        #expect(groupSource.contains("} label: {"),
                "the board's group must carry a label (= the name and the count)")
        let labelStart = try #require(groupSource.range(of: "} label: {"))
        let labelSource = String(groupSource[labelStart.upperBound...])
        #expect(labelSource.contains("status.boardLabel"),
                "the disclosure's label must be the group's name")
        // The group wears no shell of its own (= a card inside a card, =
        // the column's cards are the cards).
        #expect(!groupSource.contains(".background("),
                "the board's group must not wear a shell (= the column's cards are the cards)")
    }

    @Test("The plan's cards do not fold (= the count says how much is left)")
    func thePlanDoesNotFold() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/InspectorTodoPageView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(!content.contains("DisclosureGroup"),
                "the plan's cards must not fold (= a fold hid the plan behind one more click)")
        #expect(!content.contains("isExpanded"),
                "the plan's page must not hold a fold state")
    }
}
