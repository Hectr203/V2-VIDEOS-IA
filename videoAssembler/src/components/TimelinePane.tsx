import { useRef } from 'react'
import type { ClipState, OverlayState, Selection, TrackState } from '../state.ts'
import { baseName, clipOutSeconds, formatTime, trackSegments } from '../state.ts'

interface Props {
  clips: ClipState[]
  voice: TrackState | null
  music: TrackState | null
  overlays: OverlayState[]
  selection: Selection
  playhead: number
  totalDuration: number
  totalMB: number
  onSelect: (sel: Selection) => void
  onMove: (from: number, to: number) => void
  onScrub: (time: number) => void
  onOverlayDragBegin: () => void
  onOverlayMove: (id: string, start: number) => void
}

function rulerStep(total: number): number {
  if (total <= 15) return 1
  if (total <= 60) return 5
  if (total <= 180) return 10
  if (total <= 600) return 30
  return 60
}

export function TimelinePane({
  clips,
  voice,
  music,
  overlays,
  selection,
  playhead,
  totalDuration,
  totalMB,
  onSelect,
  onMove,
  onScrub,
  onOverlayDragBegin,
  onOverlayMove,
}: Props) {
  const dragFrom = useRef<number | null>(null)
  const bodyRef = useRef<HTMLDivElement>(null)

  const total = Math.max(totalDuration, 0.001)
  const pct = (secs: number) => `${(secs / total) * 100}%`

  const timeAtEvent = (clientX: number): number => {
    const rect = bodyRef.current?.getBoundingClientRect()
    if (!rect || rect.width === 0) return 0
    return Math.min(total, Math.max(0, ((clientX - rect.left) / rect.width) * total))
  }

  const scrubFrom = (e: React.PointerEvent, drag: boolean) => {
    onScrub(timeAtEvent(e.clientX))
    if (!drag) return
    const move = (ev: PointerEvent) => onScrub(timeAtEvent(ev.clientX))
    const up = () => {
      window.removeEventListener('pointermove', move)
      window.removeEventListener('pointerup', up)
    }
    window.addEventListener('pointermove', move)
    window.addEventListener('pointerup', up)
  }

  const ticks: number[] = []
  if (totalDuration > 0) {
    const step = rulerStep(totalDuration)
    for (let t = 0; t <= totalDuration; t += step) ticks.push(t)
  }

  const audioTrack = (kind: 'voice' | 'music', track: TrackState | null, label: string, icon: string) => (
    <div className="tl-track tl-audio-track">
      {!track ? (
        <span className="tl-empty">Sin {label.toLowerCase()} — asígnala desde «Archivos»</span>
      ) : (
        trackSegments(track).map((seg, i) => {
          const selected = selection?.type === kind && selection.segment === i
          return (
            <div
              key={`${seg.from}-${seg.to}`}
              className={`tl-block tl-block-audio${selected ? ' selected' : ''}${track.media ? '' : ' tl-missing'}`}
              style={{ width: pct(seg.to - seg.from) }}
              onClick={() => onSelect({ type: kind, segment: i })}
              title={`${track.file} · ${formatTime(seg.from)} → ${formatTime(seg.to)}`}
            >
              <span className="tl-block-name">{icon} {baseName(track.file)}</span>
              <span className="tl-block-meta">{formatTime(seg.to - seg.from)}</span>
            </div>
          )
        })
      )}
    </div>
  )

  return (
    <section className="timeline">
      <div className="tl-head">
        <h2>Línea de tiempo</h2>
        <span className="tl-stats">
          {clips.length} clip{clips.length === 1 ? '' : 's'} · total {formatTime(totalDuration)}
          {totalMB > 0 && ` · ${totalMB} MB`}
        </span>
        <span className="tl-keys">
          clic = cursor · <kbd>espacio</kbd> = play/pausa · <kbd>S</kbd> = cortar · <kbd>⌫</kbd> = borrar ·{' '}
          <kbd>←→</kbd> = afinar cursor (Shift = 1s) · <kbd>⌘Z</kbd> = deshacer
        </span>
      </div>

      <div className="tl-body" ref={bodyRef} onPointerDown={(e) => scrubFrom(e, false)}>
        <div className="tl-ruler" onPointerDown={(e) => { e.stopPropagation(); scrubFrom(e, true) }}>
          {ticks.map((t) => (
            <span key={t} className="tl-tick" style={{ left: pct(t) }}>
              {formatTime(t).replace(/\.\d$/, '')}
            </span>
          ))}
        </div>

        {overlays.length > 0 && (
          <div className="tl-track tl-overlay-track">
            {overlays.map((o) => {
              const selected = selection?.type === 'overlay' && selection.id === o.id
              const dur = o.end - o.start
              return (
                <div
                  key={o.id}
                  className={`tl-block tl-block-overlay${selected ? ' selected' : ''}${o.media ? '' : ' tl-missing'}`}
                  style={{ left: pct(o.start), width: pct(dur) }}
                  onClick={(e) => {
                    e.stopPropagation()
                    onSelect({ type: 'overlay', id: o.id })
                  }}
                  onPointerDown={(e) => {
                    // arrastre horizontal: mueve la capa en el tiempo
                    e.stopPropagation()
                    onSelect({ type: 'overlay', id: o.id })
                    const rect = bodyRef.current?.getBoundingClientRect()
                    if (!rect || rect.width === 0) return
                    const startX = e.clientX
                    const origStart = o.start
                    let moved = false
                    const move = (ev: PointerEvent) => {
                      const dt = ((ev.clientX - startX) / rect.width) * total
                      if (!moved && Math.abs(ev.clientX - startX) > 3) {
                        moved = true
                        onOverlayDragBegin()
                      }
                      if (moved) {
                        const ns = Math.min(Math.max(0, origStart + dt), Math.max(0, total - dur))
                        onOverlayMove(o.id, Math.round(ns * 10) / 10)
                      }
                    }
                    const up = () => {
                      window.removeEventListener('pointermove', move)
                      window.removeEventListener('pointerup', up)
                    }
                    window.addEventListener('pointermove', move)
                    window.addEventListener('pointerup', up)
                  }}
                  title={`${o.file} · capa ${formatTime(o.start)} → ${formatTime(o.end)} — arrastra para mover`}
                >
                  <span className="tl-block-name">◱ {baseName(o.file)}</span>
                  <span className="tl-block-meta">{dur.toFixed(1)}s · {Math.round(o.scale * 100)}%</span>
                </div>
              )
            })}
          </div>
        )}

        <div className="tl-track tl-video-track">
          {clips.length === 0 && <span className="tl-empty">Manda clips aquí desde «Archivos» con «+ Timeline»</span>}
          {clips.map((c, i) => {
            const secs = clipOutSeconds(c)
            const selected = selection?.type === 'clip' && selection.id === c.id
            return (
              <div
                key={c.id}
                className={`tl-block${selected ? ' selected' : ''}${c.media ? '' : ' tl-missing'}`}
                style={{ width: pct(secs) }}
                draggable
                onClick={() => onSelect({ type: 'clip', id: c.id })}
                onDragStart={() => {
                  dragFrom.current = i
                  onSelect({ type: 'clip', id: c.id })
                }}
                onDragOver={(e) => {
                  e.preventDefault()
                  const from = dragFrom.current
                  if (from != null && from !== i) {
                    onMove(from, i)
                    dragFrom.current = i
                  }
                }}
                onDragEnd={() => {
                  dragFrom.current = null
                }}
                title={`${c.file} — arrastra para reordenar`}
              >
                <span className="tl-block-name">{i + 1}. {baseName(c.file)}</span>
                <span className="tl-block-meta">
                  {formatTime(secs)}
                  {c.speed !== 1 && ` · ×${c.speed.toFixed(2).replace(/\.?0+$/, '')}`}
                  {(c.cuts?.length ?? 0) > 0 && ` · ✂${c.cuts.length}`}
                  {c.keepAudio && ' · 🔊'}
                </span>
              </div>
            )
          })}
        </div>

        {audioTrack('voice', voice, 'Voz', '🎙')}
        {audioTrack('music', music, 'Música', '🎵')}

        {totalDuration > 0 && (
          <div className="tl-playhead" style={{ left: pct(playhead) }}>
            <div className="tl-playhead-cap" />
          </div>
        )}
      </div>
    </section>
  )
}
