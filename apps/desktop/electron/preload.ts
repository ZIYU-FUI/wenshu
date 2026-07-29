import { contextBridge, ipcRenderer, webUtils } from 'electron'

contextBridge.exposeInMainWorld('wenshuDesktop', {
  getConnection: profile => ipcRenderer.invoke('wenshu:connection', profile),
  revalidateConnection: () => ipcRenderer.invoke('wenshu:connection:revalidate'),
  touchBackend: profile => ipcRenderer.invoke('wenshu:backend:touch', profile),
  getGatewayWsUrl: profile => ipcRenderer.invoke('wenshu:gateway:ws-url', profile),
  openSessionWindow: (sessionId, opts) => ipcRenderer.invoke('wenshu:window:openSession', sessionId, opts),
  openNewSessionWindow: () => ipcRenderer.invoke('wenshu:window:openNewSession'),
  petOverlay: {
    // Main renderer → main process: window lifecycle + drag. `request` is
    // `{ bounds, screen }`; resolves with the screen bounds it actually used.
    open: request => ipcRenderer.invoke('wenshu:pet-overlay:open', request),
    close: () => ipcRenderer.invoke('wenshu:pet-overlay:close'),
    setBounds: bounds => ipcRenderer.send('wenshu:pet-overlay:set-bounds', bounds),
    setIgnoreMouse: ignore => ipcRenderer.send('wenshu:pet-overlay:ignore-mouse', ignore),
    // Flip the overlay focusable (and focus it) while the composer needs keys.
    setFocusable: focusable => ipcRenderer.send('wenshu:pet-overlay:set-focusable', focusable),
    // Main renderer → overlay (forwarded by main): push the latest pet state.
    pushState: payload => ipcRenderer.send('wenshu:pet-overlay:state', payload),
    // Overlay → main renderer (forwarded by main): pop back in / composer submit.
    control: payload => ipcRenderer.send('wenshu:pet-overlay:control', payload),
    // Overlay subscribes to state pushes.
    onState: callback => {
      const listener = (_event, payload) => callback(payload)
      ipcRenderer.on('wenshu:pet-overlay:state', listener)

      return () => ipcRenderer.removeListener('wenshu:pet-overlay:state', listener)
    },
    // Main renderer subscribes to overlay control messages.
    onControl: callback => {
      const listener = (_event, payload) => callback(payload)
      ipcRenderer.on('wenshu:pet-overlay:control', listener)

      return () => ipcRenderer.removeListener('wenshu:pet-overlay:control', listener)
    }
  },
  getBootProgress: () => ipcRenderer.invoke('wenshu:boot-progress:get'),
  getConnectionConfig: profile => ipcRenderer.invoke('wenshu:connection-config:get', profile),
  saveConnectionConfig: payload => ipcRenderer.invoke('wenshu:connection-config:save', payload),
  applyConnectionConfig: payload => ipcRenderer.invoke('wenshu:connection-config:apply', payload),
  testConnectionConfig: payload => ipcRenderer.invoke('wenshu:connection-config:test', payload),
  probeConnectionConfig: remoteUrl => ipcRenderer.invoke('wenshu:connection-config:probe', remoteUrl),
  oauthLoginConnectionConfig: remoteUrl => ipcRenderer.invoke('wenshu:connection-config:oauth-login', remoteUrl),
  oauthLogoutConnectionConfig: remoteUrl => ipcRenderer.invoke('wenshu:connection-config:oauth-logout', remoteUrl),
  // 文枢 Cloud: one portal login powers discovery + silent per-agent sign-in
  // (cloud-auto-discovery Phase 3).
  cloud: {
    status: () => ipcRenderer.invoke('wenshu:cloud:status'),
    login: () => ipcRenderer.invoke('wenshu:cloud:login'),
    logout: () => ipcRenderer.invoke('wenshu:cloud:logout'),
    discover: org => ipcRenderer.invoke('wenshu:cloud:discover', org),
    agentSignIn: dashboardUrl => ipcRenderer.invoke('wenshu:cloud:agent-sign-in', dashboardUrl)
  },
  profile: {
    get: () => ipcRenderer.invoke('wenshu:profile:get'),
    set: name => ipcRenderer.invoke('wenshu:profile:set', name)
  },
  api: request => ipcRenderer.invoke('wenshu:api', request),
  notify: payload => ipcRenderer.invoke('wenshu:notify', payload),
  requestMicrophoneAccess: () => ipcRenderer.invoke('wenshu:requestMicrophoneAccess'),
  readFileDataUrl: filePath => ipcRenderer.invoke('wenshu:readFileDataUrl', filePath),
  readFileText: filePath => ipcRenderer.invoke('wenshu:readFileText', filePath),
  selectPaths: options => ipcRenderer.invoke('wenshu:selectPaths', options),
  writeClipboard: text => ipcRenderer.invoke('wenshu:writeClipboard', text),
  saveImageFromUrl: url => ipcRenderer.invoke('wenshu:saveImageFromUrl', url),
  saveImageBuffer: (data, ext) => ipcRenderer.invoke('wenshu:saveImageBuffer', { data, ext }),
  saveClipboardImage: () => ipcRenderer.invoke('wenshu:saveClipboardImage'),
  getPathForFile: file => {
    try {
      return webUtils.getPathForFile(file) || ''
    } catch {
      return ''
    }
  },
  normalizePreviewTarget: (target, baseDir) => ipcRenderer.invoke('wenshu:normalizePreviewTarget', target, baseDir),
  watchPreviewFile: url => ipcRenderer.invoke('wenshu:watchPreviewFile', url),
  stopPreviewFileWatch: id => ipcRenderer.invoke('wenshu:stopPreviewFileWatch', id),
  setTitleBarTheme: payload => ipcRenderer.send('wenshu:titlebar-theme', payload),
  setNativeTheme: mode => ipcRenderer.send('wenshu:native-theme', mode),
  setTranslucency: payload => ipcRenderer.send('wenshu:translucency', payload),
  setPreviewShortcutActive: active => ipcRenderer.send('wenshu:previewShortcutActive', Boolean(active)),
  openExternal: url => ipcRenderer.invoke('wenshu:openExternal', url),
  openPreviewInBrowser: url => ipcRenderer.invoke('wenshu:openPreviewInBrowser', url),
  fetchLinkTitle: url => ipcRenderer.invoke('wenshu:fetchLinkTitle', url),
  sanitizeWorkspaceCwd: cwd => ipcRenderer.invoke('wenshu:workspace:sanitize', cwd),
  settings: {
    getDefaultProjectDir: () => ipcRenderer.invoke('wenshu:setting:defaultProjectDir:get'),
    setDefaultProjectDir: dir => ipcRenderer.invoke('wenshu:setting:defaultProjectDir:set', dir),
    pickDefaultProjectDir: () => ipcRenderer.invoke('wenshu:setting:defaultProjectDir:pick')
  },
  zoom: {
    // Current zoom of this window, as { level, percent }.
    get: () => ipcRenderer.invoke('wenshu:zoom:get'),
    setPercent: percent => ipcRenderer.send('wenshu:zoom:set-percent', percent),
    // Fires on every zoom change, including the Ctrl/Cmd +/-/0 shortcuts,
    // so the settings UI can stay in sync with the keyboard.
    onChanged: callback => {
      const listener = (_event, payload) => callback(payload)
      ipcRenderer.on('wenshu:zoom:changed', listener)

      return () => ipcRenderer.removeListener('wenshu:zoom:changed', listener)
    }
  },
  revealLogs: () => ipcRenderer.invoke('wenshu:logs:reveal'),
  getRecentLogs: () => ipcRenderer.invoke('wenshu:logs:recent'),
  readDir: dirPath => ipcRenderer.invoke('wenshu:fs:readDir', dirPath),
  gitRoot: startPath => ipcRenderer.invoke('wenshu:fs:gitRoot', startPath),
  revealPath: targetPath => ipcRenderer.invoke('wenshu:fs:reveal', targetPath),
  openDir: dirPath => ipcRenderer.invoke('wenshu:fs:openDir', dirPath),
  renamePath: (targetPath, newName) => ipcRenderer.invoke('wenshu:fs:rename', targetPath, newName),
  writeTextFile: (filePath, content) => ipcRenderer.invoke('wenshu:fs:writeText', filePath, content),
  trashPath: targetPath => ipcRenderer.invoke('wenshu:fs:trash', targetPath),
  git: {
    worktreeList: repoPath => ipcRenderer.invoke('wenshu:git:worktreeList', repoPath),
    worktreeAdd: (repoPath, options) => ipcRenderer.invoke('wenshu:git:worktreeAdd', repoPath, options),
    worktreeRemove: (repoPath, worktreePath, options) =>
      ipcRenderer.invoke('wenshu:git:worktreeRemove', repoPath, worktreePath, options),
    branchSwitch: (repoPath, branch) => ipcRenderer.invoke('wenshu:git:branchSwitch', repoPath, branch),
    branchList: repoPath => ipcRenderer.invoke('wenshu:git:branchList', repoPath),
    baseBranchList: repoPath => ipcRenderer.invoke('wenshu:git:baseBranchList', repoPath),
    repoStatus: repoPath => ipcRenderer.invoke('wenshu:git:repoStatus', repoPath),
    fileDiff: (repoPath, filePath) => ipcRenderer.invoke('wenshu:git:fileDiff', repoPath, filePath),
    scanRepos: (roots, options) => ipcRenderer.invoke('wenshu:git:scanRepos', roots, options),
    review: {
      list: (repoPath, scope, baseRef) => ipcRenderer.invoke('wenshu:git:review:list', repoPath, scope, baseRef),
      diff: (repoPath, filePath, scope, baseRef, staged) =>
        ipcRenderer.invoke('wenshu:git:review:diff', repoPath, filePath, scope, baseRef, staged),
      stage: (repoPath, filePath) => ipcRenderer.invoke('wenshu:git:review:stage', repoPath, filePath),
      unstage: (repoPath, filePath) => ipcRenderer.invoke('wenshu:git:review:unstage', repoPath, filePath),
      revert: (repoPath, filePath) => ipcRenderer.invoke('wenshu:git:review:revert', repoPath, filePath),
      revParse: (repoPath, ref) => ipcRenderer.invoke('wenshu:git:review:revParse', repoPath, ref),
      commit: (repoPath, message, push) => ipcRenderer.invoke('wenshu:git:review:commit', repoPath, message, push),
      commitContext: repoPath => ipcRenderer.invoke('wenshu:git:review:commitContext', repoPath),
      push: repoPath => ipcRenderer.invoke('wenshu:git:review:push', repoPath),
      shipInfo: repoPath => ipcRenderer.invoke('wenshu:git:review:shipInfo', repoPath),
      createPr: repoPath => ipcRenderer.invoke('wenshu:git:review:createPr', repoPath)
    }
  },
  terminal: {
    cwd: id => ipcRenderer.invoke('wenshu:terminal:cwd', id),
    dispose: id => ipcRenderer.invoke('wenshu:terminal:dispose', id),
    resize: (id, size) => ipcRenderer.invoke('wenshu:terminal:resize', id, size),
    start: options => ipcRenderer.invoke('wenshu:terminal:start', options),
    write: (id, data) => ipcRenderer.invoke('wenshu:terminal:write', id, data),
    onData: (id, callback) => {
      const channel = `wenshu:terminal:${id}:data`
      const listener = (_event, payload) => callback(payload)
      ipcRenderer.on(channel, listener)

      return () => ipcRenderer.removeListener(channel, listener)
    },
    onExit: (id, callback) => {
      const channel = `wenshu:terminal:${id}:exit`
      const listener = (_event, payload) => callback(payload)
      ipcRenderer.on(channel, listener)

      return () => ipcRenderer.removeListener(channel, listener)
    }
  },
  onClosePreviewRequested: callback => {
    const listener = () => callback()
    ipcRenderer.on('wenshu:close-preview-requested', listener)

    return () => ipcRenderer.removeListener('wenshu:close-preview-requested', listener)
  },
  onOpenUpdatesRequested: callback => {
    const listener = () => callback()
    ipcRenderer.on('wenshu:open-updates', listener)

    return () => ipcRenderer.removeListener('wenshu:open-updates', listener)
  },
  onDeepLink: callback => {
    const listener = (_event, payload) => callback(payload)
    ipcRenderer.on('wenshu:deep-link', listener)

    return () => ipcRenderer.removeListener('wenshu:deep-link', listener)
  },
  signalDeepLinkReady: () => ipcRenderer.invoke('wenshu:deep-link-ready'),
  onWindowStateChanged: callback => {
    const listener = (_event, payload) => callback(payload)
    ipcRenderer.on('wenshu:window-state-changed', listener)

    return () => ipcRenderer.removeListener('wenshu:window-state-changed', listener)
  },
  onFocusSession: callback => {
    const listener = (_event, sessionId) => callback(sessionId)
    ipcRenderer.on('wenshu:focus-session', listener)

    return () => ipcRenderer.removeListener('wenshu:focus-session', listener)
  },
  onNotificationAction: callback => {
    const listener = (_event, payload) => callback(payload)
    ipcRenderer.on('wenshu:notification-action', listener)

    return () => ipcRenderer.removeListener('wenshu:notification-action', listener)
  },
  onPreviewFileChanged: callback => {
    const listener = (_event, payload) => callback(payload)
    ipcRenderer.on('wenshu:preview-file-changed', listener)

    return () => ipcRenderer.removeListener('wenshu:preview-file-changed', listener)
  },
  onBackendExit: callback => {
    const listener = (_event, payload) => callback(payload)
    ipcRenderer.on('wenshu:backend-exit', listener)

    return () => ipcRenderer.removeListener('wenshu:backend-exit', listener)
  },
  // Soft gateway-mode apply finished tearing down the primary backend. Renderer
  // should wipe session lists + re-dial without a window reload.
  onConnectionApplied: callback => {
    const listener = () => callback()
    ipcRenderer.on('wenshu:connection:applied', listener)

    return () => ipcRenderer.removeListener('wenshu:connection:applied', listener)
  },
  onPowerResume: callback => {
    const listener = () => callback()
    ipcRenderer.on('wenshu:power-resume', listener)

    return () => ipcRenderer.removeListener('wenshu:power-resume', listener)
  },
  onBootProgress: callback => {
    const listener = (_event, payload) => callback(payload)
    ipcRenderer.on('wenshu:boot-progress', listener)

    return () => ipcRenderer.removeListener('wenshu:boot-progress', listener)
  },
  // First-launch bootstrap progress -- emitted by the install.ps1 stage
  // runner in main.ts (apps/desktop/electron/bootstrap-runner.ts).
  // Renderer's install overlay subscribes to live events and queries the
  // current snapshot via getBootstrapState() to recover after a devtools
  // reload mid-bootstrap.
  getBootstrapState: () => ipcRenderer.invoke('wenshu:bootstrap:get'),
  resetBootstrap: () => ipcRenderer.invoke('wenshu:bootstrap:reset'),
  repairBootstrap: () => ipcRenderer.invoke('wenshu:bootstrap:repair'),
  cancelBootstrap: () => ipcRenderer.invoke('wenshu:bootstrap:cancel'),
  onBootstrapEvent: callback => {
    const listener = (_event, payload) => callback(payload)
    ipcRenderer.on('wenshu:bootstrap:event', listener)

    return () => ipcRenderer.removeListener('wenshu:bootstrap:event', listener)
  },
  getVersion: () => ipcRenderer.invoke('wenshu:version'),
  getRemoteDisplayReason: () => ipcRenderer.invoke('wenshu:get-remote-display-reason'),
  uninstall: {
    summary: () => ipcRenderer.invoke('wenshu:uninstall:summary'),
    run: mode => ipcRenderer.invoke('wenshu:uninstall:run', { mode })
  },
  updates: {
    check: () => ipcRenderer.invoke('wenshu:updates:check'),
    apply: opts => ipcRenderer.invoke('wenshu:updates:apply', opts),
    getBranch: () => ipcRenderer.invoke('wenshu:updates:branch:get'),
    setBranch: name => ipcRenderer.invoke('wenshu:updates:branch:set', name),
    onProgress: callback => {
      const listener = (_event, payload) => callback(payload)
      ipcRenderer.on('wenshu:updates:progress', listener)

      return () => ipcRenderer.removeListener('wenshu:updates:progress', listener)
    }
  },
  themes: {
    fetchMarketplace: id => ipcRenderer.invoke('wenshu:vscode-theme:fetch', id),
    searchMarketplace: query => ipcRenderer.invoke('wenshu:vscode-theme:search', query)
  }
})
