"""
8 hidden editorial roles (per AGENTS.md v0.2 §13).

Each module exposes `async def run(context: dict) -> dict` returning a
placeholder payload. The orchestrator in plugin_api.py /projects routes
will wire them up in 0.2.0.

Order matches AGENTS.md §13 editor list:
    outline → research → style → character → plot → dialogue → proofread → chief
"""
