#!/usr/bin/env python3
"""
session_effort_audit.py - the running-time gate: is this session producing, or looking?

One question, one gate:

  CONTRACT  does this session's own transcript show that it read its way to
            an artifact, or did it read its way to a bigger transcript?

WHY THE GATE EXISTS (measured on the wenshu board, 2026-10-27):

  The card contract (effort_budget_gate.py) bounds what a worker may read
  BEFORE it starts. This tool answers the other half: after the fact, was
  the worker's looking worth anything? It reads the session's own
  transcript and counts.

  The right-column session is the reference case. Over 4h42m it made 624
  tool calls: 387 execute_code, 87 terminal, 53 read_file, 31
  search_files, 19 tool_call, 17 vision_analyze, 16 skill_view. It wrote
  no file and created no card. Of its 387 execute_code calls, 97 queried
  its own history (state.db, kanban.db, agent.log, session_search)
  instead of the code. It cost 2,861,026 input tokens, 1,470,842 output
  tokens and 61,162,861 cache-read tokens, against a median worker
  session's 244,012 input tokens: 12x, for nothing.

  Three mechanisms drove it, and each has a number here:

    1. THE REPEAT. 113 of the session's tool messages were byte-identical
       duplicates of another tool message. One execute_code output was
       written 14 times over 1h17m. Tool messages are not compressed, so
       every repeat is re-read and re-paid on every later turn.

    2. THE RECOVERY. The session hit "Operation interrupted" 5 times, each
       one a turn that had to be re-planned from a transcript that had
       already lost the work.

    3. THE RESTART. Two pairs of assistant messages in the transcript are
       byte-identical, one pair 8 minutes apart. The same planning sentence
       was written twice because the session lost the first one and wrote
       it again.

  So the tool reports four numbers per session, and one verdict:

    calls        total tool calls
    reads        calls that read the code (read_file, search_files, terminal
                 and execute_code that touch the repo tree)
    history      calls that read the worker's own past (execute_code or
                 terminal against state.db, kanban.db, agent.log, session
                 search, worktree listings)
    writes       calls that write a file, create a card, or post a comment
    repeats      tool messages that duplicate an earlier one byte for byte
    restarts     assistant messages that duplicate an earlier one

  A session with writes == 0 and history > reads has the shape of the
  right-column session, whatever it was working on. A session with
  history >= 0.5 * calls is looking at its own past rather than the code.

  It also reports the FAN-OUT of one parent session, which is where the
  money goes. The audit of 2026-10-24 (session 20261024_193219_f0d8b8)
  opened 11 subagents in 71 minutes against 7 distinct areas of the
  tree. The subagents re-read each other's ground: 624 distinct files
  were read 2132 times, a factor of 3.4, and
  EditorChatNSController.swift was read by all 11. The parent spent
  441,256,206 cache-read tokens on its own, the subagents 195,089,989
  between them, and the parent's cache was of no use to them: the parent
  ran on one model and the children on another, so the system prompt
  hash differed and the provider's prompt cache, which matches on a
  prefix, could not be shared.

  So the fan-out report names three things a card can fix:

    overlap      the same file read by more than one session of the tree
    duplicate    two subagents given the same goal
    cold cache   a child whose model differs from its parent's, so the
                 parent's cache is unavailable to it

WHAT THE TOOL DOES NOT DO:

  It does not judge the quality of a session. A long session that writes a
  lot is fine, however long it ran. It reports the shape, and the shape is
  what the card contract and the board's budgets are set against.

Usage:
    session_effort_audit.py --session ID       one session, by id
    session_effort_audit.py --card ID           the session that ran a card
    session_effort_audit.py --profile NAME      every session of a profile
    session_effort_audit.py --json              machine-readable output

Exit code 0 = the session shows production, 1 = the session is looking
without producing, 2 = the session could not be read.
"""
from __future__ import annotations

