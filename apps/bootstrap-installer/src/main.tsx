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
// `get_log_path` + `get_hermes_home` diagnostics and the live `bootstrap`
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
