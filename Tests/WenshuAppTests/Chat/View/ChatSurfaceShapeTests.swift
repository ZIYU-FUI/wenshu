//
//  ChatSurfaceShapeTests.swift · Wenshu
//
//  The chat surfaces' outlines: the composer field wears the shared
//  ChatSurfaceShape capsule; the outgoing message band wears the app's
//  content-area material at the shared card radius, and floors at the
//  composer's resting height so a one-line message reads as the same
//  height the person typed into. Neither surface carries its own
//  corner-radius token.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ChatSurfaceShape shared chat-surface outline")
struct ChatSurfaceShapeTests {
    private static let messageViewPath = "Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift"
    private static let inputBarPath = "Sources/WenshuApp/Features/Chat/View/ChatInputBarView.swift"
    private static let shapePath = "Sources/WenshuApp/Features/Chat/View/ChatSurfaceShape.swift"

    @Test("The outgoing message band wears the shared content-area material, not the composer's capsule")
    func outgoingBandUsesSharedMaterial() throws {
        let content = try SourceLocator.read(Self.messageViewPath)
        #expect(content.contains("ContentAreaMaterial.surface"),
                "The outgoing band must wear the app's one content-area material (= the surface the content cards use)")
        #expect(!content.contains("ChatSurfaceShape()"),
                "The outgoing band must not wear the composer's capsule shape (= a row of the transcript has corners)")
        #expect(!content.contains("surfaceCornerRadiusHeroCard"),
                "The outgoing band must not carry its own corner-radius token (= the shared card radius owns the outline)")
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
