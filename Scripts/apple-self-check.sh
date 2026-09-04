#!/bin/bash
# apple-self-check.sh -- wenshu v0.40 Apple 3-tier authority self-check
#
# Runs the 12-item dead-code / SoT greps from the Apple-API-first skill
# (5-stage dead-code grep protocol + SoT trace recipe).
#
# Outputs raw grep evidence under:
#   .scratch/2026-09-04-apple-methodology/grep-evidence/<row>.txt
#
# Then prints a one-line summary per row.
#
# Idempotent. No third-party deps. Exits 0 on success (= all greps ran),
# exits 1 only on shell-level failure (= bad PATH, missing repo).
#
# Usage: cd /Volumes/ANAN/Engineering/wenshu && bash Scripts/apple-self-check.sh
#
# Per AGENTS.md: English-only in all generated artifacts.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

EVIDENCE_DIR=".scratch/2026-09-04-apple-methodology/grep-evidence"
mkdir -p "$EVIDENCE_DIR"

# Helper: run a grep, write output to evidence file, print a 1-line summary.
# Usage: run_grep <id> <description> <grep-args...>
run_grep() {
    local id="$1"
    local description="$2"
    shift 2
    local out="$EVIDENCE_DIR/${id}.txt"
    echo ">>> [$id] $description" >&2
    # Use a subshell so `set -e` does not abort on grep's exit-1 (= no match).
    ( "$@" > "$out" 2>&1 || true )
    local n
    n=$(wc -l < "$out" | tr -d ' ')
    echo "  -> $out ($n lines)"
}

echo "=== wenshu Apple self-check (= ticket A1) ==="
echo "    repo: $PROJECT_ROOT"
echo "    date: $(date '+%Y-%m-%d %H:%M %Z')"
echo

# D1 CrossRefInject v2 - 5-stage dead-code grep
run_grep "D1-stage1-selfdef"     "D1 stage1: self-def in CrossRefInject_v2.swift" \
    grep -n 'struct \|class ' Sources/WenshuApp/Domain/CrossRefInject_v2.swift
run_grep "D1-stage2-callers"      "D1 stage2: callers (excluding self-def + comments)" \
    grep -rn 'CrossRefInject_v2\|CrossRefInjectV2' Sources/WenshuApp/ Tests/ 2>/dev/null \
        | grep -v -E '\.swift:[0-9]+:struct|\.swift:[0-9]+:class |^[^:]*\.swift:[0-9]+:[ ]*//|^[^:]*\.swift:[0-9]+:[ ]*\*|^[^:]*\.swift:[0-9]+:[ ]*/\*'
run_grep "D1-stage3-wiring"       "D1 stage3: wiring-chain references" \
    grep -n 'CrossRefInject_v2\|CrossRefInjectV2\|CrossRefInjectCapability' \
        Sources/WenshuApp/App.swift \
        Sources/WenshuApp/Views/Workspace/WorkspaceView.swift \
        Sources/WenshuApp/Views/Workspace/TabContentDispatcher.swift 2>/dev/null
run_grep "D1-stage4-staletest"    "D1 stage4: stale-test references" \
    grep -rn 'CrossRefInject_v2\|CrossRefInjectV2' Tests/ 2>/dev/null
run_grep "D1-stage5-substring"    "D1 stage5: substring references (Sources/ Tests/ scripts only, + AGENTS.md)" \
    grep -rn 'CrossRefInject_v2\|CrossRefInjectV2' Sources/ Tests/ AGENTS.md CONTEXT.md CLAUDE.md README.md \
        2>/dev/null \
        | grep -v '\.swift:' || true

# D2 LLMWikiLayerDeriver + LLMWikiLinter - 5-stage dead-code grep
run_grep "D2-deriver-stage1"     "D2 stage1: self-def LLMWikiLayerDeriver" \
    grep -n 'struct \|class ' Sources/WenshuApp/Storage/LLMWikiLayerDeriver.swift
run_grep "D2-deriver-stage2"     "D2 stage2: LLMWikiLayerDeriver callers" \
    grep -rn 'LLMWikiLayerDeriver' Sources/WenshuApp/ Tests/ 2>/dev/null \
        | grep -v -E '\.swift:[0-9]+:struct|\.swift:[0-9]+:class |^[^:]*\.swift:[0-9]+:[ ]*//|^[^:]*\.swift:[0-9]+:[ ]*\*|^[^:]*\.swift:[0-9]+:[ ]*/\*'
run_grep "D2-deriver-stage3"     "D2 stage3: wiring-chain for LLMWikiLayerDeriver" \
    grep -n 'LLMWikiLayerDeriver' \
        Sources/WenshuApp/App.swift \
        Sources/WenshuApp/Views/Workspace/WorkspaceView.swift \
        Sources/WenshuApp/Views/Workspace/TabContentDispatcher.swift 2>/dev/null
run_grep "D2-deriver-stage4"     "D2 stage4: stale-test for LLMWikiLayerDeriver" \
    grep -rn 'LLMWikiLayerDeriver' Tests/ 2>/dev/null
run_grep "D2-deriver-stage5"     "D2 stage5: substring LLMWikiLayerDeriver (scoped)" \
    grep -rn 'LLMWikiLayerDeriver' Sources/ Tests/ AGENTS.md CONTEXT.md CLAUDE.md README.md \
        2>/dev/null \
        | grep -v '\.swift:' || true

run_grep "D2-linter-stage1"      "D2 stage1: self-def LLMWikiLinter" \
    grep -n 'struct \|class ' Sources/WenshuApp/Storage/LLMWikiLinter.swift