import argparse
import collections
import json
import re
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import product_lines  # noqa: E402  (sibling module, same directory)

PROFILE_ROOT = Path.home() / ".hermes/profiles"
BOARD_DB = Path(product_lines.board_db())

# Tools that read the code.
CODE_READERS = ("read_file", "search_files", "terminal", "execute_code")

# Writes. A session that produces must use one of these.
WRITERS = ("write_file", "patch", "kanban_create", "kanban_comment",
           "kanban_complete", "kanban_request_review", "kanban_attach")

# The words in a tool call's arguments that mean "look at your own past".
# These are the READ-ONLY stores of the agent's own past. A call that
# mentions "worktree" is not necessarily history: `git worktree remove` is
# an action on the repo, so the markers below are the stores themselves,
# not the operations on them.
HISTORY_MARKERS = (
    "state.db",
    "kanban.db",
    "agent.log",
    "errors.log",
    "session_search",
    "message_fts",
    "task_events",
    "task_runs",
)

# The tools that can be asked to look at the past.
HISTORY_TOOLS = ("execute_code", "terminal", "session_search")


def _profile_db(profile: str) -> Path:
    return PROFILE_ROOT / profile / "state.db"


def _session_of_card(card_id: str) -> tuple[str | None, str | None]:
    """Return (profile, session_id) for the session that ran a card."""
    if not BOARD_DB.exists():
        return None, None
    conn = sqlite3.connect(f"file:{BOARD_DB}?mode=ro", uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    row = conn.execute(
        "SELECT profile, metadata FROM task_runs WHERE task_id = ? "
        "ORDER BY id DESC LIMIT 1",
        (card_id,),
    ).fetchone()
    conn.close()
    if row is None:
        return None, None
    try:
        meta = json.loads(row["metadata"] or "{}")
    except (TypeError, ValueError):
        meta = {}
    return row["profile"], meta.get("worker_session_id")


def _tool_calls(message: str) -> list[dict]:
    try:
        arr = json.loads(message or "[]")
    except (TypeError, ValueError):
        return []
    return [c for c in arr if isinstance(c, dict)]


def _is_history_call(name: str, arguments: str) -> bool:
    """Does this call read the worker's own past rather than the code?"""
    if name not in HISTORY_TOOLS:
        return False
    # The tool that IS the history is a history call whatever it is asked
    # for. The first cut of this tool looked only at the ARGUMENTS, so a
    # session_search call whose query was a plain word scored zero history
    # calls, and the count that names the right-column session (97) was 86.
    if name == "session_search":
        return True
    blob = (arguments or "").lower()
    return any(marker in blob for marker in HISTORY_MARKERS)


def _is_write_call(name: str, arguments: str) -> bool:
    """Does this call produce something?

    The judge is the CALL, never the text. A session that discusses
    write_file, or whose Python source happens to contain the word, has not
    written anything. The right-column session scored 69 "writes" under a
    text match and wrote nothing at all, so the test here is on the tool's
    identity: a tool whose name says it writes, plus the one shell form
    that writes by definition.

    A terminal call counts when it commits, because a commit is the
    artifact. An execute_code call does NOT count on the strength of its
    source text: the same word appears in a query that asks whether a file
    exists, and a false write is a false production.
    """
    if name in WRITERS:
        return True
    if name == "terminal":
        return bool(re.search(r"\bgit\s+commit\b", arguments or ""))
    return False


def _digest(text: str) -> str:
    import hashlib

    return hashlib.md5((text or "").strip().encode("utf-8", "replace")).hexdigest()


def audit_session(profile: str, session_id: str) -> dict:
    """Audit one session. Return the report."""
    db = _profile_db(profile)
    if not db.exists():
        return {
            "session": session_id,
            "profile": profile,
            "error": f"no state.db for profile {profile}",
        }
    try:
        conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=30)
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            "SELECT id, role, content, tool_calls, tool_name, timestamp "
            "FROM messages WHERE session_id = ? ORDER BY id",
            (session_id,),
        ).fetchall()
        usage = conn.execute(
            "SELECT sum(input_tokens) i, sum(output_tokens) o, sum(api_call_count) ac "
            "FROM session_model_usage WHERE session_id = ? AND task = ''",
            (session_id,),
        ).fetchone()
        conn.close()
    except sqlite3.Error as exc:
        return {
            "session": session_id,
            "profile": profile,
            "error": f"could not read the transcript: {exc}",
        }

    calls = 0
    reads = 0
    history = 0
    writes = 0
    tool_digests: dict[str, int] = collections.Counter()
    assistant_digests: dict[str, int] = collections.Counter()
    tool_messages = 0
    repeated_tool_messages = 0
    repeated_assistant_messages = 0
    names: collections.Counter = collections.Counter()

    for row in rows:
        role = row["role"]
        if role == "tool":
            tool_messages += 1
            digest = _digest(row["content"] or "")
            tool_digests[digest] += 1
            if tool_digests[digest] == 2:
                repeated_tool_messages += 1
            continue
        if role != "assistant":
            continue
        text = row["content"] or ""
        if len(text.strip()) > 20:
            digest = _digest(text)
            assistant_digests[digest] += 1
            if assistant_digests[digest] == 2:
                repeated_assistant_messages += 1
        for call in _tool_calls(row["tool_calls"]):
            fn = call.get("function", {}) or {}
            name = fn.get("name", "")
            args = fn.get("arguments", "") or ""
            calls += 1
            names[name] += 1
            if name in CODE_READERS:
                reads += 1
            if _is_history_call(name, args):
                history += 1
            if _is_write_call(name, args):
                writes += 1

    input_tokens = usage["i"] or 0 if usage else 0
    output_tokens = usage["o"] or 0 if usage else 0
    api_calls = usage["ac"] or 0 if usage else 0

    report = {
        "session": session_id,
        "profile": profile,
        "messages": len(rows),
        "calls": calls,
        "reads": reads,
        "history": history,
        "writes": writes,
        "repeats": repeated_tool_messages,
        "restarts": repeated_assistant_messages,
        "tool_messages": tool_messages,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "api_calls": api_calls,
        "top_tools": names.most_common(6),
    }
    report["verdict"], report["why"] = _verdict(report)
    return report


