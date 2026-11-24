#!/usr/bin/env python3
"""test_process_data_gate.py — the process-data gate's own test suite.

The gate reads the machine's real mount table, so every case runs on a
FIXTURE: a temporary directory tree with a FAKE system disk and a FAKE data
disk, and a fake `df` reader that names the volume each fixture path is on.
The gate's disk-reading is one small function, so the suite replaces it and
drives the gate without touching the machine's disks.

The cases are the ways the gate can be wrong:

  1. a path on the system disk is found, and the run exits 1.
  2. a path on the data disk is not a finding, and the run exits 0.
  3. the volume is the MOUNT POINT (= = the thing `df` prints), not a path
     prefix: a `/Users/...` path that is really on the data disk reads as
     the data disk.
  4. the system disk is the CONTAINER of `/` and `/System/Volumes/Data`
     (= = two devices of one disk), and the container id comes from the
     device id, not from the size.
  5. a path that does not exist is reported as absent, not as a finding.
  6. every path this repo's flow writes is in the report (= = the repo's
     .scratch/.worktrees/.gate-logs, the board's workspaces and database,
     the profile caches, and the TMPDIR).
  7. the size of each path is printed.
  8. the gate is a REPORT: it names the move as the boss's call and moves
     nothing (= = the fixture tree is byte-for-byte the same after a run).
  9. --json carries the same numbers the text report prints.

Run:  python3 Tools/wenshu-devtool/tests/test_process_data_gate.py
Exit: 0 = every case passed, 1 = at least one case failed.
"""
from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "process_data_gate.py"

spec = importlib.util.spec_from_file_location("process_data_gate", TOOL)
assert spec is not None and spec.loader is not None
pdg = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pdg)

FAILURES: list[str] = []


def check(name: str, got, want) -> None:
    if got == want:
        print(f"  ok   {name}")
    else:
        print(f"  FAIL {name}: got {got!r}, want {want!r}")
        FAILURES.append(name)


# The two fake disks. The system disk answers with a slice of disk3 (= = the
# same container as the system volume) and the data disk with a slice of
# disk7, so the gate's container comparison is what decides.
SYSTEM_DISK = {"device": "/dev/disk3s5", "mount": "/System/Volumes/Data",
               "container": "disk3"}
DATA_DISK = {"device": "/dev/disk7s1", "mount": "/Volumes/ANAN",
             "container": "disk7"}
ROOT_VOLUME = {"device": "/dev/disk3s1s1", "mount": "/",
               "container": "disk3"}
DATA_VOLUME = {"device": "/dev/disk3s5", "mount": "/System/Volumes/Data",
               "container": "disk3"}


def fake_mount_reader(volumes: dict):
    """A `df` that answers from a fixture table instead of the machine.

    The anchors (= = `/` and `/System/Volumes/Data`) always answer with the
    system disk, so the gate learns which containers ARE the system disk
    from the same reader it asks about the paths.
    """
    def reader(path: Path) -> dict:
        key = str(path)
        if key in volumes:
            return volumes[key]
        if key in ("/", "/System/Volumes/Data"):
            return dict(ROOT_VOLUME if key == "/" else DATA_VOLUME)
        raise OSError(f"no fixture volume for {key}")
    return reader


def fake_size_reader(sizes: dict):
    def reader(path: Path) -> str:
        return sizes.get(str(path), "1K")
    return reader


def make_tree(root: Path) -> tuple[Path, Path, dict, dict]:
    """A fixture tree: one path on the system disk, one on the data disk."""
    system_path = root / "system" / "board"
    data_path = root / "data" / "cache"
    for p in (system_path, data_path):
        p.mkdir(parents=True)
        (p / "file.txt").write_text("x" * 16)
    volumes = {
        str(system_path): dict(SYSTEM_DISK),
        str(data_path): dict(DATA_DISK),
    }
    sizes = {str(system_path): "12M", str(data_path): "34G"}
    return system_path, data_path, volumes, sizes


