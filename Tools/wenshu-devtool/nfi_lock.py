#!/usr/bin/env python3
"""ONE writer on the contended registers: a session-scoped exclusive reservation.

WHY THIS FILE EXISTS

`docs/agents/nfi.md` is the tree's own list of its unfinished work, and
every ticket that extracts a file appends a row to it (= AGENTS.md 1.7).
`OOB.md` is the boss's register of directives, and every lane that carries a
directive appends a row to it (= so it collides the same way).
The rows carry numbers (= the parent commit, the line count of the file
at the moment the row was written), so a row written against a file
another session moved at the same time is a row that states a number
that is not true of any tree (= the complaint of 2026-11-25). The
existing answer was a sentence: AGENTS.md 7.4 says "the premise of a
line number is that no other session is writing the same file". A
sentence is not a gate, and the register kept taking rows whose numbers
did not hold.

WHAT THIS MAKES TRUE

While one session holds the reservation for a file, no other session can
commit a change to that file (= the pre-commit hook added by
`nfi_lock.py install` refuses it), and no other session can take the
reservation. The hook guards every register in `GUARDED_RESOURCES`, and each
one is leased on its own (= a lease on the NFI register does not block a
commit that touches only OOB.md, = and the other way round). The holder is a SESSION, not a card and not a worktree: a
developer writes in its own worktree without a board card (= AGENTS.md
1.12), and several worktrees of one card are still one writer.

The reservation lives in the COMMON git directory
(`<git-dir>/nfi-lock/`), not in a worktree, because every worktree of
this clone is one shared state, and a lock that lives inside one of
them is a lock nobody else can see.

THE OWNER STRING

`--owner` beats everything; otherwise the first present of
HERMES_SESSION_ID, HERMES_SESSION_CHAT_ID, HERMES_KANBAN_TASK is the
owner; failing all three the owner is `tty:<uid>:<ppid>` — a machine-
local handle that keeps two terminal sessions apart but is NOT a Hermes
session id, so a human commit that must be attributed to a session
should pass `--owner` (or set HERMES_SESSION_ID) itself.

DEAD HOLDERS

A reservation is a LEASE, not a process handle: the command that takes it
exits a second later, so the process that wrote it is the wrong thing to
ask about. A lease binds while EITHER it is younger than `--ttl` (default
90 min, refreshed by `renew`, by `acquire`, and by the holder's own
commit) OR a running process carries the owner token in its environment
(= the session is alive and thinking, which is worth more than a clock).
Neither holds and the lease is void: the next taker removes it and says
so. `--hard-ttl` (default 8h) bounds even a living holder, so nothing can
freeze the register forever. A killed worker releases nothing, so a human
who knows it is dead runs `nfi_lock.py release --force`.

WHAT IS NOT GATED

A worktree whose tree predates this tool is not gated: the hook runs the
tool from the tree it commits in, and a tree without it cannot be asked
to obey it. `nfi_lock.py install --verify` prints the truth per tree.

NO SECOND READER OF THE REGISTER

This file reads and writes the reservation and nothing else. The
register's rows stay the register's business (`merge-nfi-registry.py`,
`registry_row_keys` in `registry_loc_gate.py` where that exists).

USAGE

  nfi_lock.py acquire  [path] [--owner X] [--card t_x] [--ttl SECONDS]
  nfi_lock.py renew    [path] [--owner X]
  nfi_lock.py release  [path] [--owner X] [--force]
  nfi_lock.py status   [path] [--json]
  nfi_lock.py check    [path] | --staged     # the hook's verb: 0 free/self, 3 foreign
  nfi_lock.py run      [path] -- COMMAND... # acquire, run, release
  nfi_lock.py install  | --verify           # wire the pre-commit hook

  exit 0 held/free/ok · 1 usage/IO · 2 not mine · 3 a live session holds it
"""

from __future__ import annotations

import argparse
import itertools
import json
import os
import subprocess
import sys
import time
from pathlib import Path

