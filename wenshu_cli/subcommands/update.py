"""``wenshu update`` subcommand parser.

Extracted verbatim from ``wenshu_cli/main.py:main()`` (god-file Phase 2).
Handler injected to avoid importing ``main``.
"""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path
from typing import Callable


def _run_update_build_step(command: list[str], cwd: Path) -> None:
    """Run a release step without shell splitting macOS paths."""
    print(f"→ Running: {' '.join(command)} (cwd={cwd})")
    subprocess.run(command, cwd=cwd, check=True)


def build_and_stage_macos_release(project_root: Path) -> dict[str, Path]:
    """Build and stage macOS releases without writing to system Applications."""
    if os.uname().sysname != "Darwin":
        raise RuntimeError("macOS release staging was requested on a non-macOS host")

    desktop_dir = project_root / "apps" / "desktop"
    installer_dir = project_root / "apps" / "bootstrap-installer"
    pnpm = shutil.which("pnpm")
    cargo = shutil.which("cargo")
    if not pnpm:
        raise RuntimeError("pnpm was not found on PATH")
    if not cargo:
        raise RuntimeError("cargo was not found on PATH")

    _run_update_build_step([pnpm, "dist:mac"], desktop_dir)
    _run_update_build_step([cargo, "tauri", "build"], installer_dir)

    desktop_app = desktop_dir / "release" / "mac-arm64" / "文枢.app"
    desktop_dmg = desktop_dir / "release" / "文枢-0.1.0-arm64.dmg"
    installer_dmg = installer_dir / "src-tauri" / "target" / "release" / "bundle" / "dmg" / "文枢_0.1.0_aarch64.dmg"
    for artifact in (desktop_app, desktop_dmg, installer_dmg):
        if not artifact.exists():
            raise RuntimeError(f"expected macOS artifact was not produced: {artifact}")

    runtime_app = Path(os.environ.get(
        "WENSHU_RUNTIME_APP",
        str(Path.home() / "Applications" / "文枢.app"),
    )).expanduser()
    applications = Path("/Applications")
    if runtime_app == applications / "文枢.app" or applications in runtime_app.parents:
        raise RuntimeError("refusing to write the desktop app directly under /Applications")
    runtime_app.parent.mkdir(parents=True, exist_ok=True)
    staged_app = runtime_app.with_name(runtime_app.name + ".r113-new")
    if staged_app.exists():
        shutil.rmtree(staged_app)
    shutil.copytree(desktop_app, staged_app)
    if runtime_app.exists():
        shutil.rmtree(runtime_app)
    staged_app.rename(runtime_app)

    downloads = Path.home() / "Downloads"
    downloads.mkdir(parents=True, exist_ok=True)
    installer_download = downloads / "WenShu-Setup.dmg"
    desktop_download = downloads / "文枢-0.1.0-arm64.dmg"
    shutil.copy2(installer_dmg, installer_download)
    shutil.copy2(desktop_dmg, desktop_download)
    print(f"✓ Staged desktop app at {runtime_app}; restart 文枢 to use it")
    print(f"✓ Installer DMG: {installer_download}")
    print(f"✓ Desktop DMG: {desktop_download}")
    return {
        "app": runtime_app,
        "installer_dmg": installer_download,
        "desktop_dmg": desktop_download,
    }


def build_update_parser(subparsers, *, cmd_update: Callable) -> None:
    """Attach the ``update`` subcommand to ``subparsers``."""
    # =========================================================================
    # update command
    # =========================================================================
    update_parser = subparsers.add_parser(
        "update",
        help="Update 文枢 to the latest version",
        description="Pull the latest changes from git and reinstall dependencies",
    )
    update_parser.add_argument(
        "--gateway",
        action="store_true",
        default=False,
        help="Gateway mode: use file-based IPC for prompts instead of stdin (used internally by /update)",
    )
    update_parser.add_argument(
        "--check",
        action="store_true",
        default=False,
        help="Check whether an update is available without installing anything",
    )
    update_parser.add_argument(
        "--no-backup",
        action="store_true",
        default=False,
        help="Skip ALL pre-update backups for this run (both the quick state snapshot and the full zip; overrides updates.pre_update_backup)",
    )
    update_parser.add_argument(
        "--backup",
        action="store_true",
        default=False,
        help="Force a FULL pre-update backup (quick state snapshot + WENSHU_HOME zip) for this run, regardless of updates.pre_update_backup",
    )
    update_parser.add_argument(
        "--yes",
        "-y",
        action="store_true",
        default=False,
        help="Assume yes for interactive prompts (config migration, stash restore). API-key entry is skipped; run 'wenshu config migrate' separately for those.",
    )
    update_parser.add_argument(
        "--branch",
        default=None,
        metavar="NAME",
        help=(
            "Update against this branch instead of the default (main). "
            "If the local checkout is on a different branch, wenshu will "
            "switch to the requested branch first (auto-stashing any "
            "uncommitted changes)."
        ),
    )
    update_parser.add_argument(
        "--force",
        action="store_true",
        default=False,
        help="Windows: proceed with the update even when another wenshu.exe is detected. The concurrent process will likely cause WinError 32 warnings and may leave a reboot-deferred .exe replacement. Does NOT bypass the venv-process guard (see --force-venv).",
    )
    update_parser.add_argument(
        "--force-venv",
        action="store_true",
        default=False,
        help="Windows: mutate the venv even while other processes are running from its interpreter (desktop backend, gateway, terminals). Those processes keep native .pyd files locked, so the dependency sync will likely fail partway and strand the install half-updated. Use only if you know the detected holders are false positives.",
    )
    update_parser.set_defaults(func=cmd_update)
