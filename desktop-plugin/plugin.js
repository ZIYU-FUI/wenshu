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

const STRINGS = {
  en: {
    title: '文枢',
    prompt: 'Drop a line — wenshu will sketch a plot, beat out scenes, and draft prose.',
    newProject: 'New project',
    paletteLabel: 'Launch wenshu',
    paletteTip: 'Open the wenshu launch page',
    // 8/4 装机 user 第二轮拍:这个 slogan 区(Launch 页副文案)要做
    // 成 fade 轮播。8/4 装机 user 第五轮拍:全量放,不用分所谓角色设定。
    // 当前 locale active 时取对应数组。
    slogans: [
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
    ]
  },
  zh: {
    title: '文枢',
    prompt: '说一句你想写的事,文枢 会带你拼大纲、磨场景、出稿子。',
    newProject: '新建项目',
    paletteLabel: '启动 文枢',
    paletteTip: '打开 文枢 启动页',
    slogans: [
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
}

function errorMessage(error) {
  return error && error.message ? error.message : String(error || '未知错误')
}

function selectedDirectory(result) {
  if (typeof result === 'string') return result.trim()
  if (Array.isArray(result)) return String(result[0] || '').trim()
  if (result && typeof result === 'object') {
    if (result.canceled) return ''
    if (typeof result.dir === 'string') return result.dir.trim()
    if (typeof result.path === 'string') return result.path.trim()
    if (Array.isArray(result.filePaths)) return String(result.filePaths[0] || '').trim()
    if (Array.isArray(result.paths)) return String(result.paths[0] || '').trim()
  }
  return ''
}

async function pickDirectory() {
  // The public desktop-plugin SDK currently exposes no native picker helper.
  // Try the requested gateway RPC names; callers keep the editable Input as the
  // documented fallback when the connected Hermes gateway does not expose one.
  const attempts = [
    ['desktop.dialog.openDirectory', { title: '指定项目位置' }],
    ['desktop.dialog.selectPaths', {
      title: '指定项目位置',
      directories: true,
      multiple: false
    }]
  ]
  let lastError = null
  for (const attempt of attempts) {
    try {
      const path = selectedDirectory(await host.request(attempt[0], attempt[1]))
      if (path) return path
      return ''
    } catch (error) {
      lastError = error
    }
  }
  throw lastError || new Error('当前 Hermes 未暴露文件夹选择 API')
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
      host.notify({
        kind: 'info',
        message: '原生文件夹选择不可用,请粘贴绝对路径。' + errorMessage(error)
      })
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
      host.notify({ kind: 'error', message: '创建项目失败:' + errorMessage(error) })
    } finally {
      setSubmitting(false)
    }
  }

  return jsx(Dialog, {
    open,
    onOpenChange,
    children: jsxs(DialogContent, {
      className: 'max-w-md',
      onInteractOutside: event => event.preventDefault(),
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
        jsx(Input, {
          value: name,
          placeholder: '项目名',
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
        }),
        jsxs('div', {
          className: 'flex flex-col gap-1.5',
          children: [
            jsx('span', {
              className: 'text-[0.6875rem] font-medium text-(--ui-text-tertiary)',
              children: '项目位置'
            }),
            jsxs('div', {
              className: 'flex items-center gap-2',
              children: [
                jsx(Codicon, {
                  className: 'shrink-0 text-(--ui-text-tertiary)',
                  name: 'folder',
                  size: '0.75rem'
                }),
                jsx(Input, {
                  id: 'wenshu-project-location',
                  value: targetDir,
                  placeholder: '粘贴绝对路径',
                  disabled: submitting,
                  onChange: event => setTargetDir(event.target.value),
                  className:
                    'min-w-0 flex-1 border-(--ui-stroke-tertiary) ' +
                    'focus-visible:border-(--ui-stroke-secondary)'
                }),
                jsxs(Button, {
                  type: 'button',
                  variant: 'ghost',
                  size: 'sm',
                  disabled: submitting,
                  onClick: browse,
                  className:
                    'shrink-0 text-(--ui-text-tertiary) hover:bg-(--ui-control-hover-background)',
                  children: [
                    jsx(Codicon, { name: 'folder-opened', size: '0.75rem' }),
                    '选择...'
                  ]
                })
              ]
            }),
            jsx('span', {
              className: 'text-[0.75rem] text-(--ui-text-quaternary)',
              children:
                '将在该位置创建 ' + (cleanName || '<项目名>') + '/ 文件夹'
            })
          ]
        }),
        jsxs('div', {
          className: 'flex flex-col gap-1.5',
          children: [
            jsx('span', {
              className: 'text-[0.6875rem] font-medium text-(--ui-text-tertiary)',
              children: '故事简介'
            }),
            jsx(Textarea, {
              value: summary,
              placeholder: '用一两句话描述你的故事,文枢 会基于此引导你展开',
              disabled: submitting,
              onChange: event => setSummary(event.target.value),
              className:
                'min-h-20 border-(--ui-stroke-tertiary) text-[0.8125rem] ' +
                'focus-visible:border-(--ui-stroke-secondary)'
            }),
            jsx('span', {
              className: 'text-[0.75rem] text-(--ui-text-quaternary)',
              children: '可以稍后继续补充和修改。'
            })
          ]
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
//   - locale-aware:locale 切换时(STRINGS swap)从 index 0 重启
//   - 10 条 slogan × 2 locale(全量放,不区分角色)
//
// 实现:useState + useEffect + chain setTimeout(不用 reel-text.js
// / grapheme.js / measure.js / install.sh inline-concat —— 整套
// 4 文件架构撤掉,plugin.js 单文件直 rsync)。
function RotatingSlogan() {
  function currentLocale() {
    if (typeof document === 'undefined') return 'zh'
    var lang = document.documentElement && document.documentElement.lang
    return lang && STRINGS[lang] ? lang : 'zh'
  }

  function pickSlogans() {
    var loc = currentLocale()
    var s = (STRINGS[loc] && STRINGS[loc].slogans) || STRINGS.zh.slogans
    return s
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
// red bg + red foreground)。中央 helper 让以后所有 banner / callout /
// inline alert 复用同一基类 + tone。
//
// PM-direct 真值:
//   - rounded-xl  圆角同 hermes dialog / chip 的 border-radius token
//   - border      1px 同 hermes info container
//   - px-4 py-3   内边距同 about-settings 的 statusbox
//   - text-sm     字号同 about-settings
//   - flex items-center gap-3 内部 alignment 多 icon 时不用再加 className
//   - 3 个 tone:'error' (red) | 'warn' (orange/yellow) | 'info' (neutral)
//     当前只用 'error',同装机 user 8/4 红框要求
var ALERT_BASE_CLASSNAME =
  'flex items-center gap-3 rounded-xl border px-4 py-3 text-sm'

var ALERT_TONES = {
  error:
    'border-(--ui-diff-remove-border) bg-(--ui-diff-remove-background) text-(--ui-diff-remove-foreground)',
  warn:
    'border-(--ui-orange)/60 bg-(--ui-orange)/10 text-(--ui-orange)',
  info:
    'border-(--ui-stroke-secondary) bg-(--ui-bg-elevated) text-(--ui-text-primary)'
}

function alertClassName(tone, extra) {
  var t = ALERT_TONES[tone] || ALERT_TONES.info
  return (ALERT_BASE_CLASSNAME + ' ' + t + (extra ? ' ' + extra : '')).trim()
}

function Launch({ ctx }) {
  const profile = useValue(host.state.profile)
  const blocked = profile !== 'wenshu'
  const [dialogOpen, setDialogOpen] = useState(false)

  return jsxs('div', {
    className: 'flex h-full w-full flex-col text-(--ui-text-primary)',
    children: [
      blocked
        ? jsx('div', {
            // 8/4 装机 user 第三轮拍:"红框的样式复用 hermes info box
            // 那个(about-settings.tsx:113),改个颜色就行"。用上方
            // alertClassName('error') 复用 base,rounded-xl / px-4
            // py-3 / text-sm 完全沿用 hermes。banner 居顶距离由外层
            // flex column 的 mt-10 把控(8/4 第二轮拍保留)。
            className: 'mx-8 mt-10 ' + alertClassName('error'),
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
                // 本文件尾定义)。轮播副本以数组形式放在 STRINGS 内,
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
    ctx.i18n.register(STRINGS)

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