DEFAULT_RESOURCE = "docs/agents/nfi.md"
# The registers the pre-commit hook guards. The NFI register is one; OOB.md is
# the other contended register (= 39 commits touch it in
# `a4f094d796..97ac0dfde5`, = and two sessions that each append one entry
# CONFLICT, = measured). It is guarded by the SAME reservation, NOT by a merge
# driver, because a driver needs a key that names one row, and OOB.md's key is
# a DATE that is deliberately NOT unique: 103 rows share 45 keys (= at this
# head), and 2026-10-16 alone carries 25 rows, because that date is the handle
# a code comment looks up (= `(see OOB.md #YYYY-MM-DD)`). A key-level merge
# would collapse those 25 rows into one. The reservation needs no key at all.
GUARDED_RESOURCES = (DEFAULT_RESOURCE, "OOB.md")
DEFAULT_TTL_SECONDS = 90 * 60
DEFAULT_HARD_TTL_SECONDS = 8 * 60 * 60
MARKER = "# wenshu: nfi_lock check (installed by nfi_lock.py install)"
TAKE_ATTEMPTS = 64
# A reservation whose file exists but carries no record is a create in
# flight. The reader waits this long for the record to land before it
# calls the file a dead writer's residue (and reclaims it).
UNREADABLE_ATTEMPTS = 20
UNREADABLE_DELAY = 0.01
# Every publication names its temporary file after this counter, so two
# threads of one process never stage their content into the same file.
_PUBLISH_SEQ = itertools.count()


class LockError(Exception):
    pass


class Refused(LockError):
    """A live session that is not us holds the resource."""


def repo_root() -> Path:
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                         capture_output=True, text=True)
    if out.returncode != 0:
        raise LockError("this is not a git working tree: "
                        + out.stderr.strip())
    return Path(out.stdout.strip())


def lock_dir(explicit: str | None = None) -> Path:
    if explicit:
        return Path(explicit)
    env = os.environ.get("WENSHU_NFI_LOCK_DIR")
    if env:
        return Path(env)
    out = subprocess.run(["git", "rev-parse", "--git-common-dir"],
                         capture_output=True, text=True)
    if out.returncode != 0:
        raise LockError("cannot read the common git directory: "
                        + out.stderr.strip())
    common = Path(out.stdout.strip())
    if not common.is_absolute():
        common = Path.cwd() / common
    return common / "nfi-lock"


def record_path(dirpath: Path, key: str) -> Path:
    """One reservation file per resource, and no nested directories.

    The key is a repo-relative path, so its slashes are encoded (= "%2F")
    rather than made into folders: a resource named like another
    resource's parent directory would then be a file colliding with a
    directory, and the reservation would fail to be taken at all.
    """
    return dirpath / (key.replace("/", "%2F") + ".json")


def resource_key(root: Path, raw: str) -> str:
    p = Path(raw)
    if p.is_absolute():
        try:
            p = p.resolve().relative_to(root.resolve())
        except ValueError as exc:
            raise LockError(f"{p} is inside neither the register's repo "
                            f"({root}) nor the caller's tree") from exc
    return p.as_posix()


def owner_id(explicit: str | None) -> str:
    if explicit:
        return explicit
    for var in ("HERMES_SESSION_ID", "HERMES_SESSION_CHAT_ID",
                "HERMES_KANBAN_TASK"):
        value = os.environ.get(var)
        if value:
            return f"{var}={value}"
    return f"tty:{os.getuid()}:{os.getppid()}"


def pid_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    except OSError:
        return False
    return True


def read_reservation(path: Path) -> tuple[dict | None, str | None]:
    """The reservation at path, and why it is unreadable when it is.

    Returns (record, problem):
      (record, None)  the reservation, readable
      (None, None)    there is no reservation
      (None, problem) the file exists but carries no complete record: a
                      create in flight, or the residue of a writer that
                      died between creating the name and writing it

    The third case used to raise, and that made the state TERMINAL: a
    0-byte record was refused by `status`, `check`, `acquire` AND
    `release --force`, so `void_reason` was never reached and no TTL
    could ever evict it (= the register froze forever). It is reported
    instead, so the callers can treat it as a lease that binds nobody
    and can be reclaimed.
    """
    try:
        raw = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return None, None
    except OSError as exc:
        raise LockError(f"the reservation {path} cannot be read: {exc}") from exc
    if not raw.strip():
        return None, f"the reservation {path.name} is empty"
    try:
        record = json.loads(raw)
    except json.JSONDecodeError:
        return None, f"the reservation {path.name} is not complete JSON"
    if not isinstance(record, dict) or "owner" not in record:
        return None, f"the reservation {path.name} has no owner field"
    return record, None


