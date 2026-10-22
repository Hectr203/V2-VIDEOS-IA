import { useState } from 'react'
import type { Manifest, OutputFormat } from '../lib/types.ts'
import { ManifestHelp } from './ManifestHelp.tsx'
import { inputFiles } from '../lib/graph.ts'
import { renderInBrowser, downloadBlob } from '../lib/wasm.ts'
import type { ClipState, OverlayState, TrackState } from '../state.ts'
import { buildManifest } from '../state.ts'

interface Props {
  name: string
  onName: (v: string) => void
  outputs: OutputFormat[]
  onOutputs: (v: OutputFormat[]) => void
  clips: ClipState[]
  voice: TrackState | null
  music: TrackState | null
  overlays: OverlayState[]
  missing: string[]
  onLoadManifest: (m: Manifest) => void
}

export function TopBar({ name, onName, outputs, onOutputs, clips, voice, music, overlays, missing, onLoadManifest }: Props) {
  const [busy, setBusy] = useState(false)
  const [status, setStatus] = useState('')
  const [ratio, setRatio] = useState(0)
  const [error, setError] = useState('')
  const [showHelp, setShowHelp] = useState(false)

  const manifest = () => buildManifest(name, clips, voice, music, overlays, outputs)

  const toggleFormat = (f: OutputFormat) =>
    onOutputs(outputs.includes(f) ? outputs.filter((x) => x !== f) : [...outputs, f])

  const downloadManifest = () => {
    const m = manifest()
    downloadBlob(`${m.name}.json`, JSON.stringify(m, null, 2), 'application/json')
  }

  const exportInBrowser = async () => {
    setError('')
    setBusy(true)
    try {
      const m = manifest()
      if (m.clips.length === 0) throw new Error('Agrega al menos un clip a la línea de tiempo')
      if (m.outputs.length === 0) throw new Error('Selecciona al menos un formato de salida')
      const files = [
        ...clips.map((c) => c.media),
        ...(voice ? [voice.media] : []),
        ...(music ? [music.media] : []),
        ...overlays.map((o) => o.media),
      ]
      if (files.some((f) => !f)) throw new Error('Faltan archivos por asignar')
      if (inputFiles(m).length !== files.length) throw new Error('Estado inconsistente de archivos')
      setStatus('Cargando ffmpeg…')
      for (const format of m.outputs) {
        setStatus(`Renderizando ${format}…`)
        setRatio(0)
        const { name: outName, data } = await renderInBrowser(m, files as File[], format, setRatio)
        downloadBlob(outName, data.slice())
      }
      setStatus('Listo — revisa tus descargas')
    } catch (err) {
      setStatus('')
      setError(
        `${err instanceof Error ? err.message : String(err)}. ` +
          'Si el problema persiste o el material es pesado, descarga el manifiesto y renderiza con el CLI.',
      )
    } finally {
      setBusy(false)
    }
  }

  const loadManifestFile = (file: File) => {
    file
      .text()
      .then((text) => {
        const m = JSON.parse(text) as Manifest
        if (!Array.isArray(m.clips)) throw new Error('El JSON no parece un manifiesto (falta "clips")')
        onLoadManifest(m)
        setError('')
        setStatus(`Manifiesto "${m.name}" cargado`)
      })
      .catch((err) => setError(`No se pudo cargar el manifiesto: ${err.message}`))
  }

  return (
    <header className="topbar">
      <div className="topbar-row">
        <span className="logo">🎬 Video Assembler</span>
        <input
          className="project-name"
          type="text"
          value={name}
          onChange={(e) => onName(e.target.value)}
          placeholder="nombre-del-proyecto"
          title="Nombre del proyecto"
        />
        <div className="format-toggles">
          <label className="check" title="Vertical 1080×1920">
            <input type="checkbox" checked={outputs.includes('vertical')} onChange={() => toggleFormat('vertical')} />
            9:16
          </label>
          <label className="check" title="Horizontal 1920×1080">
            <input type="checkbox" checked={outputs.includes('horizontal')} onChange={() => toggleFormat('horizontal')} />
            16:9
          </label>
        </div>
        <div className="topbar-actions">
          <button className="help-btn" onClick={() => setShowHelp(true)} title="¿Qué es el manifiesto?">
            ?
          </button>
          <label className="btn">
            Abrir manifiesto…
            <input
              type="file"
              accept="application/json,.json"
              disabled={busy}
              onChange={(e) => {
                const f = e.target.files?.[0]
                if (f) loadManifestFile(f)
                e.target.value = ''
              }}
            />
          </label>
          <button onClick={downloadManifest} disabled={clips.length === 0}>
            Guardar manifiesto
          </button>
          <button
            className="primary"
            onClick={exportInBrowser}
            disabled={busy || clips.length === 0 || missing.length > 0}
            title={missing.length > 0 ? `Faltan archivos: ${missing.join(', ')}` : 'Renderizar en el navegador'}
          >
            {busy ? 'Renderizando…' : 'Exportar'}
          </button>
        </div>
      </div>
      {busy && (
        <div className="progress">
          <div className="progress-bar" style={{ width: `${Math.round(ratio * 100)}%` }} />
        </div>
      )}
      {(status || error) && (
        <div className="topbar-status">
          {status && <span className="status">{status}</span>}
          {error && <span className="error">{error}</span>}
        </div>
      )}
      {showHelp && <ManifestHelp onClose={() => setShowHelp(false)} />}
    </header>
  )
}
