//
//  EditorTools.swift · Wenshu · P1 ticket #10 (PORT-SPECIALIZED-005, 2026-09-04)
//
//  1:1 Swift port of hermes `agent/editing/editor_tools.py`
//  (= the paragraph-level editor transformations surface). The
//  Python module ships 6 transforms that fire on a paragraph of
//  prose:
//
//    1. expand       — make text longer; add concrete detail /
//                       supporting ideas; keep voice.
//    2. shorten      — condense to ~50% of the original; preserve
//                       the load-bearing claim.
//    3. rephrase     — same meaning, different wording; preserve
//                       length and tone.
//    4. shiftTone    — rewrite in a chosen tone (= formal / casual /
//                       literary / punchy / neutral); the target
//                       tone is supplied by the caller.
//    5. simplify     — reduce reading level; prefer short sentences
//                       and common words; cut jargon.
//    6. dramatize    — add sensory detail + dialogue beats; raise
//                       scene energy without changing the plot.
//
//  All 6 transforms are LLM-driven (= the Swift module produces
//  the prompt prefix + tool description that the LLM consumes; the
//  actual rewriting happens in the model's response, not in
//  Swift). This matches the hermes convention where specialized
//  tools are prompt-builders + tool-schema providers (= the heavy
//  lifting lives in the LLM call already wired into
//  ConversationLoop).
//
//  Public surface (= the task spec verbatim):
//
//    - enum EditorTransform           : 6 cases (= the transforms)
//    - enum TargetTone                : 5 cases (= formal / casual /
//                                         literary / punchy / neutral)
//    - actor EditorTransformTools     : init()
//                                       availableTransforms() async
//                                       promptPrefix(for:targetTone:) async
//                                       toolDescription(for:) async
//                                       defaultTone(for:) async
//
//  Concurrency: actor (= Swift 6 strict concurrency). Reads
//  serialize cleanly across the SpecializedTools pane + the chat
//  loop (= the LLM may call `paragraph_ai` while the editor
//  surface pre-renders tool descriptions).
//
//  Stateless design rationale (= same as the rest of the
//  specialized tools family): the actor holds no state; each call
//  is a pure function of its inputs (= `EditorTransform` +
//  optional `TargetTone`). The actor boundary exists for
//  concurrency safety + to match the established port pattern
//  (= `ReaderExperienceAnalyzer`, `PlotThreadTracker`,
//  `GenreFitAnalyzer` all expose actors for the same reason).
//
//  Standards-axis (wenshu house style):
//    S1 (Apple-API-first): Foundation only. No third-party deps.
//    S3 (single source of truth for JSON parsing): the actor
//        ships no JSON I/O (= stateless).
//    S4 (no new third-party deps): zero added.
//    S5 (no private types the rest of the app needs): all types
//        public (= matches the ticket spec).
//

import Foundation

// MARK: - Public surface

/// The 6 paragraph-level editor transformations (= matches the
/// task spec verbatim). Each case maps 1:1 to a Python transform
/// in hermes's `agent/editing/editor_tools.py`.
public enum EditorTransform: String, Sendable, Codable, CaseIterable, Identifiable {
    /// Make text longer; add concrete detail / supporting ideas;
    /// keep voice.
    case expand
    /// Condense to ~50% of the original; preserve the
    /// load-bearing claim.
    case shorten
    /// Same meaning, different wording; preserve length and tone.
    case rephrase
    /// Rewrite in a chosen tone (= see `TargetTone`).
    case shiftTone
    /// Reduce reading level; prefer short sentences + common
    /// words; cut jargon.
    case simplify
    /// Add sensory detail + dialogue beats; raise scene energy
    /// without changing the plot.
    case dramatize

    public var id: String { rawValue }

    /// Display label for the SwiftUI tool palette.
    public var displayName: String {
        switch self {
        case .expand:     return "Expand"
        case .shorten:    return "Shorten"
        case .rephrase:   return "Rephrase"
        case .shiftTone:  return "Shift tone"
        case .simplify:   return "Simplify"
        case .dramatize:  return "Dramatize"
        }
    }

    /// One-sentence hint shown next to the picker.
    public var hint: String {
        switch self {
        case .expand:
            return "Make this longer; add concrete detail and supporting ideas while keeping the voice."
        case .shorten:
            return "Condense to about half the length; preserve the load-bearing claim."
        case .rephrase:
            return "Say the same thing in different words; keep length and tone."
        case .shiftTone:
            return "Rewrite in a chosen tone — formal, casual, literary, punchy, or neutral."
        case .simplify:
            return "Reduce reading level; short sentences, common words, no jargon."
        case .dramatize:
            return "Add sensory detail and dialogue beats; raise scene energy without changing the plot."
        }
    }