def settle_reservation(path: Path, attempts: int = UNREADABLE_ATTEMPTS,
                       delay: float = UNREADABLE_DELAY) -> tuple[dict | None, str | None]:
    """The reservation, waiting out a create that is still in flight.

    A reservation whose file exists but carries no record is usually a
    writer between the create and the write. The window is short, so the
    reader waits it out and reads the record if it arrives; a file that
    stays unreadable is a dead writer's residue, and it is reported as
    such (= a lease that binds nobody, and can be reclaimed).
    """
    problem = None
    for attempt in range(attempts):
        record, problem = read_reservation(path)
        if record is not None or problem is None:
            return record, problem
        if attempt + 1 < attempts:
            time.sleep(delay)
    return None, problem


def read_record(path: Path) -> dict | None:
    """The reservation at path, or None when nobody holds it."""
    return read_reservation(path)[0]


def hint_pid(owner: str) -> int:
    """The process a `tty:` owner names (= the shell that owns it).

    A reservation taken from a terminal records the CLI's pid, which is
    gone a second later; for a human session the persistent process is
    the parent shell, and `tty:<uid>:<ppid>` carries it.
    """
    if owner.startswith("tty:"):
        try:
            return int(owner.rsplit(":", 1)[1])
        except (IndexError, ValueError):
            return 0
    return 0


def live_holder_process(owner: str) -> int | None:
    """A running process that IS this owner, or None.

    The owner token is what a session carries in its environment, so the
    process table answers the question a dead CLI pid cannot: is the
    session still running? `ps -eww` prints each process with its
    environment appended, which is how a Hermes worker's
    HERMES_SESSION_ID / HERMES_KANBAN_TASK becomes visible.
    """
    hinted = hint_pid(owner)
    if hinted and pid_alive(hinted):
        return hinted
    token = owner.split("=", 1)[1] if "=" in owner else ""
    if not token or len(token) < 6:
        return None
    out = subprocess.run(["ps", "-axwwE", "-o", "pid=,command="],
                         capture_output=True, text=True)
    if out.returncode != 0:
        return None
    for line in out.stdout.splitlines():
        if token in line:
            head = line.strip().split(" ", 1)
            if head and head[0].isdigit() and pid_alive(int(head[0])):
                return int(head[0])
    return None


def void_reason(record: dict | None, now: float, ttl: int,
                hard_ttl: int = DEFAULT_HARD_TTL_SECONDS) -> str | None:
    """Why this reservation does NOT bind anybody, or None when it does.

    A reservation is a LEASE with two ways to be alive: a running process
    that carries the owner token, or a renewal inside the lease. The
    first is a session that is thinking; the second is a session that
    took the register from a short-lived command line. Both being absent
    means nobody is holding it, and the register must not stay frozen
    because a worker was killed (= `pid` alone would freeze it, because
    the CLI that wrote the row exits immediately).
    """
    if record is None:
        return "no reservation"
    owner = str(record.get("owner") or "")
    renewed = float(record.get("renewed") or record.get("acquired") or 0)
    acquired = float(record.get("acquired") or renewed)
    fresh = ttl <= 0 or now - renewed <= ttl
    if hard_ttl > 0 and now - acquired > hard_ttl:
        return (f"the lease of {owner or 'someone'} was taken "
                f"{int(now - acquired)}s ago, past the "
                f"{hard_ttl}s hard cap")
    if fresh:
        return None
    if live_holder_process(owner):
        return None
    return (f"{owner or 'someone'} last renewed {int(now - renewed)}s ago, "
            f"past the {ttl}s lease, and no running process carries it")


def write_record(path: Path, record: dict) -> None:
    tmp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    tmp.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n",
                   encoding="utf-8")
    os.replace(tmp, path)


