#!/usr/bin/env python3
"""process_data_gate.py — THE PROCESS DATA LIVES ON THE DATA DISK.

One question, one gate:

  CONTRACT  does every path this repo's own flow writes land on the DATA
            disk (= = /Volumes/ANAN), and not on the system disk?

WHY THE GATE EXISTS (measured 2026-11-24):

  - The system disk is nearly full: `df -h /` reports 228 GiB total with
    8.0 GiB free, and `df -h /System/Volumes/Data` reports the SAME
    container at 96% capacity (= = the writable volume of that container).
  - The data disk has room: `df -h /Volumes/ANAN` reports 1.8 TiB total with
    1.4 TiB free.
  - So every GiB of process data that lands on the system disk is a GiB the
    data disk could have taken, and the flow's own volume (= = the board's
    workspaces, the profile caches, the card worktrees) is what fills it.

WHAT IT MEASURES (= = one row per path this repo's flow writes):

    <label>
        path=<path>  volume=<mount point>  device=<device>  size=<du -sh>
        where=<data disk|system disk>

  The paths are the repo's own (.scratch = = the plan of record, .worktrees =
  = the card worktrees, .gate-logs = = the gate logs), the board's (the
  workspaces dir and the board database), the Hermes profile caches of the
  profiles this flow uses (pocock, wenshu-review: cache/, checkpoints/,
  state-snapshots/, sessions/), and the current TMPDIR.

HOW IT DECIDES (measured, never assumed):

  A path's VOLUME is read from the mount table (= = `df -P <path>` gives the
  device and the mount point), and the system disk is the CONTAINER of `/`
  together with the container of `/System/Volumes/Data` (= = the writable
  data volume of the SAME APFS container = = the two are one disk). The
  container id is the device's own `diskN` prefix, so the comparison is a
  DEVICE comparison, not a size comparison and not a path-prefix guess.

  The path-prefix guess is the trap this gate exists to avoid: `/Users/...`
  LOOKS like the system disk, but a symlink under it can put the very same
  bytes on `/Volumes/ANAN`. Only the mount table says which disk a file is
  on, so only the mount table is asked.

IT REPORTS, IT DOES NOT MOVE (= = the boss's call):

  Moving 22 GiB of board files and 34 GiB of profile cache is a change to the
  Hermes install, not to this repo, so the gate prints the rows and one line
  naming the move as the boss's decision. It moves nothing and deletes
  nothing.

Usage:
    python3 Tools/wenshu-devtool/process_data_gate.py
    python3 Tools/wenshu-devtool/process_data_gate.py --repo PATH
    python3 Tools/wenshu-devtool/process_data_gate.py --json

Exit code 0 = every path is on the data disk, 1 = at least one path is on the
system disk (the row names it), 2 = the disk could not be measured.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import product_lines  # noqa: E402  (sibling module, same directory)

# The board slug whose workspaces the flow creates (= = the line's own board).
BOARD = product_lines.DEFAULT_BOARD

# The Hermes home that holds the board and the profiles (= = derived from the
# board's own path, so a profile's HERMES_HOME does not move it).
GLOBAL_HOME = Path(product_lines.board_db(BOARD)).parents[3]

# The profiles this repo's flow runs under.
PROFILES = ("pocock", "wenshu-review")

# The profile dirs that grow with use (= = cache, checkpoints, snapshots, sessions).
PROFILE_DIRS = ("cache", "checkpoints", "state-snapshots", "sessions")

# The device id's container: /dev/disk3s1s1 and /dev/disk3s5 are slices of
# the SAME container (disk3), and /dev/disk7s1 is another one (disk7).
CONTAINER_RE = re.compile(r"^(?:/dev/)?(disk\d+)")


def repo_root() -> Path:
    """The repo root the flow writes its own artifacts into.

    A copy of this file inside a card worktree lives at
    `<main>/.worktrees/<name>/Tools/wenshu-devtool/`, and the flow's
    artifacts (.scratch, .worktrees, .gate-logs) live in the MAIN checkout,
    so a worktree copy resolves to the main checkout (= = the shared .git
    directory names it). A copy outside any checkout falls back to its own
    parents.
    """
    root = Path(__file__).resolve().parents[2]
    if (root / ".git").is_file():
        try:
            out = subprocess.run(
                ["git", "-C", str(root), "rev-parse", "--path-format=absolute",
                 "--git-common-dir"],
                capture_output=True, text=True, timeout=30,
            )
            common = out.stdout.strip()
            if out.returncode == 0 and common:
                return Path(common).parent
        except (OSError, subprocess.SubprocessError):
            pass
    return root


def container_of(device: str) -> str:
    """The container a device id belongs to (= = the physical disk).

    `df` prints a slice (/dev/disk3s5) or a snapshot volume
    (/dev/disk3s1s1), and the slices of one container share the `diskN`
    prefix. A device that is not a local disk (a network mount) keeps its
    own name, so it never collides with a container id.
    """
    match = CONTAINER_RE.match((device or "").strip())
    return match.group(1) if match else (device or "").strip()


def mount_of(path: Path) -> dict:
    """The volume a path is on, read from the mount table.

    `df -P` prints POSIX output: the device, the block counts, the capacity
    and the mount point. The mount point is the VOLUME NAME (= = the thing
    the report prints), and the device is what the container is derived from.
    """
    out = subprocess.run(
        ["df", "-P", str(path)], capture_output=True, text=True, timeout=60
    )
    if out.returncode != 0:
        raise OSError(f"df failed for {path}: {out.stderr.strip() or out.returncode}")
    lines = out.stdout.strip().splitlines()
    if len(lines) < 2:
        raise OSError(f"df printed no row for {path}")
    fields = lines[-1].split(None, 5)
    if len(fields) < 6:
        raise OSError(f"df printed an unreadable row for {path}: {lines[-1]}")
    device, blocks, used, avail, capacity, mount = fields
    return {
        "device": device,
        "blocks": int(blocks),
        "used": int(used),
        "available": int(avail),
        "capacity": capacity,
        "mount": mount,
        "container": container_of(device),
    }


def size_of(path: Path) -> str:
    """The path's size, as `du -sh` prints it (= = human units).

    A path that does not exist has no size, and the report says so instead
    of failing the whole run.
    """
    if not path.exists():
        return "(absent)"
    out = subprocess.run(
        ["du", "-sh", str(path)], capture_output=True, text=True, timeout=900
    )
    if out.returncode != 0:
        return "(unreadable)"
    return out.stdout.split()[0] if out.stdout.split() else "(unknown)"


def system_volumes(mount_reader=mount_of) -> dict:
    """The volumes that ARE the system disk (= = `/` and its data volume).

    `/` and `/System/Volumes/Data` are the system volume and the writable
    volume of the SAME container, so both are read and both count. The
    device id is compared, not the size (= = two disks can hold the same
    number of bytes and still be two disks).
    """
    out = {}
    anchors = (("/", Path("/")),
               ("/System/Volumes/Data", Path("/System/Volumes/Data")))
    for label, path in anchors:
        if not path.exists():
            continue
        try:
            info = mount_reader(path)
        except (OSError, ValueError):
            continue
        out[label] = info
    return out


def process_paths(repo: Path, home: Path) -> list[tuple[str, Path]]:
    """Every path this repo's own flow writes, each with its label."""
    board = home / "kanban" / "boards" / BOARD
    paths: list[tuple[str, Path]] = [
        ("repo .scratch (the plan of record)", repo / ".scratch"),
        ("repo .worktrees (the card worktrees)", repo / ".worktrees"),
        ("repo .gate-logs (the gate logs)", repo / ".gate-logs"),
        ("board workspaces (the card worktrees)", board / "workspaces"),
        ("board database", board / "kanban.db"),
    ]
    for profile in PROFILES:
        for name in PROFILE_DIRS:
            paths.append(
                (f"profile {profile} {name}/", home / "profiles" / profile / name)
            )
    paths.append(("TMPDIR (the current scratch dir)", Path(tempfile.gettempdir())))
    return paths


