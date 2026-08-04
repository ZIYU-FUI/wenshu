/**
 * WENSHU (wenshu) desktop plugin — single plain-JS ESM file, no build.
 * Theme values come from Hermes' var(--ui-*) tokens; JSX syntax is not used.
 */

import {
  Button,
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
import { useState } from 'react'
import { jsx, jsxs } from 'react/jsx-runtime'

const ID = 'wenshu'
const PATH = '/wenshu'
const PROJECT_PATH = PATH + '/project/'

const STRINGS = {
  en: {
    title: 'WENSHU',
    prompt: '你想写什么故事?在这里简述,WENSHU 会引导你展开。',
    newProject: '新建项目',
    paletteLabel: '启动 WENSHU',
    paletteTip: '打开 WENSHU 启动页'
  },
  zh: {
    title: 'WENSHU',
    prompt: '你想写什么故事?在这里简述,WENSHU 会引导你展开。',
    newProject: '新建项目',
    paletteLabel: '启动 WENSHU',
    paletteTip: '打开 WENSHU 启动页'
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
      className: 'max-w-lg',
      children: [
        jsxs(DialogHeader, {
          children: [
            jsx(DialogTitle, { children: '新建项目' }),
            jsx(DialogDescription, {
              children:
                '为项目命名,并指定一个项目文件夹,WENSHU 会将所有产出自动存储在你指定的文件夹下。'
            })
          ]
        }),
        jsxs('div', {
          className: 'flex flex-col gap-4 py-2',
          children: [
            jsxs('label', {
              className: 'flex flex-col gap-2 text-sm font-medium text-foreground',
              children: [
                jsx('span', { children: '项目名' }),
                jsx(Input, {
                  value: name,
                  placeholder: '为项目命名',
                  onChange: event => setName(event.target.value),
                  autoFocus: true
                })
              ]
            }),
            jsxs('label', {
              className: 'flex flex-col gap-2 text-sm font-medium text-foreground',
              children: [
                jsx('span', { children: '故事简介' }),
                jsx(Textarea, {
                  value: summary,
                  placeholder: '用一两句话描述你的故事,WENSHU 会基于此引导你展开',
                  onChange: event => setSummary(event.target.value),
                  rows: 4
                })
              ]
            }),
            jsxs('div', {
              className: 'flex flex-col gap-2',
              children: [
                jsx('label', {
                  htmlFor: 'wenshu-project-location',
                  className: 'text-sm font-medium text-foreground',
                  children: '项目位置'
                }),
                jsx('p', {
                  className: 'text-xs text-(--ui-text-tertiary)',
                  children: '指定项目位置'
                }),
                jsxs('div', {
                  className: 'flex items-center gap-2',
                  children: [
                    jsx(Input, {
                      id: 'wenshu-project-location',
                      value: targetDir,
                      placeholder: '粘贴绝对路径',
                      onChange: event => setTargetDir(event.target.value),
                      className: 'min-w-0 flex-1'
                    }),
                    jsx(Button, {
                      type: 'button',
                      variant: 'outline',
                      onClick: browse,
                      children: '选择...'
                    })
                  ]
                }),
                cleanTargetDir
                  ? jsx('p', {
                      className: 'break-all text-xs text-(--ui-text-secondary)',
                      children: '已选择:' + cleanTargetDir
                    })
                  : null,
                jsx('p', {
                  className: 'text-xs text-(--ui-text-tertiary)',
                  children:
                    'WENSHU 将在该位置创建 ' + (cleanName || '<项目名>') + '/ 文件夹'
                })
              ]
            })
          ]
        }),
        jsxs(DialogFooter, {
          children: [
            jsx(Button, {
              type: 'button',
              variant: 'outline',
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

function Launch({ ctx }) {
  const profile = useValue(host.state.profile)
  const blocked = profile !== 'wenshu'
  const [dialogOpen, setDialogOpen] = useState(false)

  return jsxs('div', {
    className: 'flex h-full w-full flex-col text-foreground',
    children: [
      blocked
        ? jsx('div', {
            className:
              'mx-8 mt-10 rounded-md border border-(--ui-diff-remove-border) ' +
              'bg-(--ui-diff-remove-background) px-4 py-3 text-center ' +
              'text-sm font-medium text-(--ui-diff-remove-foreground)',
            role: 'alert',
            children: '当前角色 ≠ wenshu,请在左侧栏切换到 wenshu 后再使用'
          })
        : null,
      jsxs('div', {
        className: 'flex flex-1 flex-col items-center justify-center gap-6 px-8 py-10',
        children: [
          jsx('h1', {
            className: 'text-5xl font-semibold tracking-wide text-foreground select-none',
            children: 'WENSHU'
          }),
          jsx('p', {
            className: 'max-w-md text-center text-sm text-(--ui-text-secondary)',
            children: '你想写什么故事?在这里简述,WENSHU 会引导你展开。'
          }),
          jsx(Button, {
            type: 'button',
            disabled: blocked,
            onClick: () => setDialogOpen(true),
            children: '新建项目'
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
    className: 'flex h-full w-full flex-col items-center justify-center gap-5 px-8 py-10 text-foreground',
    children: [
      jsx('h1', {
        className: 'text-3xl font-semibold tracking-wide text-foreground',
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
  name: 'WENSHU',
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
      title: 'WENSHU',
      data: {
        placement: 'main',
        dock: { pane: 'workspace', pos: 'center' }
      },
      render: function () { return jsx(Launch, { ctx }) }
    })

    ctx.register({
      id: 'nav',
      area: SIDEBAR_NAV_AREA,
      data: { path: PATH, label: 'WENSHU', codicon: 'book' }
    })

    ctx.register({
      id: 'palette-launch',
      area: PALETTE_AREA,
      data: {
        id: 'wenshu.launch',
        label: '启动 WENSHU',
        tip: '打开 WENSHU 启动页',
        keywords: ['wenshu', 'WENSHU', '文枢', '写作', '启动'],
        run: function () { host.navigate(PATH) }
      }
    })
  }
}
