/**
 * 文枢 (wenshu) desktop plugin — single plain-JS ESM file, no build.
 * Theme values come from Hermes' var(--ui-*) tokens; JSX syntax is not used.
 */

import {
  Button,
  Codicon,
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  Input,
  PALETTE_AREA,
  ROUTES_AREA,
  SIDEBAR_NAV_AREA,
  Textarea,
  host,
  useValue
} from '@hermes/plugin-sdk'
import React, { useEffect, useRef, useState } from 'react'
import { jsx, jsxs } from 'react/jsx-runtime'

const ID = 'wenshu'
const PATH = '/wenshu'
const PROJECT_PATH = PATH + '/project/'

// 8/4 装机 user 第二轮拍:slogan 区(Launch 页副文案)打字机效果轮播。
// 8/4 装机 user 第五轮拍:全量放,不用分所谓角色设定。
// locale-aware:locale 切换时(SLOGANS swap)从 idx 0 重启。
//
// 当前结构只保留 slogans 数组 —— 之前装的 prompt / newProject /
// paletteLabel / paletteTip 字段是死字段(plugin 内没有 component 读,
// SDK i18n 也没必要 register,因为只内部查 slogans)。删掉死字段,
// 让 SLOGANS 真只为 RotatingSlogan 兜底。RotatingSlogan 不走 SDK
// usePluginI18n —— slogan 是数据不是 UI 文案,SDK 没暴露数组类型,
// 字面查表 + document.documentElement.lang 切换是合理最小实现。
const SLOGANS = {
  en: [
    'Drop a line — wenshu will sketch a plot, beat out scenes, and draft prose.',
    'Open a chapter and pick up where you left off.',
    'Feed wenshu a vague idea; it will pin down a structure.',
    'Outline by snowflake, three-act, or 起承转合 — whichever fits.',
    'Draft prose, then let proofread polish the rhythm.',
    'When the plot slips, pull up the chief editor and reset the seam.',
    'Spin a prompt into a synopsis; the eight editors hold the line.',
    'Stuck on dialogue? The dialogue editor sets the tone, the rhythm editor paces it.',
    'World feels thin? The lore editor drafts the rules, the setting editor pins them down.',
    'Save often — every turn is a checkpoint you can rewind to.'
  ],
  zh: [
    '说一句你想写的事,文枢 会带你拼大纲、磨场景、出稿子。',
    '翻开上一章,继续上次断的那段。',
    '把脑子里零散的想法扔进来,文枢 来给骨架。',
    '雪花法 / 三幕 / 起承转合——想怎么拆就怎么拆。',
    '先把草稿写满,再让校稿员把节奏磨顺。',
    '剧情跑偏时,叫总编出来拍一下这条缝。',
    '把一句话喂成梗概:八个编辑轮流给你接力。',
    '对话卡住?对话编辑定调子,节奏编辑控速度。',
    '世界单薄?设定编辑写规则,场景编辑落细节。',
    '记得常存:每一步都是可以倒带的检查点。'
  ]
}

async function pickDirectory() {
  // SDK 真值路径查 ~/.hermes/hermes-agent/apps/desktop/dist/electron-preload.js
  // 的 contextBridge.exposeInMainWorld('hermesDesktop', { selectPaths, … }),
  // 选项语义查 ~/.hermes/hermes-agent/apps/desktop/electron/main.ts:10472
  // ipcMain.handle('hermes:selectPaths') — options.title /
  // options.directories(true → 'openDirectory') / options.multiple(!==false
  // 时 push 'multiSelections') / options.filters(仅文件选择)。返回值是
  // Array<string> 文件绝对路径,空数组表示用户取消。
  //
  // 注意 host.request('desktop.dialog.selectPaths', ...) 是 ghost RPC:
  // hermes 把 host.request 转发到 gateway JSON-RPC,gateway 端没有
  // desktop.dialog.* handler,会直接抛 'unknown method'。plugin 不能用
  // host.request 调 desktop bridge —— 直接走 window.hermesDesktop。
  const desktop = typeof window === 'undefined' ? null : window.hermesDesktop
  if (!desktop || typeof desktop.selectPaths !== 'function') {
    throw new Error('Hermes Desktop bridge 不可用,无法弹原生文件夹选择对话框')
  }
  const paths = await desktop.selectPaths({
    title: '指定项目位置',
    directories: true,
    multiple: false
  })
  return Array.isArray(paths) && paths.length > 0 ? String(paths[0]).trim() : ''
}