def publish_record(path: Path, record: dict) -> bool:
    """Take the reservation by CREATING ITS NAME, and write it whole.

    Returns True when this caller created the reservation, False when
    somebody else already holds the name.

    The name is created by `os.link`, which is atomic and refuses an
    existing target (= `O_EXCL` semantics) while the CONTENT is already
    in place, because the content is written to a temporary file first
    and the temporary file is linked into the name. The old way created
    the name empty and wrote the content afterwards, so a racer that
    arrived in that window saw a 0-byte file and called it corrupt (= it
    exited 1 with "the reservation is not JSON" = instead of naming the
    holder and refusing = 3). The winner's own lease was always
    parsable (= measured over 200 rounds of the old shape: 170 rounds
    carried a racer with that false alarm, and 0 left an unreadable
    file behind = the winner always wrote its own content). The
    separate, worse state = a reservation whose file carries no record
    at all = is `read_reservation`'s, and it binds nobody.

    The RATE of that false alarm is not a property of the shape (= ten
    draws of 120 rounds read 17, 23, 24, 29, 28, 28, 36, 25, 18 and 25
    clean, = and ten draws of 40 read 5, 10, 16, 6, 8, 7, 5, 10, 6 and 7
    clean, = because it depends on the machine's load), = so what the
    old shape is judged on is that it COULD happen, = not on how often.

    The link is the only step that can fail for a reason other than
    "somebody else holds it" (= a filesystem without hard links), so
    that case falls back to the exclusive create and the content is
    written into the name in one step: still a window, but the readers
    now read an unreadable record as "nobody holds it" instead of as a
    fatal error.

    The temporary file's name carries a counter and not the pid alone:
    threads of ONE process share a pid, and two of them publishing at
    the same moment would write into the same temporary file (= one
    acquirer publishing the other's content, or a truncated file).
    """
    tmp = path.with_name(f".{path.name}.{os.getpid()}.{next(_PUBLISH_SEQ)}.publish")
    try:
        tmp.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n",
                       encoding="utf-8")
        try:
            os.link(tmp, path)
            return True
        except FileExistsError:
            return False
        except OSError:
            # A filesystem without hard links: create the name
            # exclusively and write the content into it.
            try:
                fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644)
            except FileExistsError:
                return False
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                handle.write(json.dumps(record, indent=2, sort_keys=True) + "\n")
            return True
    finally:
        tmp.unlink(missing_ok=True)


def corpse_path(dirpath: Path, key: str, stamp: float) -> Path:
    """Where a void lease is moved so exactly one taker can delete it."""
    base = record_path(dirpath, key)
    return base.with_name(
        base.name[:-5] + f".gone.{int(stamp)}.{os.getpid()}")


def take(dirpath: Path, key: str, owner: str, card: str | None,
         ttl: int, now: float | None = None,
         hard_ttl: int = DEFAULT_HARD_TTL_SECONDS) -> tuple[Path, dict]:
    """Grab the reservation, or say who holds it. Never waits."""
    dirpath.mkdir(parents=True, exist_ok=True)
    path = record_path(dirpath, key)
    stamp = now if now is not None else time.time()
    mine = None
    for _ in range(TAKE_ATTEMPTS):
        record = {
            "resource": key,
            "owner": owner,
            "pid": os.getpid(),
            "card": card,
            "worktree": str(Path.cwd()),
            "acquired": stamp,
            "renewed": stamp,
            "ttl": ttl,
        }
        # The name is created WITH its content (= `publish_record`), so a
        # reader never meets a reservation that is still empty.
        if publish_record(path, record):
            return path, record
        # Somebody holds the name. Read it, and decide.
        held_record, problem = settle_reservation(path)
        if held_record is None and problem is not None:
            # The name exists but carries no readable record, and it did
            # not become readable while we waited: a dead writer's
            # residue. It binds nobody, so it is reclaimed and the
            # attempt continues. The old reading raised here, which made
            # the state terminal: no TTL could evict the file and
            # `release --force` refused to guess, so the register froze
            # forever.
            gone = corpse_path(dirpath, key, stamp)
            try:
                os.replace(path, gone)  # atomic claim of the corpse
            except FileNotFoundError:
                continue  # another taker claimed it first; retry
            gone.unlink(missing_ok=True)
            continue
        if held_record is None:
            # The name vanished between the publish and the read (= the
            # holder released it): try again.
            continue
        reason = void_reason(held_record, stamp, ttl, hard_ttl)
        if reason and held_record.get("owner") == owner:
            # ours but void: we may simply overwrite it below
            mine = held_record
            break
        if reason:
            gone = corpse_path(dirpath, key, stamp)
            try:
                os.replace(path, gone)  # atomic claim of the corpse
            except FileNotFoundError:
                continue  # another taker claimed it first; retry
            gone.unlink(missing_ok=True)
            continue
        if held_record.get("owner") == owner:
            return path, held_record
        holder = held_record.get("owner", "someone")
        pid = held_record.get("pid", "?")
        card_of = held_record.get("card") or "-"
        renewed = held_record.get("renewed")
        when = (time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(renewed))
                if isinstance(renewed, (int, float)) and renewed
                else "never")
        raise Refused(f"{key} is reserved by {holder} (pid {pid}, card "
                      f"{card_of}, last renewed {when})")
    if mine is None:
        raise LockError(f"{key}: the reservation was contested {TAKE_ATTEMPTS} "
                        "times without settling; retry")
    record = {
        "resource": key, "owner": owner, "pid": os.getpid(), "card": card,
        "worktree": str(Path.cwd()), "acquired": stamp, "renewed": stamp,
        "ttl": ttl,
    }
    write_record(path, record)
    return path, record