    /// Lucide icon name (= uses Lucide names already shipped by
    /// wenshu; avoids needing to add a new icon import path).
    public var lucideIcon: String {
        switch self {
        case .expand:     return "chevrons-out"
        case .shorten:    return "chevrons-in"
        case .rephrase:   return "refresh-cw"
        case .shiftTone:  return "palette"
        case .simplify:   return "feather"
        case .dramatize:  return "flame"
        }
    }
}

/// The 5 target tones the `shiftTone` transform can rewrite
/// toward. `neutral` is included so the LLM can be asked to strip
/// tonal coloring (= useful when the source text already reads
/// editorial-neutral and the user wants to confirm that).
public enum TargetTone: String, Sendable, Codable, CaseIterable, Identifiable {
    /// Polished, distant, third-person; typical of formal essays
    /// and journalism.
    case formal
    /// Conversational, contractions, fragments; typical of chat
    /// and informal blog posts.
    case casual
    /// Image-rich, rhythmic, allusive; typical of literary
    /// fiction.
    case literary
    /// Short, declarative, front-loaded verbs; typical of
    /// headlines, taglines, and high-energy prose.
    case punchy
    /// Strip tonal coloring; preserve voice without leaning
    /// toward any of the other four.
    case neutral

    public var id: String { rawValue }

    /// Display label for the SwiftUI tone picker.
    public var displayName: String {
        switch self {
        case .formal:   return "Formal"
        case .casual:   return "Casual"
        case .literary: return "Literary"
        case .punchy:   return "Punchy"
        case .neutral:  return "Neutral"
        }
    }
}

// MARK: - Errors

/// Errors thrown by `EditorTransformTools`. The single case
/// mirrors the convention used by the other specialized tools
/// actors (= one LocalizedError per failure mode; = no
/// `fatalError` paths).
public enum EditorTransformToolsError: Error, LocalizedError, Sendable, Equatable {
    case unknownTransform(String)

    public var errorDescription: String? {
        switch self {
        case .unknownTransform(let raw):
            return "EditorTransformTools: unsupported transform raw value `\(raw)`."
        }
    }
}

// MARK: - Actor

