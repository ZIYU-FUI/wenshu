"""The register reservation's own cases.

The tool answers one question: while a session is writing
`docs/agents/nfi.md`, may another session write it too? The answer must be
NO in the places a collision can actually happen, and it must not be NO
forever (= a dead holder must not freeze the register).

The cases below are the ones that decide it:

1. a free register is taken by the first asker
2. a live foreign lease REFUSES the second asker (= exit 3), and names it
3. the same owner taking it twice is not a collision (= idempotent)
4. an expired lease nobody carries is reclaimed, and the reclaim is REPORTED
   (= a killed worker must not freeze the register)
5. an expired lease a RUNNING process carries still holds past the lease
   (= a session that is thinking is not evicted by a clock)
6. the hard cap binds even a running holder (= nothing holds it forever)
7. a foreign holder is not released behind its back (= exit 2), --force does
8. a commit that touches the register while another session holds it is
   REFUSED by the wired pre-commit hook, wired where git reads it
9. a commit that does not touch the register passes while it is held
10. `run` releases the reservation when the command fails (= a crash is not
    a permanent lock)
11. install is idempotent, and --verify reads the wiring honestly
12. a tree WITHOUT the tool is not gated (= a shared hook must not brick
    the worktrees that predate it)
13. TWELVE simultaneous acquirers of one lease: exactly one wins and
    eleven are refused, EVERY round (= the reservation is published whole,
    so no reader ever meets a half-written lease)
14. a reservation whose file carries no record (= a dead writer's residue)
    binds nobody: it is reclaimable, and it does not freeze the register
15. the OOB register is guarded too (= it collides the same way: = two
    sessions that each append one entry conflict)
16. a commit that touches the OOB register while another session holds it is
    REFUSED, and the refusal names the OOB register
17. an OOB lease does NOT block a commit that touches only the NFI register
18. an NFI lease does NOT block a commit that touches only the OOB register

Each case names the tree it measured (= the temp repo's path), because the
subject of a reservation is the repository the caller stands in, not this
one.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import nfi_lock  # noqa: E402

TOOL = Path(__file__).resolve().parents[1] / "nfi_lock.py"
REGISTER = "docs/agents/nfi.md"
FAILURES: list[str] = []


def check(label: str, ok: bool, detail: str = "") -> None:
    line = f"  {'ok  ' if ok else 'FAIL'} {label}"
    if detail:
        line += f"  [{detail}]"
    print(line)
    if not ok:
        FAILURES.append(label)


def run(args: list[str], repo: Path, owner: str = "session-a",
        env: dict | None = None) -> subprocess.CompletedProcess:
    base = dict(os.environ)
    base.pop("HERMES_SESSION_ID", None)
    base.pop("HERMES_SESSION_CHAT_ID", None)
    base.pop("HERMES_KANBAN_TASK", None)
    base["WENSHU_NFI_LOCK_DIR"] = str(repo / ".git" / "nfi-lock")
    if env:
        base.update({k: str(v) for k, v in env.items()})
    return subprocess.run([sys.executable, str(TOOL), *args],
                          cwd=repo, env=base, capture_output=True, text=True)


def new_repo(tmp: Path, name: str = "clone") -> Path:
    repo = tmp / name
    repo.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "init", "-q", "."], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.email", "gate@example.invalid"],
                   cwd=repo, check=True)
    subprocess.run(["git", "config", "user.name", "Gate"], cwd=repo,
                   check=True)
    (repo / "docs" / "agents").mkdir(parents=True, exist_ok=True)
    (repo / REGISTER).write_text("# NFI\n\n| file | parent | loc | tag |\n"
                                 "| --- | --- | --- | --- |\n", encoding="utf-8")
    # The hook resolves the tool inside the tree it runs in, so the temp
    # repo carries a copy (= the case measures the wiring, not this checkout).
    (repo / "Tools" / "wenshu-devtool").mkdir(parents=True, exist_ok=True)
    (repo / "Tools" / "wenshu-devtool" / "nfi_lock.py").write_text(
        TOOL.read_text(encoding="utf-8"), encoding="utf-8")
    subprocess.run(["git", "add", "-A"], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-q", "-m", "seed the register"],
                   cwd=repo, check=True)
    return repo


def free_pid() -> int:
    """A pid that is certainly not alive: spawn a child, reap it."""
    child = subprocess.Popen([sys.executable, "-c", "pass"])
    child.wait()
    return child.pid


def keeper(owner: str) -> subprocess.Popen:
    """A running process that carries the owner token (= a live session)."""
    env = dict(os.environ)
    env["HERMES_SESSION_ID"] = owner
    for var in ("HERMES_SESSION_CHAT_ID", "HERMES_KANBAN_TASK"):
        env.pop(var, None)
    return subprocess.Popen([sys.executable, "-c",
                             "import time; time.sleep(120)"], env=env)


def wait_for_token(owner: str, limit: float = 5.0) -> bool:
    """Until `ps` shows a process carrying the token, or the window closes.

    A process spawned a millisecond ago is not always in the table yet, and
    the question the tool asks is about the table — so the case waits for
    the fact instead of assuming it.
    """
    deadline = time.time() + limit
    while time.time() < deadline:
        out = subprocess.run(["ps", "-axwwE", "-o", "pid=,command="],
                             capture_output=True, text=True)
        if owner in out.stdout:
            return True
        time.sleep(0.05)
    return False


def fake_holder(repo: Path, owner: str, pid: int, renewed: float,
                acquired: float | None = None, resource: str = REGISTER) -> Path:
    path = repo / ".git" / "nfi-lock"
    path.mkdir(parents=True, exist_ok=True)
    record = {"resource": resource, "owner": owner, "pid": pid,
              "card": "t_fake", "worktree": str(repo),
              "acquired": acquired if acquired is not None else renewed,
              "renewed": renewed, "ttl": 3600}
    target = nfi_lock.record_path(path, resource)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(record), encoding="utf-8")
    return target


def empty_holder(repo: Path) -> Path:
    """A reservation file that carries no record (= a dead writer's residue).

    The old tool created the name empty and wrote the content
    afterwards, so a file like this was what a reader in that window
    saw. It must bind nobody, be reclaimable, and never freeze the
    register.
    """
    path = repo / ".git" / "nfi-lock"
    path.mkdir(parents=True, exist_ok=True)
    target = nfi_lock.record_path(path, REGISTER)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("", encoding="utf-8")
    return target


def race_round(repo: Path, racers: int) -> list[int]:
    """Twelve acquirers of one lease, released together, and their codes.

    The acquirers are PROCESSES (= the tool as a session runs it), and
    they are released by a barrier so they contend for the same instant:
    a race that staggers itself proves nothing.
    """
    lockdir = repo / ".git" / "nfi-lock"
    lockdir.mkdir(parents=True, exist_ok=True)
    barrier = threading.Barrier(racers)
    results: list[int] = []

    def acquire(index: int) -> None:
        env = dict(os.environ)
        env.pop("HERMES_SESSION_ID", None)
        env.pop("HERMES_SESSION_CHAT_ID", None)
        env.pop("HERMES_KANBAN_TASK", None)
        env["WENSHU_NFI_LOCK_DIR"] = str(lockdir)
        proc = subprocess.Popen(
            [sys.executable, str(TOOL), "acquire", REGISTER,
             "--owner", f"racer-{index}", "--dir", str(lockdir)],
            cwd=repo, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True)
        barrier.wait()
        out, err = proc.communicate()
        results.append(proc.returncode)
        if proc.returncode not in (0, 3):
            print(f"    racer-{index} exited {proc.returncode}: "
                  f"{(err or out).strip()[:160]}")

    threads = [threading.Thread(target=acquire, args=(i,)) for i in range(racers)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    return results


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="nfi-lock-") as raw:
        tmp = Path(raw)
        repo = new_repo(tmp)
        subject = f"measured in {repo}"

        # 1 + 2: first taker wins, a live foreign taker is refused.
        r1 = run(["acquire", REGISTER, "--owner", "session-a"], repo)
        check("1 free register is taken", r1.returncode == 0,
              r1.stderr.strip() or subject)
        r2 = run(["acquire", REGISTER, "--owner", "session-b"], repo)
        check("2 a live foreign holder refuses", r2.returncode == 3,
              f"exit={r2.returncode} {r2.stdout.strip()}")
        check("2 the refusal names the holder", "session-a" in r2.stderr,
              r2.stderr.strip()[:120])
        st = run(["status", REGISTER, "--owner", "session-b", "--json"], repo)
        view = json.loads(st.stdout)
        check("2 status says theirs", view["state"] == "theirs", st.stdout)

        # 3: the holder asking again is not a collision.
        r3 = run(["acquire", REGISTER, "--owner", "session-a", "--card",
                  "t_x"], repo)
        check("3 same owner re-acquires", r3.returncode == 0, r3.stderr)

        # 4: an expired lease no process carries is reclaimed.
        fake_holder(repo, "session-dead", free_pid(),
                    time.time() - 99999, acquired=time.time() - 99999)
        r4 = run(["acquire", REGISTER, "--owner", "session-c", "--ttl", "60"],
                 repo)
        check("4 an expired uncarried lease is reclaimed", r4.returncode == 0,
              r4.stderr.strip() or r4.stdout.strip())
        run(["acquire", REGISTER, "--owner", "session-x", "--ttl", "60"], repo)
        fake_holder(repo, "session-gone", free_pid(),
                    time.time() - 99999, acquired=time.time() - 99999)
        st4 = run(["status", REGISTER, "--owner", "session-y", "--ttl", "60",
                   "--json"], repo)
        view4 = json.loads(st4.stdout)
        check("4 the reclaim is reported, not silent",
              view4["state"] == "free" and "void" in view4, st4.stdout)

        # 5: a lease a running process carries survives the lease clock.
        hold = keeper("session-keeper")
        seen = wait_for_token("session-keeper")
        try:
            fake_holder(repo, "HERMES_SESSION_ID=session-keeper",
                        free_pid(), time.time() - 99999,
                        acquired=time.time() - 99999)
            check("5 the running holder is visible in the process table",
                  seen, "ps never showed the token")
            r5 = run(["acquire", REGISTER, "--owner", "session-other",
                      "--ttl", "60", "--hard-ttl", "999999"], repo)
            check("5 a running holder keeps the lease past the clock",
                  r5.returncode == 3, r5.stdout.strip())
            # 6: but the hard cap binds even a running holder.
            r6 = run(["acquire", REGISTER, "--owner", "session-other",
                      "--ttl", "60", "--hard-ttl", "3600"], repo)
            check("6 the hard cap voids a running holder too",
                  r6.returncode == 0, r6.stderr.strip())
        finally:
            hold.terminate()
            hold.wait()

        # 7: a foreign LIVE lease is not released behind its back.
        fake_holder(repo, "session-live", os.getpid(), time.time())
        rel = run(["release", REGISTER, "--owner", "session-e"], repo)
        check("7 a foreign release is refused", rel.returncode == 2,
              rel.stdout.strip())
        forced = run(["release", REGISTER, "--owner", "session-e", "--force"],
                     repo)
        check("7 --force releases", forced.returncode == 0, forced.stderr)
        check("7 the register is free again",
              run(["status", REGISTER, "--owner", "session-e"],
                  repo).returncode == 0)

        # 11 + 8 + 9: the wired hook, end to end, on a real commit.
        ins = run(["install"], repo, owner="")
        check("11 install wires the hook", ins.returncode == 0, ins.stdout)
        wired = subprocess.run(["git", "rev-parse", "--git-path",
                               "hooks/pre-commit"], cwd=repo,
                              capture_output=True, text=True).stdout.strip()
        wired_path = (repo / wired) if not Path(wired).is_absolute() \
            else Path(wired)
        check("11 the hook was written where git reads it",
              wired_path.exists()
              and nfi_lock.MARKER in wired_path.read_text(encoding="utf-8"),
              str(wired_path))
        check("11 install is idempotent",
              run(["install"], repo, owner="").returncode == 0
              and wired_path.read_text(encoding="utf-8")
              .count(nfi_lock.MARKER) == 1)
        check("11 --verify reads the wiring",
              run(["install", "--verify"], repo, owner="").returncode == 0)
        fake_holder(repo, "session-holder", os.getpid(), time.time())
        (repo / REGISTER).write_text(
            (repo / REGISTER).read_text(encoding="utf-8")
            + "| new.swift | abc123 | 120 | extract |\n", encoding="utf-8")
        subprocess.run(["git", "add", REGISTER], cwd=repo, check=True)
        blocked = subprocess.run(["git", "commit", "-m", "second session's row"],
                                 cwd=repo, capture_output=True, text=True)
        check("8 a commit touching the register is refused",
              blocked.returncode != 0 and "reserved by session-holder"
              in (blocked.stderr + blocked.stdout),
              f"exit={blocked.returncode} "
              f"{(blocked.stderr + blocked.stdout).strip()[:200]}")
        untouched = repo / "README.lock.md"
        untouched.write_text("not the register\n", encoding="utf-8")
        subprocess.run(["git", "reset", "-q"], cwd=repo, check=True)
        subprocess.run(["git", "add", "README.lock.md"], cwd=repo, check=True)
        passed = subprocess.run(["git", "commit", "-m", "unrelated file"],
                                cwd=repo, capture_output=True, text=True)
        check("9 a commit that does not touch it passes while held",
              passed.returncode == 0,
              f"exit={passed.returncode} {(passed.stderr or '').strip()[:200]}")

        # 10: `run` releases even when the command fails.
        subprocess.run(["git", "reset", "-q", "--hard", "HEAD~1"], cwd=repo,
                       check=True)
        nfi_lock.record_path(repo / ".git" / "nfi-lock", REGISTER).unlink(
            missing_ok=True)
        r10 = run(["run", REGISTER, "--owner", "session-run", "--ttl", "60",
                   "--", sys.executable, "-c", "raise SystemExit(4)"], repo)
        check("10 run keeps the command's code", r10.returncode == 4,
              f"exit={r10.returncode} {r10.stderr.strip()[:160]}")
        check("10 run released the reservation",
              nfi_lock.record_path(repo / ".git" / "nfi-lock", REGISTER)
              .exists() is False)

        # 12: a tree WITHOUT the tool is not gated (= the documented gap: a
        # shared hook must not brick the worktrees that predate the gate).
        old = tmp / "oldclone"
        old.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "init", "-q", "."], cwd=old, check=True)
        subprocess.run(["git", "config", "user.email", "gate@example.invalid"],
                       cwd=old, check=True)
        subprocess.run(["git", "config", "user.name", "Gate"], cwd=old,
                       check=True)
        (old / "docs" / "agents").mkdir(parents=True, exist_ok=True)
        (old / REGISTER).write_text("# NFI\n", encoding="utf-8")
        subprocess.run(["git", "add", "-A"], cwd=old, check=True)
        env = dict(os.environ)
        env["WENSHU_NFI_LOCK_DIR"] = str(old / ".git" / "nfi-lock")
        subprocess.run(["git", "commit", "-q", "-m", "seed"], cwd=old,
                       check=True, env=env)
        # the shared hook, installed by hand here, pointing at no tool
        hook = old / ".git" / "hooks" / "pre-commit"
        hook.write_text("#!/usr/bin/env bash\nset -e\n"
                        + nfi_lock.HOOK_SNIPPET + "\n", encoding="utf-8")
        hook.chmod(0o755)
        (old / REGISTER).write_text("# NFI\n| row |\n", encoding="utf-8")
        subprocess.run(["git", "add", REGISTER], cwd=old, check=True)
        legacy = subprocess.run(["git", "commit", "-m", "row from an old tree"],
                                cwd=old, capture_output=True, text=True,
                                env=env)
        check("12 a tree without the tool still commits",
              legacy.returncode == 0,
              f"exit={legacy.returncode} "
              f"{(legacy.stderr or '').strip()[:160]}")

        # 13: twelve simultaneous acquirers of ONE lease. Exactly one
        # wins and eleven are refused, EVERY round. The old tool created
        # the reservation's name empty and wrote the content afterwards,
        # so a racer arriving in that window was told the reservation was
        # broken (= it exited 1 with "the reservation is not JSON" =,
        # instead of naming the holder and refusing = 3). The winner's
        # own lease was always parsable (= measured over 200 rounds of
        # the old shape: 170 rounds carried such a racer, and 0 left an
        # unreadable file behind), = so the defect is that a racer could
        # meet a half-written lease AT ALL. The RATE of it is not a
        # property of the shape (= it depends on the machine's load), =
        # so this case asserts the OUTCOME (= one 0 and eleven 3s, every
        # round) rather than a count of how often the old shape failed.
        rounds = 20
        bad_rounds = []
        for round_no in range(rounds):
            race_repo = new_repo(tmp, f"race{round_no}")
            codes = race_round(race_repo, 12)
            winners = codes.count(0)
            refusals = codes.count(3)
            if winners != 1 or refusals != 11:
                bad_rounds.append((round_no, sorted(codes)))
        check(f"13 twelve simultaneous acquirers: one 0 + eleven 3s, "
              f"every one of {rounds} rounds", not bad_rounds,
              f"bad rounds: {bad_rounds[:4]}" if bad_rounds else
              f"{rounds} rounds clean")

        # 14: a reservation whose file carries no record binds nobody.
        # It must be reclaimable, and it must never freeze the register
        # (= the old reading refused status, check, acquire AND
        # release --force, so no TTL could evict it).
        empty_holder(repo)
        st14 = run(["status", REGISTER, "--owner", "session-q"], repo)
        check("14 an empty reservation does not freeze status",
              st14.returncode == 0, f"exit={st14.returncode} {st14.stderr}")
        chk14 = run(["check", REGISTER, "--owner", "session-q"], repo)
        check("14 an empty reservation does not freeze check",
              chk14.returncode == 0, f"exit={chk14.returncode} {chk14.stderr}")
        acq14 = run(["acquire", REGISTER, "--owner", "session-q"], repo)
        check("14 an empty reservation is reclaimed by the taker",
              acq14.returncode == 0, f"exit={acq14.returncode} {acq14.stderr}")
        empty_holder(repo)
        rel14 = run(["release", REGISTER, "--owner", "session-q", "--force"],
                    repo)
        check("14 release --force clears an empty reservation",
              rel14.returncode == 0, f"exit={rel14.returncode} {rel14.stderr}")
        check("14 the empty reservation is gone",
              not nfi_lock.record_path(repo / ".git" / "nfi-lock", REGISTER)
              .exists())

        # 15 + 16 + 17 + 18: the SECOND guarded register. The OOB register
        # collides the same way (= two sessions that each append one entry
        # CONFLICT, = measured), and it is guarded by the same reservation,
        # not by a merge driver (= a driver needs a key that names one row, =
        # and OOB.md's key is a DATE that is deliberately NOT unique: = 103
        # rows share 45 keys (= at this head, = 2026-10-16 alone carries 25).
        guarded = new_repo(tmp, "guarded")
        (guarded / "OOB.md").write_text(
            "# OOB\n\n| 2026-11-26 | an entry |\n", encoding="utf-8")
        subprocess.run(["git", "add", "OOB.md"], cwd=guarded, check=True)
        subprocess.run(["git", "commit", "-q", "-m", "seed the OOB register"],
                       cwd=guarded, check=True)
        ins15 = run(["install"], guarded, owner="")
        check("15 install wires the hook", ins15.returncode == 0, ins15.stdout)
        check("15 the guarded set names both registers",
              nfi_lock.GUARDED_RESOURCES
              == (nfi_lock.DEFAULT_RESOURCE, "OOB.md"),
              str(nfi_lock.GUARDED_RESOURCES))
        fake_holder(guarded, "session-oob", os.getpid(), time.time(),
                    resource="OOB.md")
        (guarded / "OOB.md").write_text(
            "# OOB\n\n| 2026-11-26 | an entry |\n| 2026-11-26 | another |\n",
            encoding="utf-8")
        subprocess.run(["git", "add", "OOB.md"], cwd=guarded, check=True)
        blocked16 = subprocess.run(
            ["git", "commit", "-m", "second session's OOB entry"],
            cwd=guarded, capture_output=True, text=True)
        out16 = blocked16.stderr + blocked16.stdout
        check("16 a commit touching the OOB register is refused",
              blocked16.returncode != 0 and "reserved by session-oob" in out16,
              f"exit={blocked16.returncode} {out16.strip()[:200]}")
        check("16 the refusal names the OOB register", "OOB.md" in out16,
              out16.strip()[:200])
        # 17: the two registers are leased SEPARATELY (= a lease on the OOB
        # register does not block a commit that touches only the NFI one).
        subprocess.run(["git", "reset", "-q"], cwd=guarded, check=True)
        (guarded / REGISTER).write_text(
            (guarded / REGISTER).read_text(encoding="utf-8")
            + "| new.swift | abc123 | 120 | extract |\n", encoding="utf-8")
        subprocess.run(["git", "add", REGISTER], cwd=guarded, check=True)
        passed17 = subprocess.run(["git", "commit", "-m", "a row, not OOB"],
                                  cwd=guarded, capture_output=True, text=True)
        check("17 an OOB lease does not block a commit that touches only "
              "the NFI register", passed17.returncode == 0,
              f"exit={passed17.returncode} {(passed17.stderr or '').strip()[:200]}")
        # 18: and the other way round (= an NFI lease does not block an OOB
        # commit). The OOB lease goes first, = or it would refuse this commit
        # for its own sake (= which is case 16, = already measured).
        run(["release", "OOB.md", "--owner", "session-oob", "--force"], guarded)
        fake_holder(guarded, "session-nfi", os.getpid(), time.time())
        (guarded / "OOB.md").write_text(
            "# OOB\n\n| 2026-11-26 | an entry |\n| 2026-11-26 | another |\n"
            "| 2026-11-26 | a third |\n", encoding="utf-8")
        subprocess.run(["git", "add", "OOB.md"], cwd=guarded, check=True)
        passed18 = subprocess.run(["git", "commit", "-m", "an OOB entry"],
                                  cwd=guarded, capture_output=True, text=True)
        check("18 an NFI lease does not block a commit that touches only "
              "the OOB register", passed18.returncode == 0,
              f"exit={passed18.returncode} {(passed18.stderr or '').strip()[:200]}")

    print(f"\nnfi_lock: {'FAILED ' + str(len(FAILURES)) + ' case(s): ' + ', '.join(FAILURES) if FAILURES else 'all cases hold'}")
    return 1 if FAILURES else 0


if __name__ == "__main__":
    raise SystemExit(main())
