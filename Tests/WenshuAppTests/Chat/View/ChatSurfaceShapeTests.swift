//
//  ChatSurfaceShapeTests.swift · Wenshu
//
//  One outline for every chat surface: the composer field and the
//  outgoing message band must resolve their glass shape from the same
//  file, and the band must floor at the composer's resting height so
//  a one-line message reads as the same surface the person typed into.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ChatSurfaceShape shared chat-surface outline")
struct ChatSurfaceShapeTests {

    private static let messageViewPath = "Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift"
    private static let inputBarPath = "Sources/WenshuApp/Features/Chat/View/ChatInputBarView.swift"
    private static let shapePath = "Sources/WenshuApp/Features/Chat/View/ChatSurfaceShape.swift"

    @Test("The outgoing message band wears the shared ChatSurfaceShape")
    func outgoingBandUsesSharedShape() throws {
        let content = try SourceLocator.read(Self.messageViewPath)
        #expect(content.contains("ChatSurfaceShape()"),
                "The outgoing glass card must use ChatSurfaceShape (= the same outline the composer field wears)")
        #expect(!content.contains("surfaceCornerRadiusHeroCard"),
                "The outgoing glass card must not carry its own corner-radius token (= the shared shape owns the outline)")
    }

    @Test("The outgoing message band floors at the composer resting height")
    func outgoingBandFloorsAtComposerHeight() throws {
        let content = try SourceLocator.read(Self.messageViewPath)
        #expect(content.contains("minHeight: DesignTokens.controlHeightLarge"),
                "The outgoing glass card must floor at DesignTokens.controlHeightLarge (= the composer field height)")
        #expect(!content.contains(".padding(.vertical, DesignTokens.spacingTight)"),
                "The outgoing glass card must not stack vertical padding on top of the height floor")
    }

    @Test("The composer field wears the shared ChatSurfaceShape")
    func composerUsesSharedShape() throws {
        let content = try SourceLocator.read(Self.inputBarPath)
        #expect(content.contains("ChatSurfaceShape()"),
                "The composer field must use ChatSurfaceShape (= the shared chat-surface outline)")
        #expect(!content.contains("ChatInputBarShape"),
                "The composer file must not declare its own shape (= the shared ChatSurfaceShape replaced it)")
    }

    @Test("ChatSurfaceShape derives its radius cap from DesignTokens")
    func shapeCapComesFromDesignTokens() throws {
        let content = try SourceLocator.read(Self.shapePath)
        #expect(content.contains("struct ChatSurfaceShape: Shape"),
                "ChatSurfaceShape.swift must declare the shared shape")
        #expect(content.contains("DesignTokens.controlHeightLarge"),
                "The radius cap must come from DesignTokens.controlHeightLarge (= no new token, no magic literal)")
        #expect(!content.contains("cornerRadius: 18"),
                "The shape must not hard-code the 18 PT radius (= it is derived from the resting height)")
    }
}
