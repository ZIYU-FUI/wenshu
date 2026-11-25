# ADR-0037: The novel's own continuity — claims carry their moment and their grade, and the rules are three shapes

> Status: accepted
> Date: 2026-11-25
> Decision-maker(s): pocock
>
> The number: `0035` and `0036` are both spoken for elsewhere (= `ADR-0027`
> reserves `0035` for a future decision, = = and the Board's own client
> carries `0035` and `0036`), = = so this decision takes the next number
> neither of them holds.

## Context

A long novel states its world in prose, and that is what makes a novel a novel. It is also
what makes the world's facts expensive: every question about the world ("is she still alive
at chapter nine?", "does that letter ever get paid off?", "was he born in the north or the
west?") costs a re-read of the book, and two re-reads can disagree.

The tree had nothing to hold that. `WSEntity` carries a character's aliases, tags and an
untyped JSON attribute bag; `WSChapter` carries a chapter whose `status` is a free string.
So nothing in the store can say "she is alive at chapter nine", nothing can be checked
against anything else, and the app's own help copy
(`LibraryMigrator+HelpDoc.swift:122`) promises a whole-book consistency check the tree
cannot perform.

Apple's own answer was measured on this machine before anything was designed, and it stops
short of the question:

- `NaturalLanguage`'s `NLTagger` reads a Chinese sentence and names its parts
  (`NLTag.personalName` for a person's name, `NLTag.placeName` for a place name). It is a
  tokenizer over the text. It cannot say whether two chapters disagree.
- `NLEmbedding` measures whether two Chinese sentences mean the same thing (a paraphrase
  measured 0.255 from its original, an unrelated sentence 0.443). A similarity, not a
  contradiction: two similar sentences can say opposite things, and two differently-worded
  sentences can mean the same thing.
- No Apple framework ships a fiction world model. Nothing holds a story's rules, checks a
  story's claims against them, or walks a story's threads.

⇒ ⇒ ⇒ **⇒ So the finding IS the decision: Apple ships no answer here, and the shape of the
answer is ours.** A game framework does not fill the gap either. `GKGraph` is a game
framework whose node-level reverse path query segfaults on this machine's macOS 27.2
(`SIGSEGV`, exit 139) and whose `GKNSPredicateRule` raises `NSUnknownKeyException` (exit
134) on a key the fact does not carry; its rule facts and grades are a game model's, not a
novel's. Borrowing its types would buy a crash-prone graph and a wrong model of what a fact
is. Borrowing its *shape* — a fact with a certainty, a rule with a salience, a graph walk
over what the world says — costs nothing and is ours to define.

The scope of record is `.scratch/2026-11-25-novel-continuity-core/spec.md`.

## Decision

The world's continuity is a **domain kernel in the data package**, holding claims and rules,
and it answers one question in two halves.

**1. A claim carries six fields.**

| field | what it is | why it cannot be dropped |
|---|---|---|
| **id** | the claim's own name (= what a conflict names it by) | a conflict must point at the claims that met |
| subject + attribute + value | what the book says, about whom, for which property | the claim itself |
| **grade** (0...1) | how firmly the book states it | a hint contradicts nothing: a character "seemed to be dead" and a chapter that says he is dead are not a conflict, and without the grade they are |
| **chapter** | the moment of the story the claim belongs to (nil = the book's own documents, which stand beside the chapters rather than inside them) | a world changes over time: a character who dies between chapter three and chapter nine states two values, and they are not a contradiction |

**2. A rule is one of exactly three shapes, and they are not variants of one shape.**

- `.oneValuePerMoment(attribute:)` — at one moment, the attribute holds one value. Compares
  **within** a moment.
- `.neverChanges(attribute:)` — the attribute's value is the same at every moment (an
  origin does not move). Compares **across** moments.
- `.notTogether(first:second:)` — two attributes that cannot both hold at one moment.

A fourth shape is not added without a rule that cannot be expressed as one of these three.

**3. A conflict names the claims that met**, and the report's order is **total** (severity,
then rule, subject, attribute, claim ids, and the rule's own sentence), so the same book
always produces the same conflicts in the same order. The last key is what makes it total:
two rules that share a name and a subject are still told apart, = = and without it the
order of those two would be unspecified.

**4. The kernel writes nothing and the `.ws` format does not change.** Every object is
rebuilt from the book's own files on each read. The kernel is value types and pure
functions, so it can be exercised without the app and without a view.

## Consequences

**Easier.** A question about the world's facts becomes a call on a value type instead of a
re-read of the book, and the same book always gives the same answer. The rules live in one
place, so a writer can change what "contradiction" means for their book without touching a
view.

**Harder.** The claim is now a thing somebody has to produce, and nothing in the tree
produces it yet: the extraction of claims out of prose and the delivery of findings into the
agent's context bundle (`ContextEngine`'s `worldContext` is still empty) are the two tickets
this kernel exists to feed, and they are outside this decision.

**Locked in.** The claim's six fields. The three rule shapes. The total report order. And
the kernel's placement in the data package, so it can be exercised without the app.

**The other half of this scope** (= the book's thread chains, read out of the chapters' own
marker lines) is its own record: `ADR-0038`.

## Alternatives considered

- **Adopt `GameplayKit`.** Rejected: it is a game framework, its own semantics are a game
  model's, and its node-level reverse path query segfaults on this machine. Its *shape* was
  borrowed; its types were not.
- **Use `NLEmbedding` to decide whether two claims contradict.** Rejected: it measures
  similarity, and similarity is not contradiction. It remains the right tool for "are these
  two sentences the same claim", which is a different question from "do these two claims
  both hold at the same moment".
- **Let an LLM do the checking.** Rejected: an LLM's verdict is not reproducible, so the
  same book would give different conflicts on different days, and a writer could not cite
  what the tool said. The model may read the prose; the arithmetic that decides is the
  kernel's.
- **Store the world's claims in the `.ws` store as new models.** Rejected: the format does
  not change. Every claim is rebuilt from the book's own files, so there is no second
  source of truth to keep in step with the prose.
- **One rule shape instead of three.** Rejected: "one value at a moment" and "a value that
  never changes" are different comparisons (within a moment versus across moments), and
  collapsing them makes a world that changes over time read as broken.
- **A game framework's rule system.** Rejected: a game's facts and grades are a game
  model's, and this book's facts need a moment and a certainty, which a game model's do
  not carry.
