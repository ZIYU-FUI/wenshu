#!/usr/bin/env python3
"""card_title.py = the one reader of a draft body's title.

WHY A MODULE AND NOT A LINE IN EACH GATE. Two gates classify a body file:
`ticket_tier.py` (the tier and its contract) and `effort_budget_gate.py` (the evidence
budget). Both needed the same thing, = a draft's title. One of them had a loop to read it
while the other passed an empty string, = = so a card whose title lives in the body's own
first heading was credited by one gate and charged `title carries no tier tag` by the
other. = = That is the same defect this repository already fixed for the two gates that
read a card's GATES section: = = two readers of one document, = = two answers.

THE RULE IT IMPLEMENTS. A card carries its tier in its TITLE, because the board shows the
title and not the body. A draft has no board row yet, so its title is the body's first
heading: `# [T2] The window ...` says `T2`. The tag itself is left in the returned text,
= because parsing it is the caller's business and there is already one parser for it.

WHAT IT REFUSES TO DO. It does not hunt further down the file, and it does not invent a
title from prose: = a body that opens with a paragraph has no title, = and a title
fabricated here would be a claim about a line the author never wrote.
"""

from __future__ import annotations

import re

# A CommonMark ATX heading: one to six `#`, then a space or the end of the line.
# `#foo` is NOT a heading, so it must not be read as one and have its `#` eaten.
ATX_HEADING = re.compile(r"^#{1,6}(?:\s|$)")


def title_from_body(body: str) -> str:
    """The draft's title: the text of its first heading, or the empty string."""
    for line in (body or "").splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if not ATX_HEADING.match(stripped):
            # The first real line is prose. The draft has no title, and saying so is
            # the caller's finding to make, not this function's to paper over.
            return ""
        return stripped.lstrip("#").strip()
    return ""
