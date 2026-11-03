//
//  PreviewPaneCard+Body.swift
//
//  The card's body: the paper wash, the cover, the words over the
//  artwork, the badges, and the context menu.
//
//  Why: the body is a cluster of its own, and the card's file was over
//  the file-size cap.
//
import os
import SwiftUI

extension Card {
    var body: some View {
        // THE CARD IS THE PICTURE.
        //
        // It used to be a banner with the text under it on the panel.
        // The App Store's own card is the other way round: the artwork
        // IS the card, and the words sit on the artwork over a wash,
        // so the picture is what the eye reads first. That is also
        // what macOS does with a media tile (= Photos' grid: the
        // picture, the title on it, and the badges in the corner).
        //
        // So the picture fills the card, the title and the tags sit on
        // it at the bottom left over a scrim, and the play badge sits
        // in the middle (= the App Store's shape, and macOS's own
        // paused-player glyph).
        ZStack(alignment: .bottomLeading) {
            // The card with no picture yet.
            //
            // It should read as the thing it stands in for: a card
            // whose cover is a Chinese scroll painting on pale paper
            // gets a warm paper wash, not a cool grey. The old
            // gradient (= the accent tint into the quaternary label
            // colour) was cold and blue, and it fought every picture
            // that landed in the same slot.
            LinearGradient(
                colors: [
                    DesignTokens.coverPaperTop,
                    DesignTokens.coverPaperMiddle,
                    DesignTokens.coverPaperBottom,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // The symbol is a watermark in the middle of the paper,
            // in ink, not a badge in the corner: the ZStack
            // aligns its children to the bottom left (= that is
            // where the words go), so the symbol carries its own
            // frame to sit in the middle.
            //
            // Per wenshu-icon-policy v1.5: 64 PT (= empty-state threshold >=38 PT)
            // MUST pin .symbolRenderingMode(.monochrome). SF
            // Symbols 6 on macOS 27 silently falls back to the
            // .fill variant (= the bold-blue book icon. Pinning
            // .monochrome forces the outline glyph at 64 PT.
            // Trade-off: .tint(.opacity 0.85) blue is replaced by
            // default .secondary blue tint via .foregroundStyle.
            Image(systemName: source.iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(DesignTokens.coverPaperWatermarkInk.opacity(0.32))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            // A card with a generated cover shows the picture in
            // the SAME slot, over the gradient and the symbol. The
            // gradient and the symbol stay underneath, so a card
            // whose picture is still loading, or whose file has
            // gone missing, degrades to what it showed before.
            //
            // The slot's size does not change: the cover is a wide
            // banner (100pt tall, 216-316pt wide depending on the
            // pane), and the stored picture is 768x320 (= 2.40:1),
            // which fills it and trims only the sides.
            // A card with a moving cover shows the STILL picture
            // until the pointer arrives, and the clip while it is
            // there. The grid of stills is what the user sees
            // normally; a grid of moving clips would be noise.
            if coverVideoURL != nil {
                LoopingCoverView(
                    videoURL: coverVideoURL,
                    isHovered: isHovered,
                    stillImageURL: coverImageURL
                )
            } else {
                CardCoverView(imageURL: coverImageURL)
            }
            // A cover is being drawn, or a clip is being made: the
            // card says so, in place. The work takes seconds and
            // the user asked for it, so the card must not sit
            // there looking finished.
            if isCoverWorkInFlight {
                ZStack {
                    Color.black.opacity(0.15)
                    ProgressView()
                        .controlSize(.small)
                }
            }
            // A card that MOVES says so in the corner.
            //
            // The mark is the one the Photos app puts on a picture
            // that moves (= the Live Photo mark), and it is a HINT
            // and not a control: the clip plays when the pointer
            // arrives, and the mark says the card can do that. It
            // is small, because a card whose picture is the card
            // must not have a button on top of it.
            if coverVideoURL != nil {
                SFIcon(
                    CoverClipControl.symbol,
                    style: .inlineSmall,
                    color: .white,
                    rendering: .monochrome,
                    pointSizeOverride: CoverClipControl.badgeSize
                )
                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                .padding(DesignTokens.spacingStandard)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(false)
            }
            // The last attempt failed: the card carries the mark
            // (= the Apple HIG "needs attention" pattern, in the
            // corner the completion badge does not use).
            if showsFailureMark {
                SFIcon(
                    "exclamationmark.triangle.fill",
                    style: .inlineSmall,
                    color: Color.orange
                )
                .padding(DesignTokens.spacingCaption)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .allowsHitTesting(false)
            }
            // The wash the words sit in.
            //
            // The App Store washes the bottom of its artwork so the
            // white copy can be read over it, and macOS does the same
            // in Photos. It is a gradient and NOT a solid panel: a
            // panel behind the words would be a box pretending to be
            // hierarchy, and the picture is the card.
            //
            // A card with NO picture is already pale paper, so it
            // gets no wash: its words are ink (see below) and the
            // paper stays paper. A wash over a pale ground turned the
            // whole card into a smoky grey, which is the one thing a
            // placeholder must not be.
            if hasCover {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.18), .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }

            // The words, on the picture.
            //
            // They sit low, in white, with a shadow: a generated cover
            // is a pale painting (= pale paper with a subject on it),
            // and a shadow is what keeps white words readable on a
            // pale ground. The hierarchy is the type itself (= the
            // title, then the tags), not a plate behind it.
            VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                Text(source.title)
                    .font(.headline)
                    .foregroundStyle(hasCover ? .white : DesignTokens.coverInk)
                    .shadow(color: hasCover ? .black.opacity(0.55) : .white.opacity(0.5), radius: 3, x: 0, y: 1)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if !source.tags.isEmpty {
                    HStack(spacing: DesignTokens.spacingCaption) {
                        ForEach(source.tags, id: \.self) { tag in
                            CardTagChip(tag: tag, hasCover: hasCover)
                        }
                    }
                    .lineLimit(1)
                }
            }
            .padding(DesignTokens.spacingModerate)
            .allowsHitTesting(false)
        }
        // The picture keeps the card's shape: 4:3, which is the shape
        // the picture is generated in, so it fills the tile and
        // nothing is trimmed.
        .aspectRatio(DesignTokens.coverTileRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(
            RoundedRectangle(
                cornerRadius: DesignTokens.surfaceCornerRadiusWindow,
                style: .continuous
            )
        )
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // parent component owns style, child component only does function. Hover tint (=
        // matches the pane tab hover pattern).
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusWindow, style: .continuous)
                .fill(isHovered ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.clear))
        )
        .overlay(
            // the border is now conditional on 3 states. `needsCompletion` overrides
            // hover (= the card keeps the orange border whether the user
            // is hovering or not; = the visual signal persists across
            // mouse-off events; = the user can leave the card and the
            // orange tint stays; = matches the boss's "需 要用户补 齐" wording =
            // the card needs attention, not just a hover hint). The orange
            // tint = Apple HIG "needs- attention" color (= the system
            // orange; = not the wenshu accent color; = the user
            // immediately recognizes "this needs action").
            RoundedRectangle(cornerRadius: DesignTokens.surfaceCornerRadiusWindow, style: .continuous)
                .stroke(
                    needsCompletion
                        ? AnyShapeStyle(Color.orange)
                        : (isHovered ? AnyShapeStyle(.tint.opacity(0.4)) : AnyShapeStyle(.tertiary)),
                    lineWidth: needsCompletion ? 1.5 : 0.5
                )
        )
        // the top-right corner badge (= a small orange triangle icon in a white circle; =
        // the Apple HIG "needs attention" pattern; = the badge persists across
        // hover events; = the user can scroll the card into view and
        // immediately see "this one needs 补齐" without hovering). Only shown
        // when `needsCompletion == true`.
        .overlay(alignment: .topTrailing) {
            if needsCompletion {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 18, height: 18)
                    Circle()
                        .stroke(Color.orange, lineWidth: 1.2)
                        .frame(width: 18, height: 18)
                    SFIcon(
                        "exclamationmark.triangle.fill",
                        style: .inlineSmall,
                        color: Color.orange
                    )
                }
                .padding(DesignTokens.spacingCaption)
                // The user can right-click the badge to see the "补齐" menu item (= the
                // full menu is on the card body; = the badge itself
                // has no gesture = clicking the badge passes through
                // to the card's .contextMenu).
                .allowsHitTesting(false)
            }
        }
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        // 2026-10-14 v7.5 (= the boss 2026-10-14 (see OOB.md #2026-10-14) root-cause):
        // the previous `.onTapGesture` (= single-tap detected via macOS click-
        // count latch) was NOT firing in the `LazyVGrid` / `ScrollView` nest
        // (= the `LazyVGrid` scroll gesture recognizer was eating the single
        // tap). Fix: use `.simultaneousGesture` with `TapGesture(count: 2)` (=
        // the SwiftUI canonical "fire double-click without conflicting with
        // the enclosing scroll gesture" pattern; = the `simultaneousGesture`
        // modifier tells the gesture system to also recognize this gesture in
        // parallel with the parent `ScrollView`'s pan gesture; = the count=2
        // TapGesture is the macOS HIG double-click surface for SwiftUI; = the
        // previous attempts of `.onTapGesture(count: 2)` were blocked by
        // LazyVGrid's ScrollView gesture recognizer, but `simultaneousGesture`
        // bypasses the conflict by asserting "fire this gesture in parallel
        // with any other gesture on the same view"). The `TapGesture(count:
        // 2)` requires two taps within `NSEvent.doubleClickInterval` (= 500 ms
        // on macOS; = the system default double-click threshold; = the AppKit
        // NSDoubleClick semantic = matches macOS Finder / TextEdit / Safari
        // tab bar double-click). No more click-count latch (= the SwiftUI
        // `count: 2` gesture handles the double-click detection natively; = no
        // manual state needed; = the `static var clickCountByID` hack is no
        // longer needed).
        .simultaneousGesture(
            TapGesture(count: 2).onEnded { _ in
                // "多次双击"清明"，没有打开" (see OOB.md #2026-07-23) (= the double-click does not
                // reach the Card; = the user can see the card
                // highlight, the tap lands, but neither the onTap path
                // nor the onDoubleClick path fires; = the gesture is
                // eaten somewhere upstream). Log every double tap (=
                // even if it ends up no-op) so the boss can grep
                // `Console.app` to see whether the tap reached the
                // Card at all.
                let cardID: String
                switch source {
                case let .reference(r): cardID = r.id.uuidString
                case let .bookDoc(d): cardID = d.id.uuidString
                }
                os_log("[wenshu.preview.card] v0.74 doubleTap firing cardID=%{public}@ title=%{public}@",
                       cardID, source.title)
                onDoubleClick(source)
                os_log("[wenshu.preview.card] v0.74 doubleTap fired cardID=%{public}@",
                       cardID)
            }
        )
        // Apple HIG tooltip (= .help = NSWindow tooltip = separate window per Apple HIG =
        // the user can hover any tab label and get its full name; = matches
        // macOS Finder / TextEdit tab bar tooltip behavior).
        .help(source.title)
        // the right-click context menu on the card (= the boss's "素材区，卡片 ，右键菜单，做 删除、重命名"
        // directive; = the per-card context menu uses the per-card callback
        // pattern; = the macOS 14+ List first-click bug doesn't apply here
        // because the Card is a standalone view inside a LazyVGrid, NOT a List
        // row; = the menu fires on first right-click reliably). Only
        // `.reference` cards get the delete / rename menu (= the `.bookDoc`
        // cards are managed by the chapter flow = a separate ticket; = for now
        // we add the menu only to the reference case = the [archived-round] / 64
        // focused on reference-library cards per the boss's "素材 区" wording).
        // the right-click context menu on the card. The menu shows for BOTH
        // `.reference` AND `.bookDoc` sources (= the boss 2026-10-10 "资料 库 的 卡
        // 片 已 经 实 现 了 右 键 菜 单 ， 但 十 二 地 仙 书 的 卡 片 没 有 生 效 ， 应 该 不 是 同 一 个 卡 片
        // 控 件 ， 你 把 书 的 加 上 就 行 了 " directive; = the [archived-round] conditional was
        // `if case .reference = source` which made the contextMenu empty for
        // bookDoc cards (= the macOS 14+ List first- click bug doesn't apply
        // because the Card is in a LazyVGrid, NOT a List row; = the menu just
        // didn't show because the items array was empty). The contextMenu is
        // always attached (= unconditional); the items list varies by source
        // case.
        .contextMenu {
            switch source {
            case .reference:
                // the "补齐" item shows when `needsCompletion == true` AND `onComplete` is
                // wired. The item is the FIRST entry (= top of menu; =
                // the user's primary intent when seeing an orange card
                // is to补齐 it; = putting it first reduces mouse
                // travel).
                if needsCompletion, let onComplete {
                    Button(String(localized: "card_completion_context_menu_complete")) {
                        onComplete()
                    }
                    Divider()
                }
                // The cover items (= the same in both card kinds).
                if onGenerateCover != nil || onRemoveCover != nil {
                    if hasCover {
                        Button(String(localized: "cover_context_menu_regenerate")) {
                            onGenerateCover?()
                        }
                        .disabled(isGeneratingCover)
                    } else {
                        Button(String(localized: "cover_context_menu_generate")) {
                            onGenerateCover?()
                        }
                        .disabled(isGeneratingCover)
                    }
                    if let onRemoveCover {
                        Button(String(localized: "cover_context_menu_remove")) {
                            onRemoveCover()
                        }
                    }
                    // "Make it move" shows only when the card HAS a
                    // still cover (= a clip is made FROM the still) and
                    // does not already have a clip.
                    if hasCover, onMakeDynamicCover != nil {
                        Button(String(localized: "cover_context_menu_make_dynamic")) {
                            onMakeDynamicCover?()
                        }
                        .disabled(isMakingVideo)
                    }
                    // The last attempt failed: the menu reports it, so
                    // the user can read why. The PICTURE's failure and
                    // the CLIP's failure are two different things and
                    // each is reported with its own words: a good
                    // picture with a failed clip is not a card without
                    // a cover.
                    if let coverErrorMessage {
                        Divider()
                        Button(String(localized: "cover_context_menu_failed")) {
                            // A failure is a report, not an action.
                        }
                        .disabled(true)
                        .help(coverErrorMessage)
                    }
                    if let coverClipErrorMessage {
                        if coverErrorMessage == nil {
                            Divider()
                        }
                        Button(String(localized: "cover_context_menu_video_failed")) {
                            // A failure is a report, not an action.
                        }
                        .disabled(true)
                        .help(coverClipErrorMessage)
                    }
                    Divider()
                }
                Button(String(localized: "sidebar_context_menu_rename")) {
                    onRename()
                }
                Divider()
                Button(
                    String(localized: "sidebar_context_menu_delete"),
                    role: .destructive
                ) {
                    onDelete()
                }
            case .bookDoc:
                // same "补齐" item for bookDoc cards (= the boss's "双 向" directive; = both
                // card types support the chat 补齐 flow; = the wiring is
                // identical to reference).
                if needsCompletion, let onComplete {
                    Button(String(localized: "card_completion_context_menu_complete")) {
                        onComplete()
                    }
                    Divider()
                }
                // The cover items (= the same in both card kinds).
                if onGenerateCover != nil || onRemoveCover != nil {
                    if hasCover {
                        Button(String(localized: "cover_context_menu_regenerate")) {
                            onGenerateCover?()
                        }
                        .disabled(isGeneratingCover)
                    } else {
                        Button(String(localized: "cover_context_menu_generate")) {
                            onGenerateCover?()
                        }
                        .disabled(isGeneratingCover)
                    }
                    if let onRemoveCover {
                        Button(String(localized: "cover_context_menu_remove")) {
                            onRemoveCover()
                        }
                    }
                    // "Make it move" shows only when the card HAS a
                    // still cover (= a clip is made FROM the still) and
                    // does not already have a clip.
                    if hasCover, onMakeDynamicCover != nil {
                        Button(String(localized: "cover_context_menu_make_dynamic")) {
                            onMakeDynamicCover?()
                        }
                        .disabled(isMakingVideo)
                    }
                    // The last attempt failed: the menu reports it, so
                    // the user can read why. The PICTURE's failure and
                    // the CLIP's failure are two different things and
                    // each is reported with its own words: a good
                    // picture with a failed clip is not a card without
                    // a cover.
                    if let coverErrorMessage {
                        Divider()
                        Button(String(localized: "cover_context_menu_failed")) {
                            // A failure is a report, not an action.
                        }
                        .disabled(true)
                        .help(coverErrorMessage)
                    }
                    if let coverClipErrorMessage {
                        if coverErrorMessage == nil {
                            Divider()
                        }
                        Button(String(localized: "cover_context_menu_video_failed")) {
                            // A failure is a report, not an action.
                        }
                        .disabled(true)
                        .help(coverClipErrorMessage)
                    }
                    Divider()
                }
                Button(String(localized: "sidebar_context_menu_rename")) {
                    onRename()
                }
                Divider()
                Button(
                    String(localized: "sidebar_context_menu_delete"),
                    role: .destructive
                ) {
                    onDelete()
                }
            }
        }
    }
}
