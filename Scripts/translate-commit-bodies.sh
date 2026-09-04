#!/usr/bin/env bash
# translate-commit-bodies.sh -- B-03 T3a toolkit (wenshu)
#
# Walks the commit range 6585a0476^..HEAD and rewrites CJK-bearing commit
# BODIES (subjects stay untouched). Two modes:
#
#   --dry-run  (default): enumerate every commit whose body holds any
#                          non-ASCII byte (= CJK / em dash / smart quotes /
#                          etc.); write a per-commit summary line to
#                          Scripts/translate-commit-bodies.dry-run.txt.
#
#   --apply              : run `git filter-branch --msg-filter ...` on the
#                          range. Subject line is preserved verbatim. Body
#                          lines are rewritten using a hand-curated lookup
#                          table (sed). CJK lines with no lookup match are
#                          marked with `[AUTO-TRANSLATED, PLEASE REVIEW]`
#                          (= human eyes needed; the script never claims
#                          Chinese -> English without a curated rule).
#
#   --help               : print usage and exit 0.
#
# Hard rules baked in:
#   * Subjects are NEVER touched (subject = git log --oneline column).
#   * Lookups are hand-curated = no LLM, no auto-translation of arbitrary
#     Chinese characters.
#   * `git filter-branch -f` rewrites the range in place. A backup ref
#     `refs/backup/translate-commit-bodies-pre` is written FIRST so the
#     T3b rollback path is a single `git reset --hard` against it.
#   * Stdlib only = bash / awk / sed / git / python3. Zero new third-party
#     dependency. (python3 ships with macOS; bash / awk / sed / git are
#     POSIX stdlib.)

set -euo pipefail

# ---- constants ----------------------------------------------------------------

RANGE_FROM="6585a0476^"   # inclusive parent of the B-03 target range
RANGE_TO="HEAD"           # inclusive tip
BACKUP_REF="refs/backup/translate-commit-bodies-pre"
DRY_RUN_OUT="Scripts/translate-commit-bodies.dry-run.txt"

# ---- usage -------------------------------------------------------------------

usage() {
    cat <<'EOF'
translate-commit-bodies.sh -- B-03 T3a toolkit (wenshu)

USAGE
    Scripts/translate-commit-bodies.sh [--dry-run | --apply | --help]

MODES
    --dry-run   (default) Enumerate every commit in 6585a0476^..HEAD whose
                body has any non-ASCII byte. Writes a per-commit summary
                line to Scripts/translate-commit-bodies.dry-run.txt.
                Exits 0. Does not touch git history.

    --apply     Rewrite the same range with `git filter-branch`. Subjects
                are preserved. Bodies are translated via the hand-curated
                lookup table baked into this script. CJK lines with no
                lookup match are marked with
                `[AUTO-TRANSLATED, PLEASE REVIEW]`.
                Backs up the pre-apply ref to refs/backup/translate-commit-bodies-pre.
                FORCE-PUSH is the operator's responsibility (= T3b manual step).

    --help      Print this help and exit 0.

EXIT CODES
    0   success
    1   range is empty (= not a wenshu repo, or wrong commit hash)
    2   git command failed
EOF
}

# ---- dry-run -----------------------------------------------------------------

