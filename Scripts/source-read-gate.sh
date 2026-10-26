#!/usr/bin/env bash
# The gate for the "a source-text test must read the tree it is testing"
# card (= 71 test files, cwd-relative source reads moved onto
# SourceLocator).
#
# Every command below is a NAMED, FILTERED suite (= the suites that own
# the touched directories). The whole suite is never run (= it hangs in
# the swift-testing half on this machine).
#
# The property under test: the suite that owns each touched directory
# gives the SAME verdict when run from the repository root and when run
# with a different working directory (= the cwd the test process sees
# has no Sources/ folder).
#
# Usage:
#   Scripts/source-read-gate.sh                 # both working directories
#   Scripts/source-read-gate.sh root            # repository root only
#   Scripts/source-read-gate.sh cwd             # the other working directory only

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/wenshu-source-read-gate"
mkdir -p "$OUT"
MODE="${1:-both}"

# The suites that own the touched directories: the type names of the
# touched files in that directory.
FILTERS_FILE="$OUT/filters.txt"
cat > "$FILTERS_FILE" <<'EOF'
agent|PlanModelTests|AppleKeychainContractTests|TodoStoreTests|FileToolsTests|VisionToolsTests
chatview|ChatFocusSwitchesInspectorPageTests|ChatMessageTimestampTests|ChatMessageViewClockPrefixTests|ChatMessageViewDeliveredCheckTests|ChatMessageViewDollarIconTests|ChatMessageViewElapsedTimeTests|ChatMessageViewFooterComboTooltipTests|ChatMessageViewHoverTimestampTests|ChatMessageViewPlanApproveTests|ChatMessageViewTimestampTooltipTests|ChatMessageViewTokenFooterTests|ChatMessageViewTokenIconTests|ChatMessageViewTokenTooltipTests|ChatPartViewTextFadeInTests|ChatPartViewThinkingFadeInTests|ChatPartViewToolUseFadeInTests|ChatPlanPartElapsedTimeTests|ChatPublishesScopeTests|ChatTextPartViewCursorTooltipTests|ChatTextPartViewStreamCursorTests|ChatToolUsePartViewCardTintTests|ChatToolUsePartViewDurationTests|ChatToolUsePartViewStatusIconTests|ChatToolUsePartViewStatusPulseTests|ChatUserBubbleReadabilityTests|ChatViewAltCShortcutTests|ChatViewAppendShortcutTests|ChatViewBoldShortcutTests|ChatViewClearChatShortcutTests|ChatViewCodeBlockShortcutTests|ChatViewCopyConversationShortcutTests|ChatViewCopyLastAssistantShortcutTests|ChatViewEditShortcutTests|ChatViewExpandReasoningShortcutTests|ChatViewFindShortcutTests|ChatViewGroupShortcutTests|ChatViewHistoryShortcutTests|ChatViewItalicShortcutTests|ChatViewKeyboardShortcutsTests|ChatViewListShortcutTests|ChatViewModelDefaultModelTests|ChatViewMuteShortcutTests|ChatViewNewChatShortcutTests|ChatViewNextChatShortcutTests|ChatViewOptCmdDShortcutTests|ChatViewPasteImageTests|ChatViewPrevChatShortcutTests|ChatViewPrintShortcutTests|ChatViewQuoteShortcutTests|ChatViewRegenShortcutTests|ChatViewReloadShortcutTests|ChatViewSaveSelectionShortcutTests|ChatViewShortcutHelpTests|ChatViewStrikethroughShortcutTests|ChatViewThemeToggleTests|ChatViewUnreadShortcutTests|ChatViewWordCountShortcutTests|ChatViewZoomInShortcutTests|ChatViewZoomOutShortcutTests
e2e|E2EMemoryAndLLMFlowTests|ObsidianVaultBatchImportTests|AnbaiqiangLiveResearch
library|AppleSidebarMVVMSplitTests
kanban|KanbanStoreTests
backup|BackupTests
EOF

# Every recorded issue, whatever its shape (= "Expectation failed" for a
# false assertion, "Caught error" for a thrown read error).
issues() {
  grep -oE 'recorded an issue at [^ ]+' "$1" \
    | sed -E 's/ recorded an issue at /|/' | sort -u
}

cd "$ROOT" || exit 2

status=0
while IFS='|' read -r label filter; do
  [ -z "$label" ] && continue

  if [ "$MODE" = "root" ] || [ "$MODE" = "both" ]; then
    ( cd "$ROOT" && swift test --filter "$filter" >"$OUT/$label.root.log" 2>&1 )
    issues "$OUT/$label.root.log" > "$OUT/$label.root.issues"
  fi
  if [ "$MODE" = "cwd" ] || [ "$MODE" = "both" ]; then
    # The other working directory: a directory with no Sources/ folder,
    # so a cwd-relative source read cannot resolve there.
    ( cd "$ROOT/Sources/WenshuApp" \
        && swift test --package-path . --filter "$filter" \
           >"$OUT/$label.cwd.log" 2>&1 )
    issues "$OUT/$label.cwd.log" > "$OUT/$label.cwd.issues"
  fi

  if [ "$MODE" = "both" ]; then
    if diff -q "$OUT/$label.root.issues" "$OUT/$label.cwd.issues" >/dev/null; then
      verdict="SAME"
    else
      verdict="DIFFERENT"
      status=1
    fi
    echo "$label: root=$(wc -l <"$OUT/$label.root.issues" | tr -d ' ') \
cwd=$(wc -l <"$OUT/$label.cwd.issues" | tr -d ' ') -> $verdict"
  else
    side=$([ "$MODE" = "root" ] && echo root || echo cwd)
    echo "$label: $side=$(wc -l <"$OUT/$label.$side.issues" | tr -d ' ')"
  fi
done < "$FILTERS_FILE"

if [ "$MODE" = "both" ]; then
  echo
  if [ "$status" -eq 0 ]; then
    echo "PASS: every touched suite gives the same verdict from both working directories"
  else
    echo "FAIL: a suite's verdict depends on the working directory"
    for label in agent chatview e2e library kanban backup; do
      diff "$OUT/$label.root.issues" "$OUT/$label.cwd.issues" | head -10
    done
  fi
fi
exit "$status"
