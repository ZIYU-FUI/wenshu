import type { Translations } from './languages'

/*
 * Chinese (zh-CN) installer strings.
 *
 * `steps` holds the 10 high-level step labels used by the progress screen.
 * The PowerShell-side stage names (uv, repository, venv, ...) are mapped
 * to these labels in routes/progress.tsx via STAGE_TO_STEP_KEY, so we keep
 * the keys stable even when the install script adds new stages.
 */

export const zh: Translations = {
  steps: {
    Prerequisites: '系统环境检查',
    Repository: '拉取文枢源码',
    Venv: '创建 Python 虚拟环境',
    'Python deps': '安装 Python 依赖',
    'Node deps': '安装 Node 依赖',
    Path: '配置命令行入口',
    Config: '准备配置和技能',
    Setup: '配置 API 密钥和设置',
    Gateway: '配置网关服务',
    Complete: '完成安装'
  }
}
