import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import path from 'node:path'

// Hermes Setup — Tauri-targeted Vite config.
//
// Port 5175 keeps us out of the way of:
//   web       (vite default 5173)
//   apps/desktop dev     (5174 per its package.json)
//
// `clearScreen: false` is the Tauri convention — they spawn vite as a child
// process and want our errors to stay visible.
//
// `base: './'` (added 2026-07-27 WO-001AM) — relative asset paths are more
// robust under the `tauri://localhost/` scheme across macOS WebKit versions
// than the default absolute `/`; avoids silent 404s on the JS bundle that
// manifest as a "blue screen" (actually the unstyled dark-mode background).
// NOTE: in Vite 8, `base` lives at the top level of UserConfig, NOT inside
// `build` (BuildEnvironmentOptions uses a narrower type that lacks it).

const host = process.env.TAURI_DEV_HOST

export default defineConfig({
  // Top-level UserConfig (vite 8). Relative public path for both dev + build.
  base: './',
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src')
    }
  },
  clearScreen: false,
  server: {
    port: 5175,
    strictPort: true,
    host: host || '127.0.0.1',
    hmr: host
      ? {
          protocol: 'ws',
          host,
          port: 5176
        }
      : undefined,
    watch: {
      // Don't watch the Rust side — tauri-cli handles it.
      ignored: ['**/src-tauri/**']
    }
  },
  build: {
    target: 'esnext',
    outDir: 'dist',
    emptyOutDir: true
  }
})
