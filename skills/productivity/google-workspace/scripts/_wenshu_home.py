"""Resolve WENSHU_HOME for standalone skill scripts.

Skill scripts may run outside the Wenshu process (e.g. system Python,
nix env, CI) where ``wenshu_constants`` is not importable.  This module
provides the same ``get_wenshu_home()`` and ``display_wenshu_home()``
contracts as ``wenshu_constants`` without requiring it on ``sys.path``.

When ``wenshu_constants`` IS available it is used directly so that any
future enhancements (profile resolution, Docker detection, etc.) are
picked up automatically.  The fallback path replicates the core logic
from ``wenshu_constants.py`` using only the stdlib.

All scripts under ``google-workspace/scripts/`` should import from here
instead of duplicating the ``WENSHU_HOME = Path(os.getenv(...))`` pattern.
"""

from __future__ import annotations

import os
from pathlib import Path

try:
    from wenshu_constants import display_wenshu_home as display_wenshu_home
    from wenshu_constants import get_wenshu_home as get_wenshu_home
except (ModuleNotFoundError, ImportError):

    def get_wenshu_home() -> Path:
        """Return the Wenshu home directory (default: ~/.wenshu).

        Mirrors ``wenshu_constants.get_wenshu_home()``."""
        val = os.environ.get("WENSHU_HOME", "").strip()
        return Path(val) if val else Path.home() / ".wenshu-hermes"

    def display_wenshu_home() -> str:
        """Return a user-friendly ``~/``-shortened display string.

        Mirrors ``wenshu_constants.display_wenshu_home()``."""
        home = get_wenshu_home()
        try:
            return "~/" + str(home.relative_to(Path.home()))
        except ValueError:
            return str(home)
