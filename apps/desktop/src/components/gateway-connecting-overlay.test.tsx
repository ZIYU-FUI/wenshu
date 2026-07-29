import { act, cleanup, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'

import { $desktopBoot } from '@/store/boot'
import { $gatewaySwitching } from '@/store/gateway-switch'
import { $desktopOnboarding } from '@/store/onboarding'
import { setGatewayState } from '@/store/session'

import { BootFailureOverlay } from './boot-failure-overlay'
import { GatewayConnectingOverlay } from './gateway-connecting-overlay'

// Repro for the "remote gateway → stuck on CONNECTING, no way to settings"
// report. The connecting overlay (z-1200, full-screen, pointer-events on) used
// to be shown whenever `gatewayState !== 'open' && !boot.error`. The ONLY escape
// hatch — BootFailureOverlay, which has "Use local gateway" / "Sign in" /
// "Retry" — only renders when `boot.error` is set.
//
// useGatewayBoot only calls failDesktopBoot() (which sets boot.error) when the
// INITIAL boot() throws. After the first successful connect (bootCompleted),
// any later socket drop goes through scheduleReconnect(), which loops FOREVER
// against the dead remote. So gatewayState sits at 'closed'/'error' with
// boot.error null. The fix keeps the initial-boot overlay out of post-boot
// reconnects, leaving chat/settings usable while the reconnect loop runs.

function resetStores() {
  setGatewayState('idle')
  $gatewaySwitching.set(false)
  $desktopBoot.set({
    error: null,
    fakeMode: false,
    message: 'ready',
    phase: 'renderer.ready',
    progress: 100,
    running: false,
    timestamp: Date.now(),
    visible: false
  })
  $desktopOnboarding.set({
    configured: true,
    flow: { status: 'idle' },
    mode: 'oauth',
    providers: null,
    reason: null,
    requested: false,
    firstRunSkipped: false,
    manual: false,
    localEndpoint: false
  })
}

beforeEach(resetStores)
afterEach(cleanup)

// The connecting overlay renders the first four localized characters plus a
// scrambled tail inside one span. Match that node specifically so recovery
// copy doesn't read as a false positive. The matcher also accepts the English
// branch for users who explicitly select it; fresh installs use Chinese.
const isConnectingShown = () =>
  screen.queryAllByText((_, el) => /^(?:CONN.*|正在连接.*)$/.test(el?.textContent?.trim() ?? '')).length > 0

const isRecoveryShown = () =>
  Boolean(
    screen.queryByText(/use local gateway|使用本地网关/i) ||
      screen.queryByText(/retry|重试/i) ||
      screen.queryByText(/sign in|登录/i)
  )

describe('connecting overlay vs recovery surface', () => {
  it('renders the cold-start connection message in Simplified Chinese by default', () => {
    $desktopBoot.set({
      ...$desktopBoot.get(),
      message: '正在连接桌面网关',
      phase: 'renderer.gateway.connect',
      progress: 95,
      running: true,
      visible: true
    })

    render(<GatewayConnectingOverlay />)

    expect(screen.getByText('正在连接桌面网关')).toBeTruthy()
    expect(screen.queryByText('CONNECTING')).toBeNull()
  })

  it('hard initial-boot failure surfaces the recovery overlay (the working path)', async () => {
    // failDesktopBoot() ran: error set, gateway never opened.
    $desktopBoot.set({
      ...$desktopBoot.get(),
      error: '文枢 backend did not become ready',
      running: false,
      visible: true
    })
    setGatewayState('error')

    await act(async () => {
      render(
        <>
          <GatewayConnectingOverlay />
          <BootFailureOverlay />
        </>
      )
    })

    expect(isRecoveryShown()).toBe(true)
    // Connecting overlay bows out when boot.error is set.
    expect(isConnectingShown()).toBe(false)
  })

  it('post-boot socket drops do not re-cover the app with the initial CONNECTING overlay', async () => {
    // 1. Initial boot succeeded: gateway opened, boot completed (no error).
    setGatewayState('open')

    let rerender!: (ui: React.ReactElement) => void
    await act(async () => {
      const result = render(
        <>
          <GatewayConnectingOverlay />
          <BootFailureOverlay />
        </>
      )

      rerender = result.rerender
    })

    expect(isConnectingShown()).toBe(false)

    // 2. The remote VPS socket drops (sleep/wake, remote restart, network).
    //    bootCompleted is true, so useGatewayBoot routes this through
    //    scheduleReconnect() — boot.error stays NULL.
    await act(async () => {
      setGatewayState('closed')
      rerender!(
        <>
          <GatewayConnectingOverlay />
          <BootFailureOverlay />
        </>
      )
    })

    // The initial-boot connecting overlay stays out of the way, so settings and
    // the composer remain reachable during the reconnect loop.
    expect(isConnectingShown()).toBe(false)
    expect(isRecoveryShown()).toBe(false)

    // 3. Reconnect loops against the dead remote: gatewayState bounces closed
    //    → error → closed. Until the escalation path sets boot.error, the app
    //    remains usable instead of modal-blocked.
    await act(async () => {
      setGatewayState('error')
      rerender!(
        <>
          <GatewayConnectingOverlay />
          <BootFailureOverlay />
        </>
      )
    })
    expect($desktopBoot.get().error).toBeNull()
    expect(isConnectingShown()).toBe(false)
    expect(isRecoveryShown()).toBe(false)
  })

  it('soft gateway switch keeps the shell — no fullscreen CONNECTING', async () => {
    setGatewayState('open')

    const { rerender } = render(
      <>
        <GatewayConnectingOverlay />
        <BootFailureOverlay />
      </>
    )

    await act(async () => {
      $gatewaySwitching.set(true)
      $desktopBoot.set({
        ...$desktopBoot.get(),
        running: true,
        visible: true,
        progress: 4,
        error: null
      })
      setGatewayState('closed')
      rerender(
        <>
          <GatewayConnectingOverlay />
          <BootFailureOverlay />
        </>
      )
    })

    expect(isConnectingShown()).toBe(false)
    expect(isRecoveryShown()).toBe(false)
  })

  it('FIX: once the prolonged reconnect raises a recoverable boot error, the recovery overlay takes over', async () => {
    // Mirrors what useGatewayBoot.scheduleReconnect() now does after ~45s of
    // failed post-boot reconnects: it calls failDesktopBoot(), flipping the UI
    // from the dead-end CONNECTING overlay to the recovery surface.
    setGatewayState('error')
    $desktopBoot.set({
      ...$desktopBoot.get(),
      error: 'Lost connection to the 文枢 gateway and could not reconnect.',
      running: false,
      visible: true
    })

    await act(async () => {
      render(
        <>
          <GatewayConnectingOverlay />
          <BootFailureOverlay />
        </>
      )
    })

    // Escape hatch is now reachable; the connecting overlay bows out.
    expect(isRecoveryShown()).toBe(true)
    expect(screen.getByRole('button', { name: /gateway settings|网关设置/i })).toBeTruthy()
    expect(isConnectingShown()).toBe(false)
  })
})
