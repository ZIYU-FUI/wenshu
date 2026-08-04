"""WENSHU Python backend for project creation and editor stubs."""

from datetime import datetime, timezone
import json
from pathlib import Path

from fastapi import APIRouter, Response

from editors import (  # noqa: F401 - imports are part of the smoke test
    outline,
    research,
    style,
    character,
    plot,
    dialogue,
    proofread,
    chief,
)

manifest = {
    "id": "wenshu",
    "name": "WENSHU",
    "api": "plugin_api.py",
}

router = APIRouter()

_HEALTH = {
    "status": "ok",
    "service": "wenshu",
    "version": "0.2.0",
}


def _project_body(request):
    """Accept a direct body or the legacy {body: ...} test-call shape."""
    payload = request or {}
    if isinstance(payload, dict) and isinstance(payload.get("body"), dict):
        payload = payload["body"]
    return payload if isinstance(payload, dict) else {}


def _validated_project(request):
    body = _project_body(request)
    name = str(body.get("name") or "").strip()
    summary = str(body.get("summary") or "").strip()
    target_dir = str(body.get("target_dir") or "").strip()

    if not name:
        raise ValueError("项目名不能为空")
    if name in {".", ".."} or Path(name).name != name or "/" in name or "\\" in name:
        raise ValueError("项目名不能包含路径分隔符")
    if not target_dir:
        raise ValueError("目标目录不能为空")

    target = Path(target_dir).expanduser()
    if not target.is_absolute():
        raise ValueError("目标目录必须是绝对路径")
    return name, summary, target


def _read_existing_summary(project_dir):
    metadata_path = project_dir / ".wenshu" / "project.json"
    try:
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    except (OSError, ValueError, TypeError):
        return ""
    return str(metadata.get("summary") or "")


def _create_project(request):
    name, summary, target = _validated_project(request)
    project_dir = target / name

    if project_dir.exists():
        return {
            "status": "exists",
            "project_path": str(project_dir),
            "existing_summary": _read_existing_summary(project_dir),
        }

    project_dir.mkdir(parents=True, exist_ok=False)
    metadata_dir = project_dir / ".wenshu"
    chapters_dir = project_dir / "chapters"
    metadata_dir.mkdir()
    (project_dir / "characters").mkdir()
    chapters_dir.mkdir()

    metadata = {
        "name": name,
        "summary": summary,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "methodology": None,
        "style": None,
    }
    (metadata_dir / "project.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    (project_dir / "outline.md").write_text(
        "<!-- WENSHU 大纲占位,后续将在此生成故事大纲。 -->\n",
        encoding="utf-8",
    )
    (chapters_dir / "README.md").write_text(
        "# 章节\n\nWENSHU 生成的章节将保存在此目录。\n",
        encoding="utf-8",
    )
    return {"status": "created", "project_path": str(project_dir)}


@router.get("/health")
async def health():
    return _HEALTH


@router.get("/projects")
async def list_projects():
    return {"projects": []}


@router.post("/projects")
async def create_project_route(body: dict, response: Response):
    result = _create_project(body)
    response.status_code = 201 if result["status"] == "created" else 200
    return result


# Direct-call adapter retained for local smoke tests and older Hermes hosts.
def create_project(request):
    return _create_project(request)


def get_outline(request):
    name = (request or {}).get("params", {}).get("name", "")
    return {
        "project": name,
        "status": "stub",
        "editor": "outline",
        "chapters": [{"n": 1, "title": "第一章(占位)", "beats": []}],
    }


def get_chapter(request):
    params = (request or {}).get("params", {})
    name = params.get("name", "")
    n = params.get("n", 0)
    return {
        "project": name,
        "chapter": n,
        "status": "stub",
        "editor": "dialogue",
        "markdown": "# 第 {n} 章(占位)\n\n_占位章节 markdown。_\n".format(n=n),
    }
