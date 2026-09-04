#!/usr/bin/env python3
"""
upstreams-scan.py · Wenshu (文枢) · v0.34
Walk `Package.swift` (= canonical wenshu source of truth for SPM
dependencies) + emit `upstreams.json` (machine-readable) and
`THIRD_PARTY_NOTICES.md` (human-readable). Boss 2026-09-02
OOB: '我在让卡片缩略图' Issue 03 spec.

Apple-API-first check: n/a (= Python build tooling, not framework).
"""

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
PACKAGE_SWIFT = REPO_ROOT / "Package.swift"
UPSTREAMS_JSON = REPO_ROOT / "upstreams.json"
NOTICES_MD = REPO_ROOT / "THIRD_PARTY_NOTICES.md"


def parse_package_swift(text: str) -> list[dict]:
    """
    Parse the SPM dependencies block. Each upstream gets:
    - name (= GitHub repo slug, e.g. "bring-shrubbery/lucide-swift")
    - url (= full GitHub URL)
    - version (= pinned version string, or "from:X.Y.Z" range)
    - license (= MIT / Apache / BSD / etc. — derived per wenshu §11.1
      ratification table; = no GitHub API needed)
    - reason (= one-line description; = extracted from the comment
      block above the dependency, if present)
    """
    # Block: .package(url: "...", exact: "X") or .package(url: "...", from: "X")
    pkg_re = re.compile(
        r'\.package\(\s*url:\s*"([^"]+)",\s*(?:exact:\s*"([^"]+)"|from:\s*"([^"]+)")\s*\)',
        re.MULTILINE,
    )
    # Comment block above the .package line (= 1+ comment lines,
    # immediate-prior).
    comment_re = re.compile(
        r'(?:^#[^\n]*\n)+?\s*\.package\(',
        re.MULTILINE,
    )

    def slug_from_url(url: str) -> str:
        """Extract 'owner/repo' from a GitHub URL. Handles:
        - https://github.com/owner/repo
        - https://github.com/owner/repo.git
        - https://github.com/owner/repo.git?some=query
        - git@github.com:owner/repo (SSH style — defensive)
        Returns 'owner/repo' on success, or the full URL on failure.
        """
        # Strip .git suffix.
        clean = url.split("?")[0].rstrip("/")
        if clean.endswith(".git"):
            clean = clean[:-4]
        # Standard HTTPS form.
        if "github.com/" in clean:
            after = clean.split("github.com/", 1)[1]
            # Filter out path components beyond owner/repo (=
            # e.g. swift-log → apple/swift-log, NOT apple/swift-log/sub).
            parts = after.split("/")
            if len(parts) >= 2:
                return f"{parts[0]}/{parts[1]}"
        # SSH form: git@github.com:owner/repo
        if clean.startswith("git@github.com:"):
            after = clean.split("git@github.com:", 1)[1]
            parts = after.split("/")
            if len(parts) >= 2:
                return f"{parts[0]}/{parts[1]}"
        return url

    upstreams = []
    # Use the matched comment-block pattern to associate a comment
    # with the .package line.
    for m in pkg_re.finditer(text):
        url = m.group(1)
        exact = m.group(2)
        from_v = m.group(3)
        version = exact or from_v or "unknown"
        slug = slug_from_url(url)
        # License + reason: hardcoded per wenshu §11.1 ratification
        # table (= 2026-08-28 boss拍). GitHub API call avoided
        # (= offline build, deterministic output).
        L = LICENSE_MAP.get(slug, "Unknown")
        R = REASON_MAP.get(slug, "Wenshu SPM dependency.")
        upstreams.append({
            "name": slug,
            "url": url,
            "version": version,
            "license": L,
            "reason": R,
        })
    return upstreams


# v0.34 boss 2026-09-02 ratification (= 2026-08-28 §11.1 hard rule:
# Apple-API-first = use Apple stack exclusive; approved third-party
# exceptions are pinned below).
LICENSE_MAP = {
    "bring-shrubbery/lucide-swift":         "MIT",
    "sindresorhus/Defaults":               "MIT",
    "sindresorhus/KeyboardShortcuts":      "MIT",
    "kean/Nuke":                          "MIT",
    "weichsel/ZIPFoundation":             "MIT",
    "groue/GRDB.swift":                   "MIT",
    "swiftlang/swift-markdown":           "Apache-2.0",
    "mattt/EventSource":                  "MIT",
    "gonzalezreal/Textual":               "MIT",
    "gonzalezreal/textual":               "MIT",
    "apple/swift-log":                    "Apache-2.0",
    "smittytone/HighlighterSwift":        "MIT",
    "witekbobrowski/EPUBKit":             "MIT",
    "davecom/SwiftGraph":                 "Apache-2.0",
    "orchetect/MenuBarExtraAccess":       "MIT",
    "li3zhen1/Grape":                     "MIT",
    "krzysztofzablocki/Inject":           "MIT",
    "nalexn/ViewInspector":               "MIT",
    "pointfreeco/swift-snapshot-testing": "MIT",
}