# Two-step: emit one record per commit to /tmp via `--format` markers, then
# hand /tmp to python3 which parses cleanly. python3 is on macOS stdlib
# (= /usr/bin/python3 ships with Xcode CLT since 14.x).
run_dry_run() {
    local raw_dump
    raw_dump="$(mktemp -t translate-commit-bodies-rawdump.XXXXXX.txt)"

    # Emit NUL-separated records. Each record has:
    #   SHA\n
    #   SUBJECT:<subject>\n
    #   BODY:\n<body lines>\n
    #   ENDBODY\n
    git log --reverse --format='%H%nSUBJECT:%s%nBODY:%n%b%nENDBODY%n%x00' \
        "$RANGE_FROM..$RANGE_TO" \
    | sed '$d' > "$raw_dump"   # strip trailing NUL bash added

    python3 - "$raw_dump" "$DRY_RUN_OUT" <<'PYEOF'
import sys

raw_path, out_path = sys.argv[1], sys.argv[2]

with open(raw_path, 'r', encoding='utf-8', errors='replace') as f:
    data = f.read()

records = data.split('\x00')

n_hits = 0
with open(out_path, 'w', encoding='utf-8') as out:
    for rec in records:
        rec = rec.strip('\n')
        if not rec:
            continue
        lines = rec.split('\n')
        sha = lines[0].strip()
        if len(sha) < 40 or not sha[:40].isalnum():
            continue
        hash_ = sha[:40]

        subject = ""
        body_lines = []
        state = "pre"
        for line in lines[1:]:
            if state == "pre" and line.startswith("SUBJECT:"):
                subject = line[len("SUBJECT:"):]
                state = "wait_body"
            elif state == "wait_body" and line == "BODY:":
                state = "body"
            elif state == "body" and line == "ENDBODY":
                state = "done"
                break
            elif state == "body":
                body_lines.append(line)

        body = "\n".join(body_lines)
        # Count non-ASCII bytes (= bytes outside 0x00..0x7F).
        non_ascii = sum(1 for b in body.encode('utf-8') if b >= 0x80)
        if non_ascii > 0:
            out.write("%s %s | %d non-ASCII bytes\n" % (hash_, subject, non_ascii))
            n_hits += 1

print("translate-commit-bodies.sh --dry-run: %d commit(s) with non-ASCII bytes in body" % n_hits)
PYEOF

    rm -f "$raw_dump"

    local n
    n=$(wc -l < "$DRY_RUN_OUT" | tr -d ' ')
    echo "translate-commit-bodies.sh --dry-run: $n commit(s) with non-ASCII bytes in body (range $RANGE_FROM..$RANGE_TO)"
    echo "  -> $DRY_RUN_OUT"
}

# ---- apply (T3b) ------------------------------------------------------------

# Translate a single body line via the hand-curated lookup table.
# - Known CJK phrases are replaced with English inline.
# - CJK chars with no lookup hit are left in place but the line is prefixed
#   with `[AUTO-TRANSLATED, PLEASE REVIEW] ` so a human can find/replace.
# - Pure-ASCII lines are passed through unchanged.
#
# Hand-curated lookup table (= recurring boss OOB / cadence phrases found
# by `git log 6585a0476^..HEAD --format=%b | grep` on 2026-09-04).
#
# NB: every sed command is anchored on the literal CJK substring so we
# never mistranslate an unrelated English phrase.
build_msg_filter() {
    cat <<'FILTER'
#!/usr/bin/env bash
# msg-filter for `git filter-branch` -- see translate-commit-bodies.sh.
# stdin = a full commit message (subject\n\nbody). stdout = rewritten msg.
set -euo pipefail

# 1. Split: keep first line (= subject) verbatim; the rest is body.
#    NB: `head -n 1` then `tail -n +2` in two separate `$(...)`
#    command substitutions does NOT work -- both substitutions consume
#    stdin, and the first one eats the entire message before `tail` can
#    see the body (= B-03 T3b 2026-09-04 lesson learned: an earlier
#    `git filter-branch --apply` produced 284 commit objects with EMPTY
#    bodies, discovered on verification and immediately rolled back via
#    `git reset --hard refs/backup/translate-commit-bodies-pre`). Read
#    the whole message into a variable first, then split.
FULL=$(cat)
FIRST_LINE="${FULL%%$'\n'*}"
REST="${FULL#*$'\n'}"

# 2. Subject = NEVER translated. Print verbatim.
printf '%s\n' "$FIRST_LINE"
printf '\n'

# 3. Body: feed REST through python3 so we can apply the hand-curated
#    lookup table reliably (= BSD awk byte arithmetic is a footgun).
#    Use a tempfile for the python script because the heredoc form
#    `python3 - <<'PYEOF' ... PYEOF` overrides the pipe from `printf`
#    (= the heredoc redirection for python's stdin takes the body
#    AWAY from the pipeline; B-03 T3b 2026-09-04 lesson learned). See
#    `write_msg_filter_py` for the script body.
MSG_FILTER_PY=$(mktemp -t translate-commit-bodies-py.XXXXXX.py)
write_msg_filter_py > "$MSG_FILTER_PY"
printf '%s' "$REST" | python3 "$MSG_FILTER_PY"
rm -f "$MSG_FILTER_PY"
FILTER
}