def held(dirpath: Path, key: str, owner: str, ttl: int,
         hard_ttl: int = DEFAULT_HARD_TTL_SECONDS,
         now: float | None = None) -> dict:
    """Who holds the reservation, as a view a reader can print.

    A reservation whose file carries no readable record is reported as
    `free` with the reason in `void`, because it binds nobody: it is a
    create in flight, or a dead writer's residue. The old reading
    raised out of here, and the caller of the `--staged` branch did not
    guard it, so a legitimate commit died on an UNCAUGHT TRACEBACK
    (= the register refused a commit it should have allowed, and the
    traceback named no holder and no remedy).
    """
    record, problem = settle_reservation(record_path(dirpath, key))
    if record is None:
        if problem is None:
            return {"resource": key, "state": "free"}
        return {"resource": key, "state": "free", "void": problem,
                "was": None}
    reason = void_reason(record, now if now is not None else time.time(),
                         ttl, hard_ttl)
    if reason:
        return {"resource": key, "state": "free", "void": reason,
                "was": record.get("owner")}
    state = "mine" if record.get("owner") == owner else "theirs"
    return {"resource": key, "state": state, **record}


def staged_paths() -> list[str]:
    out = subprocess.run(["git", "diff", "--cached", "--name-only",
                          "--diff-filter=ACMR"],
                         capture_output=True, text=True)
    if out.returncode != 0:
        raise LockError("git diff --cached failed: " + out.stderr.strip())
    return [line for line in out.stdout.splitlines() if line.strip()]


HOOK_SNIPPET = (
    'tool="$(git rev-parse --show-toplevel)/Tools/wenshu-devtool/'
    "nfi_lock.py\"; [ -f \"$tool\" ] || exit 0; "
    'python3 "$tool" check --staged || { echo "nfi_lock: the commit is refused"; '
    'exit 1; }  ' + MARKER
)


def hook_path() -> Path:
    """The pre-commit file git will actually read from this tree.

    `git rev-parse --git-path` is asked instead of the directory being
    rebuilt here: it already knows about `core.hooksPath`, about a
    worktree's private git dir, and about the linked worktrees that
    share this clone's `.git/hooks`. A second rule for the same question
    is how a hook ends up installed where nothing reads it.
    """
    out = subprocess.run(["git", "rev-parse", "--git-path",
                          "hooks/pre-commit"],
                         capture_output=True, text=True)
    if out.returncode != 0 or not out.stdout.strip():
        raise LockError("cannot read where the pre-commit hook lives: "
                        + out.stderr.strip())
    path = Path(out.stdout.strip())
    if not path.is_absolute():
        path = repo_root() / path
    return path


