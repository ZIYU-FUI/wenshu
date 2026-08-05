"""WENSHU Python backend for project creation and editor stubs."""

import sys
import json
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, Response

# hermes 上游用 importlib.util.spec_from_file_location 把本文件当模块
# load(spec._montas 模式),它**不**把 api_path.parent 加到 sys.path。
# 本文件在 dashboard/ 子目录,editors/ 也在 dashboard/ 子目录,
# `from editors import ...` 找不到。
# 修法:启动时把 dashboard/ 父目录加 sys.path,editors/ 是它的子包
# (有 __init__.py),Python import 系统会把 dashboard/ 当 namespace
# package,editors 是 dashboard 下的 module。
sys.path.insert(0, str(Path(__file__).resolve().parent))

from editors import (  # noqa: E401 - imports are part of the smoke test
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

# wenshu 自管的项目注册表,记录所有 `_create_project` 创建过的项目。
# _create_project 接受任意 target_dir(用户显式指定),所以不能 hardcode
# 扫 PROJECTS_ROOT(装机 user 选 ~/Documents/ 时项目落到 ~/Documents/xxx/,
# 不在 PROJECTS_ROOT 下,装机会看不到)。
# registry 写到 wenshu profile 内部 ~/.hermes/profiles/wenshu/projects.json,
# 跟 hermes 自带 projects.db 物理隔离,AGENTS §12 不越界(不动 hermes 端
# 任何文件,只写 wenshu 自家 profile 内新文件)。
_PROJECTS_INDEX = Path.home() / ".hermes" / "profiles" / "wenshu" / "projects.json"

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
    now_iso = datetime.now(timezone.utc).isoformat()

    if project_dir.exists():
        existing_summary = _read_existing_summary(project_dir)
        # 已存在 → 也注册到 registry(可能用户换了 target_dir 或新装 user)
        _save_index(_record_project(
            project_dir, name, existing_summary,
            now_iso,
        ))
        return {
            "status": "exists",
            "project_path": str(project_dir),
            "existing_summary": existing_summary,
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
        "created_at": now_iso,
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
    _save_index(_record_project(project_dir, name, summary, now_iso))
    return {"status": "created", "project_path": str(project_dir)}


def _load_index():
    """读 wenshu 自管的项目注册表。文件不存在 / 损坏 → 返空 list。"""
    if not _PROJECTS_INDEX.is_file():
        return []
    try:
        data = json.loads(_PROJECTS_INDEX.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError, TypeError):
        return []
    return data if isinstance(data, list) else []


def _save_index(entries):
    """原子写 wenshu 项目注册表。先写 .tmp 再 rename,避免半写状态。"""
    _PROJECTS_INDEX.parent.mkdir(parents=True, exist_ok=True)
    tmp = _PROJECTS_INDEX.with_suffix(".json.tmp")
    tmp.write_text(
        json.dumps(entries, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    tmp.replace(_PROJECTS_INDEX)


def _record_project(project_dir, name, summary, created_at):
    """append 一条到 registry。dedupe by absolute path,同名项目不重复。"""
    entries = _load_index()
    abs_path = str(project_dir.resolve())
    for entry in entries:
        if entry.get("path") == abs_path:
            # 已存在 → 更新 summary / created_at 不变
            entry["name"] = name
            entry["summary"] = summary
            return entries
    entries.append({
        "name": name,
        "summary": summary,
        "created_at": created_at,
        "path": abs_path,
    })
    return entries


@router.get("/health")
async def health():
    return _HEALTH


@router.get("/projects")
async def list_projects():
    """列出所有 wenshu 已建项目。

    路径来源 = ~/.hermes/profiles/wenshu/projects.json registry
    (由 _create_project / _record_project 同步写)。
    registry 损坏 / 缺失 → 返空。

    跳过条件:registry 条目指向的目录不存在 / .wenshu/project.json 缺 / 损坏。
    """
    entries = _load_index()
    projects = []
    for entry in entries:
        path = entry.get("path")
        if not path:
            continue
        project_dir = Path(path)
        project_json = project_dir / ".wenshu" / "project.json"
        if not project_json.is_file():
            continue
        # 读磁盘上的真值 summary(registry 可能落后)
        try:
            data = json.loads(project_json.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError, TypeError):
            continue
        projects.append({
            "name": data.get("name") or project_dir.name,
            "summary": data.get("summary") or "",
            "created_at": data.get("created_at") or entry.get("created_at") or "",
        })

    def _sort_key(p):
        return p.get("created_at") or ""
    projects.sort(key=_sort_key, reverse=True)

    return {"projects": projects}


@router.get("/projects/{name}")
async def get_project(name: str):
    """读 registry 拿单个项目的真值 metadata + path。

    8/5 工单:ProjectPage 改对话启动器需要 project_path 才能调
    host.request('session.create', { cwd: projectDir, ... })。
    list_projects() 只返 name/summary/created_at,不足以撑起"开新对话"
    按钮。新增本条 endpoint,不动其它 endpoint。
    """
    for entry in _load_index():
        if entry.get("name") == name:
            project_dir = Path(entry["path"])
            project_json = project_dir / ".wenshu" / "project.json"
            if not project_json.is_file():
                continue
            try:
                data = json.loads(project_json.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError, TypeError):
                continue
            return {
                "name": data.get("name") or project_dir.name,
                "summary": data.get("summary") or "",
                "created_at": data.get("created_at") or entry.get("created_at") or "",
                "project_path": str(project_dir),
            }
    # 找不到 → 返空字段(让 ProjectPage 显示空状态,不 404,因为
    # hash 路由可能短暂指向还没建好的项目)
    return {"name": name, "summary": "", "created_at": "", "project_path": ""}


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