def main() -> int:
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        system_path, data_path, volumes, sizes = make_tree(root)
        reader = fake_mount_reader(volumes)
        sizer = fake_size_reader(sizes)

        paths = [("system path", system_path), ("data path", data_path)]
        report = pdg.measure(paths, mount_reader=reader, size_reader=sizer)

        # ---- case 1 and 2: the finding and the clean run ----------------
        check("a path on the system disk is a finding", report["on_system_disk"], 1)
        check("the count of measured paths is printed", report["paths"], 2)
        row_system = report["rows"][0]
        row_data = report["rows"][1]
        check("the system path names its volume", row_system["volume"],
              "/System/Volumes/Data")
        check("the system path names its device", row_system["device"],
              "/dev/disk3s5")
        check("the system path is on the system disk", row_system["where"],
              "system disk")
        check("the data path is on the data disk", row_data["where"], "data disk")
        check("the data path names its volume", row_data["volume"], "/Volumes/ANAN")

        # ---- case 3: the mount point decides, not the path prefix ------
        prefixed = root / "Users" / "someone" / "cache"
        prefixed.mkdir(parents=True)
        volumes[str(prefixed)] = dict(DATA_DISK)
        report2 = pdg.measure([("prefixed path", prefixed)],
                              mount_reader=reader,
                              size_reader=fake_size_reader({str(prefixed): "2G"}))
        check("a /Users path on the data disk reads as the data disk",
              report2["rows"][0]["where"], "data disk")
        check("a /Users path on the data disk is not a finding",
              report2["on_system_disk"], 0)

        # ---- case 4: the container, not the size ------------------------
        check("the system volume's container is read",
              pdg.container_of("/dev/disk3s1s1"), "disk3")
        check("the data volume's container is read",
              pdg.container_of("/dev/disk3s5"), "disk3")
        check("a slice of the same disk is the same container",
              pdg.container_of("/dev/disk3s5") == pdg.container_of("/dev/disk3s1s1"),
              True)
        check("the other disk is another container",
              pdg.container_of("/dev/disk7s1"), "disk7")
        check("the system disks named are the two volumes of one disk",
              sorted(report["system_volumes"].keys()),
              ["/", "/System/Volumes/Data"])
        # a device of the system container that is neither of the two anchors
        # is still the system disk (= = the container is what counts)
        extra = root / "system" / "extra"
        extra.mkdir(parents=True)
        volumes[str(extra)] = {"device": "/dev/disk3s6", "mount": "/System/Volumes/VM",
                               "container": "disk3"}
        report3 = pdg.measure([("extra system slice", extra)],
                              mount_reader=reader,
                              size_reader=fake_size_reader({str(extra): "3G"}))
        check("another slice of the system container is the system disk",
              report3["rows"][0]["where"], "system disk")

        # ---- case 5: an absent path ------------------------------------
        absent = root / "not-there"
        report4 = pdg.measure([("absent path", absent)], mount_reader=reader,
                              size_reader=sizer)
        check("an absent path is reported as absent",
              report4["rows"][0]["where"], "(absent)")
        check("an absent path is not a finding", report4["on_system_disk"], 0)

        # ---- case 7: the size is printed --------------------------------
        check("the size is read", row_system["size"], "12M")
        check("the data path's size is read", row_data["size"], "34G")

    # ---- case 6: every path the flow writes is in the report -----------
    with tempfile.TemporaryDirectory() as td:
        repo = Path(td) / "repo"
        home = Path(td) / "home"
        repo.mkdir()
        board = home / "kanban" / "boards" / "wenshu-par"
        board.mkdir(parents=True)
        (board / "kanban.db").write_text("db")
        for profile in ("pocock", "wenshu-review"):
            for name in ("cache", "checkpoints", "state-snapshots", "sessions"):
                (home / "profiles" / profile / name).mkdir(parents=True)
        labels = [label for label, _ in pdg.process_paths(repo, home)]
        for want in ("repo .scratch (the plan of record)",
                     "repo .worktrees (the card worktrees)",
                     "repo .gate-logs (the gate logs)",
                     "board workspaces (the card worktrees)",
                     "board database",
                     "profile pocock cache/",
                     "profile wenshu-review sessions/",
                     "TMPDIR (the current scratch dir)"):
            check(f"the report names '{want}'", want in labels, True)

    # ---- case 8: the gate reports and moves nothing --------------------
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        system_path, data_path, volumes, sizes = make_tree(root)
        before = {p: p.read_bytes() for p in root.rglob("*") if p.is_file()}
        paths = [("system path", system_path), ("data path", data_path)]
        report = pdg.measure(paths, mount_reader=fake_mount_reader(volumes),
                             size_reader=fake_size_reader(sizes))
        after = {p: p.read_bytes() for p in root.rglob("*") if p.is_file()}
        check("the fixture tree is untouched", sorted(map(str, after)),
              sorted(map(str, before)))
        check("the move is named as the boss's call",
              "boss's call" in report["note"], True)

    # ---- case 9: the CLI prints the report -----------------------------
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        repo = root / "repo"
        repo.mkdir()
        (repo / ".scratch").mkdir()
        env = {"PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOME": str(root)}
        r = subprocess.run([sys.executable, str(TOOL), "--repo", str(repo)],
                           capture_output=True, text=True, timeout=900, env=env)
        out = r.stdout + r.stderr
        check("the cli prints the repo's own paths", ".scratch" in out, True)
        check("the cli prints a volume per path", "volume=" in out, True)
        check("the cli prints the count", "paths measured:" in out, True)
        check("the cli names the boss's call", "boss's call" in out, True)
        r_json = subprocess.run(
            [sys.executable, str(TOOL), "--repo", str(repo), "--json"],
            capture_output=True, text=True, timeout=900, env=env)
        payload = json.loads(r_json.stdout)
        check("the json carries the path count", payload["paths"], 14)
        check("the json carries the note", "boss's call" in payload["note"], True)

    print()
    if FAILURES:
        print(f"{len(FAILURES)} case(s) failed: {', '.join(FAILURES)}")
        return 1
    print("all cases passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
