# Langfuse Observability Plugin

This plugin ships bundled with Wenshu but is **opt-in** — it only loads when
you explicitly enable it.

## Enable

Pick one:

```bash
# Interactive: walks you through credentials + SDK install + enable
wenshu tools  # → Langfuse Observability

# Manual
pip install langfuse
wenshu plugins enable observability/langfuse
```

## Required credentials

Set these in `~/.wenshu-hermes/.env` (or via `wenshu tools`):

```bash
WENSHU_LANGFUSE_PUBLIC_KEY=pk-lf-...
WENSHU_LANGFUSE_SECRET_KEY=sk-lf-...
WENSHU_LANGFUSE_BASE_URL=https://cloud.langfuse.com   # or your self-hosted URL
```

Without the SDK or credentials the hooks no-op silently — the plugin fails
open.

## Verify

```bash
wenshu plugins list                 # observability/langfuse should show "enabled"
wenshu chat -q "hello"              # then check Langfuse for a "Wenshu turn" trace
```

## Optional tuning

```bash
WENSHU_LANGFUSE_ENV=production       # environment tag
WENSHU_LANGFUSE_RELEASE=v1.0.0       # release tag
WENSHU_LANGFUSE_SAMPLE_RATE=0.5      # sample 50% of traces
WENSHU_LANGFUSE_MAX_CHARS=12000      # max chars per field (default: 12000)
WENSHU_LANGFUSE_DEBUG=true           # verbose plugin logging
```

## Disable

```bash
wenshu plugins disable observability/langfuse
```