// Dialog form field — label + optional hint, wrapping the input/textarea/select.
// SDK 不暴露 Field/FormLabel,kanban board.tsx:527 也是 plugin-local helper
// 同样的 <label> + <span> 结构(kanban 用同一份 className `FIELD_LABEL`)。
function Field({ label, hint, children }) {
  return jsxs('label', {
    className: 'flex flex-col gap-1',
    children: [
      jsx('span', {
        className:
          'text-[0.6875rem] font-medium text-(--ui-text-tertiary)',
        children: label
      }),
      children,
      hint
        ? jsx('span', {
            className: 'text-[0.75rem] text-(--ui-text-quaternary)',
            children: hint
          })
        : null
    ]
  })
}

function NewProjectDialog({ ctx, open, onOpenChange }) {
  const [name, setName] = useState('')
  const [summary, setSummary] = useState('')
  const [targetDir, setTargetDir] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const cleanName = name.trim()
  const cleanTargetDir = targetDir.trim()

  async function browse() {
    try {
      const path = await pickDirectory()
      if (path) setTargetDir(path)
    } catch (error) {
      host.notifyError(error, '原生文件夹选择失败,请粘贴绝对路径')
    }
  }

  async function create() {
    if (submitting) return
    if (!cleanName) {
      host.notify({ kind: 'error', message: '请填写项目名' })
      return
    }
    if (!cleanTargetDir) {
      host.notify({ kind: 'error', message: '请选择或粘贴项目位置' })
      return
    }

    setSubmitting(true)
    try {
      const result = await ctx.rest('/projects', {
        method: 'POST',
        body: {
          name: cleanName,
          summary: summary.trim(),
          target_dir: cleanTargetDir
        }
      })
      if (!result || (result.status !== 'created' && result.status !== 'exists')) {
        throw new Error('后端返回了无法识别的项目状态')
      }
      if (result.status === 'exists') {
        host.notify({
          kind: 'info',
          message: '项目 ' + cleanName + ' 已存在,已加载现有项目'
        })
      }
      onOpenChange(false)
      host.navigate(
        PROJECT_PATH + encodeURIComponent(cleanName) +
        '?summary=' + encodeURIComponent(
          result.status === 'exists'
            ? String(result.existing_summary || '')
            : summary.trim()
        )
      )
    } catch (error) {
      host.notifyError(error, '创建项目失败')
    } finally {
      setSubmitting(false)
    }
  }

  return jsx(Dialog, {
    open,
    onOpenChange,
    children: jsxs(DialogContent, {
      className: 'max-w-md',
      children: [
        jsxs(DialogHeader, {
          children: [
            jsx(DialogTitle, { children: '新建项目' }),
            jsx(DialogDescription, {
              children:
                '为项目命名并指定存储位置,文枢 会在所选位置创建项目文件夹。'
            })
          ]
        }),
        jsx(Field, { label: '项目名', children: jsx(Input, {
          value: name,
          placeholder: '为项目起个名字',
          disabled: submitting,
          onChange: event => setName(event.target.value),
          onKeyDown: event => {
            if (event.key === 'Enter') {
              event.preventDefault()
              void create()
            } else if (event.key === 'Escape') {
              onOpenChange(false)
            }
          },
          autoFocus: true
        }) }),
        jsx(Field, {
          label: '项目位置',
          hint: '将在该位置创建 ' + (cleanName || '<项目名>') + '/ 文件夹',
          children: jsxs('div', {
            className: 'flex items-center gap-2',
            children: [
              jsx(Input, {
                id: 'wenshu-project-location',
                value: targetDir,
                placeholder: '粘贴绝对路径',
                disabled: submitting,
                onChange: event => setTargetDir(event.target.value),
                className: 'min-w-0 flex-1'
              }),
              jsx(Button, {
                type: 'button',
                variant: 'ghost',
                size: 'sm',
                disabled: submitting,
                onClick: browse,
                children: jsx('span', { children: '选择...' })
              })
            ]
          })
        }),
        jsx(Field, {
          label: '故事简介',
          hint: '可以稍后继续补充和修改。',
          children: jsx(Textarea, {
            value: summary,
            placeholder: '用一两句话描述你的故事,文枢 会基于此引导你展开',
            disabled: submitting,
            onChange: event => setSummary(event.target.value),
            className: 'min-h-20'
          })
        }),
        jsxs(DialogFooter, {
          children: [
            jsx(Button, {
              type: 'button',
              variant: 'ghost',
              disabled: submitting,
              onClick: () => onOpenChange(false),
              children: '取消'
            }),
            jsx(Button, {
              type: 'button',
              disabled: submitting || !cleanName || !cleanTargetDir,
              onClick: create,
              children: submitting ? '创建中...' : '创建'
            })
          ]
        })
      ]
    })
  })
}

