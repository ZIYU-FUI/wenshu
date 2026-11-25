# ADR-0038: The book's own thread chains — the chapters already write them down, so they are read down

> Status: accepted
> Date: 2026-11-25
> Decision-maker(s): pocock
>
> The number: `0035` and `0036` are both spoken for elsewhere (= `ADR-0027`
> reserves `0035` for a future decision, = = and the Board's own client
> carries `0035` and `0036`), = = and `0037` is this scope's other half, = =
> so this decision takes the number none of them holds.

## Context

A novel hangs threads across its chapters: a scar in chapter three is paid
off in chapter nine, a letter nobody answers is answered in chapter
twenty. The reader is meant to feel the chain close. The writer has to hold
it open in their head, because nothing in the tree holds it for them.

The book already writes its own threads down. The chapter template
(`ImportDocumentTemplateSkeletons.swift:263` and `:369`) ships a thread
section whose markers are the section's own name and the two words a chapter
uses for "planted here" and "paid off here", and whose payoff line names the
chapter the thread came from (`源自第 X 章`). So the whole chain is already
in the book's own files.

Nothing read it. A thread that is never paid off, a payoff that arrives
before its plant, and a payoff pointing at a chapter that never planted
anything were all invisible to the writer who has to fix them.

Apple's own answer was measured on this machine before anything was
designed, and it stops short of the question. `NaturalLanguage`'s `NLTagger`
names the parts of a Chinese sentence; it cannot say that chapter nine pays
off a thread that chapter three planted. Nothing in Apple's frameworks
walks a book's own threads.

⇒ ⇒ ⇒ **⇒ So the finding IS the decision: Apple ships no answer here, and the shape
of the answer is ours.** The shape that fits is a **deterministic read of the
book's own marker lines**: no language model, no extraction step, no second
source of truth, and the same book always gives the same breaks.

The scope of record is `.scratch/2026-11-25-novel-continuity-core/spec.md`.
The other half of this scope (= the world's claims and the rules they are
checked against) is its own record: `ADR-0037`.

## Decision

A thread chain is read out of the chapters' own marker lines, and it breaks
in exactly four ways.

**1. The markers are the book's own vocabulary, not the kernel's.** The
section heading, the plant label, the payoff label and the punctuation
between a label and its text live in `ForeshadowVocabulary` as code points,
so the production file stays English-only and a marker can change without a
code edit.

**2. A marker's head must BE the label.** The text before the colon is
stripped of its markdown (= the bullet, the bold pair, the whitespace) and
what is left must equal the label. A line whose head merely *mentions* the
label (= a note that says "this chapter plants nothing") is not a marker:
reading it as one reports a thread the book does not have. This is the same
rule the payoff side already obeyed (= a payoff whose text mentions a plant
is not a plant), applied to the head.

**3. A marker line's punctuation is the one a human writes.** The template
ships the half-width colon, but the same template uses the full-width colon
two lines away, so a chapter a writer typed by hand carries the full-width
one. Both are read, because a kernel that reads only the template's
punctuation reads nothing from exactly the chapters a human wrote.

**4. The template's own placeholder is not a thread.** A marker line whose
text is the angle brackets the template ships is a marker the writer has not
filled in, so the book has not planted anything there yet.

**5. A chapter number is read the way the book writes it.** An arabic
number, or the book's own numerals, and always closed by the word that names
a chapter (= so an ordinary word that merely begins the same way names no
chapter). The arabic branch asks for ASCII only, because the book's own
numerals are letters that also read as numbers.

**6. A chain breaks in exactly four ways**, and a payoff is reported once:

| break | what it is |
|---|---|
| `payoffBeforePlant` | a payoff arrives before the chapter that plants its thread |
| `payoffNamesChapterThatPlantsNothing` | a payoff names a chapter that plants no thread |
| `payoffNamesChapterThatDoesNotExist` | a payoff names a chapter the book does not have |
| `plantNeverPaidOff` | no payoff in the book names this chapter as a thread's origin |

The first three are **one break each** (= the chapter the payoff names is
missing, = = or it plants nothing, = = or it plants AFTER the payoff), so a
payoff that names a chapter the book does not have is not also "before its
plant". The fourth is **chapter grain**: a payoff names the chapter its
thread was planted in, not the thread.

**7. A break is one thing for the writer to fix, so the report says it
once.** A chapter that plants two threads and is paid off by neither is one
unpaid chapter, and two payoff lines naming the same absent chapter name the
same absent chapter. Both are one row.

**8. The report never cries wolf.** A payoff whose origin the file cannot
read could pay off any thread, so while one exists no thread counts as
unpaid.

**9. The order is the book's own order**: a break is reported against the
chapter that causes it, so the earliest chapter's breaks read first.

**10. The kernel reads no file and writes no file.** The caller supplies
the chapter bodies; the `.ws` format does not change.

## Consequences

**Easier.** A writer who has not closed a thread can be told, without
re-reading the book, and told the same way every time (= so two readers of
the same manuscript never disagree about what is broken). The chapters
already carry the answer, so there is no extraction step to build, to run,
or to get wrong.

**Harder.** The markers are a contract. A chapter that spells its thread
section differently is invisible to the kernel, and the kernel says nothing
rather than guessing. A thread the writer names in one chapter but not in
the payoff is still read at chapter grain, because the payoff line carries
no thread's name; thread grain needs the writer to name the thread in the
payoff, and the marker vocabulary does not carry that yet.

**Locked in.** The four breaks. The chapter grain of the unpaid break. The
head-must-be-the-label rule. The code-point vocabulary. The order. And the
kernel's placement in the data package, so it can be exercised without the
app.

## Alternatives considered

- **Have a language model read the chapters.** Rejected: a model's verdict
  is not reproducible, so the same manuscript would give different breaks on
  different days, and the writer could not cite what the tool said.
- **Extract the threads into the store as new models.** Rejected: the format
  does not change, and a second source of truth has to be kept in step with
  the prose. The book already writes its threads down; reading them beats
  storing them twice.
- **Read the marker by "the head mentions the label".** Rejected: a note
  that says "this chapter plants nothing" mentions the label, so this reads
  as a plant and reports a thread the book does not have (= the failure
  mode the whole kernel exists to avoid).
- **Report a thread at thread grain.** Rejected for now: the payoff line
  names a chapter, not a thread, so there is nothing to join on. The grain
  would have to be carried by the marker vocabulary first.
