# wenshu pre-commit filter tests

Self-contained bash tests using `mktemp -d` (no impact on real wenshu repo).

## Run

```bash
cd Tools/wenshu-devtool/tests
./test_block_pollution.sh
./test_allow_allowed_tokens.sh
```

Each test exits 0 on PASS, non-1 on FAIL.

## Coverage

- `test_block_pollution.sh` — staged .md with forbidden vocab → commit blocked.
- `test_allow_allowed_tokens.sh` — staged .md with only allowed tokens (老板 / 文枢 / 拍 / 拍板 / ※) → commit succeeds.

## Allowed vs forbidden

Forbidden (filter blocks):

```
修真 渡劫 筑基 返虚 结丹 金丹 元婴 飞升 天劫 雷劫 心魔 魔障
```

Allowed (filter passes through):

```
老板 (project user address)
文枢 (project brand)
拍 (boss-decide verb)
拍板 (boss board-decide verb)
※ (marker glyph)
```

## Install the filter

```bash
cd Tools/wenshu-devtool
./install_hook.sh
```

Idempotent. Removes / overwrites `.git/hooks/pre-commit`.

## Bypass

`git commit --no-verify` skips the hook (logged to stderr; discouraged).