def install_hook(verify_only: bool) -> tuple[int, str]:
    path = hook_path()
    body = path.read_text(encoding="utf-8") if path.exists() else ""
    present = MARKER in body
    if verify_only:
        if not present:
            return 3, (f"{path}: the reservation is not wired into the "
                       "pre-commit hook")
        return 0, f"{path}: the reservation is wired"
    if present:
        return 0, f"{path}: already wired"
    if not body:
        body = "#!/usr/bin/env bash\nset -e\n"
    lines = body.rstrip("\n").splitlines() + ["", HOOK_SNIPPET]
    tmp = path.with_name(path.name + f".nfi.{os.getpid()}")
    tmp.write_text("\n".join(lines) + "\n", encoding="utf-8")
    os.replace(tmp, path)
    mode = path.stat().st_mode
    path.chmod(mode | 0o111)
    return 0, f"{path}: wired the reservation into the pre-commit hook"


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(
        description=(__doc__ or "nfi_lock").splitlines()[0])
    ap.add_argument("verb", choices=["acquire", "renew", "release", "status",
                                     "check", "run", "install"])
    ap.add_argument("path", nargs="?", default=None,
                    help="the register to act on (= the guarded set when "
                         "omitted, = and only for `check --staged`)")
    ap.add_argument("--staged", action="store_true",
                    help="check: read the staged set instead of one path")
    ap.add_argument("--owner", default=None)
    ap.add_argument("--card", default=None)
    ap.add_argument("--ttl", type=int, default=DEFAULT_TTL_SECONDS,
                    help="lease seconds; a renewal inside it holds the file")
    ap.add_argument("--hard-ttl", type=int,
                    default=DEFAULT_HARD_TTL_SECONDS,
                    help="hard cap: seconds since the acquisition a lease may "
                         "bind for, renewals included")
    ap.add_argument("--force", action="store_true",
                    help="release: drop a reservation you do not own")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--verify", action="store_true",
                    help="install: report whether the hook is wired")
    ap.add_argument("--dir", default=None, help="the reservation directory")
    ap.add_argument("--now", type=float, default=None,
                    help="testing seam: the value of the clock")
    return ap


