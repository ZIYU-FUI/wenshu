/**
 * Tests for electron/dashboard-token.ts.
 *
 * Run with: node --test electron/dashboard-token.test.ts
 * (Wired into npm test:desktop:platforms in package.json.)
 */

import assert from 'node:assert/strict'

import { test } from 'vitest'

import {
  adoptServedDashboardToken,
  dashboardIndexUrl,
  dashboardStatusUrl,
  fetchPublicJson,
  fetchPublicText,
  isForeignBackendToken,
  resolveServedDashboardToken
} from './dashboard-token'

test('dashboardStatusUrl normalises trailing slashes and targets /api/status', () => {
  assert.equal(dashboardStatusUrl('http://127.0.0.1:9120'), 'http://127.0.0.1:9120/api/status')
  assert.equal(dashboardStatusUrl('https://host.example/wenshu/'), 'https://host.example/wenshu/api/status')
})

test('dashboardIndexUrl preserves dashboard path prefixes (legacy compat)', () => {
  assert.equal(dashboardIndexUrl('http://127.0.0.1:9120'), 'http://127.0.0.1:9120/')
  assert.equal(dashboardIndexUrl('https://host.example/wenshu/'), 'https://host.example/wenshu/')
})

test('fetchPublicJson parses a JSON body', async () => {
  const body = await fetchPublicJson('http://127.0.0.1:9120/api/status', {
    fetchText: async () => JSON.stringify({ authToken: 'served-token', version: '0.0.1' })
  })
  assert.deepEqual(body, { authToken: 'served-token', version: '0.0.1' })
})

test('fetchPublicJson surfaces a clear error when the body is not JSON', async () => {
  await assert.rejects(
    () =>
      fetchPublicJson('http://127.0.0.1:9120/api/status', {
        fetchText: async () => '<html></html>'
      }),
    /Invalid JSON from http:\/\/127\.0\.0\.1:9120\/api\/status/
  )
})

test('resolveServedDashboardToken reads authToken from /api/status JSON', async () => {
  const logs = []

  const token = await resolveServedDashboardToken('http://127.0.0.1:9120', 'spawn-token', {
    fetchJson: async url => {
      assert.equal(url, 'http://127.0.0.1:9120/api/status')

      return { authToken: 'served-token', version: '0.0.1' }
    },
    rememberLog: line => logs.push(line)
  })

  assert.equal(token, 'served-token')
  assert.equal(logs.length, 1)
  assert.match(logs[0], /served a different session token/)
})

test('resolveServedDashboardToken falls back when the status body omits authToken', async () => {
  const token = await resolveServedDashboardToken('http://127.0.0.1:9120', 'spawn-token', {
    fetchJson: async () => ({ version: '0.0.1' }),
    rememberLog: () => {
      throw new Error('should not log when no served token is present')
    }
  })

  assert.equal(token, 'spawn-token')
})

test('resolveServedDashboardToken does not log when served token matches fallback', async () => {
  const token = await resolveServedDashboardToken('http://127.0.0.1:9120', 'same-token', {
    fetchJson: async () => ({ authToken: 'same-token' }),
    rememberLog: () => {
      throw new Error('should not log when token already matches')
    }
  })

  assert.equal(token, 'same-token')
})

test('resolveServedDashboardToken propagates fetch errors so callers can fall back explicitly', async () => {
  await assert.rejects(
    () =>
      resolveServedDashboardToken('http://127.0.0.1:9120', 'spawn-token', {
        fetchJson: async () => {
          throw new Error('boom')
        }
      }),
    /boom/
  )
})

test('fetchPublicText rejects unsupported protocols', async () => {
  await assert.rejects(() => fetchPublicText('file:///tmp/index.html'), /Unsupported 文枢 backend URL protocol/)
})

test('isForeignBackendToken only flags a mismatched token from a dead child', () => {
  const cases = [
    [{ servedToken: 'other', spawnToken: 'mine', childAlive: false }, true],
    // Live child + drift = our backend regenerated the token (env pin lost).
    [{ servedToken: 'other', spawnToken: 'mine', childAlive: true }, false],
    [{ servedToken: 'mine', spawnToken: 'mine', childAlive: false }, false],
    [{ servedToken: 'mine', spawnToken: 'mine', childAlive: true }, false],
    [{ servedToken: null, spawnToken: 'mine', childAlive: false }, false],
    [{ servedToken: '', spawnToken: 'mine', childAlive: false }, false]
  ]

  for (const [input, expected] of cases) {
    assert.equal(isForeignBackendToken(input as any), expected, JSON.stringify(input))
  }
})

test('adoptServedDashboardToken adopts drift from a live child', async () => {
  const token = await adoptServedDashboardToken('http://127.0.0.1:9120', 'spawn-token', {
    childAlive: () => true,
    fetchJson: async () => ({ authToken: 'served-token' })
  })

  assert.equal(token, 'served-token')
})

test('adoptServedDashboardToken refuses a foreign token when our child is dead', async () => {
  await assert.rejects(
    () =>
      adoptServedDashboardToken('http://127.0.0.1:9120', 'spawn-token', {
        childAlive: () => false,
        fetchJson: async () => ({ authToken: 'squatter-token' }),
        label: '文枢 backend for profile "work"'
      }),
    /profile "work".*process we did not spawn/
  )
})

test('adoptServedDashboardToken falls back to the spawn token when the fetch fails', async () => {
  const logs = []

  const token = await adoptServedDashboardToken('http://127.0.0.1:9120', 'spawn-token', {
    childAlive: () => true,
    fetchJson: async () => {
      throw new Error('boom')
    },
    rememberLog: line => logs.push(line)
  })

  assert.equal(token, 'spawn-token')
  assert.equal(logs.length, 1)
  assert.match(logs[0], /could not read served dashboard token \(文枢 backend\): boom/)
})