// ---------- Rotating slogan (打字机轮播) ----------
//
// 8/4 装机 user 第二轮拍:Launch 页 slogan 区要打字机效果轮播。
// 8/4 装机 user 第七轮拍:ReelText 1V1 复刻动画效果极差,撤掉整套
//   reel_text 翻译,改回最简单打字机 —— 字符串逐字追加 + 间隔 hold + 切下一条。
//
// 真值(8/4 装机 user 拍):
//   - 每条 slogan 循环:typing 38ms / 字 → holding 3800ms → erasing 22ms / 字
//     (erasing 把字逐个删,最后字保留 + holding,然后切下一条)
//   - locale-aware:locale 切换时(SLOGANS swap)从 index 0 重启
//   - 10 条 slogan × 2 locale(全量放,不区分角色)
//
// 实现:useState + useEffect + chain setTimeout(不用 reel-text.js
// / grapheme.js / measure.js / install.sh inline-concat —— 整套
// 4 文件架构撤掉,plugin.js 单文件直 rsync)。
function RotatingSlogan() {
  function currentLocale() {
    if (typeof document === 'undefined') return 'zh'
    var lang = document.documentElement && document.documentElement.lang
    return lang && SLOGANS[lang] ? lang : 'zh'
  }

  function pickSlogans() {
    var loc = currentLocale()
    return SLOGANS[loc] || SLOGANS.zh
  }

  // 三态:typing | holding | erasing
  var _phase = useState('typing')
  var phase = _phase[0]
  var setPhase = _phase[1]

  var _idx = useState(0)
  var idx = _idx[0]
  var setIdx = _idx[1]

  var _displayed = useState('')
  var displayed = _displayed[0]
  var setDisplayed = _displayed[1]

  var slogans = pickSlogans()
  var n = slogans.length

  // locale swap → 回到 idx 0
  useEffect(function () {
    setIdx(0)
    setDisplayed('')
    setPhase('typing')
  }, [slogans])

  // chain setTimeout 状态机
  useEffect(function () {
    var current = slogans[idx] || ''
    var timer
    if (phase === 'typing') {
      if (displayed.length < current.length) {
        timer = setTimeout(function () {
          setDisplayed(current.slice(0, displayed.length + 1))
        }, 38)
      } else {
        // 打完了 → 进入 holding 3800ms
        timer = setTimeout(function () { setPhase('erasing') }, 3800)
      }
    } else if (phase === 'erasing') {
      if (displayed.length > 0) {
        timer = setTimeout(function () {
          setDisplayed(current.slice(0, displayed.length - 1))
        }, 22)
      } else {
        // 删完了(留最后字也清了)→ 切下一条
        setIdx((idx + 1) % n)
        setPhase('typing')
      }
    }
    return function () { if (timer) clearTimeout(timer) }
  }, [phase, displayed, idx, slogans, n])

  return jsx('p', {
    className:
      'm-0 text-center leading-normal tracking-tight text-(--ui-text-secondary) min-h-[1.5em]',
    children: displayed + '\u200B' // zero-width space 保高度稳定(wenshu 大字不抖)
  })
}

