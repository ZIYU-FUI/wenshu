#!/usr/bin/env python3
"""
test_slice_gate.py — the minimum-verifiable-slice gate's own test suite.

Every case runs on a FIXTURE body, so the tests stay valid when the real
card bodies change.

The cases are the shapes that made a board session expensive, measured on
board wenshu-par 2026-10-29:

  1. a card that writes one feature, with the suite that owns it, IS a
     minimum verifiable slice.
  2. a card that writes ONE feature but names NO suite for it is not (= the
     worker has to decide what "done" means for it).
  3. a card that writes TWO features is TWO slices: a board session has no
     cache and starts from zero, so a card that spans features is re-dispatched
     from zero, and 89% of dev runs landed nothing.
  4. a card's own test file rides with the slice it proves (= it does not open
     a second slice).
  5. a card that writes no code is not this gate's business.
  6. a bare `swift test` is not a proof (= the whole suite is the board's, not
     a slice's, and it costs 224 s against 10.5 s for one filtered suite).
  7. the paths in a CURRENT STATE section are CONTEXT: they are not the files
     the card writes, so they do not open a second slice.

Run:  python3 Tools/wenshu-devtool/tests/test_slice_gate.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "slice_gate.py"

FAILURES: list[str] = []


def load_tool():
    """Import slice_gate.py as a module, whatever its directory is."""
    spec = importlib.util.spec_from_file_location("slice_gate", TOOL)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check(name: str, got, want) -> None:
    """Assert one case, and record the failure instead of raising."""
    if got == want:
        print(f"  PASS  {name}")
    else:
        print(f"  FAIL  {name}\n          got:  {got!r}\n          want: {want!r}")
        FAILURES.append(name)


# One feature, one file, the suite that owns it.
ONE_SLICE = """## GOAL

The chat bubble must not wear the error colour.

## WHAT TO BUILD

- `Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift`
- `Tests/WenshuAppTests/Chat/View/ChatMessageViewTests.swift`

## GATES

`swift test --filter ChatMessageViewTests` exits 0.
"""

# One feature, and the card names a suite — but NOT the suite that owns the
# test file it writes. This is the case the gate exists for: the card carries
# a proof, just not the right one, so the worker still has to decide what
# "done" means for the file.
WRONG_SUITE = """## GOAL

The chat bubble must not wear the error colour.

## WHAT TO BUILD

- `Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift`
- `Tests/WenshuAppTests/Chat/View/ChatMessageViewTests.swift`

## GATES

`swift test --filter SomeOtherTests` exits 0.
"""

# One feature, but the card names no suite for it.
NO_PROOF = """## GOAL

The chat bubble must not wear the error colour.

## WHAT TO BUILD

- `Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift`
- `Tests/WenshuAppTests/Chat/View/ChatMessageViewTests.swift`

## GATES

The relevant tests pass.
"""

# Two features: two slices. A board session has no cache and starts from
# zero, so a card that spans features is re-dispatched from zero.
#
# The card carries a test file and names its suite, so the ONLY finding this
# fixture can produce is the one about spanning features = the dimension under
# test stays isolated.
TWO_FEATURES = """## GOAL

The completion request reaches the chat.

## WHAT TO BUILD

- `Sources/WenshuApp/Features/Agent/Service/BookChapterFileSystem.swift`
- `Sources/WenshuApp/Features/Editor/View/EditorChatNSController.swift`
- `Tests/WenshuAppTests/Agent/Service/BookChapterFileSystemTests.swift`

## GATES

`swift test --filter BookChapterFileSystemTests` exits 0.
"""

# A card that writes no code is a prose card: verified by reading it.
PROSE_ONLY = """## GOAL

Explain why the divider settles once per frame.

## WHAT TO BUILD

Nothing to change: this card documents the behaviour.

## GATES

`Scripts/verify-divider.sh` exits 0.
"""

# A bare `swift test` is the whole suite: not a slice's proof.
WHOLE_SUITE = """## GOAL

Delete the keys no screen asks for.

## WHAT TO BUILD

- `Sources/WenshuApp/Resources/Localizable.xcstrings`

## GATES

`swift test` exits 0.
"""

# The paths in a CURRENT STATE section are CONTEXT, not the card's work.
CONTEXT_ONLY = """## GOAL

The mention parser must not name a role.

## CURRENT STATE

Today the role is read out of these files:

- `Sources/WenshuApp/Features/Agent/Store/SubAgentIdentity.swift`
- `Sources/WenshuApp/Features/Chat/Model/ChatMessage.swift`

## WHAT TO BUILD

- `Sources/WenshuApp/Features/Agent/Store/SubAgentMentionParser.swift`
- `Tests/WenshuAppTests/Agent/Conversation/SubAgentMentionParserTests.swift`

## GATES

`swift test --filter SubAgentMentionParserTests` exits 0.
"""

# The HOST layer does not open a slice. A card that writes one feature, the
# shared component it needs, and the shell that assembles it is ONE vertical
# slice (= narrow but COMPLETE through every layer). Counting `App/` and
# `Shared/` as features of their own reported every well-formed card as
# several slices.
HOST_LAYER = """## GOAL

The connection card is the system's glass.

## WHAT TO BUILD

