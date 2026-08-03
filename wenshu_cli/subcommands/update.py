"""``wenshu update`` subcommand parser.

Extracted verbatim from ``wenshu_cli/main.py:main()`` (god-file Phase 2).
Handler injected to avoid importing ``main``.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tarfile
import tempfile
import urllib.error
import urllib.request
import zipfile
from pathlib import Path
from typing import Callable


# R128: bootstrap-installed wenshu-cli runs from the installer's PATH context,
# which often lacks the locations where `pnpm` and `cargo` actually live
# (`~/.cargo/bin`, `/opt/homebrew/bin`, `~/.local/bin`). Without an explicit
# probe the update flow falls back to RuntimeError("pnpm was not found on PATH")
# even though the binaries are installed (e.g. ~/.local/share/pnpm/pnpm).
_R128_FALLBACK_PATHS = (
    "/Users/anbaiqiang/.cargo/bin",
    "/Users/anbaiqiang/.local/bin",
    "/Users/anbaiqiang/.local/share/pnpm",
    "/opt/homebrew/bin",
    "/usr/local/bin",
    str(Path.home() / ".cargo" / "bin"),
)


# R130: electron-builder 26.15.3 ships with an internal bug — its
# `app-builder-lib/out/util/electronGet.js:resolveCacheMode()` reads
# `@electron/get.ElectronDownloadCacheMode.ReadWrite`, but `@electron/get@3.0.0`
# (the version pinned by app-builder-lib@26.15.3) does not export that enum
# (it only exports the `Cache` class). Every Electron/toolset download blows up
# with `Cannot read properties of undefined (reading 'ReadWrite')`.
#
# Workaround: pre-stage the two artifacts that electron-builder/dmg-builder
# would otherwise try to download, so the buggy code path is never executed:
#
#   1. Electron.app — extracted into the directory Node resolves as
#      `electron/package.json`'s sibling (`<root>/node_modules/electron/dist/`).
#      `apps/desktop/scripts/run-electron-builder.mjs` auto-detects that dir
#      and passes `-c.electronDist=<abs>/dist` to electron-builder, which
#      short-circuits the @electron/get download entirely.
#
#   2. dmgbuild — extracted under the electron-builder binaries cache
#      (`~/Library/Caches/electron-builder-binaries/dmg-builder@1.2.5/`) and
#      referenced via `CUSTOM_DMGBUILD_PATH=<...>/dmgbuild`. `dmg-builder`
#      checks `CUSTOM_DMGBUILD_PATH` *before* calling `downloadBuilderToolset`
#      (dmg-builder/out/dmgUtil.js:getDmgVendorPath), so the broken
#      resolveCacheMode path is skipped.
#
# Both artifacts are mirrored on npmmirror.com:
#   - Electron:     https://cdn.npmmirror.com/binaries/electron/<v>/electron-v<v>-<plat>-<arch>.zip
#   - dmg-builder:  https://cdn.npmmirror.com/binaries/electron-builder-binaries/dmg-builder@1.2.5/dmgbuild-bundle-<arch>-75c8a6c.tar.gz
# The install.sh harness already uses these mirrors; we reuse them here so the
# update flow works on networks that block github.com.
_R130_ELECTRON_MIRROR = "https://cdn.npmmirror.com/binaries/electron/"
_R130_DMGBUILD_MIRROR = (
    "https://cdn.npmmirror.com/binaries/electron-builder-binaries/"
    "dmg-builder@1.2.5/"
)
_R130_DMGBUILD_RELEASE = "dmg-builder@1.2.5"
_R130_DMGBUILD_BUNDLE_HASH = "75c8a6c"


def _http_download(url: str, dest: Path, *, timeout: float = 300.0) -> None:
    """Stream ``url`` to ``dest``. Raises ``RuntimeError`` on HTTP failure."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "wenshu-update/R130"})
        with urllib.request.urlopen(req, timeout=timeout) as resp, open(dest, "wb") as fh:
            shutil.copyfileobj(resp, fh, length=1024 * 256)
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, OSError) as exc:
        raise RuntimeError(f"R130: failed to download {url}: {exc}") from exc


def _resolve_node_modules_dir(start: Path, package: str) -> Path | None:
    """Emulate Node's ``require.resolve`` walk for ``package`` from ``start``.

    Node's module resolution walks parent directories looking for
    ``node_modules/<package>/package.json``. pnpm hoists dependencies to the
    workspace root, so from ``apps/desktop`` we often resolve to
    ``<repo>/node_modules/electron/package.json``.
    """
    cur = start.resolve()
    while True:
        candidate = cur / "node_modules" / package / "package.json"
        if candidate.is_file():
            return candidate.parent
        if cur.parent == cur:
            return None
        cur = cur.parent


