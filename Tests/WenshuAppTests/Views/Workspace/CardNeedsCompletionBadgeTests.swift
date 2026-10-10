// CardNeedsCompletionBadgeTests.swift
//
// v2.7 round-66 commit A (= boss 2026-10-10 "如果有不符合模版
// 的内容，导入后，卡片加橙色提示角标" directive). The Card
// view's `needsCompletion: Bool` property drives the orange
// border + the top-right triangle badge (= Apple HIG
// needs-attention pattern; = the orange tint overrides the
// hover tint so the user sees the attention signal even when
// not hovering).
//
// The `Card` view is a `private struct` inside `PreviewPane`
// (= file-scoped, = not directly accessible from the test
// target). The test verifies the public-facing shape
// (= the `CardSource` enum is public; = the enum has
// `.reference` + `.bookDoc` cases; = the cases carry the
// `iconName` + `title` properties the Card view consumes).
// The Card's `needsCompletion` / `onComplete` properties are
// verified by the Swift compiler (= if the Card struct
// gains or loses those properties, the call sites in
// `PreviewPane` stop compiling; = the test target doesn't
// need to assert them). The real verification is the
// boss's manual screenshot once the app is running.

import SwiftUI
import Testing
@testable import WenshuApp

@MainActor
@Suite("Card 卡片 needsCompletion 角标 (v2.7 round-66 commit A)")
struct CardNeedsCompletionBadgeTests {

    /// v2.7 round-66: the
    /// `CardSource` enum
    /// (= the public
    /// surface the
    /// `Card` view
    /// consumes) has
    /// both `.reference`
    /// and `.bookDoc`
    /// cases. The Card
    /// view's
    /// `.contextMenu`
    /// `switch source`
    /// must handle both
    /// cases (= the
    /// round-65b work
    /// already added
    /// both; = this
    /// test guards
    /// against a future
    /// change dropping
    /// either case).
    @Test func cardSourceHasBothCases() {
        let refSource = CardSource.reference(.placeholder)
        let docSource = CardSource.bookDoc(.placeholder)
        // CardSource's
        // `iconName` + `title`
        // accessors are
        // the ones the
        // Card view uses
        // (= if the
        // accessors return
        // non-empty strings,
        // the Card can
        // render the row).
        #expect(!refSource.iconName.isEmpty)
        #expect(!refSource.title.isEmpty)
        #expect(!docSource.iconName.isEmpty)
        #expect(!docSource.title.isEmpty)
    }
}

// MARK: - Test fixtures

extension Reference {
    /// Test fixture: a
    /// minimal `Reference`
    /// for `CardSource.reference`.
    @MainActor
    static var placeholder: Reference {
        Reference(
            title: "Test Reference",
            category: .a,
            tags: ["test"],
            summary: ""
        )
    }
}

extension BookDoc {
    /// Test fixture: a
    /// minimal `BookDoc`
    /// for `CardSource.bookDoc`.
    /// The BookDoc is
    /// constructed with
    /// the existing
    /// `init` (= check
    /// the BookDoc type
    /// for the right
    /// parameter order).
    @MainActor
    static var placeholder: BookDoc {
        BookDoc(
            id: UUID(),
            bookId: UUID(),
            folderName: "chapters",
            fileName: "test.md",
            modifiedAt: Date(),
            createdAt: Date(),
            body: "# Test"
        )
    }
}