def _files_in_session(conn, session_id: str) -> set[str]:
    """The .swift files this session's transcript names."""
    import re as _re

    files: set[str] = set()
    rows = conn.execute(
        "SELECT tool_calls, content FROM messages WHERE session_id = ?", (session_id,)
    ).fetchall()
    for row in rows:
        blob = (row["tool_calls"] or "") + " " + (row["content"] or "")
        for match in _re.finditer(r"(Sources/[A-Za-z0-9_/]+\.swift)", blob):
            files.add(match.group(1))
    return files


def _delegated_goals(conn, session_id: str) -> tuple[list[tuple[float, str]], int]:
    """The goals this session handed to subagents, in order.

    A goal is what the parent SAYS the child will do. Two children given
    the same goal are doing the same job, whatever they end up writing.
    """
    import json as _json

    goals: list[tuple[float, str]] = []
    empty = 0
    # A child with an EMPTY goal is a child with no scope, and a batch of
    # them is the most expensive kind of fan-out: the parent pays for the
    # worker, the worker invents its own scope, and the parent's own plan
    # is not what gets built. The measured batch had 30 empty goals out of
    # 37 tasks, so the count is reported beside the overlap count.
    rows = conn.execute(
        "SELECT timestamp, tool_calls FROM messages "
        "WHERE session_id = ? AND role = 'assistant' AND tool_calls LIKE '%delegate_task%' "
        "ORDER BY id",
        (session_id,),
    ).fetchall()
    for row in rows:
        try:
            calls = _json.loads(row["tool_calls"] or "[]")
        except (TypeError, ValueError):
            continue
        for call in calls:
            fn = call.get("function", {}) or {}
            if fn.get("name") != "delegate_task":
                continue
            try:
                args = _json.loads(fn.get("arguments") or "{}")
            except (TypeError, ValueError):
                args = {}
            for task in args.get("tasks") or []:
                goal = (task.get("goal") or "").strip()
                if goal:
                    goals.append((row["timestamp"] or 0.0, goal))
                else:
                    empty += 1
    return goals, empty