// ---------- Alert tone helper (复用) ----------
//
// 8/4 装机 user 第三轮拍:红框的"字号、框大小、padding"完全复用 hermes
// 信息框样式 —— hermes 在 `app/settings/about-settings.tsx:113` 用
// `'rounded-xl border px-4 py-3 text-sm'` 作为 base,搭配 tone variant
// `border-destructive/35 bg-destructive/5 text-destructive`。Plugin
// 不能直接用 shadcn semantic token(border-destructive / bg-destructive),
// 改用 hermes 自带的 theme token `--ui-diff-remove-*`(red border +
// PM-direct 真值(同 hermes about-settings.tsx:113 的 inline 写法):
//   rounded-xl border px-4 py-3 text-sm,与 hermes 内置 info container 共享
//   字号 / 框大小 / padding;颜色走 plugin theme token --ui-diff-remove-*
//   (SDK 不暴露 Alert,Plugin 不能用 shadcn border-destructive/35 这类
//   semantic token)。inline 写不抽 helper,装机 user 拍 8/5「小体量,能用
//   SDK 的就复用」—— 自抽 ALERT_BASE_CLASSNAME / ALERT_TONES 反而多此一举。
function Launch({ ctx }) {
  const profile = useValue(host.state.profile)
  const blocked = profile !== 'wenshu'
  const [dialogOpen, setDialogOpen] = useState(false)

  return jsxs('div', {
    className: 'flex h-full w-full flex-col text-(--ui-text-primary)',
    children: [
      blocked
        ? jsx('div', {
            className:
              'mx-8 mt-10 rounded-xl border border-(--ui-diff-remove-border) ' +
              'bg-(--ui-diff-remove-background) ' +
              'text-(--ui-diff-remove-foreground) px-4 py-3 text-sm',
            role: 'alert',
            children: '当前角色 ≠ wenshu,请在左侧栏切换到 wenshu 后再使用'
          })
        : null,
      jsxs('div', {
        className:
          'flex min-h-0 flex-1 flex-col items-center justify-center px-0.5 py-12 ' +
          'text-center sm:px-6 lg:px-8',
        children: [
          jsxs('div', {
            className: 'w-full min-w-0',
            children: [
              jsxs('p', {
                'aria-label': 'wenshu',
                className:
                  "fit-text mx-auto mb-1 w-[calc(100%-1rem)] font-['Collapse'] " +
                  'font-bold uppercase leading-[0.9] tracking-[0.08em] text-midground ' +
                  'mix-blend-plus-lighter dark:text-foreground/90',
                // 8/4 装机 user 第二轮拍:HERMES AGENT 11 字符 vs wenshu 6
                // 字符,容器一样宽 → fit-text 把 wenshu 字号拉得偏胖。
                // fit-text 自带 --fit-min / --fit-max CSS 变量;封顶
                // 4.5rem(同 HERMES AGENT 实际渲染感),下限沿 hermes 2.75rem。
                // 不要在新加 inline fontSize clamp —— fit-text 自己会按 cqi
                // 在 min/max 之间缩放,加 inline 会盖过 fit-text 的 cqi 逻辑。
                style: {
                  '--fit-min': '2.75rem',
                  '--fit-max': '4.5rem'
                },
                children: [
                  jsx('span', {
                    children: jsx('span', { children: 'wenshu' })
                  }),
                  jsx('span', {
                    'aria-hidden': 'true',
                    children: 'wenshu'
                  })
                ]
              }),
              jsx('p', {
                // 8/4 装机 user 第二轮拍:这个 slogan 区要做成轮播(像是
                // hermes 启动的文字加载,但更明确要求是「fade 轮播」)。
                // 沿用 hermes intro 的 m-0 + text-center + leading-normal
                // + tracking-tight + text-(--ui-text-secondary) 样式不
                // 改 className;改 children 为 RotatingSlogan 组件(在
                // 本文件尾定义)。轮播副本以数组形式放在 SLOGANS 内,
                // 让 en/zh 各自有轮播词库 —— 不同 locale 轮播不同内容。
                className:
                  'm-0 text-center leading-normal tracking-tight text-(--ui-text-secondary)',
                children: jsx(RotatingSlogan, {})
              })
            ]
          }),
          jsx(Button, {
            type: 'button',
            variant: 'ghost',
            disabled: blocked,
            onClick: () => setDialogOpen(true),
            className:
              'mt-6 text-(--ui-text-tertiary) hover:bg-(--ui-control-hover-background) ' +
              'hover:text-(--ui-text-primary)',
            children: jsx('span', { children: '[ 新建项目 ]' })
          }),
          jsx(NewProjectDialog, {
            ctx,
            open: dialogOpen,
            onOpenChange: setDialogOpen
          })
        ]
      })
    ]
  })
}

