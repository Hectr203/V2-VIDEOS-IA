import { useEffect, useRef, useState } from 'react'
import type { Manifest, OutputFormat } from './lib/types.ts'
import { keepIntervals } from './lib/graph.ts'
import type { BinItem, ClipState, OverlayState, Selection, TrackState } from './state.ts'
import {
  baseName,
  binPlaceholder,
  buildManifest,
  clipAt,
  clipFromBin,
  clipFromSpec,
  clipOutSeconds,
  isAudioFile,
  newId,
  overlayFromBin,
  overlayFromSpec,
  probeMedia,
  trackFromBin,
  trackFromSpec,
  trackOutSeconds,
  trackSegments,
} from './state.ts'
import type { DirHandle } from './lib/mediaFolder.ts'
import {
  findFilesByName,
  folderPermission,
  loadFolderHandle,
  pickFolder,
  requestFolderPermission,
  saveFolderHandle,
  supportsFolders,
} from './lib/mediaFolder.ts'
import { TopBar } from './components/TopBar.tsx'
import { MediaBin } from './components/MediaBin.tsx'
import { PreviewPane } from './components/PreviewPane.tsx'
import { Inspector } from './components/Inspector.tsx'
import { TimelinePane } from './components/TimelinePane.tsx'

export default function App() {
  const [name, setName] = useState('mi-video')
  const [bin, setBin] = useState<BinItem[]>([])
  const [clips, setClips] = useState<ClipState[]>([])
  const [voice, setVoice] = useState<TrackState | null>(null)
  const [music, setMusic] = useState<TrackState | null>(null)
  const [overlays, setOverlays] = useState<OverlayState[]>([])
  const [outputs, setOutputs] = useState<OutputFormat[]>(['vertical'])
  const [selection, setSelection] = useState<Selection>(null)
  const [playhead, setPlayhead] = useState(0)
  const [restored, setRestored] = useState(false)
  const [dragOver, setDragOver] = useState(false)
  const [dropError, setDropError] = useState('')
  const [folder, setFolder] = useState<DirHandle | null>(null)
  const [folderPrompt, setFolderPrompt] = useState(false)
  const folderRef = useRef<DirHandle | null>(null)
  folderRef.current = folder

  // instantánea para los atajos de teclado (el listener vive fuera del ciclo de render)
  const snap = useRef({ clips, voice, music, overlays, selection, playhead })
  snap.current = { clips, voice, music, overlays, selection, playhead }

  // ---- deshacer ----

  interface HistoryEntry {
    clips: ClipState[]
    voice: TrackState | null
    music: TrackState | null
    overlays: OverlayState[]
    selection: Selection
  }
  const history = useRef<HistoryEntry[]>([])

  /** Guarda el estado actual antes de una operación destructiva */
  const pushHistory = () => {
    const { clips, voice, music, overlays, selection } = snap.current
    history.current.push({ clips, voice, music, overlays, selection })
    if (history.current.length > 50) history.current.shift()
  }

  const undo = () => {
    const prev = history.current.pop()
    if (!prev) return
    setClips(prev.clips)
    setVoice(prev.voice)
    setMusic(prev.music)
    setOverlays(prev.overlays)
    setSelection(prev.selection)
  }

  // controles del preview, registrados por PreviewPane (para la barra espaciadora)
  const playerRef = useRef<{ toggle: () => void } | null>(null)

  // ---- biblioteca de archivos ----

  const addFiles = (list: FileList | File[] | null) => {
    if (!list || list.length === 0) return
    const prepared = Array.from(list).map((file) => ({
      file,
      url: URL.createObjectURL(file),
      kind: (isAudioFile(file) ? 'audio' : 'video') as 'audio' | 'video',
    }))

    setBin((prev) => {
      const next = [...prev]
      for (const p of prepared) {
        const idx = next.findIndex((b) => !b.media && b.name === p.file.name)
        if (idx >= 0) next[idx] = { ...next[idx], media: p.file, url: p.url, kind: p.kind }
        else next.push({ id: newId(), name: p.file.name, media: p.file, url: p.url, kind: p.kind, duration: 0, width: 0, height: 0 })
      }
      return next
    })
    setClips((prev) =>
      prev.map((c) => {
        if (c.media) return c
        const p = prepared.find((p) => baseName(c.file) === p.file.name)
        return p ? { ...c, media: p.file, url: p.url } : c
      }),
    )
    const fillTrack = (t: TrackState | null) => {
      if (!t || t.media) return t
      const p = prepared.find((p) => baseName(t.file) === p.file.name)
      return p ? { ...t, media: p.file, url: p.url } : t
    }
    setVoice(fillTrack)
    setMusic(fillTrack)
    setOverlays((prev) =>
      prev.map((o) => {
        if (o.media) return o
        const p = prepared.find((p) => baseName(o.file) === p.file.name)
        return p ? { ...o, media: p.file, url: p.url } : o
      }),
    )

    for (const p of prepared) {
      void probeMedia(p.url, p.kind).then((meta) => {
        if (meta.duration <= 0) return
        setBin((prev) => prev.map((b) => (b.url === p.url ? { ...b, ...meta } : b)))
        setClips((prev) =>
          prev.map((c) =>
            c.url === p.url && c.duration === 0
              ? { ...c, ...meta, trimOut: c.trimOut > 0 ? Math.min(c.trimOut, meta.duration) : meta.duration }
              : c,
          ),
        )
        const fillDur = (t: TrackState | null) =>
          t && t.url === p.url && t.duration === 0 ? { ...t, duration: meta.duration } : t
        setVoice(fillDur)
        setMusic(fillDur)
        setOverlays((prev) =>
          prev.map((o) => (o.url === p.url && o.duration === 0 ? { ...o, duration: meta.duration } : o)),
        )
      })
    }
  }

  /** Nombres de archivo que el proyecto necesita y aún no tienen File asignado */
  const missingNames = (): string[] => {
    const { clips, voice, music, overlays } = snap.current
    return [
      ...clips.filter((c) => !c.media).map((c) => baseName(c.file)),
      ...(voice && !voice.media ? [baseName(voice.file)] : []),
      ...(music && !music.media ? [baseName(music.file)] : []),
      ...overlays.filter((o) => !o.media).map((o) => baseName(o.file)),
    ].filter((v, i, arr) => arr.indexOf(v) === i)
  }

  const resolving = useRef(false)

  /** Busca en la carpeta conectada los archivos faltantes y los carga solos */
  const resolveFromFolder = async (names?: string[]) => {
    const handle = folderRef.current
    if (!handle || resolving.current) return
    const wanted = names ?? missingNames()
    if (wanted.length === 0) return
    resolving.current = true
    try {
      if ((await folderPermission(handle)) !== 'granted') {
        setFolderPrompt(true)
        return
      }
      const files = await findFilesByName(handle, wanted)
      if (files.length > 0) addFiles(files)
      setFolderPrompt(false)
    } finally {
      resolving.current = false
    }
  }

  const connectFolder = async () => {
    const handle = await pickFolder()
    if (!handle) return
    await saveFolderHandle(handle)
    setFolder(handle)
    setFolderPrompt(false)
    void resolveFromFolder()
  }

  // al arrancar, recupera la carpeta conectada en sesiones anteriores
  useEffect(() => {
    void loadFolderHandle().then((h) => h && setFolder(h))
  }, [])

  // drag & drop sobre toda la ventana: manifiesto .json o archivos de medios
  const dropHandlers = useRef<{ loadManifest: (m: Manifest) => void; addFiles: (f: File[]) => void } | null>(null)

  useEffect(() => {
    let depth = 0
    const hasFiles = (e: DragEvent) => e.dataTransfer?.types.includes('Files') ?? false
    const onDragEnter = (e: DragEvent) => {
      if (!hasFiles(e)) return
      depth++
      setDragOver(true)
    }
    const onDragOver = (e: DragEvent) => {
      if (hasFiles(e)) e.preventDefault()
    }
    const onDragLeave = (e: DragEvent) => {
      if (!hasFiles(e)) return
      depth = Math.max(0, depth - 1)
      if (depth === 0) setDragOver(false)
    }
    const onDrop = (e: DragEvent) => {
      if (!hasFiles(e)) return
      e.preventDefault()
      depth = 0
      setDragOver(false)
      const files = Array.from(e.dataTransfer?.files ?? [])
      if (files.length === 0) return
      setDropError('')
      const manifestFile = files.find((f) => f.name.toLowerCase().endsWith('.json'))
      const media = files.filter((f) => !f.name.toLowerCase().endsWith('.json'))
      if (manifestFile) {
        void manifestFile.text().then((text) => {
          try {
            const m = JSON.parse(text) as Manifest
            if (!Array.isArray(m.clips)) throw new Error('falta "clips"')
            dropHandlers.current?.loadManifest(m)
          } catch (err) {
            setDropError(`El JSON soltado no parece un manifiesto (${err instanceof Error ? err.message : err})`)
          }
        })
      }
      if (media.length > 0) dropHandlers.current?.addFiles(media)
    }
    window.addEventListener('dragenter', onDragEnter)
    window.addEventListener('dragover', onDragOver)
    window.addEventListener('dragleave', onDragLeave)
    window.addEventListener('drop', onDrop)
    return () => {
      window.removeEventListener('dragenter', onDragEnter)
      window.removeEventListener('dragover', onDragOver)
      window.removeEventListener('dragleave', onDragLeave)
      window.removeEventListener('drop', onDrop)
    }
  }, [])

  const removeBinItem = (item: BinItem) => {
    pushHistory()
    setBin((prev) => prev.filter((b) => b.id !== item.id))
    setClips((prev) => prev.filter((c) => !(item.url ? c.url === item.url : baseName(c.file) === item.name)))
    const clearTrack = (t: TrackState | null) =>
      t && (item.url ? t.url === item.url : baseName(t.file) === item.name) ? null : t
    setVoice(clearTrack)
    setMusic(clearTrack)
    setOverlays((prev) => prev.filter((o) => !(item.url ? o.url === item.url : baseName(o.file) === item.name)))
    setSelection(null)
    if (item.url) URL.revokeObjectURL(item.url)
  }

  // ---- línea de tiempo ----

  const addToTimeline = (item: BinItem) => {
    pushHistory()
    const c = clipFromBin(item)
    setClips((prev) => [...prev, c])
    setSelection({ type: 'clip', id: c.id })
  }

  const assignVoice = (item: BinItem) => {
    pushHistory()
    setVoice(trackFromBin(item, voice?.volume ?? 1))
    setSelection({ type: 'voice', segment: 0 })
  }

  const assignMusic = (item: BinItem) => {
    pushHistory()
    setMusic(trackFromBin(item, music?.volume ?? 0.15))
    setSelection({ type: 'music', segment: 0 })
  }

  const addOverlay = (item: BinItem) => {
    pushHistory()
    const o = overlayFromBin(item, snap.current.playhead)
    setOverlays((prev) => [...prev, o])
    setSelection({ type: 'overlay', id: o.id })
  }

  const updateOverlay = (id: string, patch: Partial<OverlayState>) =>
    setOverlays((prev) => prev.map((o) => (o.id === id ? { ...o, ...patch } : o)))

  const removeOverlay = (id: string) => {
    pushHistory()
    setOverlays((prev) => prev.filter((o) => o.id !== id))
    setSelection(null)
  }

  const updateClip = (id: string, patch: Partial<ClipState>) =>
    setClips((prev) => prev.map((c) => (c.id === id ? { ...c, ...patch } : c)))

  const removeClip = (id: string) => {
    pushHistory()
    setClips((prev) => prev.filter((c) => c.id !== id))
    setSelection(null)
  }

  const duplicateClip = (id: string) => {
    pushHistory()
    setClips((prev) => {
      const i = prev.findIndex((c) => c.id === id)
      if (i < 0) return prev
      const copy = { ...prev[i], id: newId() }
      return [...prev.slice(0, i + 1), copy, ...prev.slice(i + 1)]
    })
  }

  const moveClip = (from: number, to: number) =>
    setClips((prev) => {
      if (to < 0 || to >= prev.length || from === to) return prev
      const next = [...prev]
      const [item] = next.splice(from, 1)
      next.splice(to, 0, item)
      return next
    })

  // ---- cortar (S) y borrar (⌫) ----

  const splitAtPlayhead = () => {
    const { clips, voice, music, selection, playhead } = snap.current
    pushHistory()

    if (selection?.type === 'voice' || selection?.type === 'music') {
      const track = selection.type === 'voice' ? voice : music
      if (!track || track.duration === 0) return
      const setTrack = selection.type === 'voice' ? setVoice : setMusic
      // el playhead es tiempo global; la pista corre desde 0 → mapear a tiempo del archivo
      let remaining = playhead
      let src: number | null = null
      for (const [a, b] of keepIntervals(track.trimIn, track.trimOut ?? track.duration, track.cuts)) {
        const len = b - a
        if (remaining <= len) {
          src = a + remaining
          break
        }
        remaining -= len
      }
      if (src == null) return
      const rounded = Math.round(src * 1000) / 1000
      setTrack((t) =>
        t ? { ...t, splits: [...new Set([...(t.splits ?? []), rounded])].sort((a, b) => a - b) } : t,
      )
      return
    }

    // sin selección de pista → corta el clip de video bajo el cursor
    const hit = clipAt(clips, playhead)
    if (!hit) return
    const { clip, index, src } = hit
    const margin = 0.05
    if (src <= clip.trimIn + margin || src >= (clip.trimOut || clip.duration) - margin) return
    const first: ClipState = { ...clip, trimOut: src }
    const second: ClipState = { ...clip, id: newId(), trimIn: src }
    setClips((prev) => [...prev.slice(0, index), first, second, ...prev.slice(index + 1)])
    setSelection({ type: 'clip', id: second.id })
  }

  const deleteSelected = () => {
    const { voice, music, selection } = snap.current
    if (!selection) return
    if (selection.type !== 'clip') pushHistory() // el camino de clip ya la guarda en removeClip
    if (selection.type === 'clip') {
      removeClip(selection.id)
      return
    }
    if (selection.type === 'overlay') {
      removeOverlay(selection.id)
      return
    }
    const track = selection.type === 'voice' ? voice : music
    const setTrack = selection.type === 'voice' ? setVoice : setMusic
    if (!track || selection.segment == null) return
    const segments = trackSegments(track)
    const seg = segments[selection.segment]
    if (!seg) return
    if (segments.length === 1) {
      setTrack(null)
    } else {
      setTrack((t) =>
        t
          ? {
              ...t,
              cuts: [...t.cuts, { from: seg.from, to: seg.to }],
              splits: (t.splits ?? []).filter((s) => s <= seg.from || s >= seg.to),
            }
          : t,
      )
    }
    setSelection(null)
  }

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const tgt = e.target as HTMLElement
      if (tgt.tagName === 'INPUT' || tgt.tagName === 'TEXTAREA' || tgt.isContentEditable) return
      if (document.querySelector('.modal-overlay')) return // no editar con un modal abierto
      if ((e.metaKey || e.ctrlKey) && (e.key === 'z' || e.key === 'Z')) {
        e.preventDefault()
        undo()
      } else if (e.key === 's' || e.key === 'S') {
        e.preventDefault()
        splitAtPlayhead()
      } else if (e.key === 'Delete' || e.key === 'Backspace') {
        e.preventDefault()
        deleteSelected()
      } else if (e.key === ' ') {
        e.preventDefault()
        playerRef.current?.toggle()
      } else if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
        e.preventDefault()
        const step = (e.shiftKey ? 1 : 0.1) * (e.key === 'ArrowLeft' ? -1 : 1)
        const { clips, voice, music } = snap.current
        const clipsTotal = clips.reduce((s, c) => s + clipOutSeconds(c), 0)
        const total = clipsTotal > 0 ? clipsTotal : Math.max(trackOutSeconds(voice), trackOutSeconds(music))
        setPlayhead((p) => Math.min(total, Math.max(0, Math.round((p + step) * 10) / 10)))
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // ---- manifiesto ----

  const loadManifest = (m: Manifest) => {
    setName(m.name || 'mi-video')
    setOutputs(m.outputs?.length ? m.outputs : ['vertical'])

    const findLoaded = (ref: string) => bin.find((b) => b.media && b.name === baseName(ref))
    const refs: Array<{ name: string; kind: 'video' | 'audio' }> = m.clips.map((c) => ({
      name: baseName(c.file),
      kind: 'video',
    }))
    if (m.voice) refs.push({ name: baseName(m.voice.file), kind: 'audio' })
    if (m.music) refs.push({ name: baseName(m.music.file), kind: 'audio' })
    for (const o of m.overlays ?? []) refs.push({ name: baseName(o.file), kind: 'video' })
    setBin((prev) => {
      const next = [...prev]
      for (const r of refs) if (!next.some((b) => b.name === r.name)) next.push(binPlaceholder(r.name, r.kind))
      return next
    })

    setClips(
      m.clips.map((spec) => {
        const s = clipFromSpec(spec)
        const b = findLoaded(spec.file)
        return b
          ? {
              ...s,
              media: b.media,
              url: b.url,
              duration: b.duration,
              width: b.width,
              height: b.height,
              trimOut: s.trimOut > 0 ? s.trimOut : b.duration,
            }
          : s
      }),
    )
    const loadTrack = (spec: NonNullable<Manifest['voice']>) => {
      const t = trackFromSpec(spec)
      const b = findLoaded(spec.file)
      return b ? { ...t, media: b.media, url: b.url, duration: b.duration } : t
    }
    setVoice(m.voice ? loadTrack(m.voice) : null)
    setMusic(m.music ? loadTrack(m.music) : null)
    setOverlays(
      (m.overlays ?? []).map((spec) => {
        const o = overlayFromSpec(spec)
        const b = findLoaded(spec.file)
        return b ? { ...o, media: b.media, url: b.url, duration: b.duration } : o
      }),
    )
    setSelection(null)
    setPlayhead(0)
    // si hay carpeta conectada, carga los archivos referenciados sin intervención
    setTimeout(() => void resolveFromFolder(refs.map((r) => r.name)), 0)
  }

  // ---- autoguardado en el navegador ----

  const AUTOSAVE_KEY = 'videassembler-autosave'

  useEffect(() => {
    try {
      const raw = localStorage.getItem(AUTOSAVE_KEY)
      if (!raw) return
      const m = JSON.parse(raw) as Manifest
      if (Array.isArray(m.clips) && (m.clips.length > 0 || m.voice || m.music)) {
        loadManifest(m)
        setRestored(true)
      }
    } catch {
      localStorage.removeItem(AUTOSAVE_KEY)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    const id = setTimeout(() => {
      if (clips.length === 0 && !voice && !music && overlays.length === 0) localStorage.removeItem(AUTOSAVE_KEY)
      else localStorage.setItem(AUTOSAVE_KEY, JSON.stringify(buildManifest(name, clips, voice, music, overlays, outputs)))
    }, 400)
    return () => clearTimeout(id)
  }, [clips, voice, music, overlays, name, outputs])

  const resetProject = () => {
    localStorage.removeItem(AUTOSAVE_KEY)
    history.current = []
    setBin((prev) => {
      prev.forEach((b) => b.url && URL.revokeObjectURL(b.url))
      return []
    })
    setClips([])
    setVoice(null)
    setMusic(null)
    setOverlays([])
    setSelection(null)
    setPlayhead(0)
    setName('mi-video')
    setOutputs(['vertical'])
    setRestored(false)
  }

  dropHandlers.current = { loadManifest, addFiles }

  // ---- derivados ----

  const totalDuration = clips.reduce((s, c) => s + clipOutSeconds(c), 0)
  // sin clips, la timeline y el cursor viven sobre la duración de las pistas de audio
  const timelineTotal = totalDuration > 0 ? totalDuration : Math.max(trackOutSeconds(voice), trackOutSeconds(music))
  const totalBytes =
    clips.reduce((s, c) => s + (c.media?.size ?? 0), 0) +
    (voice?.media?.size ?? 0) +
    (music?.media?.size ?? 0) +
    overlays.reduce((s, o) => s + (o.media?.size ?? 0), 0)
  const totalMB = Math.round(totalBytes / (1024 * 1024))
  const has4k = clips.some((c) => Math.max(c.width, c.height) >= 2160)
  const missing = [
    ...clips.filter((c) => !c.media).map((c) => baseName(c.file)),
    ...(voice && !voice.media ? [baseName(voice.file)] : []),
    ...(music && !music.media ? [baseName(music.file)] : []),
    ...overlays.filter((o) => !o.media).map((o) => baseName(o.file)),
  ].filter((v, i, arr) => arr.indexOf(v) === i)

  // la carpeta puede conectarse después de restaurar el autosave: intenta resolver faltantes
  useEffect(() => {
    if (folder && missing.length > 0) void resolveFromFolder()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [folder, missing.length])

  const selClipIndex = selection?.type === 'clip' ? clips.findIndex((c) => c.id === selection.id) : -1
  const selClip = selClipIndex >= 0 ? clips[selClipIndex] : null
  const selOverlay = selection?.type === 'overlay' ? (overlays.find((o) => o.id === selection.id) ?? null) : null
  const scrub = clipAt(clips, playhead)

  return (
    <div className="editor">
      <TopBar
        name={name}
        onName={setName}
        outputs={outputs}
        onOutputs={setOutputs}
        clips={clips}
        voice={voice}
        music={music}
        overlays={overlays}
        missing={missing}
        onLoadManifest={loadManifest}
      />

      {folderPrompt && missing.length > 0 && folder && (
        <div className="banner banner-info">
          📂 Carpeta «{folder.name}» conectada — el navegador pide tu clic para leer los archivos.
          <button
            className="small primary"
            onClick={async () => {
              if (await requestFolderPermission(folder)) {
                setFolderPrompt(false)
                void resolveFromFolder()
              }
            }}
          >
            Cargar archivos
          </button>
        </div>
      )}
      {dragOver && (
        <div className="drop-overlay">📥 Suelta aquí tu manifiesto (.json) o archivos de video/audio</div>
      )}
      {dropError && (
        <div className="banner">
          ⚠ {dropError} <button className="small" onClick={() => setDropError('')}>✕</button>
        </div>
      )}
      {restored && (
        <div className="banner banner-info">
          💾 Proyecto recuperado del autoguardado — agrega los archivos en «Archivos» para reconectarlos.
          <button className="small" onClick={() => setRestored(false)}>Entendido</button>
          <button className="small danger" onClick={resetProject}>Empezar de cero</button>
        </div>
      )}
      {(missing.length > 0 || totalBytes > 800 * 1024 * 1024 || has4k) && (
        <div className="banner">
          {missing.length > 0 && <span>⚠ Faltan archivos: {missing.join(', ')} — agrégalos en «Archivos». </span>}
          {(totalBytes > 800 * 1024 * 1024 || has4k) && (
            <span>
              ⚠ {totalBytes > 800 * 1024 * 1024 ? `Material pesado (${totalMB} MB)` : 'Hay clips 4K'} — para exportar,
              mejor guarda el manifiesto y usa el CLI.
            </span>
          )}
        </div>
      )}

      <main className="workspace">
        <MediaBin
          items={bin}
          folderName={folder?.name ?? null}
          canConnectFolder={supportsFolders()}
          onConnectFolder={() => void connectFolder()}
          onAddFiles={addFiles}
          onAddToTimeline={addToTimeline}
          onAddOverlay={addOverlay}
          onAssignVoice={assignVoice}
          onAssignMusic={assignMusic}
          onRemove={removeBinItem}
        />
        <PreviewPane
          clip={selClip}
          clips={clips}
          voice={voice}
          music={music}
          overlays={overlays}
          scrub={scrub}
          playhead={playhead}
          onPlayhead={setPlayhead}
          onClipChange={updateClip}
          playerRef={playerRef}
        />
        {selClip ? (
          <Inspector
            kind="clip"
            clip={selClip}
            index={selClipIndex}
            count={clips.length}
            onChange={(patch) => updateClip(selClip.id, patch)}
            onRemove={() => removeClip(selClip.id)}
            onDuplicate={() => duplicateClip(selClip.id)}
            onMove={(dir) => moveClip(selClipIndex, selClipIndex + dir)}
          />
        ) : selOverlay ? (
          <Inspector
            kind="overlay"
            overlay={selOverlay}
            playhead={playhead}
            onChange={(patch) => updateOverlay(selOverlay.id, patch)}
            onRemove={() => removeOverlay(selOverlay.id)}
          />
        ) : selection?.type === 'voice' && voice ? (
          <Inspector
            kind="voice"
            track={voice}
            onChange={(patch) => setVoice((v) => (v ? { ...v, ...patch } : v))}
            onRemove={() => {
              setVoice(null)
              setSelection(null)
            }}
          />
        ) : selection?.type === 'music' && music ? (
          <Inspector
            kind="music"
            track={music}
            onChange={(patch) => setMusic((v) => (v ? { ...v, ...patch } : v))}
            onRemove={() => {
              setMusic(null)
              setSelection(null)
            }}
          />
        ) : (
          <Inspector kind="none" />
        )}
      </main>

      <TimelinePane
        clips={clips}
        voice={voice}
        music={music}
        overlays={overlays}
        selection={selection}
        playhead={playhead}
        totalDuration={timelineTotal}
        totalMB={totalMB}
        onSelect={setSelection}
        onMove={moveClip}
        onScrub={setPlayhead}
        onOverlayDragBegin={pushHistory}
        onOverlayMove={(id, start) => {
          const o = overlays.find((x) => x.id === id)
          if (o) updateOverlay(id, { start, end: start + (o.end - o.start) })
        }}
      />
    </div>
  )
}
