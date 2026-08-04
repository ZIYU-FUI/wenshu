"""
WENSHU (wenshu) Python backend — entrypoint for hermes plugin host.

Loaded only when 'wenshu' appears in `plugins.enabled` of the active
hermes profile config (cf. AGENTS.md v0.2 §7). Exposes the JSON API the
desktop plugin (`desktop-plugin/plugin.js`) talks to via
`ctx.rest('/path', ...)` → `/api/plugins/wenshu/path`.

v0.1.0 = scaffold only: every route returns a placeholder payload. Real
8-editor orchestration lands in 0.2.0 (per AGENTS.md §8 stage gate).
"""

# manifest = the only thing hermes reads to locate this backend.
# Keep it as a module-level constant — do NOT rename without PM-direct.
manifest = {
    "id": "wenshu",
    "name": "WENSHU",
    "api": "plugin_api.py",
}

# 8 hidden editorial roles (per AGENTS.md v0.2 §13). Imported here so
# `python -c "import plugin_api"` in scripts/verify.sh exercises every
# editor module in one shot. Each module exports its own
# `async def run(context: dict) -> dict` stub; the loop in 0.2.0 will
# wire them up against the `/projects/<name>/...` routes below.
from editors import (  # noqa: F401  (import-only smoke test)
    outline,
    research,
    style,
    character,
    plot,
    dialogue,
    proofread,
    chief,
)

# ---------- HTTP routes ----------
#
# The hermes plugin host wires each public function (no leading underscore)
# to a JSON route under `/api/plugins/wenshu/<func_name>`. Functions take
# a single `request: dict` arg and return a JSON-serialisable object.
# v0.1.0: every route is a stub returning a deterministic placeholder.

_HEALTH = {
    "status": "ok",
    "service": "wenshu",
    "version": "0.1.0",
}


def health(request):
    """GET /health → liveness probe."""
    return _HEALTH


def list_projects(request):
    """GET /projects → list of project names under user data root.

    v0.1.0: stub — returns empty list. Real read of
    `~/Documents/wenshu-projects/` lands in 0.2.0.
    """
    return {"projects": []}


def create_project(request):
    """POST /projects body={"name": "..."} → create a new project skeleton.

    v0.1.0: stub — echoes the requested name. Real
    `~/Documents/wenshu-projects/<name>/` creation lands in 0.2.0.
    """
    name = ((request or {}).get("body") or {}).get("name", "").strip()
    return {
        "status": "stub",
        "name": name,
        "editor": "chief",
    }


def get_outline(request):
    """GET /projects/<name>/outline → skeleton outline JSON.

    v0.1.0: stub — single-chapter placeholder. The `outline` editor
    (editors/outline.py) will own real generation in 0.2.0.
    """
    name = (request or {}).get("params", {}).get("name", "")
    return {
        "project": name,
        "status": "stub",
        "editor": "outline",
        "chapters": [
            {"n": 1, "title": "第一章(占位)", "beats": []}
        ],
    }


def get_chapter(request):
    """GET /projects/<name>/chapter/<n> → chapter markdown.

    v0.1.0: stub — placeholder markdown. The `dialogue` editor
    (editors/dialogue.py) will own real prose generation in 0.2.0.
    """
    name = (request or {}).get("params", {}).get("name", "")
    n = (request or {}).get("params", {}).get("n", 0)
    return {
        "project": name,
        "chapter": n,
        "status": "stub",
        "editor": "dialogue",
        "markdown": (
            "# 第 {n} 章(占位)\n\n"
            "_占位章节 markdown — 0.2.0 由 dialogue 编辑器实写。_\n"
        ).format(n=n),
    }
