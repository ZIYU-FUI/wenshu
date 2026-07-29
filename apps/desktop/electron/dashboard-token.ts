/**
 * Helpers for local dashboard session-token discovery.
 *
 * The desktop main process can pass WENSHU_DASHBOARD_SESSION_TOKEN when it
 * spawns the local dashboard, but the dashboard is the source of truth for the
 * token it actually serves to the renderer. If those drift, HTTP readiness
 * probes still pass while /api/ws rejects the renderer's token.
 */

const DEFAULT_TOKEN_FETCH_TIMEOUT_MS = 3_000

async function fetchPublicText(url, options: any = {}) {
  const { protocol } = new URL(url)

  if (protocol !== 'http:' && protocol !== 'https:') {
    throw new Error(`Unsupported 文枢 backend URL protocol: ${protocol}`)
  }

  const timeoutMs = options.timeoutMs ?? DEFAULT_TOKEN_FETCH_TIMEOUT_MS

  const res = await fetch(url, { signal: AbortSignal.timeout(timeoutMs) }).catch(error => {
    if (error.name === 'TimeoutError') {
      throw new Error(`Timed out connecting to 文枢 backend after ${timeoutMs}ms`)
    }

    throw error
  })

  const text = await res.text()

  if (!res.ok) {
    throw new Error(`${res.status}: ${text || res.statusText}`)
  }

  return text
}

async function fetchPublicJson(url, options: any = {}) {
  // Auth-free JSON fetch for the public /api/status readiness probe. The probe
  // is in ``PUBLIC_API_PATHS`` on every bind (loopback and gated), so no
  // ``X-Wenshu-Session-Token`` header is sent -- this avoids leaking a token
  // to a path that doesn't need one, and matches the desktop's existing
  // ``fetchPublicJson`` contract in main.ts. ``options.fetchText`` is the
  // test-injectable seam so unit tests can avoid hitting the network.
  const fetchText = options.fetchText || fetchPublicText
  const text = await fetchText(url, options)

  if (!text) {
    return null
  }

  try {
    return JSON.parse(text)
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    throw new Error(`Invalid JSON from ${url}: ${message}`)
  }
}

function dashboardStatusUrl(baseUrl) {
  return `${String(baseUrl || '').replace(/\/+$/, '')}/api/status`
}

function dashboardIndexUrl(baseUrl) {
  return `${String(baseUrl || '').replace(/\/+$/, '')}/`
}

// ``/api/status`` is the source of truth for the session token the backend
// actually serves -- in loopback mode the live ``_SESSION_TOKEN`` is included
// in the JSON body (see wenshu_cli/web_server.py::get_status), so a JSON
// fetch is BOTH the liveness probe AND the token pickup, replacing the
// HTML-scrape path that the headless ``wenshu serve`` backend cannot serve
// (it has no SPA index, ``/`` returns 404 with
// "Headless backend (wenshu serve): web UI disabled"). Reading the token
// off /api/status also means a SPA-less build can never strand the desktop.
async function resolveServedDashboardToken(baseUrl, fallbackToken, options: any = {}) {
  const fetcher = options.fetchJson || fetchPublicJson
  const status = await fetcher(dashboardStatusUrl(baseUrl), {
    timeoutMs: options.timeoutMs ?? DEFAULT_TOKEN_FETCH_TIMEOUT_MS
  })

  // ``/api/status`` is allowed to omit ``authToken`` on gated binds (the OAuth
  // gate does not inject the legacy ``_SESSION_TOKEN`` -- cookie auth is
  // authoritative there). For our headless ``wenshu serve`` loopback case the
  // field is always present.
  const servedToken = status && typeof status === 'object' ? status.authToken : null

  if (typeof servedToken !== 'string' || servedToken.length === 0) {
    return fallbackToken
  }

  if (servedToken !== fallbackToken && typeof options.rememberLog === 'function') {
    options.rememberLog('[boot] dashboard served a different session token; using served token for WebSocket auth')
  }

  return servedToken
}

/**
 * A served token that differs from our spawn token while our child is DEAD
 * came from a process we did not spawn (orphan/port squatter that satisfied
 * the public /api/status readiness probe). With a live child the mismatch is
 * benign: our own backend regenerated the token because the env pin did not
 * survive the spawn.
 */
function isForeignBackendToken({ servedToken, spawnToken, childAlive }) {
  return Boolean(servedToken) && servedToken !== spawnToken && !childAlive
}

/**
 * Resolve the token the backend actually serves, adopting benign drift and
 * failing loudly on a foreign backend. `childAlive` is a thunk so liveness is
 * sampled after the fetch, not before.
 */
async function adoptServedDashboardToken(baseUrl, spawnToken, { childAlive, label = '文枢 backend', ...options }) {
  const servedToken = await resolveServedDashboardToken(baseUrl, spawnToken, options).catch(error => {
    options.rememberLog?.(`[boot] could not read served dashboard token (${label}): ${error.message}`)

    return spawnToken
  })

  if (isForeignBackendToken({ servedToken, spawnToken, childAlive: childAlive() })) {
    throw new Error(
      `${label} exited and ${dashboardIndexUrl(baseUrl)} is served by a process we did not spawn; refusing its session token.`
    )
  }

  return servedToken
}

export {
  adoptServedDashboardToken,
  dashboardIndexUrl,
  dashboardStatusUrl,
  DEFAULT_TOKEN_FETCH_TIMEOUT_MS,
  fetchPublicJson,
  fetchPublicText,
  isForeignBackendToken,
  resolveServedDashboardToken
}