# Emit the python script that applies the LOOKUPS table to body lines.
# Kept separate from `build_msg_filter` so the bash heredoc inside
# `build_msg_filter` does not have to swallow CJK string literals.
write_msg_filter_py() {
    cat <<'PYEOF'
import sys

# Hand-curated lookup table (2026-09-04). Order matters -- longer phrases
# first so we don't half-translate. Every key here is a literal CJK
# substring that recurs in 6585a0476^..HEAD commit bodies.
LOOKUPS = [
    ("你移植 hermes 涉及到前端 UI 的你自动解决语言问题",
     "you auto-resolve language issues when porting hermes UI"),
    ("PO 全链路方法论执行",       "PO end-to-end methodology execution"),
    ("全面接口级测试,写完整测试用例,继续推进移植",
     "full interface-level tests + complete test cases + keep porting"),
    ("把表格中所有不是干净的都修", "fix every non-clean row in the table"),
    ("能用 apple api 的都用 api", "use Apple APIs wherever possible"),
    ("在 swift 化的同时, 把现在 wenshu 项目里的 ui 多语言化顺手做了",
     "while porting to Swift, do i18n on the wenshu UI along the way"),
    ("一直跑移植就行",             "just keep porting"),
    ("不用问我了",                 "no need to ask me"),
    ("全面接口级测试",             "full interface-level tests"),
    ("六类全修",                   "fix all six categories"),
    ("继续推进移植",               "keep porting"),
    ("走苹果 api",                 "use Apple APIs"),
    ("多语言化顺手做了",           "do i18n while you are at it"),
    # B-03 T3b additions (2026-09-04) -- phrases observed in the live
    # 6585a0476^..HEAD range (= the 3 commits whose bodies still held CJK
    # after the T3a sample lookup was written). Inserted BEFORE the
    # single-character lookups below so the longer phrase wins the
    # substring match (= `先继续` inside `先不验收, 先继续把工作树干完`
    # would otherwise be matched by `继续` -> `continue` first).
    ("视图无法进入 MD 编辑模式, 只是预览模式, 不能打字",
     "cannot enter MD edit mode, only preview mode, cannot type"),
    ("视图无法进入 MD 编辑模式",
     "cannot enter MD edit mode"),
    ("hermes 整体翻译成 swift, 整个工作树都完成了?",
     "is the entire hermes-to-Swift port complete across the whole tree?"),
    ("先不验收, 先继续把工作树干完",
     "skip verification for now, keep finishing the work tree"),
    ("全中文化,是走 apple api 的多语言,不是硬改",
     "fully localized via Apple API i18n, not by hard-editing strings"),
    ("布局编辑模式",             "layout edit mode"),
    ("布局",                       "layout"),
    ("整个视觉",                   "the whole visual"),
    ("暂时不验",                   "skip verification for now"),
    ("继续移植",                   "keep porting"),
    ("生图",                       "image generation"),
    ("卡牌",                       "card"),
    ("调研",                       "investigation"),
    ("铁律",                       "iron rule"),
    ("老板",                       "boss"),
    ("拍",                         "decision"),
    ("继续",                       "continue"),
    ("昨天",                       "yesterday"),
    ("今天",                       "today"),
    ("活",                         "task"),  # very weak -- only safe in OOB context
]

for raw in sys.stdin:
    line = raw.rstrip('\n')
    for key, val in LOOKUPS:
        if key in line:
            line = line.replace(key, val)
    # If line still has any non-ASCII byte (= bytes >= 0x80), no lookup
    # covered the CJK content. Prefix with the human-review marker so
    # a follow-up commit can find/replace.
    if any(ord(c) > 127 for c in line):
        line = "[AUTO-TRANSLATED, PLEASE REVIEW] " + line
    print(line)
PYEOF
}

run_apply() {
    local msg_filter
    msg_filter="$(mktemp -t translate-commit-bodies-msgfilter.XXXXXX.sh)"
    build_msg_filter > "$msg_filter"
    chmod +x "$msg_filter"

    # 1. Snapshot the pre-apply tip so rollback = `git reset --hard`.
    git update-ref "$BACKUP_REF" HEAD

    # 2. Rewrite the range. `-f` overwrites any previous filter-branch backup.
    git filter-branch -f \
        --msg-filter "bash $msg_filter" \
        -- "$RANGE_FROM..$RANGE_TO"

    echo
    echo "translate-commit-bodies.sh --apply: range $RANGE_FROM..$RANGE_TO rewritten."
    echo "  backup ref = $BACKUP_REF (rollback = \`git reset --hard $BACKUP_REF\`)"
    echo "  FORCE-PUSH is the operator's next step (T3b manual)."
}

# ---- dispatch ----------------------------------------------------------------

case "${1:-}" in
    --dry-run|"") run_dry_run ;;
    --apply)       run_apply ;;
    --help|-h)     usage ;;
    *)             usage; exit 2 ;;
esac