def _ensure_electron_dist(desktop_dir: Path) -> Path:
    """Stage ``Electron.app`` next to ``electron/package.json``.

    Skips work if the dist already matches the expected Electron version.
    Returns the absolute path to the staged ``dist`` directory.
    """
    electron_root = _resolve_node_modules_dir(desktop_dir, "electron")
    if electron_root is None:
        raise RuntimeError(
            "R130: could not resolve an `electron` install via parent-dir walk "
            f"starting at {desktop_dir}; run `pnpm install` in apps/desktop first"
        )
    dist_dir = electron_root / "dist"
    electron_app = dist_dir / "Electron.app"
    electron_bin = electron_app / "Contents" / "MacOS" / "Electron"

    # Fast path: dist already extracted and matches the package's declared version.
    pkg = json.loads(electron_root.joinpath("package.json").read_text())
    expected_version = str(pkg.get("version", "")).strip()
    version_file = dist_dir / "version"
    if electron_bin.is_file() and version_file.is_file():
        existing = version_file.read_text().strip().lstrip("v")
        if expected_version and existing == expected_version:
            print(
                f"→ R130: electron dist already staged at {dist_dir} "
                f"(version {existing}); skipping download"
            )
            return dist_dir

    # Slow path: fetch from npmmirror and extract.
    platform = "darwin"
    arch = "arm64" if os.uname().machine == "arm64" else "x64"
    zip_name = f"electron-v{expected_version}-{platform}-{arch}.zip"
    url = f"{_R130_ELECTRON_MIRROR}{expected_version}/{zip_name}"
    print(f"→ R130: fetching Electron {expected_version} {platform}-{arch} from npmmirror")

    with tempfile.TemporaryDirectory(prefix="wenshu-r130-electron-") as tmp:
        tmp_dir = Path(tmp)
        zip_path = tmp_dir / zip_name
        _http_download(url, zip_path)

        # Extract atomically: stage into a tmp sibling, then rename.
        staging = electron_root / "dist.r130-stage"
        if staging.exists():
            shutil.rmtree(staging)
        staging.mkdir(parents=True)
        with zipfile.ZipFile(zip_path) as zf:
            zf.extractall(staging)

        if dist_dir.exists():
            shutil.rmtree(dist_dir)
        staging.rename(dist_dir)

    # Pin the version so re-runs short-circuit and so electron-builder's
    # `install.js` happy-paths (`isInstalled()` reads `dist/version`).
    (dist_dir / "version").write_text(expected_version + "\n")
    # `path.txt` lets Node's `electron` CLI launch Electron.app without argv tricks.
    (electron_root / "path.txt").write_text(
        "Electron.app/Contents/MacOS/Electron\n"
    )
    print(f"✓ R130: staged {electron_app} (version {expected_version})")
    return dist_dir


def _ensure_dmgbuild() -> Path:
    """Stage the dmgbuild binary under the electron-builder binaries cache.

    Returns the absolute path to the unpacked ``dmgbuild`` executable. The
    caller is expected to export it as ``CUSTOM_DMGBUILD_PATH``.
    """
    cache_root = Path.home() / "Library" / "Caches" / "electron-builder-binaries"
    release_dir = cache_root / _R130_DMGBUILD_RELEASE
    bundle_name = f"dmgbuild-bundle-arm64-{_R130_DMGBUILD_BUNDLE_HASH}"
    archive_name = f"{bundle_name}.tar.gz"
    archive_url = f"{_R130_DMGBUILD_MIRROR}{archive_name}"

    # Fast path: any extracted bundle directory already containing a `dmgbuild`
    # executable. electron-builder's `downloadBuilderToolset` extracts into a
    # hash-suffixed subdirectory (`<bundle>-<5-char-hash>`), so we scan for it.
    if release_dir.is_dir():
        for child in release_dir.iterdir():
            if child.is_dir() and (child / "dmgbuild").is_file():
                print(f"→ R130: dmgbuild already staged at {child / 'dmgbuild'}")
                return child / "dmgbuild"

    # Slow path: fetch the tarball from npmmirror, extract under the canonical
    # release dir. We deliberately extract to `<bundle>-r130-stage` first and
    # rename, so a half-extracted cache can never satisfy a later run.
    release_dir.mkdir(parents=True, exist_ok=True)
    archive_path = release_dir / archive_name
    if not archive_path.is_file():
        print(f"→ R130: fetching dmgbuild bundle from npmmirror ({archive_url})")
        _http_download(archive_url, archive_path)

    staging = release_dir / f"{bundle_name}-r130-stage"
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)
    with tarfile.open(archive_path, "r:gz") as tf:
        tf.extractall(staging)

    # Drop any pre-existing canonical extract dir before promoting staging.
    canonical = release_dir / bundle_name
    if canonical.exists():
        shutil.rmtree(canonical)
    staging.rename(canonical)

    dmgbuild_bin = canonical / "dmgbuild"
    if not dmgbuild_bin.is_file():
        raise RuntimeError(
            f"R130: dmgbuild extraction succeeded but {dmgbuild_bin} is missing — "
            "the npmmirror tarball layout may have changed; inspect the archive"
        )
    dmgbuild_bin.chmod(0o755)
    print(f"✓ R130: staged dmgbuild at {dmgbuild_bin}")
    return dmgbuild_bin


