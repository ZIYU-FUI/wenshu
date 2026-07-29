// Backend subcommand routing for the desktop-managed 文枢 processes.
//
// The desktop owns two distinct children in the isolated 文枢 runtime:
//   1. `python -m wenshu_cli.main gateway run` for messaging + cron.
//   2. `python -m wenshu_cli.main serve ...` for the desktop HTTP/WebSocket API.
//
// Keep the argv builders separate: `gateway run` is not a substitute for
// `serve` and does not announce the ephemeral desktop API port. `serve` is a
// newer subcommand: a runtime that predates it (an older managed install the
// app hasn't updated yet, or an older `wenshu` resolved from PATH) only knows
// `dashboard --no-open`. To avoid bricking those users mid-upgrade we detect
// whether the resolved runtime understands `serve` and, only when it does not,
// fall back to the legacy `dashboard --no-open` invocation. Both produce the
// exact same headless gateway; `serve` is just the decoupled name.
//
// These helpers are pure so they can be unit-tested without Electron.

/** Build the isolated messaging gateway argv. */
export function gatewayBackendArgs() {
  return ['gateway', 'run']
}

/**
 * Build the canonical headless backend argv (always `serve`).
 * @param {string} [profile] optional 文枢 profile to pin via `--profile`.
 */
export function serveBackendArgs(profile?: string) {
  const head = profile ? ['--profile', profile] : []

  return [...head, 'serve', '--host', '127.0.0.1', '--port', '0']
}

/**
 * Rewrite a resolved backend argv from `serve` to the legacy
 * `dashboard --no-open` form, preserving every other argument (incl. a leading
 * `-m wenshu_cli.main` and any `--profile <name>`). Returns a copy; if there is
 * no `serve` token the argv is returned unchanged.
 */
export function dashboardFallbackArgs(args) {
  const i = args.indexOf('serve')

  if (i === -1) {
    return args.slice()
  }

  return [...args.slice(0, i), 'dashboard', '--no-open', ...args.slice(i + 1)]
}

/**
 * True when a runtime's `wenshu_cli/subcommands/dashboard.py` source registers
 * the `serve` subcommand. Matches `add_parser("serve"` / `add_parser('serve'`
 * specifically so the substring "server" (e.g. "start_server", "web server")
 * never produces a false positive.
 */
export function sourceDeclaresServe(dashboardPySource) {
  return /add_parser\(\s*["']serve["']/.test(String(dashboardPySource || ''))
}
