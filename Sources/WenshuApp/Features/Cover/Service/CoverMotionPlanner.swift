//
//  Features/Cover/Service/CoverMotionPlanner.swift
//
//   : CoverMotionPlanner.
//  Decides what a breeze may move in a picture, before the clip is
//  asked for.
//
//  The clip's prompt used to be one constant that said "a breeze".
//  That makes the clip a lottery: the model is told only that
//  something should move, so it decides what moves, and on a still
//  life it invents camera movement.
//
//  So the clip is made in two steps, the same way the picture is: the
//  document is REDUCED to its motifs first (CoverMotifExtractor),
//  the picture is drawn from those, and now the motion is PLANNED
//  from those same motifs. The plan is the answer to "which of the
//  things in this picture can a breeze move", and it comes from the
//  chat model because the chat model can tell a stalk of grass from
//  a vase and can say what kind of flower it is.
//
//  The plan's inputs are the motifs (= what the picture was actually
//  drawn from), not the picture's pixels: the chat connector takes
//  text only, and the motifs are the description of the picture
//  anyway.
//
//  Measured 2026-10-23 against the live chat endpoint on all nine
//  covers in the real library. It read the objects correctly, it kept
//  the motif names exactly, and for the five covers with nothing
//  that can move it put the wind on the light instead of inventing
//  motion.
//

import Foundation
import WenshuAgent

/// The plan, behind a protocol so the service can be tested without
/// a network call.
protocol CoverMotionPlanning: Sendable {
    /// Decides what a breeze may move in a picture.
    func plan(motifs: CoverMotifs) async throws -> CoverMotionPlan
}

/// The failures the planning can raise.
enum CoverMotionError: Error, LocalizedError {
    /// The chat model could not be reached.
    case noConnector(String)
    /// The model answered, but not with anything usable.
    case unreadableAnswer(String)
    /// The model ran out of budget before it answered.
    ///
    /// The chat model is a THINKING model: it reasons out of the
    /// same budget as the answer, so a budget too small for the
    /// reasoning leaves the response with a thinking block and no
    /// answer at all. Measured 2026-10-23: at 2000 tokens the whole
    /// budget went to the reasoning (thinking_tokens 1999) and
    /// nothing came back. This is not the same as an unreadable
    /// answer, and the sidecar's `lastError` is what the next reader
    /// of a failed cover sees.
    case answerTruncated(String)

    var errorDescription: String? {
        switch self {
        case .noConnector(let slug):
            return "No chat model is available to plan the motion (\(slug))."
        case .unreadableAnswer(let raw):
            return "The motion plan could not be read: \(raw.prefix(120))"
        case .answerTruncated(let detail):
            return "The motion plan was cut off before the model answered: \(detail)"
        }
    }
}

/// The planning, over the app's own chat model.
struct CoverMotionPlanner: CoverMotionPlanning {