run_grep "D2-linter-stage2"      "D2 stage2: LLMWikiLinter callers" \
    grep -rn 'LLMWikiLinter' Sources/WenshuApp/ Tests/ 2>/dev/null \
        | grep -v -E '\.swift:[0-9]+:struct|\.swift:[0-9]+:class |^[^:]*\.swift:[0-9]+:[ ]*//|^[^:]*\.swift:[0-9]+:[ ]*\*|^[^:]*\.swift:[0-9]+:[ ]*/\*'

# D3 ReferenceEntityExtractor - follows D2
run_grep "D3-stage1"             "D3 stage1: self-def ReferenceEntityExtractor" \
    grep -n 'struct \|class ' Sources/WenshuApp/Domain/ReferenceEntityExtractor.swift
run_grep "D3-stage2"             "D3 stage2: ReferenceEntityExtractor callers" \
    grep -rn 'ReferenceEntityExtractor' Sources/WenshuApp/ Tests/ 2>/dev/null \
        | grep -v -E '\.swift:[0-9]+:struct|\.swift:[0-9]+:class |^[^:]*\.swift:[0-9]+:[ ]*//|^[^:]*\.swift:[0-9]+:[ ]*\*|^[^:]*\.swift:[0-9]+:[ ]*/\*'

# D4 WikiEntityPreflight + EntityIngestion + EntityClassifier - 5-stage per file
for path in \
    "WikiEntityPreflight:Sources/WenshuApp/Domain/WikiEntityPreflight.swift" \
    "EntityIngestion:Sources/WenshuApp/Domain/EntityIngestion.swift" \
    "EntityClassifier:Sources/WenshuApp/Storage/EntityClassifier.swift" ; do
    name="${path%%:*}"
    file="${path#*:}"
    run_grep "D4-${name}-stage1" "D4 stage1: self-def $name" \
        grep -n 'struct \|class ' "$file"
    run_grep "D4-${name}-stage2" "D4 stage2: $name callers" \
        grep -rn "$name" Sources/WenshuApp/ Tests/ 2>/dev/null \
            | grep -v -E '\.swift:[0-9]+:struct|\.swift:[0-9]+:class |^[^:]*\.swift:[0-9]+:[ ]*//|^[^:]*\.swift:[0-9]+:[ ]*\*|^[^:]*\.swift:[0-9]+:[ ]*/\*'
    run_grep "D4-${name}-stage3" "D4 stage3: $name in wiring-chain" \
        grep -n "$name" \
            Sources/WenshuApp/App.swift \
            Sources/WenshuApp/Views/Workspace/WorkspaceView.swift \
            Sources/WenshuApp/Views/Workspace/TabContentDispatcher.swift 2>/dev/null
    run_grep "D4-${name}-stage4" "D4 stage4: $name in stale-tests" \
        grep -rn "$name" Tests/ 2>/dev/null
done

# C2 WenshuLibrary vs BookStore - SoT trace
run_grep "C2-wenshuLib-selfdef"  "C2: WenshuLibrary self-def + state" \
    grep -n 'class WenshuLibrary\|var shelves\|var selectedBookId\|var selectedShelfId\|var selectedDocumentId' \
        Sources/WenshuApp/State/WenshuLibrary.swift
run_grep "C2-bookStore-selfdef"  "C2: BookStore self-def + state" \
    grep -n 'class BookStore\|var shelves\|var selectedBookId\|var referenceLibrary\|var currentBook' \
        Sources/WenshuApp/State/BookStore.swift
run_grep "C2-wenshuLib-callers"   "C2: WenshuLibrary callers" \
    grep -rn 'WenshuLibrary' Sources/WenshuApp/ Tests/ 2>/dev/null \
        | grep -v -E '\.swift:[0-9]+:class [^W]|^[^:]*\.swift:[0-9]+:[ ]*//|^[^:]*\.swift:[0-9]+:[ ]*\*|^[^:]*\.swift:[0-9]+:[ ]*/\*'
run_grep "C2-bookStore-callers"   "C2: BookStore callers" \
    grep -rn 'BookStore' Sources/WenshuApp/ Tests/ 2>/dev/null \
        | grep -v -E '\.swift:[0-9]+:class [^B]|^[^:]*\.swift:[0-9]+:[ ]*//|^[^:]*\.swift:[0-9]+:[ ]*\*|^[^:]*\.swift:[0-9]+:[ ]*/\*'

# E - magic constants sweep (the 2 known tokens)
run_grep "E-magic-constants"     "E: smallChipCornerRadius + subtleSurfaceAlpha usage sites" \
    grep -rn 'smallChipCornerRadius\|subtleSurfaceAlpha' Sources/WenshuApp/ 2>/dev/null

# G - 3 entity-level stores + LibraryStoring protocol conformances
run_grep "G-library-conformance" "G: LibraryStoring protocol conformances" \
    grep -rn 'LibraryStoring' Sources/WenshuApp/ 2>/dev/null

# H - ComponentIndex.md references to view structures inside App.swift
run_grep "H-component-index"     "H: ComponentIndex.md size + Level 8 markers" \
    wc -l Sources/WenshuApp/UI/ComponentIndex.md && \
    grep -n 'Level 8\|DELETED' Sources/WenshuApp/UI/ComponentIndex.md 2>/dev/null

echo
echo "=== done ==="
echo "evidence at: $EVIDENCE_DIR/"
ls "$EVIDENCE_DIR" | wc -l | tr -d ' ' | xargs -I {} echo "  {} evidence files"
