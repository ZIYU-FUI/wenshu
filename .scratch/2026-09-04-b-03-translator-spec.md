2026-09-04-b-03-translator-spec.md

B-03 T3a spec: CJK commit-body translator toolkit (= ship pre-stage, not the rebase itself).

Why T3a ships without applying the rebase:

The B-03 backlog ticket wants the commit bodies in 6585a0476^..HEAD rewritten from CJK to English. The naive path (= `git rebase -i 6585a0476^..HEAD` + hand-edit every commit message) is risky:

1. takes 30+ minutes interactive;
2. conflicts with any in-flight work that lands in the range;
3. push is forced (= every collaborator has to reset);
4. operator has to monitor (= it cannot run unattended).

Boss 2026-09-04 OOB cadence = "需要推, 不要存大量 commits". The cadence rule means a single PR with a 30-minute interactive rebase + a force-push is the wrong shape: it produces a huge diff at push time and burns attention.

T3a therefore splits the work into two packets:

* T3a (this ship-packet) = ship a safe, idempotent toolkit (= shell script + dry-run report + this spec). Zero history change. Zero risk. Reviewed in one read.
* T3b (future) = `Scripts/translate-commit-bodies.sh --apply` (= one-shot, idempotent, backup-ref-protected). Boss can run T3b later, or never.

This split matches the cadence rule (= ship now, no big push) and the policy rule (= boss decides when the rebase lands; the toolkit just makes the decision safe when it lands).

# Algorithm

The script walks 6585a0476^..HEAD with `git log --reverse --format=...` and emits one record per commit. Each record carries the subject and the body separately. The script then either:

1. `--dry-run` (= default): counts non-ASCII bytes (= bytes outside 0x00..0x7F) in each body and prints `<hash> <subject> | <N> non-ASCII bytes` for every commit where the count is greater than zero. Output is written to `Scripts/translate-commit-bodies.dry-run.txt`. No history change. Exits 0.
2. `--apply`: invokes `git filter-branch -f --msg-filter '<embedded pipeline>' -- 6585a0476^..HEAD`. The msg-filter splits each commit message at the first newline (= preserves the subject verbatim), then feeds the body lines to a python3-driven hand-curated lookup table. Lines with no lookup hit that still contain CJK are prefixed with `[AUTO-TRANSLATED, PLEASE REVIEW]`. Subjects are never touched (= `git log --oneline` column stays stable).

Hand-curated lookup table (= 26 phrases that recur in the B-03 range, derived from `git log 6585a0476^..HEAD --format=%b | grep` on 2026-09-04):

* `你移植 hermes 涉及到前端 UI 的你自动解决语言问题` -> `you auto-resolve language issues when porting hermes UI`
* `PO 全链路方法论执行` -> `PO end-to-end methodology execution`
* `全面接口级测试,写完整测试用例,继续推进移植` -> `full interface-level tests + complete test cases + keep porting`
* `把表格中所有不是干净的都修` -> `fix every non-clean row in the table`
* `能用 apple api 的都用 api` -> `use Apple APIs wherever possible`
* `在 swift 化的同时, 把现在 wenshu 项目里的 ui 多语言化顺手做了` -> `while porting to Swift, do i18n on the wenshu UI along the way`
* `一直跑移植就行` -> `just keep porting`
* `不用问我了` -> `no need to ask me`
* `全面接口级测试` -> `full interface-level tests`
* `六类全修` -> `fix all six categories`
* `继续推进移植` -> `keep porting`
* `走苹果 api` -> `use Apple APIs`
* `多语言化顺手做了` -> `do i18n while you are at it`
* `整个视觉` -> `the whole visual`
* `暂时不验` -> `skip verification for now`
* `继续移植` -> `keep porting`
* `生图` -> `image generation`
* `卡牌` -> `card`
* `调研` -> `investigation`
* `铁律` -> `iron rule`
* `老板` -> `boss`
* `拍` -> `decision`
* `继续` -> `continue`
* `昨天` -> `yesterday`
* `今天` -> `today`
* `活` -> `task` (= weak single-char rule; only safe because the recurring `老板 ... 活` cluster is the only context)

The table is order-sensitive: longer phrases are matched first so `PO 全链路方法论执行` is not half-eaten by `继续` (= which would leave a stale fragment). The script never invents a translation; only entries in the table are applied. CJK content with no lookup match is left in place but prefixed with the human-review marker.

# T3b rollback path

`git filter-branch -f` rewrites the range in place. Before the rewrite, T3a writes a backup ref:

```
git update-ref refs/backup/translate-commit-bodies-pre HEAD
```

If T3b ever lands and the operator wants to undo:

```
git reset --hard refs/backup/translate-commit-bodies-pre
git push --force-with-lease origin main   # safe-force (= push fails if remote moved)
```

The force-push is the operator's responsibility (= T3b manual step). The script never force-pushes.

# Acceptable outcomes

There are exactly two acceptable outcomes for this ship-packet:

1. Zero application (= boss never runs T3b). The toolkit stays as reference material; future maintainers can extend the lookup table and re-apply.
2. T3b succeeds and the rebase lives in history. The CJK commit bodies are now English, with `[AUTO-TRANSLATED, PLEASE REVIEW]` markers flagging the lines that need human polish.

Both outcomes satisfy the B-03 ticket (= the migration is either complete or executable on demand).

# Files in this ship-packet

* `Scripts/translate-commit-bodies.sh` (new, +x) -- bash entry-point. Two modes (= --dry-run / --apply) + --help. Stdlib only (= bash / sed / awk / python3 / git). No new third-party dependency.
* `Scripts/translate-commit-bodies.dry-run.txt` (new) -- generated by --dry-run. One line per affected commit. 224 commits in the B-03 range currently have non-ASCII bytes in their body (= measured on 2026-09-04; 247 commits total in 6585a0476^..HEAD).
* `.scratch/2026-09-04-b-03-translator-spec.md` (this file).

# Acceptance verification (= done 2026-09-04)

* `Scripts/translate-commit-bodies.sh --dry-run` -> exit 0, 224 lines written.
* `Scripts/translate-commit-bodies.sh --help` -> exit 0, prints usage.
* `Scripts/translate-commit-bodies.sh --apply` -> NOT executed (= T3b is a future packet).
* `swift build` -> exit 0 (= no source code touched).
* `Scripts/translate-commit-bodies.sh` chmod +x (= executable bit set).