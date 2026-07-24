import { useStore } from '@nanostores/react'
import { FileText, RefreshCw } from 'lucide-react'
import { type CSSProperties } from 'react'

import { Button } from '../components/button'
import {
  $logPath,
  $mode,
  type BootstrapStateModel,
  openLogDir,
  startInstall,
  startUpdate
} from '../store'

interface FailureProps {
  bootstrap: BootstrapStateModel
}

/*
 * Failure screen. Same hero treatment as Welcome/Success — the wordmark
 * carries the brand, so we keep it across every terminal state.
 *
 * The actual error message lives below in muted text. Two affordances on
 * shared Button tokens: Retry (primary) and Open logs (quiet text link).
 */
export default function Failure({ bootstrap }: FailureProps) {
  const logPath = useStore($logPath)
  const mode = useStore($mode)
  const isUpdate = mode === 'update'

  return (
    <div className="hermes-fade-in flex h-full flex-col items-center justify-center gap-6 px-12 py-10">
      <div className="w-full max-w-2xl min-w-0 text-center">
        <p
          className="fit-text mx-auto mb-4 w-full font-['Collapse'] font-bold uppercase leading-[0.9] tracking-[0.08em] text-destructive mix-blend-plus-lighter dark:text-destructive/90"
          style={
            {
              '--fit-text-line-height': '0.9',
              '--fit-text-max': '5rem',
              '--fit-text-min': '2.25rem'
            } as CSSProperties
          }
        >
          <span>
            <span>{isUpdate ? '\u66f4\u65b0\u672a\u5b8c\u6210' : '\u5b89\u88c5\u672a\u5b8c\u6210'}</span>
          </span>
          <span aria-hidden="true">{isUpdate ? '\u66f4\u65b0\u672a\u5b8c\u6210' : '\u5b89\u88c5\u672a\u5b8c\u6210'}</span>
        </p>

        <p className="m-0 mx-auto max-w-xl text-center text-sm leading-normal tracking-tight text-muted-foreground">
          {bootstrap.error ??
            (isUpdate
              ? '更新过程中出现错误。'
              : '安装过程中出现错误。')}
        </p>
      </div>

      <div className="flex items-center gap-3">
        <Button className="gap-1.5" onClick={() => void (isUpdate ? startUpdate() : startInstall())}>
          <RefreshCw />
          {isUpdate ? '重试更新' : '重试安装'}
        </Button>
        <Button className="gap-1.5" onClick={() => void openLogDir()} variant="text">
          <FileText />
          打开日志
        </Button>
      </div>

      {logPath && (
        <p className="max-w-lg text-center text-xs text-muted-foreground/70">
          日志: <code className="font-mono">{logPath}</code>
        </p>
      )}
    </div>
  )
}
