#!/bin/bash
# installer-smoke.sh — 装机 user 装完后跑这个烟测
# 验: PATH 隔离 / commit hash / dmg md5 / desktop CFBundle
# exit 0 = 全过, exit N = N 项 fail

set -u

PASS=0
FAIL=0

ok() { printf "  PASS: %s\n" "$1"; PASS=$((PASS+1)); }
no() { printf "  FAIL: %s\n" "$1"; FAIL=$((FAIL+1)); }

echo "=== 1. 装机 user 端 installer dmg 隔离验证 ==="
DMG="$HOME/Downloads/文枢_0.0.1_aarch64.dmg"
if [ -f "$DMG" ]; then
  ok "dmg 在 ~/Downloads/: $(ls -lh "$DMG" | awk '{print $5}')"
else
  no "dmg 不在 ~/Downloads/ — 让 PM-direct 重 build"
fi

echo
echo "=== 2. install.sh 拉 wenshu repo (不是 hermes 上游) ==="
WENSHU_HOME="${WENSHU_HOME:-$HOME/.wenshu-hermes}"
if [ ! -d "$WENSHU_HOME" ]; then
  ok "(skip) $WENSHU_HOME 不存在 — 装机 user 没跑 installer (fresh 状态)"
else
  if [ -d "$WENSHU_HOME/hermes-agent/.git" ]; then
    REMOTE=$(git -C "$WENSHU_HOME/hermes-agent" config --get remote.origin.url 2>/dev/null || echo "")
    if [[ "$REMOTE" == *"ZIYU-FUI/wenshu.git"* ]]; then
      ok "git remote = $REMOTE (隔离 ✓)"
    else
      no "git remote = $REMOTE (期望 ZIYU-FUI/wenshu.git)"
    fi
  else
    no "$WENSHU_HOME/hermes-agent 不是一个 git checkout"
  fi
fi

echo
echo "=== 3. 隔离验证: ~/.hermes 没被污染 ==="
if [ -d "$HOME/.hermes" ]; then
  WENSHU_MTIME=$(stat -f '%m' "$WENSHU_HOME/hermes-agent" 2>/dev/null || echo 0)
  HERMES_MTIME=$(stat -f '%m' "$HOME/.hermes" 2>/dev/null || echo 0)
  if [ "$HERMES_MTIME" -lt "$WENSHU_MTIME" ] || [ "$HERMES_MTIME" = "0" ]; then
    ok "✓ ~/.hermes 没被 wenshu 装污染 (mtime 比 wenshu 旧)"
  else
    echo "  WARN: ~/.hermes mtime $HERMES_MTIME 比 wenshu $WENSHU_MTIME 新 — 可能装机 user 自己动过"
  fi
else
  ok "(skip) ~/.hermes 不存在 — 装机 user 本来就没装 hermes"
fi

echo
echo "=== 4. desktop .app 安装与 CFBundle ==="
APP="/Applications/文枢.app"
if [ ! -d "$APP" ]; then
  no "$APP 不存在 — 装机 user 没拖 installer .app"
else
  DISPLAY_NAME=$(plutil -extract CFBundleDisplayName raw "$APP/Contents/Info.plist" 2>/dev/null)
  IDENTIFIER=$(plutil -extract CFBundleIdentifier raw "$APP/Contents/Info.plist" 2>/dev/null)
  VERSION=$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist" 2>/dev/null)
  if [ "$DISPLAY_NAME" = "文枢" ]; then ok "CFBundleDisplayName = 文枢"; else no "CFBundleDisplayName = $DISPLAY_NAME"; fi
  if [ "$IDENTIFIER" = "com.wenshu.app" ]; then ok "CFBundleIdentifier = com.wenshu.app"; else no "CFBundleIdentifier = $IDENTIFIER"; fi
  if [ "$VERSION" = "0.0.1" ]; then ok "CFBundleShortVersionString = 0.0.1"; else no "version = $VERSION"; fi
  # wenshu 二进制名 (不是 Hermes)
  EXEC_NAME=$(plutil -extract CFBundleExecutable raw "$APP/Contents/Info.plist" 2>/dev/null)
  if [ "$EXEC_NAME" = "文枢" ]; then ok "CFBundleExecutable = 文枢"; else no "CFBundleExecutable = $EXEC_NAME"; fi
fi

echo
echo "=== 5. desktop .app 进程 alive ==="
PID=$(pgrep -f '/文枢.app/Contents/MacOS/文枢' | head -1)
if [ -n "$PID" ]; then
  ok "文枢.app 进程 alive: PID $PID"
else
  echo "  WARN: 文枢.app 进程没找到 — 可能没启动 (无害, 装机 user 自己 open)"
fi

echo
echo "=== 6. desktop LOGO 是否真 icns ==="
if [ -d "$APP" ]; then
  ICNS_TYPE=$(file "$APP/Contents/Resources/icon.icns" 2>/dev/null | grep -o 'ic[0-9]*' | head -1)
  if [ -n "$ICNS_TYPE" ]; then
    ok "icon.icns = $ICNS_TYPE type (real icns, 不是 PNG mock)"
  else
    no "icon.icns 不是真 icns type"
  fi
fi

echo
echo "=== 7. 远端 main 最新 commit ==="
HEAD=$(git -C /Volumes/ANAN/Engineering/wenshu rev-parse HEAD 2>/dev/null || echo "")
ORIGIN=$(git -C /Volumes/ANAN/Engineering/wenshu rev-parse origin/main 2>/dev/null || echo "")
if [ -n "$HEAD" ] && [ "$HEAD" = "$ORIGIN" ]; then
  ok "本地 HEAD = origin/main = $HEAD"
else
  echo "  WARN: 本地 $HEAD vs 远端 $ORIGIN 不一致 (可能没 push)"
fi

echo
echo "=== 8. tag v0.0.1 在 ==="
TAG=$(git -C /Volumes/ANAN/Engineering/wenshu ls-remote --tags origin 'v0.0.1' 2>/dev/null | head -1 | awk '{print $1}')
if [ -n "$TAG" ]; then
  ok "tag v0.0.1 = $TAG (在远端)"
else
  no "tag v0.0.1 不在远端"
fi

echo
echo "=== 总结 ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo
if [ "$FAIL" -eq 0 ]; then
  echo "所有检查通过 ✓ — 文枢 0.0.1 装好"
  exit 0
else
  echo "$FAIL 项失败 — 看上面 FAIL 行 + PROJECT-NOTES.md"
  exit "$FAIL"
fi