def main(argv: list[str] | None = None) -> int:
    raw = list(sys.argv[1:] if argv is None else argv)
    # `run -- COMMAND` hands everything after the separator to the command,
    # so that a flag of the COMMAND is never read as a flag of the lock.
    command: list[str] = []
    if "--" in raw:
        cut = raw.index("--")
        command, raw = raw[cut + 1:], raw[:cut]
    ap = build_parser()
    args = ap.parse_args(raw)
    if args.verb == "install":
        code, message = install_hook(args.verify)
        print(message)
        return code
    try:
        root = repo_root()
        dirpath = lock_dir(args.dir)
    except LockError as exc:
        print(f"nfi_lock: {exc}", file=sys.stderr)
        return 1
    owner = owner_id(args.owner)
    if args.verb == "check" and args.staged:
        # The hook's question is "does this commit touch a register that
        # somebody else is writing?". Every guarded register is asked, and
        # each is asked on ITS OWN lease (= a lease on the NFI register does
        # not block a commit that touches only OOB.md, = and the other way
        # round). The first foreign holder found refuses the commit and
        # names the register it holds.
        targets = [args.path] if args.path else list(GUARDED_RESOURCES)
        try:
            staged = staged_paths()
        except LockError as exc:
            print(f"nfi_lock: {exc}", file=sys.stderr)
            return 1
        checked: list[str] = []
        for target in targets:
            try:
                tkey = resource_key(root, target)
                touched = [p for p in staged
                           if resource_key(root, p) == tkey]
            except LockError as exc:
                print(f"nfi_lock: {exc}", file=sys.stderr)
                return 1
            if not touched:
                continue
            checked.append(tkey)
            try:
                view = held(dirpath, tkey, owner, args.ttl, args.hard_ttl,
                            args.now)
            except LockError as exc:
                # Every verb answers with a line and a code, never with a
                # traceback: this branch is the pre-commit hook, and an
                # uncaught exception there refuses a legitimate commit
                # while naming neither a holder nor a remedy.
                print(f"nfi_lock: {exc}", file=sys.stderr)
                return 1
            if view["state"] in ("free", "mine"):
                if not args.json:
                    detail = view.get("void")
                    print(f"nfi_lock: {tkey} may be committed by {owner} "
                          f"({view['state']}"
                          + (f"; {detail}" if detail else "") + ")")
                continue
            print(f"nfi_lock: {tkey} is reserved by {view['owner']} "
                  f"(pid {view['pid']}, card {view.get('card') or '-'}) while "
                  f"{owner} tries to commit it. The holder must release it "
                  f"(nfi_lock.py release) or this commit must wait. A human "
                  f"who knows the holder is dead: nfi_lock.py release "
                  f"--force.",
                  file=sys.stderr)
            return 3
        if not args.json and not checked:
            print("nfi_lock: this commit touches no guarded register")
        return 0
    key = resource_key(root, args.path or DEFAULT_RESOURCE)
    if args.verb == "run":
        if not command:
            print("nfi_lock: run needs a command after --", file=sys.stderr)
            return 1
        try:
            _, record = take(dirpath, key, owner, args.card, args.ttl,
                             args.now, args.hard_ttl)
        except (LockError, Refused) as exc:
            print(f"nfi_lock: {exc}", file=sys.stderr)
            return 3 if isinstance(exc, Refused) else 1
        if not args.json:
            print(f"nfi_lock: {owner} holds {key} (pid {record['pid']})")
        try:
            return subprocess.call(command)
        finally:
            path = record_path(dirpath, key)
            current = read_record(path)
            if current and current.get("owner") == owner:
                path.unlink(missing_ok=True)
                if not args.json:
                    print(f"nfi_lock: {key} released")
    try:
        if args.verb == "acquire":
            path, record = take(dirpath, key, owner, args.card, args.ttl,
                                args.now, args.hard_ttl)
            if args.json:
                print(json.dumps(record, sort_keys=True))
            else:
                print(f"nfi_lock: {owner} holds {key} -> {path}")
            return 0
        if args.verb == "renew":
            path = record_path(dirpath, key)
            record, problem = settle_reservation(path)
            if record is None:
                detail = problem or "no reservation"
                print(f"nfi_lock: {key} is not reserved ({detail}); "
                      "nothing to renew", file=sys.stderr)
                return 2
            if record.get("owner") != owner:
                print(f"nfi_lock: {key} belongs to {record['owner']}, not "
                      f"{owner}", file=sys.stderr)
                return 2
            record["renewed"] = args.now if args.now is not None else time.time()
            record["pid"] = os.getpid()
            write_record(path, record)
            print(f"nfi_lock: renewed {key} for {owner}")
            return 0
        if args.verb == "release":
            path = record_path(dirpath, key)
            record, problem = settle_reservation(path)
            if record is None and problem is not None:
                # The file carries no readable record (= a dead writer's
                # residue). It binds nobody, so there is no holder to
                # protect and no owner to guess: a human who knows it is
                # dead releases it with --force, and --force clears it.
                # The old reading refused BOTH ways, which is what made
                # the state terminal.
                if not args.force:
                    print(f"nfi_lock: {key} is not reserved ({problem}); "
                          "nothing holds it, and a human who knows it is "
                          "dead releases it with --force", file=sys.stderr)
                    return 2
                path.unlink(missing_ok=True)
                print(f"nfi_lock: released {key} ({problem}, --force)")
                return 0
            if record is None:
                print(f"nfi_lock: {key} is not reserved")
                return 0
            if record.get("owner") != owner and not args.force:
                print(f"nfi_lock: {key} belongs to {record['owner']}, not "
                      f"{owner}; a live holder is not released behind its "
                      f"back (--force overrides)", file=sys.stderr)
                return 2
            path.unlink(missing_ok=True)
            print(f"nfi_lock: released {key}"
                  + ("" if record.get("owner") == owner
                     else f" (was {record['owner']}, --force)"))
            return 0
        view = held(dirpath, key, owner, args.ttl, args.hard_ttl, args.now)
        if args.json:
            print(json.dumps(view, sort_keys=True))
        else:
            state = view["state"]
            if state == "free":
                detail = view.get("void", "nobody")
                print(f"nfi_lock: {key} is free ({detail})")
            else:
                print(f"nfi_lock: {key} is held by {view['owner']} "
                      f"(pid {view.get('pid')}, card "
                      f"{view.get('card') or '-'}, state {state})")
        return 0 if view["state"] != "theirs" else 3
    except Refused as exc:
        print(f"nfi_lock: {exc}", file=sys.stderr)
        return 3
    except LockError as exc:
        print(f"nfi_lock: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