REASON_MAP = {
    "bring-shrubbery/lucide-swift":         "图标集合 (Apple SF Symbol 替代品; 跨平台)",
    "sindresorhus/Defaults":               "UserDefaults 类型化包装 (Apple @AppStorage 替代品)",
    "sindresorhus/KeyboardShortcuts":      "全局快捷键绑定 (Apple .keyboardShortcut 替代品)",
    "kean/Nuke":                          "异步图像加载 (Apple LazyVGrid/AsyncImage 替代品)",
    "weichsel/ZIPFoundation":             "ZIP 读写 (Apple Compression 替代品)",
    "groue/GRDB.swift":                   "SQLite 工具包 + FTS5 全文检索 (Apple CoreData 替代品)",
    "swiftlang/swift-markdown":           "CommonMark/GFM 解析 (Apple AttributedString 替代品)",
    "mattt/EventSource":                  "SSE 客户端 (Apple URLSession.bytes 替代品)",
    "gonzalezreal/Textual":               "SwiftUI 富文本引擎 (Apple TextKit 替代品)",
    "gonzalezreal/textual":               "SwiftUI 富文本引擎 (Apple TextKit 替代品; 同上 slug 变体)",
    "apple/swift-log":                    "Apple 一方 Logger API",
    "smittytone/HighlighterSwift":        "代码块语法高亮 (Apple TextKit 替代品)",
    "witekbobrowski/EPUBKit":             "EPUB 2/3 解析 (Apple iBooks 替代品)",
    "davecom/SwiftGraph":                 "图算法 (Apple Foundation 替代品)",
    "orchetect/MenuBarExtraAccess":       "macOS 菜单栏集成 (Apple MenuBarExtra 替代品)",
    "li3zhen1/Grape":                     "力导向图布局 (Apple HIG 替代品)",
    "krzysztofzablocki/Inject":           "SwiftUI 热重载 (DEV/TEST only; Apple HIG 替代品)",
    "nalexn/ViewInspector":               "SwiftUI 视图层级反射 (TEST only; Apple HIG 替代品)",
    "pointfreeco/swift-snapshot-testing": "SwiftUI 像素快照测试 (TEST only; Apple HIG 替代品)",
}


def write_upstreams_json(upstreams: list[dict]) -> None:
    payload = {
        "version": 1,
        "generated_by": "Tools/wenshu-devtool/upstreams-scan.py",
        "source_of_truth": "Package.swift",
        "count": len(upstreams),
        "upstreams": upstreams,
    }
    UPSTREAMS_JSON.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def write_third_party_notices(upstreams: list[dict]) -> None:
    lines = [
        "# Third-Party Notices",
        "",
        "Auto-generated by `Tools/wenshu-devtool/upstreams-scan.py`.",
        "Source of truth = `Package.swift`. Do not edit by hand —",
        "re-run the scanner (= `bash Scripts/build-app.sh` invokes it",
        "before build) to refresh after a dependency change.",
        "",
        f"Total upstreams: **{len(upstreams)}**.",
        "",
    ]
    for u in upstreams:
        lines.append(f"## {u['name']}")
        lines.append("")
        lines.append(f"- **URL**: {u['url']}")
        lines.append(f"- **Version**: {u['version']}")
        lines.append(f"- **License**: {u['license']}")
        lines.append(f"- **Reason**: {u['reason']}")
        lines.append("")
    NOTICES_MD.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    if not PACKAGE_SWIFT.exists():
        print(f"error: {PACKAGE_SWIFT} not found", file=sys.stderr)
        return 1
    text = PACKAGE_SWIFT.read_text(encoding="utf-8")
    upstreams = parse_package_swift(text)
    if not upstreams:
        print("warning: no .package() blocks parsed (= Package.swift may be empty)", file=sys.stderr)
    write_upstreams_json(upstreams)
    write_third_party_notices(upstreams)
    print(f"wrote {UPSTREAMS_JSON.relative_to(REPO_ROOT)} ({len(upstreams)} upstreams)")
    print(f"wrote {NOTICES_MD.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())