def _goal_scope(goal: str) -> str:
    """The area a goal names, so two goals can be compared for overlap.

    "Read EVERY .swift file in Sources/WenshuApp/Features/Agent/ (113
    files) ..." and the same sentence with a different directory are
    different jobs. The same sentence with the SAME directory is the same
    job, and that is the case worth catching.
    """
    import re as _re

    # An AREA is a directory tree, and it is cut at the FEATURE segment:
    # "Sources/WenshuApp/Features/Editor" covers
    # "Features/Editor/ and Features/Cover/" and
    # "Features/Library/, Backup/, LibraryMigration/, Outline/" alike, so
    # two goals that name different subtrees of the same feature still
    # land on one area, which is the point.
    #
    # The cut is four segments, not three. Three segments end at
    # "Sources/WenshuApp/Features", which is every feature in the app, so
    # the first cut of this tool called every goal the same area and
    # reported no overlap at all.
    #
    # A goal that names a single FILE is not an area. Counting it as one
    # made the report list "EditorView.swift x11" beside the real areas,
    # which mixed two findings into one list and made both harder to read.
    for match in _re.finditer(r"Sources/[A-Za-z0-9_/]+", goal):
        path = match.group(0).rstrip("/")
        parts = path.split("/")
        if len(parts) >= 4:
            return "/".join(parts[:4])
        if len(parts) == 3:
            return path
        return path
    return goal[:60].strip()


def audit_fanout(profile: str, parent_session_id: str) -> dict:
    """Audit one parent session's subagents.

    Three questions, all of them about money:

      overlap    how many times the same file was read across the tree
      duplicate  how many subagents were given the same goal
      cold cache how many children ran on a model their parent did not
    """
    db = _profile_db(profile)
    if not db.exists():
        return {"parent": parent_session_id, "error": f"no state.db for {profile}"}
    conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    parent = conn.execute(
        "SELECT * FROM sessions WHERE id = ?", (parent_session_id,)
    ).fetchone()
    if parent is None:
        conn.close()
        return {"parent": parent_session_id, "error": "no such session"}
    children = conn.execute(
        "SELECT * FROM sessions WHERE parent_session_id = ? ORDER BY started_at",
        (parent_session_id,),
    ).fetchall()

    per_session = {parent_session_id: _files_in_session(conn, parent_session_id)}
    for child in children:
        per_session[child["id"]] = _files_in_session(conn, child["id"])
    goals, empty_goals = _delegated_goals(conn, parent_session_id)
    conn.close()

    scopes: collections.Counter = collections.Counter()
    for _, goal in goals:
        scopes[_goal_scope(goal)] += 1
    repeated_scopes = {k: v for k, v in scopes.items() if v > 1}

    counts: collections.Counter = collections.Counter()
    for files in per_session.values():
        for path in files:
            counts[path] += 1
    repeated = {k: v for k, v in counts.items() if v > 1}
    total_reads = sum(len(f) for f in per_session.values())

    parent_model = parent["model"]
    cold = [c["id"] for c in children if c["model"] != parent_model]

    child_input = sum(c["input_tokens"] or 0 for c in children)
    child_cache = sum(c["cache_read_tokens"] or 0 for c in children)

    report = {
        "parent": parent_session_id,
        "parent_model": parent_model,
        "parent_input": parent["input_tokens"] or 0,
        "parent_cache_read": parent["cache_read_tokens"] or 0,
        "children": len(children),
        "child_input": child_input,
        "child_cache_read": child_cache,
        "distinct_files": len(counts),
        "total_reads": total_reads,
        "waste_factor": round(total_reads / max(len(counts), 1), 2),
        "files_read_twice": len(repeated),
        "worst": sorted(repeated.items(), key=lambda kv: -kv[1])[:8],
        "cold_cache_children": len(cold),
        "cold_cache_ids": cold[:8],
        "delegated_goals": len(goals),
        "empty_goals": empty_goals,
        "distinct_scopes": len(scopes),
        "repeated_scopes": repeated_scopes,
        "duplicate_goals": sum(v - 1 for v in repeated_scopes.values()),
    }
    report["verdict"], report["why"] = _fanout_verdict(report)
    return report