- `Sources/WenshuApp/Features/Connection/View/ConnectionView.swift`
- `Sources/WenshuApp/Shared/UI/GlassSurface.swift`
- `Sources/WenshuApp/App/ClientShell.swift`
- `Tests/WenshuAppTests/Connection/GlassSurfaceTests.swift`

## GATES

`swift test --filter GlassSurfaceTests` exits 0.
"""

# A card may name SEVERAL suites in one filter (= the suites that cover two
# files it wrote). Each name counts, so the card is not told to add a suite
# it already named.
MULTI_SUITE_FILTER = """## GOAL

The shell keeps its behaviour while the surface changes.

## WHAT TO BUILD

- `Sources/WenshuApp/Features/Connection/View/ConnectionView.swift`
- `Sources/WenshuApp/App/ClientShell.swift`
- `Tests/WenshuAppTests/Connection/ClientShellTests.swift`

## GATES

`swift test --filter "ClientShellTests|AdaptiveLayoutTests"` exits 0.
"""


def main() -> int:
    tool = load_tool()

    print("slice_gate: the minimum verifiable slice\n")

    # 1. A card that writes one feature and names its suite IS a slice.
    check("one feature with its suite is a slice", tool.contract_errors(ONE_SLICE), [])
    check(
        "the slice's files are the order's files",
        sorted(tool.order_files(ONE_SLICE)),
        [
            "Sources/WenshuApp/Features/Chat/View/ChatMessageView.swift",
            "Tests/WenshuAppTests/Chat/View/ChatMessageViewTests.swift",
        ],
    )
    check(
        "the test file rides with the slice it proves",
        sorted(tool._slice_areas(ONE_SLICE)),
        ["Sources/WenshuApp/Features/Chat"],
    )

    # 2. One feature, and the card names a suite that is NOT the one that
    #    owns the test file it writes. The card carries a proof, just not the
    #    right one, so the worker still has to decide what "done" means for
    #    that file.
    errors = tool.contract_errors(WRONG_SUITE)
    check(
        "a slice whose test file's suite is not named is reported",
        any("no named proof covers" in e for e in errors),
        True,
    )
    check(
        "the report names the suite to add",
        any("ChatMessageViewTests" in e for e in errors),
        True,
    )

    # 2b. A card that names NO proof at all is gate_width_gate.py's finding,
    #     so this gate does not double-report it.
    check(
        "a card that names no proof is not double-reported here",
        tool.contract_errors(NO_PROOF),
        [],
    )

    # 3. Two features are two slices = a NOTE, not an error. Deciding what a
    #    feature IS needs the repository's own shape (= which directory is a
    #    feature, which is the host layer), and that shape is written down in
    #    the repository's AGENTS.md, not here. A tool that guesses it reads
    #    the wrong tree as often as the right one, and a gate that cries wolf
    #    is worse than no gate: the author learns to ignore it, and the one
    #    real finding goes unread too.
    check(
        "a card spanning two features is not an error",
        tool.contract_errors(TWO_FEATURES),
        [],
    )
    notes = tool.contract_notes(TWO_FEATURES)
    check(
        "a card spanning two features is a note",
        any("writes 2 features" in n for n in notes),
        True,
    )

    # 4. A prose card is not this gate's business.
    check("a card that writes no code has no finding", tool.contract_errors(PROSE_ONLY), [])

    # 5. A bare `swift test` is not a proof.
    check(
        "a bare whole suite is not a named proof",
        tool.named_proofs(WHOLE_SUITE),
        [],
    )

    # 6. The context paths do not open a second slice.
    check(
        "context paths are not the order's files",
        tool.order_files(CONTEXT_ONLY),
        [
            "Sources/WenshuApp/Features/Agent/Store/SubAgentMentionParser.swift",
            "Tests/WenshuAppTests/Agent/Conversation/SubAgentMentionParserTests.swift",
        ],
    )
    check(
        "context paths do not make the card span two features",
        len(tool._slice_areas(CONTEXT_ONLY)),
        1,
    )
    check(
        "a card whose context names other features is still one slice",
        tool.contract_errors(CONTEXT_ONLY),
        [],
    )

    # 7. The HOST layer (= `App/`, `Shared/`) does not open a slice. A card
    #    that writes one feature, the shared component it needs, and the
    #    shell that assembles it is ONE vertical slice.
    check(
        "the host layer does not open a slice",
        sorted(tool._slice_areas(HOST_LAYER)),
        ["Sources/WenshuApp/Features/Connection"],
    )
    check(
        "a card that writes a feature, a shared component and the shell is one slice",
        tool.contract_errors(HOST_LAYER),
        [],
    )
    check(
        "a card that writes a feature, a shared component and the shell is no note",
        tool.contract_notes(HOST_LAYER),
        [],
    )

    # 8. A card may name SEVERAL suites in one filter, and each name counts.
    check(
        "every suite in a multi-suite filter is a named proof",
        sorted(tool.named_suites(MULTI_SUITE_FILTER)),
        ["AdaptiveLayoutTests", "ClientShellTests"],
    )
    check(
        "a card naming a suite in a multi-suite filter is not asked for it again",
        tool.contract_errors(MULTI_SUITE_FILTER),
        [],
    )

    print()
    if FAILURES:
        print(f"FAILED: {len(FAILURES)} case(s)")
        for name in FAILURES:
            print(f"  - {name}")
        return 1
    print("all cases passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
