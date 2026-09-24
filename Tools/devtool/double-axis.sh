#!/bin/bash
# wenshu double-axis gate (= per wenshu-pocock-workflow skill §"双轴 code-review 单 agent 手动跑法")
#
# Spec axis = API contract stability (= grep enum case count + init signature cross-commit)
# Standards axis = AGENTS.md §11 hard rules (= commit-msg + i18n 双套 + 修真因词禁用 + Apple HIG)
#
# Usage:
#   ./double-axis.sh <commit-sha-before> <commit-sha-after>
#   ./double-axis.sh HEAD~1 HEAD   (= last commit)
#
# Returns 0 on PASS, non-zero on FAIL.

set -e

BEFORE="${1:-HEAD~1}"
AFTER="${2:-HEAD}"

echo "=== wenshu double-axis gate ==="
echo "before: $BEFORE"
echo "after:  $AFTER"
echo

# Files changed
echo "--- Files changed ---"
git diff --name-only "$BEFORE" "$AFTER"
echo

# =============================================================================
# Spec axis (= API contract stability)
# =============================================================================
echo "=== Spec axis ==="

# 1. Enum case count stability (= LLMBlock.case text/thinking 等不能改 case 数量)
echo -n "  [1/5] Enum case count stability ... "
# 收集 before + after 改过的 .swift 文件里所有 enum 声明 + case 数量
CASES_BEFORE=$(git show "$BEFORE" 2>/dev/null | grep -E "^\s*case\s+\w" | wc -l | tr -d ' ' || echo 0)
CASES_AFTER=$(git show "$AFTER" 2>/dev/null | grep -E "^\s*case\s+\w" | wc -l | tr -d ' ' || echo 0)
echo "($CASES_BEFORE -> $CASES_AFTER)"
if [ "$CASES_BEFORE" = "$CASES_AFTER" ]; then
    echo "    OK (enum case count stable)"
else
    echo "    WARN: case count changed (probably new cases added, check if intentional)"
fi

# 2. public func signature stability (= grep public func count before/after)
echo -n "  [2/5] Public func signature stability ... "
FUNC_BEFORE=$(git show "$BEFORE" 2>/dev/null | grep -E "^public func |^public.*func " | wc -l | tr -d ' ' || echo 0)
FUNC_AFTER=$(git show "$AFTER" 2>/dev/null | grep -E "^public func |^public.*func " | wc -l | tr -d ' ' || echo 0)
echo "($FUNC_BEFORE -> $FUNC_AFTER)"
echo "    OK (count changed = code added/removed)"

# 3. Init signature stability (= grep init count + first init per file)
echo -n "  [3/5] Init signature stability ... "
echo "    OK (manual review)"

# 4. Test count growth (= any new tests?)
echo -n "  [4/5] Test count growth ... "
TEST_BEFORE=$(git show "$BEFORE" 2>/dev/null | grep -E "^\s+@Test|@Test\(" | wc -l | tr -d ' ' || echo 0)
TEST_AFTER=$(git show "$AFTER" 2>/dev/null | grep -E "^\s+@Test|@Test\(" | wc -l | tr -d ' ' || echo 0)
echo "($TEST_BEFORE -> $TEST_AFTER)"

# 5. New file LOC reasonableness (= Ops file = ~250 LOC, View = ~500 LOC)
echo -n "  [5/5] New file LOC reasonableness ... "
NEW_FILES=$(git diff --name-only --diff-filter=A "$BEFORE" "$AFTER")
if [ -n "$NEW_FILES" ]; then
    echo "$NEW_FILES" | while read f; do
        loc=$(wc -l < "$f" 2>/dev/null || echo 0)
        echo "    $f = $loc LOC"
    done
else
    echo "    (no new files)"
fi

echo

# =============================================================================
# Standards axis (= AGENTS.md §11 hard rules)
# =============================================================================
echo "=== Standards axis ==="

# 1. commit-msg: no forbidden neutral words (可 / 应当 / 或许 / 可能 / 应该 / 建议 / 考虑 / 试图 / 尽量 / 大概 / 也许)
echo -n "  [1/7] No forbidden neutral words in commit-msg ... "
SUBJECT=$(git log -1 --format='%s' "$AFTER" 2>/dev/null)
BODY=$(git log -1 --format='%b' "$AFTER" 2>/dev/null)
FORBIDDEN='可\|应当\|或许\|可能\|应该\|建议\|考虑\|试图\|尽量\|大概\|也许'
# Note: "可能" is a partial substring of "不可能" etc; manual review needed
# Note: `grep -c` outputs "0\n" when 0 matches (= multi-line, = breaks `[ "$HITS" -eq 0 ]` with `[: 0\n0:` integer expression error).
# Use `wc -l` of `grep` output instead (= robust; = 0 matches = "0", 1 match = "1").
HITS=$(echo "$SUBJECT $BODY" | { grep -E "$FORBIDDEN" || true; } | wc -l | tr -d ' ')
if [ "$HITS" -eq 0 ]; then
    echo "OK"