def _fanout_verdict(report: dict) -> tuple[str, str]:
    """Return (verdict, why) for a fan-out report."""
    if report.get("error"):
        return "error", report["error"]
    problems = []
    if report["waste_factor"] >= 2.0:
        problems.append(
            f"{report['total_reads']} reads of {report['distinct_files']} files "
            f"({report['waste_factor']}x): the subagents read each other's ground"
        )
    if report.get("empty_goals"):
        problems.append(
            f"{report['empty_goals']} of the delegated tasks carry NO goal: "
            "the parent pays for a worker with no scope, and the worker "
            "invents one"
        )
    if report.get("duplicate_goals"):
        problems.append(
            f"{report['duplicate_goals']} of {report['delegated_goals']} delegated "
            f"goals repeat another goal's area ({len(report['repeated_scopes'])} "
            "areas opened more than once)"
        )
    if report["cold_cache_children"]:
        problems.append(
            f"{report['cold_cache_children']} of {report['children']} children ran "
            f"on a model their parent ({report['parent_model']}) did not, so the "
            "parent's prompt cache was unavailable to them"
        )
    if problems:
        return "duplicated", "; ".join(problems)
    return "clean", (
        f"{report['children']} children read {report['total_reads']} files "
        f"({report['waste_factor']}x) with no cold-cache child"
    )


def _print_fanout(report: dict) -> None:
    if report.get("error"):
        print(f"=== fan-out of {report['parent']}  ! {report['error']}")
        return
    print(f"=== fan-out of {report['parent']}  [{report['verdict']}]")
    print(
        f"    children {report['children']}   distinct files "
        f"{report['distinct_files']}   reads {report['total_reads']}   "
        f"waste {report['waste_factor']}x"
    )
    print(
        f"    parent cache-read {report['parent_cache_read']:,}   "
        f"children cache-read {report['child_cache_read']:,}"
    )
    print(
        f"    files read more than once {report['files_read_twice']}   "
        f"cold-cache children {report['cold_cache_children']}"
    )
    print(
        f"    delegated goals {report['delegated_goals']}   distinct areas "
        f"{report['distinct_scopes']}   duplicate goals "
        f"{report['duplicate_goals']}   empty goals {report.get('empty_goals', 0)}"
    )
    if report["repeated_scopes"]:
        print("    areas opened more than once:")
        for scope, count in sorted(
            report["repeated_scopes"].items(), key=lambda kv: -kv[1]
        )[:6]:
            print(f"      x{count}  {scope[:70]}")
    if report["worst"]:
        print("    files read by the most sessions:")
        for path, count in report["worst"][:6]:
            print(f"      x{count}  {path}")
    print(f"    why: {report['why']}")


