// WO-001AX (8/27 v10 white-screen BUG): Tauri 2.x on macOS WebKit ~17.x has
// a window-load race where the page's `<script type="module">` can begin
// evaluation before Tauri has finished injecting `window.__TAURI_INTERNALS__`.
// Any module that imports `@tauri-apps/api/*` then blows up with a synchronous
// `TypeError: Cannot read properties of undefined (reading 'invoke')` while
// walking its import graph, which strands React's render commit and leaves
// the WebView showing nothing but the CSS-only body background (== solid
// white screen on the installer's light-mode fallback path).
//
// We install a defensive no-op polyfill BEFORE any other import runs, so the
// worst case becomes a silenced console warning + a non-functional but
// rendered React tree, rather than a hard crash before mount. The real
// `__TAURI_INTERNALS__` is injected by Tauri as soon as the runtime wakes up;
// our polyfill is overwritten in place — same object reference, so callers
// don't need to re-fetch.
if (typeof window !== 'undefined' && !(window as unknown as { __TAURI_INTERNALS__?: unknown }).__TAURI_INTERNALS__) {
  Object.defineProperty(window, '__TAURI_INTERNALS__', {
    value: {
      invoke: () => Promise.reject(new Error('Tauri internals not yet ready (WO-001AX defensive polyfill)')),
      transformCallback: () => 0,
      unregisterCallback: () => undefined,
      metadata: { currentWindow: { label: 'main' }, currentWebview: { label: 'main', windowLabel: 'main' } },
      convertFileSrc: (filePath: string) => `tauri://localhost/${filePath}`,
      ipc: () => Promise.reject(new Error('Tauri internals not yet ready (WO-001AX defensive polyfill)')),
      postMessage: () => undefined,
      // Tauri 2 uses a Promise-based plugin loader; the real one resolves
      // once the runtime is awake. Our stub resolves immediately so callers
      // that `await window.__TAURI_INTERNALS__.invoke(...)` get the real
      // rejection above and fall through to the store's try/catch.
      _polyfilled: true
    },
    writable: false,
    configurable: true,
    enumerable: false
  })
}

import './styles.css'

import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'

import App from './app.tsx'
import { initialize } from './store'
import { watchTheme } from './theme'

// Follow the OS light/dark appearance. theme.ts paints the first frame on
// import (synchronously, from the media query); this subscribes to live OS
// theme changes via the authoritative Tauri window theme.
void watchTheme()

// WO-001AO (8/26 system-prerequisites bug v4): boot the bootstrap store as
// soon as the React tree mounts so the progress screen can show
// `get_log_path` + `get_wenshu_home` diagnostics and the live `bootstrap`
// event subscription is wired before the user clicks INSTALL. Previously
// the welcome screen had no log-path affordance — a 2-minute silent hang
// in `install_uv()` left the user with no recourse but to wait. Now the
// progress screen renders the log path + an `openLogDir` button below the
// stage list, so a future hang points users straight at the forensic log.
void initialize()

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>
)