def measure(paths, mount_reader=None, size_reader=None) -> dict:
    """The report: one row per path, with its volume and its size.

    The two readers are parameters (= = the disk-reading is one small
    function, so a suite can drive the gate with a fixture disk instead of
    the machine's own).
    """
    mount_reader = mount_reader or mount_of
    size_reader = size_reader or size_of
    volumes = system_volumes(mount_reader)
    system_ids = {info["container"] for info in volumes.values()}
    system_devices = {info["device"] for info in volumes.values()}
    rows = []
    for label, path in paths:
        row = {"label": label, "path": str(path)}
        if not path.exists():
            row.update({"exists": False, "size": "(absent)", "where": "(absent)"})
            rows.append(row)
            continue
        row["exists"] = True
        try:
            info = mount_reader(path)
        except (OSError, ValueError) as exc:
            row.update({"volume": "(unreadable)", "device": "(unreadable)",
                        "container": "", "size": size_reader(path),
                        "where": "system disk", "note": str(exc)})
            rows.append(row)
            continue
        on_system = (info["container"] in system_ids
                     or info["device"] in system_devices)
        row.update({
            "volume": info["mount"],
            "device": info["device"],
            "container": info["container"],
            "size": size_reader(path),
            "where": "system disk" if on_system else "data disk",
        })
        rows.append(row)
    violations = [r for r in rows if r.get("where") == "system disk"]
    return {
        "system_volumes": {label: info["mount"] for label, info in volumes.items()},
        "system_containers": sorted(system_ids),
        "paths": len(rows),
        "on_system_disk": len(violations),
        "rows": rows,
        "note": "the move is the boss's call: this gate reports the volume of every path and moves nothing",
    }


def print_report(report: dict) -> None:
    """The text report: one block per path, then the count."""
    print("process-data: where this repo's flow writes")
    for label, volume in report["system_volumes"].items():
        print(f"  system disk volume: {volume}  (mounted on {label})")
    print(f"  paths measured: {report['paths']} | on the system disk: "
          f"{report['on_system_disk']}")
    for row in report["rows"]:
        print(f"  {row['label']}")
        print(f"      path={row['path']}")
        print(f"      volume={row.get('volume', '(absent)')}  "
              f"device={row.get('device', '(absent)')}  size={row.get('size')}")
        print(f"      where={row.get('where')}")
    print(f"  {report['note']}")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo", default=None,
                    help="the repo whose flow writes the paths (default: this repo)")
    ap.add_argument("--json", action="store_true", help="print the report as JSON")
    args = ap.parse_args(argv)

    repo = Path(args.repo).expanduser() if args.repo else repo_root()
    paths = process_paths(repo, GLOBAL_HOME)
    try:
        report = measure(paths)
    except (OSError, ValueError) as exc:
        print(f"could not measure the disk: {exc}", file=sys.stderr)
        return 2

    report["repo"] = str(repo)
    report["hermes_home"] = str(GLOBAL_HOME)
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=1))
    else:
        print_report(report)
    return 1 if report["on_system_disk"] else 0


if __name__ == "__main__":
    sys.exit(main())
