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

    @Test("The shared card wears the app's own content-area material (= not glass)")
    func sharedCardWearsTheContentAreaMaterial() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Shared/UI/InspectorCard.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("ContentAreaMaterial.surface"),
                "the shared card must wear the app's own content-area material (= the surface the column's bottom bar wears)")
        #expect(!content.contains(".glassEffect("),
                "the shared card must not wear a glass surface (= a glass surface's value tracks the wallpaper behind the window, = so the card's tone changed with the desktop rather than with the app)")
        #expect(!content.contains(".regularMaterial"),
                "the shared card must not wear a SwiftUI material (= that one is behind-window on macOS, = so it would paint the desktop through the app's own content)")
    }

    @Test("The material is the CONTENT-AREA one, in the WITHIN-WINDOW blending")
    func theMaterialSamplesTheAppNotTheDesktop() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Shared/UI/ContentAreaMaterial.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains(".underWindowBackground"),
                "the material must be the under-window one (= the layer under the window's own content), = so it shows the column it sits in")
        #expect(content.contains(".withinWindow"),
                "the material must blend WITHIN the window (= = so it samples the app's own content behind it, = = and the desktop never reaches it)")
        #expect(content.contains(".active"),
                "the material must be in its active state (= the state the app's own chrome wears)")
    }

    @Test("The material is ONE recipe (= the card and the bottom bar share it)")
    func theMaterialHasOneRecipe() throws {
        let card = try String(
            contentsOf: SourceLocator.url("Sources/WenshuApp/Shared/UI/InspectorCard.swift"),
            encoding: .utf8
        )
        let footer = try String(
            contentsOf: SourceLocator.url("Sources/WenshuApp/Features/Chrome/View/ChromeBottomFooter.swift"),
            encoding: .utf8
        )
        #expect(card.contains("ContentAreaMaterial.surface"),
                "the card must wear the shared material")
        #expect(footer.contains("ContentAreaMaterial.surface"),
                "the bottom bar must wear the SAME shared material (= a rule that lives in each door separately is a rule that drifts)")
        #expect(!card.contains("NSVisualEffectView"),
                "the card must not carry its own material recipe (= the shared file owns it)")
        #expect(!footer.contains("NSVisualEffectView"),
                "the bottom bar must not carry its own material recipe (= the shared file owns it)")
    }

    @Test("The card carries NO coloured edge (= the state rides on the glyph and the words)")
    func theCardCarriesNoColouredEdge() throws {
        let card = try String(
            contentsOf: SourceLocator.url("Sources/WenshuApp/Shared/UI/InspectorCard.swift"),
            encoding: .utf8
        )
        #expect(!card.contains("hasStatusEdge"),
                "the card must not carry a status edge (= the band was the card's loudest element while saying the same thing the state glyph beside the title already said)")
        #expect(!card.contains("statusEdgeColor"),
                "the card must not carry a status edge colour (= the band was the card's loudest element while saying the same thing the state glyph beside the title already said)")
        #expect(!card.contains("kanbanCardStatusEdgeWidth"),
                "the card must not carry a status edge (= the band was the card's loudest element while saying the same thing the state glyph beside the title already said)")
        // The token itself is gone (= a token with no caller is dead code).
        let tokens = try String(
            contentsOf: SourceLocator.url("Sources/WenshuApp/DesignTokens.swift"),
            encoding: .utf8
        )
        #expect(!tokens.contains("kanbanCardStatusEdgeWidth"),
                "the status edge token must be deleted (= a token with no caller is dead code)")
    }

    @Test("No page passes the card a status edge (= the edge API is gone)")
    func noPagePassesAStatusEdge() throws {
        for page in Self.cardPages {
            let content = try String(contentsOf: SourceLocator.url(page), encoding: .utf8)
            #expect(!content.contains("hasStatusEdge"),
                    "\(page) must not pass a status edge (= the card carries no edge)")
            #expect(!content.contains("statusEdgeColor"),
                    "\(page) must not pass a status edge colour (= the card carries no edge)")
        }
    }

    @Test("The card's edge and its clip share ONE shape (= the hairline follows the corner)")
    func theEdgeAndTheClipShareOneShape() throws {
        let content = try String(
            contentsOf: SourceLocator.url("Sources/WenshuApp/Shared/UI/InspectorCard.swift"),
            encoding: .utf8
        )
        #expect(content.contains("cardShape.strokeBorder("),
                "the card's edge must be drawn with the card's own shape")
        #expect(content.contains(".clipShape(cardShape)"),
                "the card's clip must be the card's own shape (= the hairline and the corner are one shape)")
        #expect(content.contains("DesignTokens.surfaceCornerRadiusCard"),
                "the card's radius must come from the design tokens")
        // The clip comes AFTER the edge (= the material's blur is a
        // rectangle, = = and the clip is what rounds it).
        guard let edge = content.range(of: "cardShape.strokeBorder("),
              let clip = content.range(of: ".clipShape(cardShape)")
        else {
            Issue.record("The card's edge or its clip is gone.")
            return
        }
        #expect(edge.lowerBound < clip.lowerBound,
                "the clip must come after the edge (= the material's blur is a rectangle, = = and the clip is what rounds it)")
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
                    "\(page) must not hand-draw a card fill (= the shared material draws it)")
            #expect(!content.contains(".stroke(.separator"),
                    "\(page) must not hand-draw a card edge (= the shared card draws it)")
        }
    }

    @Test("No page carries a glass container (= the container groups glass, = and there is no glass)")
    func noPageCarriesAGlassContainer() throws {
        for page in Self.cardPages {
            let content = try String(contentsOf: SourceLocator.url(page), encoding: .utf8)
            #expect(!content.contains("GlassEffectContainer("),
                    "\(page) must not carry a glass container (= the container groups glass surfaces, = = and the column's cards wear no glass)")
            #expect(!content.contains(".glassEffect("),
                    "\(page) must not wear a glass surface (= the column's cards wear the content-area material)")
        }
    }

    @Test("The card that opens something IS a button (= = the whole card answers the click)")
    func theOpenCardIsAButton() throws {
        let card = try String(
            contentsOf: SourceLocator.url("Sources/WenshuApp/Shared/UI/InspectorCard.swift"),
            encoding: .utf8
        )
        #expect(card.contains("Button(action: onOpen)"),
                "the card that opens something must be a button (= = so the click answers over the whole card, = = and not only over its words)")
        #expect(card.contains(".buttonStyle(.plain)"),
                "the card's button must be plain (= = a button style that drew a bezel would put Apple's own chrome on top of the card's own surface)")
        #expect(card.contains("onOpen: (() -> Void)?"),
                "the card must carry the open action (= = and a card that opens nothing must wear NO open card's answers)")
    }

    @Test("The card's pointer says 'this opens' (= = and never a text cursor)")
    func theCardWearsTheSystemsPointer() throws {
        let card = try String(
            contentsOf: SourceLocator.url("Sources/WenshuApp/Shared/UI/InspectorCard.swift"),
            encoding: .utf8
        )
        #expect(card.contains(".pointerStyle(.link)"),
                "the card must wear the system's own pointer (= = the one answer macOS has that says 'this opens something')")
        // ⇒ The card's words must NOT be selectable: = = a selectable
        // text answers the pointer with a TEXT CURSOR, = = and a text
        // cursor over a card says "this is a document".
        for page in Self.cardPages {
            let content = try String(contentsOf: SourceLocator.url(page), encoding: .utf8)
            #expect(!content.contains(".textSelection(.enabled)"),
                    "\(page) must not make the card's words selectable (= = a selectable text answers the pointer with a text cursor, = = and a text cursor over a card says 'this is a document')")
        }
    }

    @Test("The card's hover answers over the WHOLE card (= = and it does not flicker)")
    func theCardAnswersTheWholeCard() throws {
        let card = try String(
            contentsOf: SourceLocator.url("Sources/WenshuApp/Shared/UI/InspectorCard.swift"),
            encoding: .utf8
        )
        #expect(card.contains("hoverWashOverlay("),
                "the card must draw the hover wash (= = and the wash lives in the shared file, = = so the app's hover has ONE owner)")
        #expect(card.contains("DesignTokens.surfaceCornerRadiusCard"),
                "the card's hover wash must wear the card's own corner (= = a wash in a smaller radius floats inside the card's corner instead of following it)")
        // ⇒ The tracking area hangs on the control and NOT inside its
        // label: = = a tracking area inside a label is rebuilt when
        // the label re-renders, = = and the re-render is what the
        // hover state causes, = = so the wash FLICKERS.
        guard let tracking = card.range(of: ".onHover { isHovering = $0 }"),
              let button = card.range(of: "Button(action: onOpen)")
        else {
            Issue.record("The card's hover tracking area is gone.")
            return
        }
        #expect(tracking.lowerBound > button.lowerBound,
                "the hover tracking area must hang on the control and NOT inside its label (= = a tracking area inside a label is rebuilt by the label's own re-render, = = which is what made the wash flicker)")
    }

    @Test("The hover wash is Apple's own (= = and it is painted OVER the material)")
    func theHoverWashIsApplesOwn() throws {
        let wash = try String(
            contentsOf: SourceLocator.url("Sources/WenshuApp/Shared/UI/HoverWash.swift"),
            encoding: .utf8
        )
        #expect(wash.contains("AnyShapeStyle(.quaternary)"),
                "the wash must wear Apple's own .quaternary (= = the system's hierarchical fill, = = and it adapts to light, = = to dark and to Increase Contrast by itself)")
        #expect(!wash.contains("AnyShapeStyle(.tertiary)"),
                "the wash must NOT wear .tertiary (= = that is 25% against .quaternary's 10%, = = and the file's own stated intent = = and Apple's own row wash = = are the 10% one)")
        // ⇒ The wash that a card wears is painted OVER the content, = =
        // because a material buries a wash painted under it.
        #expect(wash.contains("func hoverWashOverlay("),
                "the app must keep ONE hover wash (= = and the card's wears the one painted over the content)")
    }

    @Test("Every page's open card carries the open action (= = and the plan card does not)")
    func everyOpenCardCarriesTheOpenAction() throws {
        // The board's card and the status page's card open something.
        for page in [
            "Sources/WenshuApp/Features/Kanban/View/KanbanView.swift",
            "Sources/WenshuApp/Features/Editor/View/InspectorStatusView.swift"
        ] {
            let content = try String(contentsOf: SourceLocator.url(page), encoding: .utf8)
            #expect(content.contains("onOpen:"),
                    "\(page) must give the card its open action (= = the card is the control)")
        }
        // ⇒ The plan's card opens NOTHING today (= = the plan lives in
        // an in-memory store with no document behind it), = = so it
        // carries no open action, = = and therefore no hand, = = and no
        // hover wash (= = a card that lights up under the pointer and
        // then does nothing is a lie the user pays for).
        let plan = try String(
            contentsOf: SourceLocator.url("Sources/WenshuApp/Features/Editor/View/InspectorTodoPageView.swift"),
            encoding: .utf8
        )
        #expect(!plan.contains("onOpen:"),
                "the plan's card opens nothing today (= = and a card that opens nothing must not wear the open card's answers)")
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

    @Test("The plan carries no count line")
    func thePlanCarriesNoCountLine() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Editor/View/InspectorTodoPageView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        // The plan's cards say what the plan is (= the state rides on
        // the card), = so a count line above them says it twice.
        #expect(!content.contains("private var header"),
                "the plan must not draw a count line (= the cards carry the state)")
        #expect(!content.contains("doneCount"),
                "the plan must not keep a done count (= nothing reads it)")
        #expect(!content.contains("totalCount"),
                "the plan must not keep a total count (= nothing reads it)")
    }

    @Test("The board carries no title row and no new-task button")
    func theBoardCarriesNoTitleRow() throws {
        let url = SourceLocator.url("Sources/WenshuApp/Features/Kanban/View/KanbanView.swift")
        let content = try String(contentsOf: url, encoding: .utf8)
        // The column's own header already says which page this is, so
        // the board carries no title of its own.
        #expect(!content.contains("private var header"),
                "the board must not draw a title row (= the column's header says which page this is)")
        // The scheduler owns the tasks (= the user does not schedule),
        // so the board carries no way to add one by hand.
        #expect(!content.contains("newTaskButton"),
                "the board must not carry a new-task button (= the scheduler owns the tasks)")
        #expect(!content.contains("private func addTask()"),
                "the board must not carry the hand-made task path (= the scheduler owns the tasks)")
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