/// Paragraph-level editor transform surface. The actor is
/// stateless; each method is a pure function of its arguments
/// (= an `EditorTransform` + an optional `TargetTone`).
///
/// Why an actor and not an enum of static methods (= since the
/// actor holds no state)?
///
///   1. Swift 6 strict concurrency: the chat loop may call the
///      tool while the editor surface pre-renders tool
///      descriptions. An actor serializes access cleanly across
///      those call sites.
///   2. Pattern consistency with the rest of the specialized
///      tools family (= `ReaderExperienceAnalyzer`,
///      `PlotThreadTracker`, `GenreFitAnalyzer` all expose
///      actors). Keeping the same shape means callers use one
///      mental model across the family.
///   3. Future-proofing: when the LLM-driven transform is wired
///      in (= a future ticket that adds the ConversationLoop
///      callback that consumes `promptPrefix(...)` and feeds it
///      to the model), the actor is already the right place to
///      hold a per-book rate limiter or a cached LLM client.
public actor EditorTransformTools {

    public init() {}

    // MARK: - Public API

    /// All available transformations (= the 6 cases of
    /// `EditorTransform`). Used by the tool palette UI to
    /// enumerate the buttons.
    public func availableTransforms() async -> [EditorTransform] {
        EditorTransform.allCases
    }

    /// Build the LLM-facing prompt prefix that triggers the
    /// transformation. The ChatView tool surface composes this
    /// with the user's paragraph text (= the LLM receives
    /// "prefix + paragraph" and produces the rewrite).
    ///
    /// For `.shiftTone`, `targetTone` is required; the prompt
    /// prefix is meaningless without a target tone. For all
    /// other transforms, `targetTone` is ignored.
    ///
    /// - Parameters:
    ///   - transform: which of the 6 transformations to trigger.
    ///   - targetTone: required for `.shiftTone`; ignored
    ///     otherwise.
    /// - Returns: the LLM-facing prompt prefix. Always non-empty.
    public func promptPrefix(
        for transform: EditorTransform,
        targetTone: TargetTone? = nil
    ) async -> String {
        switch transform {
        case .expand:
            return Self.expandPrefix
        case .shorten:
            return Self.shortenPrefix
        case .rephrase:
            return Self.rephrasePrefix
        case .shiftTone:
            // Per the contract, shiftTone always carries a target
            // tone (= either caller-supplied or the default tone
            // for .shiftTone, which is .formal — see
            // defaultTone(for:)). The caller in ParagraphAITool
            // is responsible for resolving the tone before
            // reaching this method; the guard is defensive.
            let tone = targetTone ?? .formal
            return Self.shiftTonePrefix(tone: tone)
        case .simplify:
            return Self.simplifyPrefix
        case .dramatize:
            return Self.dramatizePrefix
        }
    }

    /// Build the LLM-facing tool description (= shown in the
    /// tool picker so the user knows what each transform does).
    ///
    /// The description is intentionally short (= one line) so the
    /// tool picker remains scannable; the longer `hint` lives on
    /// `EditorTransform` for the detail view.
    public func toolDescription(for transform: EditorTransform) async -> String {
        switch transform {
        case .expand:     return "Make the paragraph longer; add concrete detail."
        case .shorten:    return "Condense to about half the length."
        case .rephrase:   return "Say the same thing in different words."
        case .shiftTone:  return "Rewrite in a chosen tone."
        case .simplify:   return "Reduce reading level; cut jargon."
        case .dramatize:  return "Add sensory detail and dialogue beats."
        }
    }

    /// Suggest a default tone for a transform. Returns `nil` for
    /// every transform except `.shiftTone` (= the only transform
    /// that takes a tone) and `.dramatize` (= which conventionally
    /// lifts toward the literary register).
    ///
    /// The defaults are picked so the chat-loop caller can
    /// resolve "user said 'rewrite this' with no further
    /// instruction" without an extra round-trip.
    public func defaultTone(for transform: EditorTransform) async -> TargetTone? {
        switch transform {
        case .shiftTone:  return .formal
        case .dramatize:  return .literary
        case .expand,
             .shorten,
             .rephrase,
             .simplify:
            return nil
        }
    }

    // MARK: - Prompt prefix constants

    /// The LLM-facing directive for `.expand`. Concise enough to
    /// fit a cached system-prompt block; explicit enough that
    /// the model produces consistent rewrites across runs.
    private static let expandPrefix = """
    [TRANSFORM: expand] Lengthen the following paragraph. Add concrete \
    detail, supporting examples, and sensory grounding while \
    preserving the voice, tense, and load-bearing claim of the \
    original. Do not invent new plot facts. Return only the rewritten \
    paragraph.
    """

    /// The LLM-facing directive for `.shorten`.
    private static let shortenPrefix = """
    [TRANSFORM: shorten] Condense the following paragraph to about \
    half its length. Preserve the single load-bearing claim and the \
    voice. Cut every sentence that does not earn its place. Return \
    only the rewritten paragraph.
    """

    /// The LLM-facing directive for `.rephrase`.
    private static let rephrasePrefix = """
    [TRANSFORM: rephrase] Rewrite the following paragraph so it says \
    the same thing in different words. Preserve length, tone, and the \
    load-bearing claim. Do not add new detail and do not drop detail. \
    Return only the rewritten paragraph.
    """

    /// The LLM-facing directive for `.shiftTone`, parameterized
    /// by the target tone.
    private static func shiftTonePrefix(tone: TargetTone) -> String {
        switch tone {
        case .formal:
            return """
            [TRANSFORM: shift_tone -> formal] Rewrite the following \
            paragraph in a formal register: third-person, full \
            sentences, no contractions, no colloquialisms. Preserve \
            the load-bearing claim and the approximate length. Return \
            only the rewritten paragraph.
            """
        case .casual:
            return """
            [TRANSFORM: shift_tone -> casual] Rewrite the following \
            paragraph in a casual register: contractions, fragments \
            allowed, conversational rhythm. Preserve the \
            load-bearing claim and the approximate length. Return \
            only the rewritten paragraph.
            """
        case .literary:
            return """
            [TRANSFORM: shift_tone -> literary] Rewrite the following \
            paragraph in a literary register: image-rich, rhythmic, \
            allusive where it earns the beat. Preserve the \
            load-bearing claim and the approximate length. Return \
            only the rewritten paragraph.
            """
        case .punchy:
            return """
            [TRANSFORM: shift_tone -> punchy] Rewrite the following \
            paragraph in a punchy register: short declarative \
            sentences, front-loaded verbs, no filler. Preserve the \
            load-bearing claim. Return only the rewritten paragraph.
            """
        case .neutral:
            return """
            [TRANSFORM: shift_tone -> neutral] Rewrite the following \
            paragraph so it reads as tonally neutral: no casual \
            markers, no literary flourish, no punchy compression. \
            Preserve the load-bearing claim and the approximate \
            length. Return only the rewritten paragraph.
            """
        }
    }

    /// The LLM-facing directive for `.simplify`.
    private static let simplifyPrefix = """
    [TRANSFORM: simplify] Lower the reading level of the following \
    paragraph. Prefer short sentences, common words, and concrete \
    nouns. Cut jargon, idioms that do not survive translation, and \
    dependent clauses that obscure the main claim. Preserve the \
    load-bearing claim. Return only the rewritten paragraph.
    """

    /// The LLM-facing directive for `.dramatize`.
    private static let dramatizePrefix = """
    [TRANSFORM: dramatize] Heighten the following paragraph. Add \
    sensory detail (= sight / sound / touch / smell / taste) and \
    dialogue beats where they serve the scene. Raise scene energy \
    without changing the plot or the load-bearing claim. Return \
    only the rewritten paragraph.
    """
}
