#!/usr/bin/env bash
# gate_run.sh <worktree> <logprefix> <cmd> [cmd...]
# The gate logs land in <repo>/.gate-logs/ (= gitignored scratch
# inside the repo, not a path outside it).
# Runs each command with a hard 300s wall clock; prints one RESULT line per cmd.
# Exits 0 only if every command exited 0.
set -uo pipefail
WT="$1"; shift
LOG="$1"; shift
PER_CMD_TIMEOUT="${PER_CMD_TIMEOUT:-300}"
# The logs live beside the repo (= a scratch path would not survive the
# machine this runs on, and the log is the evidence of the gate).
LOGDIR="${LOGDIR:-$(cd "$(dirname "$0")/.." && pwd)/.gate-logs}"
mkdir -p "$LOGDIR"
cd "$WT" || exit 2
overall=0
i=0
for cmd in "$@"; do
  i=$((i+1))
  log="$LOGDIR/${LOG}_${i}.log"
  start=$(date +%s)
  perl -e '
    my $t = shift @ARGV;
    my $pid = fork();
    if ($pid == 0) { exec @ARGV; }
    my $start = time;
    while (1) {
      my $r = waitpid($pid, 1);   # WNOHANG
      if ($r == $pid) { my $st = $? >> 8; my $sig = $? & 127; exit($sig ? 124 : $st); }
      if (time - $start > $t) { kill 9, $pid; waitpid($pid,0); exit 124; }
      select(undef, undef, undef, 0.25);
    }
  ' "$PER_CMD_TIMEOUT" bash -lc "$cmd" > "$log" 2>&1
  rc=$?
  end=$(date +%s)
  dur=$((end-start))
  if [ $rc -eq 124 ]; then
    echo "TIMEOUT(${dur}s) $cmd"
    overall=1
  elif [ $rc -eq 0 ]; then
    echo "PASS(${dur}s) $cmd"
  else
    echo "FAIL(rc=$rc,${dur}s) $cmd  [log: $log]"
    overall=1
  fi
  tail -5 "$log" | sed 's/^/    | /'
done
exit $overall