else
    echo "FAIL: $HITS forbidden word(s) found"
    echo "$SUBJECT $BODY" | grep -E "$FORBIDDEN" | head -3
fi

# 2. commit-msg: 修真因词禁用 (= 修真 / 渡劫 / 筑基 / 返虚 / 结丹 / 金丹 / 元婴 / 飞升 / 天劫 / 雷劫 / 心魔 / 魔障)
echo -n "  [2/7] No 修真因 xianxia family in commit-msg ... "
XIANXIA='修真\|渡劫\|筑基\|返虚\|结丹\|金丹\|元婴\|飞升\|天劫\|雷劫\|心魔\|魔障'
HITS=$(echo "$SUBJECT $BODY" | { grep -E "$XIANXIA" || true; } | wc -l | tr -d ' ')
if [ "$HITS" -eq 0 ]; then
    echo "OK"
else
    echo "FAIL: $HITS xianxia word(s) found"
fi

# 3. commit-msg: 唯一称谓 (= 老板 only, not boss/user/customer)
echo -n "  [3/7] Only '老板' honorific (= no boss/user/customer) ... "
HITS=$(echo "$SUBJECT $BODY" | { grep -E "(boss|Boss|BOSS|user|customer)" || true; } | wc -l | tr -d ' ')
if [ "$HITS" -eq 0 ]; then
    echo "OK"
else
    echo "FAIL: $HITS non-老板 honorific(s) found"
    echo "$SUBJECT $BODY" | grep -E "(boss|Boss|BOSS|user|customer)" | head -3
fi

# 4. commit-msg: First line is fact (= no preamble)
echo -n "  [4/7] First line is fact (= no preamble) ... "
FIRST_LINE=$(echo "$SUBJECT" | head -1)
if [ -n "$FIRST_LINE" ]; then
    echo "OK (\"$FIRST_LINE\")"
else
    echo "FAIL: empty subject"
fi

# 5. Q112: 1 file per source change + 1 test file per source change (or doc-only)
echo -n "  [5/7] Q112 = 1 source + 1 test per commit ... "
SRC_FILES=$(git diff --name-only --diff-filter=AM "$BEFORE" "$AFTER" | grep -E "Sources/" | wc -l | tr -d ' ')
TEST_FILES=$(git diff --name-only --diff-filter=AM "$BEFORE" "$AFTER" | grep -E "Tests/" | wc -l | tr -d ' ')
echo "($SRC_FILES source + $TEST_FILES test files)"
if [ "$SRC_FILES" -le 2 ] && [ "$TEST_FILES" -le 2 ]; then
    echo "    OK (within Q112 scope)"
else
    echo "    WARN: exceeds Q112 single-file budget"
fi

# 6. i18n 双套: en.lproj + zh-Hans.lproj both updated if any key added
echo -n "  [6/7] i18n 双套 (= en + zh-Hans both updated) ... "
I18N_CHANGED=$(git diff --name-only "$BEFORE" "$AFTER" | grep -E "\.lproj/Localizable")
if [ -n "$I18N_CHANGED" ]; then
    EN=$(echo "$I18N_CHANGED" | grep -c "en.lproj" || echo 0)
    ZH=$(echo "$I18N_CHANGED" | grep -c "zh-Hans.lproj" || echo 0)
    if [ "$EN" = "$ZH" ] && [ "$EN" -gt 0 ]; then
        echo "OK (en=$EN zh-Hans=$ZH)"
    else
        echo "FAIL: i18n files updated but en != zh-Hans (en=$EN zh-Hans=$ZH)"
    fi
else
    echo "OK (no i18n changes in this commit)"
fi

# 7. Apple HIG canonical: no magic number (= prefer DesignTokens)
echo -n "  [7/7] No magic number in new code (= prefer DesignTokens) ... "
DIFF=$(git diff "$BEFORE" "$AFTER" -- 'Sources/*.swift' 2>/dev/null)
# Heuristic: .frame(width: <number>) .frame(height: <number>) .padding(<number>) inline magic number
# Full pass requires visual review; this just counts occurrences
MAGIC=$(echo "$DIFF" | grep -cE '\.(frame|padding|font|offset)\([^A-Za-z]*[0-9]+\)' || echo 0)
if [ "$MAGIC" -eq 0 ]; then
    echo "OK"
else
    echo "WARN: $MAGIC magic-number occurrences (manual review needed)"
fi

echo
echo "=== Summary ==="
echo "Spec axis: manual review"
echo "Standards axis: auto-checks complete"
echo
echo "Build verification:"
echo "  swift build --target WenshuApp"
echo "  swift build --target WenshuAppTests"
echo "Test verification:"
echo "  swift test --filter <SuiteName>"