function currentProjectName() {
  const hash = typeof window === 'undefined' ? '' : window.location.hash
  const marker = '#' + PROJECT_PATH
  const index = hash.indexOf(marker)
  if (index < 0) return '项目'
  const encoded = hash.slice(index + marker.length).split(/[/?#]/)[0]
  try {
    return decodeURIComponent(encoded) || '项目'
  } catch {
    return encoded || '项目'
  }
}

function ProjectPage() {
  const name = currentProjectName()
  let summary = ''
  try {
    const query = new URLSearchParams(window.location.hash.split('?')[1] || '')
    summary = query.get('summary') || ''
  } catch {
    summary = ''
  }
  return jsxs('div', {
    className: 'flex h-full w-full flex-col items-center justify-center gap-5 px-8 py-10 text-(--ui-text-primary)',
    children: [
      jsx('h1', {
        className: 'text-3xl font-semibold tracking-wide text-(--ui-text-primary)',
        children: name
      }),
      jsx('p', {
        className: 'max-w-xl text-center text-sm text-(--ui-text-secondary)',
        children: summary || '暂无故事简介'
      }),
      jsx(Button, {
        type: 'button',
        variant: 'outline',
        onClick: () => host.navigate(PATH),
        children: '回到首页'
      })
    ]
  })
}

export default {
  id: ID,
  name: '文枢',
  register(ctx) {
    // SDK i18n 不再 register —— slogan 是数据不是 UI 文案,字面查 SLOGANS
    // 已经够。若未来加用户可见 UI 文案(prompt / newProject / palette
    // label 等),改用 ctx.i18n.register + usePluginI18n('wenshu') + t('key')。

    ctx.register({
      id: 'launch',
      area: ROUTES_AREA,
      data: { path: PATH },
      render: function () { return jsx(Launch, { ctx }) }
    })

    ctx.register({
      id: 'project',
      area: ROUTES_AREA,
      data: { path: PROJECT_PATH + ':name' },
      render: function () { return jsx(ProjectPage, {}) }
    })

    ctx.register({
      id: 'launch-pane',
      area: 'panes',
      title: '文枢',
      data: {
        placement: 'main',
        dock: { pane: 'workspace', pos: 'center' }
      },
      render: function () { return jsx(Launch, { ctx }) }
    })

    ctx.register({
      id: 'nav',
      area: SIDEBAR_NAV_AREA,
      data: { path: PATH, label: '文枢', codicon: 'book' }
    })

    ctx.register({
      id: 'palette-launch',
      area: PALETTE_AREA,
      data: {
        id: 'wenshu.launch',
        label: '启动 文枢',
        tip: '打开 文枢 启动页',
        keywords: ['wenshu', '文枢', '写作', '启动'],
        run: function () { host.navigate(PATH) }
      }
    })
  }
}