    /// The prompt that asks for the plan.
    ///
    /// It names CATEGORIES and marks its examples as examples, so a
    /// picture the measurement never showed still resolves: the
    /// rules are about physics, not about a list of objects.
    ///
    /// Three rules carry the measurement:
    ///
    ///  - the objects are judged by physics, and an object that fits
    ///    no category is still judged by physics. Without that, a
    ///    picture of something the rule never named has no answer.
    ///  - the phrase for an object names THE SMOKE or THE LIGHT when
    ///    that is what moves, not the vessel it comes off. Without
    ///    that, the model slides the censer along with its smoke.
    ///  - the whole picture is named too, so the clip's prompt does
    ///    not have to guess a style. The art direction draws in three
    ///    cultures, and a prompt that says "Chinese ink-and-colour"
    ///    is wrong for the other two.
    static let prompt = """
        You are an art director. A picture has already been drawn from a list of objects. Decide what a light breeze may move in that picture, and what must hold still.

        You are given the list of objects and how they are arranged. Judge by PHYSICS, not by how good the picture looks:
        - a breeze moves what is light, flexible, loose, hanging, or growing: leaves, petals, grass, grain, vines, threads, ribbons, tassels, fringes, hair, paper, cloth.
        - a breeze cannot move what is solid and stands on a surface, or rests on or leans against another object: vessels, pottery, bronze, books, paperweights, stone, heavy fruit, food, tools, a brush resting on an inkstone.
        - something hanging or floating only bobs in place; it does not drift away.
        - something that smokes, burns or glows may have its smoke, its flame or its light shift.
        - if an object fits none of these, decide by physics: would a light breeze move this thing?

        Also classify EVERY object by what it is made of, in the "kind" value:
        - "plant" = something that grows: leaves, branches, grass, vines, flowers, moss, bamboo, pine needles, reeds, a tendril, a bud, a blossom.
        - "air" = something that is only in the air: smoke, steam, mist, dust in the light.
        - "light" = something light and loose: paper, cloth, cord, ribbon, tassel, hair, a hanging edge, a thread.
        - "solid" = everything else: vessels, pottery, bronze, books, stone, tools, heavy fruit, food.

        WHAT MOVES, AND HOW IT MOVES: if the picture has a plant, THE PLANT IS THE ONE THAT MOVES, and it GROWS (= it lengthens and opens a little, like a shoot or a bud unfurling). Only when the picture has NO plant at all does another thing move (= the lightest thing in it: smoke, dust, a paper edge, a cord). And when the plant moves, it grows: it does not sway. The clip is a growth animation when there is a plant to grow.

        Give EXACTLY one entry per object, in the same order as the list you were given. Do not add an entry, and do not split one object into two.

        The "motif" value must be the object's own name copied EXACTLY as it appears in the list you were given, in its own script. Do not translate it and do not reword it.

        For each object give an ENGLISH phrase of 3 to 8 words that identifies it in the picture: what it is, what it looks like, and where it is (for example "the closed oil-paper umbrella in the centre"). The phrase goes straight into an English video prompt, so it must be English.

        If what moves is the smoke or the flame coming off a thing, the phrase for THAT object names THE SMOKE or THE LIGHT, and it stays one entry (write "the smoke rising from the rear censer", not "the smoking censer" and not a second entry for the smoke). Otherwise the model slides the whole vessel as well.

        "picture" is an ENGLISH phrase of 6 to 12 words naming the whole picture: its style, its medium and its ground (for example "a Chinese ink-and-colour still life of festival objects on a plain light ground"). It goes straight into an English video prompt, so it must be English. Describe the picture as it actually is, in whatever style it was drawn.

        If no object can move, the wind falls on the light instead: the light drifts slowly across the ground and the soft shadows shift gently. Never on the camera.

        "wind" is one English sentence of at most 30 words: where the breeze comes from, and how it passes through the picture. It stands on its own. Write it in the SMALL words (= "a light breeze", "barely", "a hint of movement", "a few millimetres") and never in the grand ones (= "sweep", "billow", "sway violently", "rustle", "reveal", "pan across", "travel across"). The wind sentence must NOT mention the light, the shadows or the colours: those are locked elsewhere, and a sentence that mentions them asks for them to change.

        Output only this one line of JSON, no explanation, no extra text:
        {"picture":"the English phrase for the whole picture","items":[{"motif":"the object's own name, copied exactly","thing":"the English phrase","moves":true,"kind":"plant"}],"wind":"one English sentence"}
        """

    /// The provider the planning talks to (= the user's chat provider).
    private let providerSlug: @Sendable () -> String?
    /// The model the planning talks to (= the user's chat model).
    private let modelSlug: @Sendable () -> String?
    /// Builds the connector (= the app's own factory, so the shape of
    /// the request matches the provider the user configured).
    private let connectorFor: @Sendable (String) -> (any LLMConnector)?

    init(
        providerSlug: @escaping @Sendable () -> String? = {
            UserDefaults.standard.string(forKey: "wenshu.llm.provider")
        },
        modelSlug: @escaping @Sendable () -> String? = {
            WenshuAppDelegateLLMHelpers.activeModelSlug()
        },
        connectorFor: @escaping @Sendable (String) -> (any LLMConnector)? = { slug in
            WenshuAppDelegateLLMHelpers.connectorForSlug(slug)
        }
    ) {
        self.providerSlug = providerSlug
        self.modelSlug = modelSlug
        self.connectorFor = connectorFor
    }

