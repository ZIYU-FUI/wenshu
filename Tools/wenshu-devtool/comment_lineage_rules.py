#
#  comment_lineage_rules.swift · Wenshu
#
#  The rule tables of the comment-lineage judge, in ONE home.
#
#  Why: the judge used to carry its tables and its machinery in one
#  file, and the file grew past the 600-LOC cap the repository sets
#  (= a ratchet: the next lane's first commit trips it). = The tables
#  and the machinery are two concerns, = so the tables live here, = and
#  the judge imports them. = One rule, one reader: = the family table,
#  the honest-form list and the canonical regex are read from HERE, =
#  so no second copy can disagree with the first.
#
#  What: the vendor-parity family (= the product names, = the parity
#  cues, = the label), and the honest-form markers (= the shapes that
#  make a vendor sentence honest).
#
#

import re

# The product family. = A name with no comparison is a mention, not a
# parity claim: no name match can tell an API fact from a design
# justification, so both halves have to be there.
VENDOR_NAMES = (
    r"\bApple\b|\bPages\b|\bTextEdit\b|\bXcode\b|\bVSCode\b|\bSlack\b|\bDiscord\b"
    r"|\bChatGPT\b|\bClaude\b|\bBackyard[- ]Birds\b|\bFinder\b|\bMail\b|\bMessages\b"
    r"|\bNotes\b|\bNumbers\b|\bKeynote\b|\bFreeform\b|\bPreview\b|\bSafari\b"
    r"|\bReminders\b|\bCalendar\b|\bPhotos\b|\bMusic\b"
)
VENDOR_PARITY = (
    r"same UX as|same as the|same as|matches the|the standard|parity|as the .* app"
    r"|reference width|like the|as wide|-style\b"
)
VENDOR_LABEL = "vendor parity claim (unverifiable comparison)"
VENDOR_RX = re.compile(rf"(?=.*(?:{VENDOR_NAMES}))(?=.*(?i:{VENDOR_PARITY}))")

# The honest forms are exempt, and the exemption is keyed on a
# CHECKABLE MARKER, never on a vendor's name: a name is what every
# claim about the vendor carries, so a name-keyed list rescues every
# claim. = The markers are a source that can be opened, an explicit
# denial, an SDK symbol that states what the platform ships, or the
# repository's own rule.
#
# **=> A MARKER NAMES SOMETHING A READER CAN OPEN, = = OR IT DENIES
# THE PARITY ITSELF.** = An open-ended English fragment (= "unlike",
# "ships no", "was never", "figure exists", "no such") exempts any
# claim that happens to contain it, = and a tool's name (= "hermes ")
# is not a source at all. = So those shapes are GONE, = and every one
# of them has a violating arm in the battery (= so the tightening is
# pinned by the battery, = not by this comment).
VENDOR_HONEST = (
    "https://", "quoted below", "header says", "swiftinterface:",
    "not a vendor", "no vendor", "never claimed", "not parity", "no parity",
    "withdrawn", "does not match", "does not hold", "does not exist",
    "not a real", "not paraphrased", "no page for",
    "not a standard", "not the standard", "not a copy",
    "no apple number", "no apple gradient", "no apple api", "nothing about this row",
    "localizederror", "nsbutton", "buttonstyle", "redacted(reason", "dropdestination",
    "equatableview", "nsimage:", "nscolor", "progressview", "reveal-in-finder",
    "indeterminate progress indicator", "reverse-dns",
    "button-style precedence", "agents.md 1.17",
)
HONEST_MARKERS = VENDOR_HONEST

# The marker is the URL itself and not a prefix of it (= the scheme is
# optional here).
URL_RX = re.compile(r"\b[\w-]+(?:\.[\w-]+)*\.(?:com|org|net|dev|io|gov|edu)(?:/\S*)?", re.I)


def has_honest_marker(text):
    """A checkable marker in the text (= a source that can be opened, an explicit
    denial, an SDK symbol, the repository's own rule). The marker is
    what makes a vendor sentence honest, so the exemption hangs on it alone."""
    low = text.lower()
    if any(m in low for m in VENDOR_HONEST):
        return True
    return bool(URL_RX.search(text))