def _verdict(report: dict) -> tuple[str, str]:
    """Return (verdict, why) for one report.

    The order matters. A session that wrote nothing is the case that
    matters, so the absence of writes is checked FIRST: a session can
    repeat itself and still be fine, and a session can look at its own
    past and still be fine, but a session that produced nothing is never
    fine, and the reason has to be named.

    The right-column session read 86 times out of its own past against 558
    reads of code, which is 15%. The absolute count is what tells, because
    the code reads of a big session are also big: 86 is 97 execute_code
    calls spent on the transcript instead of the code, and 97 of 624 calls
    is a sixth of the session spent asking what it already knew.
    """
    calls = report["calls"]
    if calls == 0:
        return "idle", "the session made no tool calls"
    if report["writes"] > 0:
        return "producing", f"{report['writes']} write call(s)"
    # Nothing was produced. Now say why.
    if report["history"] >= 20:
        return (
            "looking",
            f"{report['history']} calls read the session's own past "
            f"({report['history'] * 100 // max(calls, 1)}% of all calls) and "
            "nothing was written: the session is asking what it already knew "
            "instead of reading the code",
        )
    if report["restarts"] >= 2 or report["repeats"] >= 10:
        return (
            "stuck",
            f"{report['repeats']} repeated tool outputs and "
            f"{report['restarts']} repeated messages, with nothing written: "
            "the session is redoing work it already did",
        )
    return (
        "idle",
        f"{calls} calls and nothing written: the session ended without an "
        "artifact",
    )


def _print(report: dict) -> None:
    if report.get("error"):
        print(f"=== {report['session']}  ! {report['error']}")
        return
    print(f"=== {report['session']}  [{report['profile']}]  {report['verdict']}")
    print(
        f"    calls {report['calls']}   reads {report['reads']}   "
        f"history {report['history']}   writes {report['writes']}"
    )
    print(
        f"    repeats {report['repeats']}   restarts {report['restarts']}   "
        f"messages {report['messages']}"
    )
    print(
        f"    tokens in {report['input_tokens']:,}  out {report['output_tokens']:,}  "
        f"api calls {report['api_calls']}"
    )
    if report["top_tools"]:
        print("    tools: " + ", ".join(f"{n} x{c}" for n, c in report["top_tools"]))
    print(f"    why: {report['why']}")


def _sessions_of_profile(profile: str, limit: int) -> list[str]:
    db = _profile_db(profile)
    if not db.exists():
        return []
    conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=30)
    rows = conn.execute(
        "SELECT session_id FROM session_model_usage WHERE task = '' "
        "GROUP BY session_id ORDER BY sum(input_tokens) DESC LIMIT ?",
        (limit,),
    ).fetchall()
    conn.close()
    return [r[0] for r in rows]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--session", help="audit one session by id")
    parser.add_argument("--card", help="audit the session that ran a card")
    parser.add_argument(
        "--fanout",
        help="audit a parent session's subagents: overlap, duplicate goals, cold cache",
    )
    parser.add_argument("--profile", help="audit a profile's sessions")
    parser.add_argument("--limit", type=int, default=20, help="sessions per profile")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    args = parser.parse_args()

    reports: list[dict] = []
    exit_code = 0

    if args.session:
        profile = args.profile or "pocock"
        reports.append(audit_session(profile, args.session))
    elif args.fanout:
        report = audit_fanout(args.profile or "pocock", args.fanout)
        if args.json:
            print(json.dumps(report, indent=2))
        else:
            _print_fanout(report)
        return 1 if report.get("verdict") == "duplicated" else 0
    elif args.card:
        profile, session_id = _session_of_card(args.card)
        if not session_id:
            print(f"no worker session recorded for card {args.card}", file=sys.stderr)
            return 2
        reports.append(audit_session(profile or "pocock", session_id))
    elif args.profile:
        for session_id in _sessions_of_profile(args.profile, args.limit):
            reports.append(audit_session(args.profile, session_id))
    else:
        parser.error("one of --session, --card or --profile is required")

    if args.json:
        print(json.dumps(reports, indent=2))
    else:
        for report in reports:
            _print(report)
            print()

    for report in reports:
        if report.get("verdict") in ("looking", "stuck"):
            exit_code = 1
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
