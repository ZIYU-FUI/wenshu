/**
 * WENSHU (wenshu) desktop plugin.
 *
 * Hermes desktop plugin — single plain-JS ESM file, no build.
 * Loaded from ~/.hermes/desktop-plugins/wenshu/plugin.js by the desktop app
 * (this file is the source of truth in ~/wenshu-plugin/, rsynced to the
 * runtime location by scripts/install.sh).
 *
 * ONLY imports that resolve: @hermes/plugin-sdk, react, react/jsx-runtime.
 * UI is written with jsx() calls (NOT JSX syntax) because the file is loaded
 * uncompiled. Theme vars only — never hardcode colors.
 *
 * AGENTS.md v0.2 §1 / §5 / §12 is the source of truth for boundaries:
 *   - id: 'wenshu' (folder name must match)
 *   - name: 'WENSHU' (UI display, uppercase)
 *   - plugin sits inside the hermes SDK — never forks / patches / rewrites it
 */

import {
  host,
  PALETTE_AREA,
  ROUTES_AREA,
  SIDEBAR_NAV_AREA
} from '@hermes/plugin-sdk'
import { jsx, jsxs } from 'react/jsx-runtime'

const ID = 'wenshu'
const PATH = '/wenshu'

// ---------- Locale bundles (plugin-scoped, never edit core en.ts) ----------

const STRINGS = {
  en: {
    title: 'WENSHU',
    subtitle: '搜素材、起草、磨稿、出稿…',
    prompt: '你想写什么故事?在这里简述,WENSHU 会引导你展开。',
    newProject: '新建项目',
    paletteLabel: 'Launch WENSHU',
    paletteTip: 'Open the WENSHU launch page'
  },
  zh: {
    title: 'WENSHU',
    subtitle: '搜素材、起草、磨稿、出稿…',
    prompt: '你想写什么故事?在这里简述,WENSHU 会引导你展开。',
    newProject: '新建项目',
    paletteLabel: '启动 WENSHU',
    paletteTip: '打开 WENSHU 启动页'
  }
}

// ---------- Launch page (startup) ----------
//
// 占主工作区:panes area + placement main + dock center on workspace.
// 装机 user 7/29 拍的核心入口 = "新建项目" 按钮(纯 UI 占位,行为后续工单接
// /projects POST)。

function Launch() {
  return jsxs('div', {
    className: 'flex h-full w-full flex-col items-center justify-center gap-6 px-8 py-10 text-foreground',
    children: [
      jsx('h1', {
        className:
          'text-5xl font-semibold tracking-wide text-foreground select-none',
        children: 'WENSHU'
      }),
      jsx('p', {
        className: 'text-base text-(--ui-text-secondary)',
        children: '搜素材、起草、磨稿、出稿…'
      }),
      jsx('p', {
        className:
          'max-w-md text-center text-sm text-(--ui-text-quaternary)',
        children:
          '你想写什么故事?在这里简述,WENSHU 会引导你展开。'
      }),
      jsx('div', {
        className: 'flex w-full max-w-md flex-col gap-3 pt-2',
        children: jsx('button', {
          type: 'button',
          className:
            'inline-flex h-10 items-center justify-center rounded-md border border-(--ui-stroke-secondary) ' +
            'bg-(--ui-accent) px-4 text-sm font-medium text-(--ui-accent-foreground) ' +
            'transition-colors hover:opacity-90',
          onClick: () => {
            // 占位:后续工单接 plugins/wenshu/dashboard/plugin_api.py /projects POST
            host.notify({
              kind: 'info',
              message: '新建项目(占位 · 后续工单接 backend)'
            })
          },
          children: '新建项目'
        })
      }),
      jsxs('div', {
        className: 'grid w-full max-w-md grid-cols-2 gap-3 pt-4',
        children: [
          jsx(SelectPlaceholder, {
            label: '文风',
            options: [
              { value: 'default', label: '默认' },
              { value: 'qian', label: '钱钟书' },
              { value: 'lu', label: '鲁迅' },
              { value: 'jin', label: '金河仁' },
              { value: 'custom', label: '自定义' }
            ]
          }),
          jsx(SelectPlaceholder, {
            label: '方法论',
            options: [
              { value: 'snowflake', label: '雪花法' },
              { value: 'three-act', label: '三幕' },
              { value: 'qi-cheng-zhuan-he', label: '起承转合' }
            ]
          })
        ]
      })
    ]
  })
}

// 下拉占位:用原生 <select> 而非 SDK Select*(SDK 完整 surface 后续工单再换)
// — 主题色仍走 var(--ui-*)。
function SelectPlaceholder({ label, options }) {
  return jsxs('label', {
    className: 'flex flex-col gap-1 text-left text-xs text-(--ui-text-tertiary)',
    children: [
      jsx('span', { children: label }),
      jsx('select', {
        defaultValue: options[0] && options[0].value,
        className:
          'h-9 rounded-md border border-(--ui-stroke-secondary) bg-(--ui-input) ' +
          'px-2 text-sm text-foreground focus:outline-none focus:ring-1 focus:ring-(--ui-accent)',
        children: options.map(function (o) {
          return jsx('option', { value: o.value, children: o.label }, o.value)
        })
      })
    ]
  })
}

// ---------- Sidebar nav row (auto-rendered by app from data.path) ----------
//
// nav.row form:只要给 data: { path, label, codicon },框架自动渲染 nav row,
// 点击行为由 path 路由决定(SIDEBAR_NAV_AREA 自带导航,不用再写 onClick)。

// ---------- Default export ----------

export default {
  id: ID, // must match folder name
  name: 'WENSHU',
  register(ctx) {
    // Plugin-scoped locale bundles.
    ctx.i18n.register(STRINGS)

    // 1) 全页启动页 — ROUTES_AREA + data.path="/wenshu"。
    //    这是装机 user 拍板 (b) 的核心:启动页变成 full page(占主工作区
    //    workspace pane),不是浮动 pane。同一份 Launch 组件,不重复写 UI。
    ctx.register({
      id: 'launch',
      area: ROUTES_AREA,
      data: { path: PATH },
      render: function () { return jsx(Launch, {}) }
    })

    // 2) Panes area 也注册一份(走同样的 Launch 组件)— 让 panes 拖动 / 复用
    //    时仍用同一份 UI,装机 user 可以把 WENSHU 当 pane 拖到任意位置。
    ctx.register({
      id: 'launch-pane',
      area: 'panes',
      title: 'WENSHU',
      data: {
        placement: 'main',
        dock: { pane: 'workspace', pos: 'center' }
      },
      render: function () { return jsx(Launch, {}) }
    })

    // 3) 侧栏入口 — SIDEBAR_NAV_AREA nav.row(data.path 决定点亮 + 导航,
    //    点击自动 host.navigate(PATH))。
    ctx.register({
      id: 'nav',
      area: SIDEBAR_NAV_AREA,
      data: { path: PATH, label: 'WENSHU', codicon: 'book' }
    })

    // 4) ⌘K 调色板:"启动 WENSHU" → host.navigate('/wenshu') 闭环。
    ctx.register({
      id: 'palette-launch',
      area: PALETTE_AREA,
      data: {
        id: 'wenshu.launch',
        label: '启动 WENSHU',
        tip: '打开 WENSHU 启动页',
        keywords: ['wenshu', '写作', '启动', '文枢'],
        run: function () { host.navigate(PATH) }
      }
    })
  }
}
