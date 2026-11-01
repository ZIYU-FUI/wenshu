#!/usr/bin/env python3
"""
agents_gate.py - the AGENTS.md contract gate: is this file still loadable and true?

One question, one gate:

  CONTRACT  does AGENTS.md still parse, still fit the context-file budget, still
            point only at things that exist, and still keep its rule ids and its
            section ids in order?

WHY THE GATE EXISTS (measured 2026-10-27, before this gate landed):

  - The Hermes context loader truncates a context file above ITS cap
    (= hermes_cli/agent/prompt_builder.py: an explicit
    `context_file_max_chars` in the config wins, else
    max(20_000, min(window * 4 * 0.06, 500_000))).
    A truncated AGENTS.md loses its tail silently: the file still parses, the
    session still starts, and the last rules simply are not there.
    Measured 2026-10-31: with a 1M-token model the loader's cap is 240,000
    chars, so this gate used to refuse growth the loader would accept (= it
    checked the loader's FLOOR and called it the cap). It now reads the
    loader's own source of truth and falls back to the floor with a clear
    message when it cannot read it.
  - The old rule 10.4 promised a tool named `validate.py`. That file has
    never existed in this repository, so the rule was a false guarantee: it
    read as "a machine checks this" and checked nothing. This gate is the
    tool the rule now names, and it checks what the rule promised.
  - Eight of the old file's enforcement columns named skills that have never
    existed upstream (wenshu-pollution-defense, wenshu-comment-policy,
    wenshu-humanizer-voice, wenshu-stale-test-cleanup, wenshu-dead-code-cleanup,
    wenshu-agent-boss-same-build-protocol, wenshu-commit-history-hygiene,
    wenshu-app-build-pipeline), and rule 1.1 pointed at
    .hermes/cjk_comment_audit.txt, which does not exist either. A rule that
    points at a missing thing teaches the reader that the reference system is
    not checked.
  - The rule ids were contiguous, but two of them said the same thing in two
    places (rule 1.7 and rule 1.11 both described the NFI registry = the
    reader has to guess which one wins), and the step ids in section 8 ran
    in a different order than the steps execute (the table read 8.1..8.10
    while the preamble ran 8.8 -> 8.9 -> 8.1 -> ... -> 8.7, so a number
    meant 'position in the table', not 'position in the run'). None of that
    is a crash. All of it is drift.

WHAT THE GATE CHECKS

  1. frontmatter   parses as YAML, and carries name / version / description
  2. budget       the file as the loader loads it (<= 20,000 chars, frontmatter
                  and the section label included = what gets truncated)
  3. references   every file path the file names exists, and every skill it
                  names is installed
  4. vocabulary   CJK appears only in the rules that enumerate the vocabulary
                  (1.2 / 1.3 / 1.4), and only as a token from that vocabulary
  5. ids          the rule ids of each section are contiguous, no row id is
                  duplicated, and every internal section reference resolves
  6. structure    the required sections are present and non-empty

USAGE
    python3 Tools/wenshu-devtool/agents_gate.py --file AGENTS.md
    python3 Tools/wenshu-devtool/agents_gate.py --file AGENTS.md --json
    python3 Tools/wenshu-devtool/agents_gate.py --file AGENTS.md --plan

Exit code 0 = the file is loadable and true, 1 = a contract error,
2 = the file could not be read.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import product_lines  # noqa: E402  (sibling module, same directory)

REPO = Path(__file__).resolve().parent.parent.parent

# The Hermes context-file cap. The loader truncates above it, so a file at
# the cap is a file whose tail may be cut.
#
# 20,000 is NOT the loader's cap: it is the FLOOR of the loader's dynamic
# cap (= `agent/prompt_builder.py`: max(20_000, min(window * 4 * 0.06,
# 500_000))), and the loader reads an explicit `context_file_max_chars`
# from the config FIRST. Measured 2026-10-31: with a 1M-token model the
# loader's cap is 240,000 chars, so a gate that hardcodes 20,000 refuses
# growth the loader would accept.
#
# So the gate asks the loader's own source of truth (the config), and
# falls back to the floor with a clear message when it cannot read it.
CONTEXT_FILE_FLOOR_CHARS = 20_000


def _hermes_config_path() -> Path:
    """THE ONE config file the loader reads, resolved the way IT resolves it.

    The loader reads EXACTLY one file: ``get_config_path()`` =
    ``get_hermes_home() / "config.yaml"`` (hermes_cli/config.py:433-435),
    merged alone with DEFAULT_CONFIG (config.py:2248-2262). A profile
    does NOT inherit the root's config: measured under
    ``HERMES_HOME=<root>/profiles/<name>``, a root-only key reads the
    default and the profile's own key reads the profile's value.

    The loader's home resolution is ``get_process_hermes_home()`` ->
    ``_expand_hermes_home`` (hermes_constants.py:52-54) =
    ``Path(os.path.expanduser(os.path.expandvars(path)))``, and with no
    ``HERMES_HOME`` it is ``_platform_default_hermes_home``
    (hermes_constants.py:57-69) = ``user_home()/(".hermes" +
    HERMES_DATA_DIR_SUFFIX)``.

    So the gate resolves it the same way. A search list let the gate
    report a number the loader will never use (= at MiniMax-M2.x's
    204,800-token window the loader's dynamic cap is 49,152 while the
    root's pin says 240,000, so the gate would be 190,848 LOOSER and
    would accept a file the loader truncates in the middle), and a
    literal path let it read a file that does not exist (= a FALSE RED:
    under ``HERMES_HOME='~/.hermes'`` the loader reads
    ``/Users/<user>/.hermes/config.yaml`` and the gate read the literal
    ``~/.hermes/config.yaml``, so it fell back to the floor and
    rejected a file the loader loads whole).
    """
    home = os.environ.get("HERMES_HOME")
    if home:
        base = Path(os.path.expanduser(os.path.expandvars(home)))
    else:
        suffix = os.environ.get("HERMES_DATA_DIR_SUFFIX", "")
        if sys.platform == "win32":
            local = os.environ.get("LOCALAPPDATA", "").strip()
            base = (
                Path(local) if local else Path.home() / "AppData" / "Local"
            ) / ("hermes" + suffix)
        else:
            base = Path.home() / (".hermes" + suffix)
    return base / "config.yaml"


def _pinned_context_file_cap() -> tuple[int, str] | None:
    """The cap the config pins, and the file it came from.

    THE LOADER'S OWN RULE, and only that rule: it honors the pin when
    the MERGED config value is an int or a float (agent/prompt_builder.py
    :1054: ``int(val) if isinstance(val, (int, float)) and val > 0``).

    So the gate parses the config the way the loader parses it, and
    honors the pin under the same condition. That decides three forms
    the loader decides:

    * ``240000`` = an int = honored.
    * ``"240000"`` = a STRING = inert (= the loader falls back to its
      dynamic cap, so a gate that honored it would be LOOSER than the
      loader and would accept a file the loader truncates in the
      middle).
    * ``${VAR}`` = a STRING after the expansion (= the expansion
      substitutes into the parsed text, it does not re-type it) = inert.
    * ``240000 # a comment`` = an int = honored (= the YAML parser strips
      the comment, and a regex that swallowed it would lose the pin and
      fall back to the floor = a false red).

    The key is TOP LEVEL, the way the loader reads it (= a top-level
    lookup in the merged config). An indented key (= a key nested under
    `agent:`) is NOT the one the loader reads, and Hermes' own CLI says
    so: "is not a recognized config key".
    """
    path = _hermes_config_path()
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        # A config that is not valid UTF-8 is not a reason to die: the
        # loader reads it (and falls back), so the gate answers too.
        return None
    # THE LOADER'S OWN PARSER, and only that: the loader parses the
    # user's config with ruamel (= hermes_yaml), so the gate does too.
    # Ruamel REJECTS a duplicate key, and its YAML 1.2 scalars differ
    # from PyYAML's YAML 1.1 (= `yes` is a string here and a boolean
    # there), so a different parser is a different answer.
    verdict, pin = _loader_honored_pin(path)
    if verdict == "pinned":
        return pin, str(path)
    if verdict == "no-pin":
        # The loader's parser RAN and the loader has no pin in this file
        # (= the key is absent, the value is not an int, or the parser
        # REJECTED the file). The text fallback must NOT run here: it is
        # LINE-based, so it would read a pin out of a file the loader
        # cannot read, and that is the LOOSER direction.
        return None
    # No loader parser on this machine: read the text, and only an
    # UNQUOTED integer (= the form the loader honors). A bare None (= NOT
    # a 2-tuple whose first element is None: a 2-tuple is truthy, so
    # `if pinned:` would be True and the cap would become None).
    value = _pinned_from_text(text)
    return (value, str(path)) if value is not None else None


def _loader_honored_pin(path: Path) -> tuple[str, int | None]:
    """The loader's verdict on this file: ('pinned', n) | ('no-pin', None)
    | ('no-parser', None).

    The loader parses the user's config with `hermes_yaml` (= YAML 1.1,
    so `yes` IS a boolean there) and applies the loader's own condition
    (= honored only when the value is an int or a float; `bool` IS a
    subclass of `int`, so the loader honors `true` as 1).

    The verdict is TRI-STATE, and the difference matters:

    * 'pinned' = the parser ran and the loader honors this value.
    * 'no-pin' = the parser ran and the loader has NO pin: the key is
      absent, the value is not an int, OR THE PARSER REJECTED THE FILE
      (= a duplicate key, invalid YAML, a multi-document file, a tab).
      A file the loader cannot read has no pin, so the text fallback
      must NOT run on it: honoring a pin there is the LOOSER direction
      (= the gate accepts a file the loader truncates in the middle).
    * 'no-parser' = no loader parser is available on this machine, so
      the text fallback is the only reader left.

    The parser is not importable from every interpreter, so it also runs
    through the same interpreter search the YAML reader uses.
    """
    script = (
        "import sys;sys.path.insert(0,'/Volumes/ANAN/.hermes/hermes-agent');"
        "from hermes_yaml import safe_load;\n"
        "try:\n"
        "    v=safe_load(open(sys.argv[1],encoding='utf-8').read())\n"
        "    raw=v.get('context_file_max_chars') if isinstance(v,dict) else None\n"
        # the loader honors the pin when the value is an int or a float
        # and it is > 0, and its cap is int(raw) (= 0 for a float in
        # (0,1)), so the PROTOCOL has to tell "no pin" apart from "an
        # honored value of 0"
        "    if not (isinstance(raw,(int,float)) and raw>0):\n"
        "        print('NOPIN')\n"
        "    else:\n"
        "        print('PIN=%d' % int(raw))\n"
        # the conversion is INSIDE the try: a value that parses and then
        # cannot be converted (= `.inf`) must not exit non-zero (= that
        # walked past every interpreter and landed on 'no-parser')
        "except Exception:\n"
        "    print('REJECTED')\n"
    )
    try:
        from hermes_yaml import safe_load  # type: ignore

        value = safe_load(path.read_text(encoding="utf-8"))
    except ImportError:
        pass
    except Exception:
        # The loader's parser REJECTED the file, so the loader has no
        # pin in it either.
        return "no-pin", None
    else:
        raw = value.get("context_file_max_chars") if isinstance(value, dict) else None
        if isinstance(raw, (int, float)) and raw > 0:
            try:
                return "pinned", int(raw)
            except (OverflowError, ValueError):
                # The loader cannot use this value either (= `.inf`),
                # so it has no pin.
                return "no-pin", None
        return "no-pin", None
    for interpreter in _hermes_pythons():
        try:
            proc = subprocess.run(
                [interpreter, "-c", script, str(path)],
                capture_output=True,
                text=True,
                timeout=60,
            )
        except (OSError, subprocess.SubprocessError):
            continue
        if proc.returncode != 0:
            continue
        out = proc.stdout.strip().splitlines()
        if not out:
            continue
        last = out[-1].strip()
        if last == "REJECTED":
            # The loader's parser REJECTED the file (= the loader has no
            # pin in it either).
            return "no-pin", None
        if last == "NOPIN":
            return "no-pin", None
        if last.startswith("PIN="):
            # An HONORED value, including 0 (= a float in (0,1) is
            # honored by the loader as int(0.5) = 0, so the loader keeps
            # nothing of the file and the gate must refuse it).
            return "pinned", int(last[4:])
    return "no-parser", None


def _pinned_from_text(text: str) -> int | None:
    """The pin read from the TEXT, for a machine with no YAML parser.

    It requires an UNQUOTED integer (= the form the loader honors), and
    the match stops at the first non-digit, so a trailing comment cannot
    swallow the pin and a quoted value is not a pin.
    """
    # The digits must be the WHOLE value (= a YAML comment may follow,
    # because the parser strips it, but `0o17` is not the number 0). The
    # loader's condition applies here too (= a value of 0 is not
    # honored, and a cap of 0 would reject every file).
    matches = re.findall(
        r"^context_file_max_chars:[ \t]*(\d+)[ \t]*(?:#.*)?$", text, re.M)
    if len(matches) != 1:
        # ZERO = no pin, and MORE THAN ONE = the loader's parser REJECTS
        # the file (= a duplicate key), so it has no pin either.
        return None
    value = int(matches[0])
    return value if value > 0 else None



def effective_context_file_cap() -> tuple[int, str]:
    """The cap the loader will really use, and where that number came from.

    The loader's own order: the explicit TOP-LEVEL config value wins,
    else the dynamic cap for the active model, else the floor. The gate
    reads the FIRST of those it can see (= the explicit value), and
    falls back to the floor, so the gate never refuses growth the loader
    accepts, and never accepts growth the loader refuses.

    The key must be the one the loader reads. Measured 2026-10-31: a pin
    nested under `agent:` is INERT (= the loader never sees it, and Hermes'
    own CLI warns "is not a recognized config key"), so the gate and the
    loader agreed only by coincidence (= the dynamic cap for a 1M-token
    model is also 240,000). Pinned at the top level, they read one
    number.
    """
    pinned = _pinned_context_file_cap()
    if pinned:
        return pinned
    return CONTEXT_FILE_FLOOR_CHARS, (
        "the loader's floor (no context_file_max_chars is pinned in the "
        "Hermes config)"
    )

# The roots a file reference may be written against. A reference is
# resolved against each of them, and it is OK when any one of them has it.
REFERENCE_ROOTS = (
    REPO,
    REPO / "Sources/WenshuApp",
    REPO / "Sources/WenshuData/Sources/WenshuData",
    REPO / "Sources/WenshuAgent/Sources/WenshuAgent",
    Path.home() / ".hermes/shared/wenshu-skills",
    Path.home(),
)

# The roots a bare file name may be found in. These are the reference
# folders, not the home directory: the search must stay fast.
BARE_NAME_ROOTS = (
    REPO / "docs",
    REPO / "Tools",
    REPO / "Sources",
    Path.home() / ".hermes/shared/wenshu-skills",
    Path.home() / ".hermes/profiles/pocock/skills",
)

# The extensions a bare file name is checked against. A bare ".json" is a
# runtime data file the app writes (shelf.json, library.json), not a
# reference in this repo, so it is not checked. A bare ".py" / ".sh" /
# ".md" is a reference: the reader will try to open it.
BARE_CHECKED_EXT = (".py", ".sh", ".md", ".swift")

# The top-level names a path may start with. A reference that starts with
# one of these is a path; anything else with a slash is a ratio ("8/18").
PATH_PREFIXES = (
    "Scripts",
    "Tools",
    "Sources",
    "Tests",
    "docs",
    "Features",
    ".github",
    ".hermes",
    "/",
    "./",
    "~",
)

# The skill families this project uses. A name with one of these prefixes
# is a promise ("this skill enforces that"), so it must resolve. A hyphenated
# English word ("cold-cache") is prose, not a promise, so it is not checked.
SKILL_PREFIXES = ("wenshu-", "pocock-", "universal-", "mattpocock", "q99-")

# The project-mandated tokens. commit_filter.py allows these in ANY file
# (= the mandate's own words), so a rule may use them anywhere.
ALLOWED_CJK_ANYWHERE = set("老板 文枢 拍 拍板 ※".split())

# The banned families. A rule has to name them to ban them, so they are
# allowed in the rows that enumerate them, and nowhere else.
# The banned family is NOT written out here: it is imported from
# commit_filter.py, which is the repo's enforcement SSOT for it (= the file
# the pre-commit and commit-msg hooks run). Writing the tokens out in a
# second file would put the very vocabulary this repo bans into a second
# place the CI pollution check has to be taught to exclude, and the two
# lists would drift apart. One list, one owner.
try:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from commit_filter import FORBIDDEN_TOKENS as _BANNED_FAMILY
except Exception:  # pragma: no cover - the family is then unbanned
    _BANNED_FAMILY = ()

ALLOWED_CJK_VOCABULARY = set(
    "可 应当 或许 可能 应该 建议 考虑 试图 尽量 大概 也许 或 任意 大概率 通常 一般来说".split()
    + list(_BANNED_FAMILY)
    + "修 改 替换 调整".split()
)

# The only rows allowed to carry the banned families.
CJK_VOCABULARY_ROWS = {"1.3", "1.4"}

CJK_RE = re.compile(r"[\u4e00-\u9fff\u3000-\u303f\uff00-\uffef]+")
BACKTICK_RE = re.compile(r"`([^`\n]+)`")
ROW_ID_RE = re.compile(r"^\|\s*(\d+(?:\.\d+)*)\s*\|", re.M)
HEADING_SECTION_RE = re.compile(r"^#{2,3}\s+§(\d+)\b", re.M)
INLINE_REF_RE = re.compile(r"§(\d+(?:\.\d+)*)")

# A backticked token that names a file: it carries a path separator that
# starts with a known top-level name, or it ends in an extension this repo
# uses. Everything else in backticks is an identifier, a flag, a ratio
# ("8/18") or a command, and is not checked for existence.
PATHLIKE_RE = re.compile(
    r"^(?:Scripts|Tools|Sources|Tests|docs|Features|\.github|\.hermes|\.{1,2}/|~)/[\w./~-]+$"
    r"|^\.[\w.-]+\.(?:py|sh|md|yml|yaml|json|swift|txt|db)$"
    r"|^[A-Za-z0-9_][\w.-]*\.(?:py|sh|md|yml|yaml|json|swift|txt|db)$"
)

# A bare file name: no path separator. It is a reference only when its
# extension says so (see BARE_CHECKED_EXT), because a bare ".json" is a
# runtime data file the app writes, not a file in this repo.
BARE_NAME_RE = re.compile(r"^[A-Za-z0-9_][\w.-]*\.[A-Za-z0-9]+$")

# A token that names a skill: lowercase words joined by hyphens. It cannot
# contain a dot (that is a file), a slash (that is a path), or an underscore
# (that is a tool call).
SKILL_NAME_RE = re.compile(r"^[a-z][a-z0-9]*(?:-[a-z0-9]+)+$")

# Identifiers that look like a skill name but are not one.
#
# The BOARD SLUGS come from the shared declaration (= product_lines), so a
# board slug is named in ONE place and every board this repo carries is
# known here. A copy of the slug list is a copy that drifts: the desktop
# slug was listed here and the mobile one was not, so a file naming the
# mobile board in a tool column was reported as naming a skill that is
# not installed (= a false error on a true reference).
NOT_A_SKILL = {
    *product_lines.BOARDS,
    "wenshu-dev",  # the implementer profile
    "wenshu-review",  # the reviewer profile
}

# The table columns whose cells name tools. A skill name in these columns
# is a promise ("this skill enforces that"), so it must resolve.
TOOL_COLUMNS = ("enforcement", "reference", "skill", "tool", "gate", "source", "path", "file")

REQUIRED_SECTIONS = ("1", "7", "8", "10")


def _strip_fenced_blocks(text: str) -> str:
    """Remove fenced code blocks, keeping the line count aligned."""
    out = []
    in_fence = False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            out.append("")
            continue
        out.append("" if in_fence else line)
    return "\n".join(out)


def split_frontmatter(text: str) -> tuple[str, str]:
    """The frontmatter block and the body. Empty frontmatter is ('', text)."""
    if not text.startswith("---"):
        return "", text
    parts = text.split("---", 2)
    if len(parts) < 3:
        return "", text
    return parts[1], parts[2]


def _hermes_pythons() -> list[str]:
    """The interpreters that can import a YAML parser, best first."""
    found: list[str] = []
    home = Path.home()
    for pattern in (
        ".hermes/installs/*/environments/*/venv/bin/python3",
        ".hermes/installs/*/environments/*/venv/bin/python",
        ".hermes/installs/*/pm-runtime/generations/*/bin/python3",
    ):
        found.extend(str(p) for p in home.glob(pattern))
    return found


def _yaml_load(block: str) -> tuple[object, str]:
    """Parse YAML. Returns (value, how): 'in-process', 'subprocess', or 'none'."""
    try:
        from hermes_cli.config import yaml as hermes_yaml  # type: ignore

        return hermes_yaml.safe_load(block), "in-process"
    except Exception:
        pass
    try:
        import yaml as pyyaml  # type: ignore

        return pyyaml.safe_load(block), "in-process"
    except Exception:
        pass
    script = (
        "import sys;sys.path.insert(0,'/Volumes/ANAN/.hermes/hermes-agent');"
        "from hermes_cli.config import yaml;"
        "import json;print(json.dumps(yaml.safe_load(sys.stdin.read())))"
    )
    for interpreter in _hermes_pythons():
        try:
            proc = subprocess.run(
                [interpreter, "-c", script],
                input=block,
                capture_output=True,
                text=True,
                timeout=60,
            )
        except (OSError, subprocess.SubprocessError):
            continue
        if proc.returncode == 0:
            try:
                return json.loads(proc.stdout), "subprocess"
            except json.JSONDecodeError:
                continue
    return None, "none"


def _installed_skills() -> set[str]:
    """The names of the skills installed for this profile, plus the shared ones."""
    names: set[str] = set()
    roots = [
        Path.home() / ".hermes/profiles/pocock/skills",
        Path.home() / ".hermes/skills",
        Path.home() / ".hermes/shared/wenshu-skills",
    ]
    for root in roots:
        if not root.is_dir():
            continue
        for skill_md in root.rglob("SKILL.md"):
            names.add(skill_md.parent.name)
    return names


def _resolve_reference(token: str) -> bool:
    """Whether a file reference names something that exists."""
    if token.startswith("~/"):
        candidates = [Path.home() / token[2:]]
    else:
        candidates = [root / token for root in REFERENCE_ROOTS]
    if any(candidate.exists() for candidate in candidates):
        return True
    # A bare file name may name a file inside a skill's references/ folder.
    # The search runs only over the reference folders: an unbounded walk of
    # the home directory takes minutes and finds nothing a rule would name.
    if "/" not in token and token.endswith(BARE_CHECKED_EXT):
        for root in BARE_NAME_ROOTS:
            if not root.is_dir():
                continue
            for hit in root.glob("**/" + token):
                if hit.is_file():
                    return True
    return False


def _backticked_tokens(text: str) -> list[tuple[str, bool]]:
    """Every backticked token, with whether it sits inside a fenced block."""
    tokens: list[tuple[str, bool]] = []
    in_fence = False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        for token in BACKTICK_RE.findall(line):
            tokens.append((token, in_fence))
    return tokens


def _table_rows(text: str) -> list[tuple[list[str], list[str]]]:
    """Every markdown table as (header cells, body rows)."""
    tables: list[tuple[list[str], list[str]]] = []
    header: list[str] | None = None
    rows: list[str] = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped.startswith("|"):
            if header is not None:
                tables.append((header, rows))
            header = None
            rows = []
            continue
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        if all(re.fullmatch(r":?-{2,}:?", c) for c in cells if c):
            continue  # the separator row
        if header is None:
            header = cells
        else:
            rows.append("|".join(cells))
    if header is not None:
        tables.append((header, rows))
    return tables


def _tool_column_cells(text: str) -> list[str]:
    """The cells of the columns that name tools, across every table."""
    cells: list[str] = []
    for header, rows in _table_rows(text):
        for index, name in enumerate(header):
            if not any(marker in name.lower() for marker in TOOL_COLUMNS):
                continue
            for row in rows:
                parts = row.split("|")
                if index < len(parts):
                    cells.append(parts[index])
    return cells


def _bare_tokens(cell: str) -> list[str]:
    """The tokens of a cell, with the backticks and trailing punctuation off.

    A leading dot is kept: ".hermes.md" is a dotfile, "hermes.md" is not.
    """
    raw = BACKTICK_RE.sub(r"\1", cell)
    tokens = []
    for token in raw.split():
        # Leading brackets are punctuation; a leading dot is a dotfile.
        token = token.lstrip("()[]").rstrip(".,;:()[]")
        if token:
            tokens.append(token)
    return tokens


def _is_reference(token: str) -> bool:
    """Whether a token is a file reference the reader would try to open."""
    if PATHLIKE_RE.match(token):
        if "/" not in token and token.endswith(BARE_CHECKED_EXT):
            return True
        if "/" in token:
            return True
        # A bare ".json" / ".yml" is a config or data file, not a reference.
        return token.endswith((".py", ".sh", ".md", ".swift"))
    if BARE_NAME_RE.match(token):
        return token.endswith(BARE_CHECKED_EXT)
    return False


def check_file(path: Path) -> dict:
    """The contract verdict for one AGENTS.md."""
    errors: list[str] = []
    warnings: list[str] = []

    if not path.is_file():
        return {
            "file": str(path),
            "errors": [f"the file does not exist: {path}"],
            "warnings": [],
            "ok": False,
        }

    text = path.read_text(encoding="utf-8")
    front, body = split_frontmatter(text)
    body = body.lstrip("\n")
    body_len = len(body)
    # The loader truncates the WHOLE file, not the body: _context_section
    # wraps the raw content (frontmatter included = only .hermes.md gets
    # its frontmatter stripped) in "## <label>\n\n", then applies the cap.
    # So the number that decides truncation is len(raw) + the label, and
    # measuring the body alone lets a file through that the loader cuts
    # in the middle (= the rules in the middle silently vanish).
    loaded_len = len(text) + len(f"## {path.name}\n\n")

    # 1. frontmatter
    meta = None
    how = "none"
    if not front.strip():
        errors.append("no frontmatter: the file needs a YAML header")
    else:
        meta, how = _yaml_load(front)
        if meta is None:
            if how == "none":
                warnings.append(
                    "no YAML parser was available: the frontmatter was not machine-checked"
                )
            else:
                errors.append("the frontmatter does not parse as YAML")
        elif not isinstance(meta, dict):
            errors.append("the frontmatter is not a mapping")
        else:
            for key in ("name", "version", "description"):
                if not meta.get(key):
                    errors.append(f"the frontmatter has no {key}")

    # 2. budget
    cap, cap_source = effective_context_file_cap()
    if loaded_len > cap:
        errors.append(
            f"the file loads as {loaded_len} chars ({len(text)} in the file + "
            f"{loaded_len - len(text)} for the section label): the context loader "
            f"truncates above {cap} (= {cap_source}), and it drops the MIDDLE "
            f"of the file (= the rules in the middle silently vanish)"
        )

    # 3. references
    #    (a) every backticked path, anywhere in the file
    for token, in_fence in _backticked_tokens(text):
        if in_fence:
            continue
        token = token.strip().lstrip("()[]").rstrip(".,;:()[]")
        if _is_reference(token) and not _resolve_reference(token):
            errors.append(f"the file names a path that does not exist: {token}")

    #    (b) every path in any table cell, backticked or not. A file name
    #        in prose is still a reference the reader will try to open.
    for header, rows in _table_rows(text):
        for row in rows:
            for token in _bare_tokens(row):
                if not _is_reference(token):
                    continue
                if not _resolve_reference(token):
                    errors.append(f"the file names a path that does not exist: {token}")

    #    (c) every skill, backticked anywhere, or bare in a tool column
    skills = _installed_skills()
    candidates: set[str] = set()
    for token, in_fence in _backticked_tokens(text):
        if not in_fence:
            candidates.add(token.strip())
    for cell in _tool_column_cells(text):
        candidates.update(_bare_tokens(cell))
    for token in sorted(candidates):
        if token in NOT_A_SKILL:
            continue
        if not SKILL_NAME_RE.match(token):
            continue
        if not token.startswith(SKILL_PREFIXES):
            continue  # a hyphenated English word, not a skill promise
        if token not in skills:
            errors.append(f"the file names a skill that is not installed: {token}")

    # 4. vocabulary
    row_id = ""
    for line in text.splitlines():
        match = ROW_ID_RE.match(line)
        if match:
            row_id = match.group(1)
        elif line.startswith("#"):
            row_id = ""
        for match in CJK_RE.finditer(line):
            run = match.group(0)
            if run in ALLOWED_CJK_ANYWHERE:
                continue
            if row_id in CJK_VOCABULARY_ROWS and run in ALLOWED_CJK_VOCABULARY:
                continue
            errors.append(f"CJK outside the vocabulary rules: {run}")
            break

    # 5. ids
    ids: list[str] = [m.group(1) for m in ROW_ID_RE.finditer(body)]
    for dup in sorted({i for i in ids if ids.count(i) > 1}):
        errors.append(f"the rule id {dup} is used more than once")

    by_section: dict[str, list[str]] = {}
    for row in ids:
        by_section.setdefault(row.split(".")[0], []).append(row)
    for head, rows in sorted(by_section.items(), key=lambda kv: int(kv[0])):
        numbers = [int(r.split(".")[-1]) for r in rows]
        if len(numbers) == 1 and "." not in rows[0]:
            continue
        if numbers != list(range(1, len(numbers) + 1)):
            errors.append(f"the rule ids in section {head} are not contiguous: {rows}")

    sections = {m.group(1) for m in HEADING_SECTION_RE.finditer(body)}
    known = set(ids)
    for match in INLINE_REF_RE.finditer(_strip_fenced_blocks(body)):
        ref = match.group(1)
        if "." not in ref:
            # A section reference: it must name a section that exists.
            if ref not in sections:
                errors.append(f"the file references a section that does not exist: §{ref}")
            continue
        if ref not in known:
            errors.append(f"the file references a rule id that does not exist: §{ref}")

    # 6. structure
    for required in REQUIRED_SECTIONS:
        if required not in sections:
            errors.append(f"the section §{required} is missing")

    return {
        "file": str(path),
        "body_chars": body_len,
        "loaded_chars": loaded_len,
        "budget": effective_context_file_cap()[0],
        "headroom": effective_context_file_cap()[0] - loaded_len,
        "frontmatter_checked": how,
        "rule_rows": len(ids),
        "errors": errors,
        "warnings": warnings,
        "ok": not errors,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--file", default="AGENTS.md", help="the file to check")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    parser.add_argument("--plan", action="store_true", help="print the contract table")
    args = parser.parse_args(argv)

    if args.plan:
        print("=== the AGENTS.md contract ===")
        print()
        print("frontmatter   parses as YAML, and carries name / version / description")
        cap, source = effective_context_file_cap()
        print(f"budget       the file as the loader loads it <= {cap} chars (= {source})")
        print("references   every named path exists; every named skill is installed")
        print("vocabulary   CJK only in rules 1.2 / 1.3 / 1.4, and only as a known token")
        print("ids          the rule ids of a section are contiguous, no id repeats,")
        print("             and every internal section reference resolves")
        print("structure    the required sections are present and non-empty")
        print()
        print("A rule that points at a missing thing teaches the reader that the")
        print("reference system is not checked, so a missing path is an error here.")
        return 0

    path = Path(args.file)
    if not path.is_absolute():
        path = REPO / path
    result = check_file(path)

    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        print(f"file       {result['file']}")
        print(f"loaded     {result.get('loaded_chars')} chars (cap {result.get('budget')}, body {result.get('body_chars')})")
        if "headroom" in result:
            print(f"headroom   {result['headroom']} chars")
        for warning in result["warnings"]:
            print(f"  ~ {warning}")
        for error in result["errors"]:
            print(f"  ! {error}")
        if result["ok"]:
            print("=== the file is loadable and true ===")
        else:
            print(f"=== {len(result['errors'])} contract error(s) ===")
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