    /// The token budget the planning asks for.
    ///
    /// The chat model is a THINKING model: it reasons before it
    /// answers, and the reasoning comes out of the same budget as the
    /// answer. Measured 2026-10-23 against MiniMax-M3.1-Flash on a
    /// document whose cultural register is hardest to decide: at 2000
    /// the whole budget went to the thinking (thinking_tokens 1999)
    /// and the answer never arrived; at 8000 it answered normally
    /// (1623 output tokens, 1527 of them thinking).
    ///
    /// So the budget has to hold the reasoning AND the answer. It is
    /// a cap, not a cost: the model spends what it spends.
    static let answerTokenBudget = 8000

    /// Plans the motion.
    func plan(motifs: CoverMotifs) async throws -> CoverMotionPlan {
        let slug = providerSlug() ?? Provider.minimaxCn.slug
        guard let connector = connectorFor(slug) else {
            throw CoverMotionError.noConnector(slug)
        }
        let model = modelSlug() ?? "MiniMax-M3"

        let response = try await connector.send(
            messages: [LLMMessage.user(Self.question(for: motifs))],
            options: LLMCallOptions(
                model: model,
                maxTokens: Self.answerTokenBudget,
                systemPrompt: Self.prompt,
                temperature: 0.3
            )
        )

        // A thinking model that ran out of budget leaves a thinking
        // block and no answer. That is a CUT-OFF answer, not an empty
        // one, and it has to be said as itself.
        if response.stopReason == .maxTokens {
            throw CoverMotionError.answerTruncated(
                "the model used its whole budget of \(response.usage.outputTokens) tokens and did not answer"
            )
        }

        let text = response.blocks
            .compactMap { block -> String? in
                if case .text(let value) = block { return value }
                return nil
            }
            .joined(separator: "\n")

        return try Self.parse(text)
    }

    /// The question the model is asked.
    ///
    /// The labels are English and the content is the motifs' own
    /// words (= the names are Chinese, and copying them exactly is
    /// what lets an entry be matched back to the picture).
    static func question(for motifs: CoverMotifs) -> String {
        """
        Objects: \(motifs.motifs.joined(separator: ", "))
        Arrangement: \(motifs.arrangement)
        Picture: \(motifs.style)
        """
    }

    /// Reads the plan out of the model's answer.
    /// The physical kind of an item, from the wire's word.
    ///
    /// A plan that does not say reads as `solid`, which is the safe
    /// default: a plan written before the classification existed must
    /// never invent a mover.
    static func movability(of kind: String?) -> CoverMotionPlan.Movability {
        guard let kind = kind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return .solid
        }
        switch kind {
        case "plant": return .plant
        case "air": return .air
        case "light": return .light
        default: return .solid
        }
    }

    static func parse(_ raw: String) throws -> CoverMotionPlan {
        guard let start = raw.firstIndex(of: "{"),
              let end = raw.lastIndex(of: "}"),
              start < end else {
            throw CoverMotionError.unreadableAnswer(raw)
        }
        let json = String(raw[start...end])
        guard let data = json.data(using: .utf8) else {
            throw CoverMotionError.unreadableAnswer(raw)
        }

        // The wire shape, decoded leniently: the model writes the
        // flags as true/false, and a plan with a missing phrase is
        // still a plan worth reading.
        struct Wire: Decodable {
            struct WireItem: Decodable {
                let motif: String?
                let thing: String?
                let moves: Bool?
                let kind: String?
            }
            let picture: String?
            let items: [WireItem]?
            let wind: String?
        }

        guard let wire = try? JSONDecoder().decode(Wire.self, from: data) else {
            throw CoverMotionError.unreadableAnswer(raw)
        }

        let items = (wire.items ?? []).compactMap { item -> CoverMotionPlan.Item? in
            guard let thing = item.thing?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !thing.isEmpty else { return nil }
            return CoverMotionPlan.Item(
                motif: item.motif ?? "",
                thing: thing,
                moves: item.moves ?? false,
                movability: movability(of: item.kind)
            )
        }
        guard !items.isEmpty else {
            throw CoverMotionError.unreadableAnswer(raw)
        }

        let wind = (wire.wind ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wind.isEmpty else {
            throw CoverMotionError.unreadableAnswer(raw)
        }

        let picture = (wire.picture ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return CoverMotionPlan(
            picture: picture.isEmpty ? "a still life" : picture,
            items: items,
            wind: wind
        )
    }
}
