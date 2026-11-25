# ADR-0039: A book's own field lines are its claims

## Status

Accepted (2026-11-25).

## Context

The consistency kernel (`StoryConsistency`; = ADR-0037) weighs a book's claims against
the world's rules and reports the conflicts. It is proven by its own suites, but every
suite feeds it arguments a test wrote by hand. Nothing in the tree ever pointed it at a
book, so the kernel has never seen the text it will be asked about.

The reader that would close that gap has one hard question: **what in a novel's text is
a claim?**

Apple's frameworks answer a related question and not this one. `NaturalLanguage`'s
`NLTagger` names parts of a Chinese sentence (`NLTag.personalName` for a person's name,
`NLTag.placeName` for a place's), and its scheme list for `.simplifiedChinese` is
`[.language, .script, .tokenType, .lexicalClass]`; it is a tokenizer over the text.
`NLEmbedding` measures that two sentences are near each other; it is a distance, and two
sentences can be near and say opposite things. Neither can say that a book contradicts
itself.

So the answer is the book's own. A novel's world is not free prose to a machine: the
document templates ship field lines, and the books this repo builds fill them in.

## Decision

**A claim is a field line: a bullet that names a property and gives it a value.**

Three decisions follow from that, and each was measured on a real book rather than
assumed.

### The field line is a bullet

Measured over the eighteen world documents of the book in `build/wenshu-look.ws`:

- every field line in every document is a bullet (`- **name**: value` or
  `- name: value`);
- **no bare line in any document is a field**. Every bare line that holds a colon is a
  sentence: `这套世界观有三条硬规则：分清、唯一、代价。` is prose, and reading it as a
  claim would turn a paragraph into a fact about the subject.

So a bare line states nothing, with one exception: the three names the book's own
template writes at the top of a document (`实体类型`, `标签`, `摘要`), which are read by
their own names. The template ships them without a bullet, and a book that filled them
in has stated them.

### Both colons are read

The template ships the half-width colon (`:`). A book a writer filled in by hand carries
the full-width one (`：`) — the punctuation the same document uses two lines away. A
reader that reads only the half-width colon reads almost nothing from exactly the books
a human wrote: measured over the same eighteen documents, the half-width-only reader
found **8** claims where the full-width-only reader found **113**, and the two-colon
reader finds **121**. The full-width colon carries 113 of the 121 (= 93%), and the 8
that only the half-width colon splits are the two documents the template itself wrote
(`00-资料库索引.md` and `故事宪法.md`, whose `来源` / `类型` / `标签` / `摘要` lines use
the half-width colon).

### A template states nothing

A line whose value is still a template (`<数字或年龄区间>`) states nothing, so it is not
a claim at all. It is not a claim of weight zero either: a book's own account of what it
says should not carry a claim the book never made.

### What is not read

A field line's name may be bold (`- **太阳到达**: 黄经 330°`), may carry a note after
the bold part (`- **三分法 · 分清原则**（用户拍板）：...`), and the line may be a nested
bullet whose colon sits inside the bold name (`- **神 = 主角十二案中"看见"的**——神格层，
归 ...`), which states nothing. The reader splits on the first colon after the bold
name, and a name with no value after it is not a claim.

### The weight a claim carries

A line the book states flatly is stated firmly (grade 1.0). A line the book hedges
(`可能`, `大概`, `也许`, `似乎`, `看来`, `或许`) is a hint, and a hint weighs below the
kernel's threshold, so it contradicts nothing. The kernel's own threshold does that
weighing; the reader only has to tell a flat line from a hedged one.

### The subject and the moment

A document's title names its subject. A claim's chapter is the document's own moment:
a chapter's claim belongs to that chapter, and a document that is not a chapter (= a
setting sheet, = a character sheet) states what holds beside the chapters rather than
inside them.

## Consequences

- **The reader opens no file and writes no file.** It is a function over text, so the
  data package keeps its no-I/O shape and the reader can be exercised on its own.
- **The reader never guesses.** It reads what the book already wrote as a field. A
  claim that would have to be inferred from free prose is a later question, and a
  guessed claim that cannot be checked is worse than no claim.
- **The rules stay the caller's.** The kernel takes rules as arguments; which of the
  world's rules to enforce is a decision about a particular book.
- **The vocabulary is the book's**, so it is carried as code points and the file stays
  English-only. The marker can still change without a code edit.
- **The same book always reads the same way**: the claims come out in the document's own
  order, and a claim's name is the document it came from (= the name the caller gives it,
  = = the subject when the caller does not) plus the line it came from. Two documents about
  one subject would then share a claim's name, so a caller that reads several documents says
  which is which.

## The measurement this rests on

The world documents of the store in `build/wenshu-look.ws` were read with this reader.
The store holds two books, = = so the scope is named: the book's own seventeen world
documents (= `68F9A258-ECEC-4CFE-8FB0-49409E5EB750`) read as **121 claims across 15
documents**, and the two documents that hold no field lines at all
(`十二地仙卷案总表.md` and `十二职业与民俗神谱.md`) hold none. The eighteenth document in
the store (`文枢是什么.md`) belongs to the help book (= `11111111-…`), and it holds no
field lines either: over both books the counts are 121 claims across 15 documents with
3 at zero. Every claim was checked by hand against the line it came from.