def _resolve_executable(name: str) -> str | None:
    """Return absolute path for ``name`` or None.

    Search order: shutil.which on the inherited PATH, then a curated list of
    well-known user-installed locations (npm/pnpm global, cargo, Homebrew).
    """
    found = shutil.which(name)
    if found:
        return found
    for directory in _R128_FALLBACK_PATHS:
        candidate = Path(directory) / name
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def _run_update_build_step(
    command: list[str],
    cwd: Path,
    extra_env: dict[str, str] | None = None,
) -> None:
    """Run a release step without shell splitting macOS paths.

    ``extra_env`` entries are merged onto a copy of the inherited environment
    after the R128 PATH fallback injection and the R129 ELECTRON_MIRROR
    default, so callers can override or append without rebuilding the whole
    environment. Keys are written verbatim; pass absolute paths for tools
    that the child resolves at startup.
    """
    print(f"→ Running: {' '.join(command)} (cwd={cwd})")
    # R128: ensure child subprocess inherits a PATH that includes the same
    # fallback directories we just searched, otherwise `pnpm dist:mac` would
    # in turn spawn pnpm-managed scripts that can't find their own pnpm shim.
    # R129: also inject ELECTRON_MIRROR so @electron/get can fetch the Electron
    # tarball (the public npmmirror.com/mirrors/electron/ is what install.sh
    # uses — otherwise the download tries github.com and times out on networks
    # that block it).
    child_env = os.environ.copy()
    extra = os.pathsep.join(p for p in _R128_FALLBACK_PATHS if Path(p).is_dir())
    if extra:
        child_env["PATH"] = f"{child_env.get('PATH', '')}{os.pathsep}{extra}"
    if "ELECTRON_MIRROR" not in child_env and "ELECTRON_DOWNLOAD" not in child_env:
        child_env["ELECTRON_MIRROR"] = "https://npmmirror.com/mirrors/electron/"
    if extra_env:
        child_env.update(extra_env)
    subprocess.run(command, cwd=cwd, check=True, env=child_env)


def build_and_stage_macos_release(project_root: Path) -> dict[str, Path]:
    """Build and stage macOS releases without writing to system Applications."""
    if os.uname().sysname != "Darwin":
        raise RuntimeError("macOS release staging was requested on a non-macOS host")

    desktop_dir = project_root / "apps" / "desktop"
    installer_dir = project_root / "apps" / "bootstrap-installer"
    pnpm = _resolve_executable("pnpm")
    cargo = _resolve_executable("cargo")
    if not pnpm:
        raise RuntimeError(
            "pnpm was not found on PATH (searched PATH + "
            + ", ".join(_R128_FALLBACK_PATHS) + ")"
        )
    if not cargo:
        raise RuntimeError(
            "cargo was not found on PATH (searched PATH + "
            + ", ".join(_R128_FALLBACK_PATHS) + ")"
        )

    # R130: pre-stage the Electron binary and the dmgbuild bundle so
    # electron-builder 26.15.3 never invokes @electron/get@3.0.0 (which would
    # throw `Cannot read properties of undefined (reading 'ReadWrite')` because
    # the upstream enum was removed in v3.0.0). See module docstring.
    _ensure_electron_dist(desktop_dir)
    dmgbuild_path = _ensure_dmgbuild()

    _run_update_build_step(
        [pnpm, "dist:mac"],
        desktop_dir,
        extra_env={"CUSTOM_DMGBUILD_PATH": str(dmgbuild_path)},
    )
    _run_update_build_step(
        [cargo, "tauri", "build"], installer_dir
    )

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
