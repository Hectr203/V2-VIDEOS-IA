import { useEffect, useRef, useState } from 'react'
import type { OverlayPosition } from '../lib/types.ts'
import type { ClipState, OverlayState, TrackState } from '../state.ts'
import { clipAt, clipOutOffsetAt, clipOutSeconds, formatTime, trackOutSeconds, trackSourceTimeAt } from '../state.ts'
import { keepIntervals } from '../lib/graph.ts'

/** Posición CSS de una capa dentro del cuadro del video (margen 3%) */
function overlayStyle(o: OverlayState): React.CSSProperties {
  const p: OverlayPosition = o.position
  const st: React.CSSProperties = { position: 'absolute', width: `${o.scale * 100}%`, zIndex: 2, borderRadius: 4 }
  const transforms: string[] = []
  if (p.endsWith('left')) st.left = '3%'
  else if (p.endsWith('right')) st.right = '3%'
  else {
    st.left = '50%'
    transforms.push('translateX(-50%)')
  }
  if (p.startsWith('top')) st.top = '3%'
  else if (p.startsWith('bottom')) st.bottom = '3%'
  else {
    st.top = '50%'
    transforms.push('translateY(-50%)')
  }
  if (transforms.length) st.transform = transforms.join(' ')
  return st
}

interface Props {
  clip: ClipState | null
  clips: ClipState[]
  voice: TrackState | null
  music: TrackState | null
  overlays: OverlayState[]
  /** Clip bajo el cursor del timeline + tiempo fuente equivalente */
  scrub: { clip: ClipState; index: number; src: number } | null
  playhead: number
  onPlayhead: (t: number) => void
  onClipChange: (id: string, patch: Partial<ClipState>) => void
  /** App registra aquí el control de reproducción (barra espaciadora) */
  playerRef: React.MutableRefObject<{ toggle: () => void } | null>
}

export function PreviewPane({ clip, clips, voice, music, overlays, scrub, playhead, onPlayhead, onClipChange, playerRef }: Props) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const voiceRef = useRef<HTMLAudioElement>(null)
  const musicRef = useRef<HTMLAudioElement>(null)
  const [seq, setSeq] = useState<number | null>(null) // índice del clip sonando al reproducir la timeline
  const [audioOnly, setAudioOnly] = useState(false) // reproduciendo solo voz/música (sin clips)
  const audioCleanups = useRef<Array<() => void>>([])
  const overlayRefs = useRef(new Map<string, HTMLVideoElement>())
  const wrapRef = useRef<HTMLDivElement>(null)
  // cuadro exacto donde se dibuja el video dentro del área (para posicionar las capas)
  const [frame, setFrame] = useState<{ left: number; top: number; width: number; height: number } | null>(null)

  const measureFrame = () => {
    const v = videoRef.current
    if (!v || v.offsetWidth === 0) {
      setFrame(null)
      return
    }
    setFrame({ left: v.offsetLeft, top: v.offsetTop, width: v.offsetWidth, height: v.offsetHeight })
  }

  const [time, setTime] = useState(0)
  const startSrcRef = useRef<{ index: number; src: number } | null>(null)

  const active = seq != null ? (clips[seq] ?? null) : (scrub?.clip ?? clip)

  useEffect(() => {
    measureFrame()
    const ro = new ResizeObserver(measureFrame)
    if (videoRef.current) ro.observe(videoRef.current)
    if (wrapRef.current) ro.observe(wrapRef.current)
    return () => ro.disconnect()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [active?.id])

  // el cursor del timeline manda cuando no se está reproduciendo
  useEffect(() => {
    const v = videoRef.current
    if (v && seq == null && scrub && active?.id === scrub.clip.id) {
      v.currentTime = scrub.src
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [scrub?.clip.id, scrub?.src])

  // capas: visibles y sincronizadas con el cursor; en reproducción corren solas
  useEffect(() => {
    for (const o of overlays) {
      const el = overlayRefs.current.get(o.id)
      if (!el) continue
      const visible = playhead >= o.start && playhead < o.end
      if (!visible) {
        el.pause()
        continue
      }
      const t = o.trimIn + (playhead - o.start)
      if (seq != null) {
        if (el.paused) {
          el.currentTime = t
          el.play().catch(() => {})
        }
      } else {
        el.pause()
        if (Math.abs(el.currentTime - t) > 0.05) el.currentTime = t
      }
    }
    if (seq == null) return
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [playhead, seq, overlays])

  const stopAll = () => {
    setSeq(null)
    setAudioOnly(false)
    startSrcRef.current = null
    for (const clean of audioCleanups.current) clean()
    audioCleanups.current = []
    videoRef.current?.pause()
    voiceRef.current?.pause()
    musicRef.current?.pause()
  }

  /** Arranca una pista saltándose sus cortes; si es la guía, mueve el cursor y detiene al final */
  const startTrack = (el: HTMLAudioElement, track: TrackState, fromOut: number, driver: boolean): boolean => {
    const kept = keepIntervals(track.trimIn, track.trimOut ?? track.duration, track.cuts)
    const src = trackSourceTimeAt(track, fromOut)
    if (kept.length === 0 || src == null) return false
    el.currentTime = src
    el.volume = Math.min(1, track.volume)
    const outAt = (t: number) => {
      let out = 0
      for (const [a, b] of kept) {
        if (t <= a) break
        out += Math.min(t, b) - a
        if (t <= b) break
      }
      return out
    }
    const onTime = () => {
      const t = el.currentTime
      const inside = kept.some(([a, b]) => t >= a - 0.05 && t < b)
      if (!inside) {
        const next = kept.find(([a]) => a > t)
        if (next) {
          el.currentTime = next[0]
        } else {
          el.pause()
          if (driver) stopAll()
        }
        return
      }
      if (driver) onPlayhead(outAt(t))
    }
    const onEnded = () => {
      if (driver) stopAll()
    }
    el.addEventListener('timeupdate', onTime)
    el.addEventListener('ended', onEnded)
    audioCleanups.current.push(() => {
      el.removeEventListener('timeupdate', onTime)
      el.removeEventListener('ended', onEnded)
    })
    el.play().catch(() => {})
    return true
  }

  /** Reproduce el segmento del clip `c` (desde startSrc si se indica), saltando cortes */
  const playClip = (c: ClipState, onEnd: () => void, startSrc?: number) => {
    const v = videoRef.current
    if (!v) return
    const cuts = [...(c.cuts ?? [])].sort((a, b) => a.from - b.from)
    v.playbackRate = c.speed
    v.muted = !c.keepAudio
    v.volume = Math.min(1, c.audioVolume)
    v.currentTime = startSrc ?? c.trimIn
    const onTime = () => {
      const t = v.currentTime
      const cut = cuts.find((x) => t >= x.from && t < x.to)
      if (cut) {
        v.currentTime = cut.to
        return
      }
      if (t >= (c.trimOut || c.duration)) {
        v.removeEventListener('timeupdate', onTime)
        v.pause()
        onEnd()
      }
    }
    v.addEventListener('timeupdate', onTime)
    v.play().catch(() => {}) // pausa inmediata: no es error
  }

  useEffect(() => {
    if (seq == null) {
      voiceRef.current?.pause()
      musicRef.current?.pause()
      return
    }
    const c = clips[seq]
    if (!c || !c.url) {
      setSeq(null)
      return
    }
    const start = startSrcRef.current?.index === seq ? startSrcRef.current.src : undefined
    startSrcRef.current = null
    const id = requestAnimationFrame(() => {
      playClip(c, () => setSeq((s) => (s != null && s + 1 < clips.length ? s + 1 : null)), start)
    })
    return () => cancelAnimationFrame(id)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [seq])

  /** Arranca voz y música en el punto del timeline T (mejor esfuerzo) */
  const startAudioAt = (T: number) => {
    for (const [ref, track] of [
      [voiceRef, voice],
      [musicRef, music],
    ] as const) {
      const el = ref.current
      if (!el || !track) continue
      const src = trackSourceTimeAt(track, T)
      if (src == null) continue // la pista ya terminó antes de este punto
      el.currentTime = src
      el.volume = Math.min(1, track.volume)
      el.play().catch(() => {})
    }
  }

  const playAll = () => {
    if (clips.some((c) => !c.url)) return
    if (clips.length > 0) {
      stopAll()
      const total = clips.reduce((s, c) => s + clipOutSeconds(c), 0)
      const from = playhead >= total - 0.05 ? 0 : playhead // cursor al final → desde el inicio
      const hit = clipAt(clips, from)
      if (hit) startSrcRef.current = { index: hit.index, src: hit.src }
      startAudioAt(from)
      setSeq(hit?.index ?? 0)
      return
    }
    // sin clips: reproducir solo la voz/música con sus cortes aplicados
    const total = Math.max(trackOutSeconds(voice), trackOutSeconds(music))
    if (total <= 0) return
    stopAll()
    const from = playhead >= total - 0.05 ? 0 : playhead
    let hasDriver = false
    for (const [ref, track] of [
      [voiceRef, voice],
      [musicRef, music],
    ] as const) {
      const el = ref.current
      if (!el || !track?.url) continue
      const started = startTrack(el, track, from, !hasDriver)
      if (started) hasDriver = true
    }
    if (hasDriver) setAudioOnly(true)
  }

  playerRef.current = { toggle: () => (seq != null ? stopAll() : playAll()) }

  const playSegment = () => {
    const target = active
    if (!target?.url) return
    stopAll()
    playClip(target, () => {})
  }

  const handleTimeUpdate = (t: number) => {
    setTime(t)
    if (seq != null && active) {
      const base = clips.slice(0, seq).reduce((s, c) => s + clipOutSeconds(c), 0)
      onPlayhead(base + clipOutOffsetAt(active, t))
    }
  }

  const segDuration = active ? clipOutSeconds(active) : 0

  return (
    <section className="preview-pane">
      <div className="preview-stage">
        {active?.url ? (
          <div className="preview-wrap" ref={wrapRef}>
          <video
            key={active.id}
            ref={videoRef}
            src={active.url}
            className="preview-video"
            playsInline
            preload="metadata"
            onClick={seq == null ? playAll : stopAll}
            onTimeUpdate={(e) => handleTimeUpdate(e.currentTarget.currentTime)}
            onLoadedMetadata={(e) => {
              const v = e.currentTarget
              measureFrame()
              if (seq == null && active.duration === 0) {
                onClipChange(active.id, {
                  duration: v.duration,
                  width: v.videoWidth,
                  height: v.videoHeight,
                  trimOut: active.trimOut > 0 ? Math.min(active.trimOut, v.duration) : v.duration,
                })
              } else if (seq == null && scrub && active.id === scrub.clip.id) {
                v.currentTime = scrub.src
              }
            }}
          />
          {frame && (
            <div className="preview-frame" style={frame}>
              {overlays.map((o) =>
                o.url ? (
                  <video
                    key={o.id}
                    muted
                    playsInline
                    preload="metadata"
                    src={o.url}
                    ref={(el) => {
                      if (el) overlayRefs.current.set(o.id, el)
                      else overlayRefs.current.delete(o.id)
                    }}
                    style={{
                      ...overlayStyle(o),
                      display: playhead >= o.start && playhead < o.end ? 'block' : 'none',
                    }}
                  />
                ) : null,
              )}
            </div>
          )}
          </div>
        ) : (
          <div className="preview-empty">
            {clips.length === 0 && (voice?.url || music?.url)
              ? `🎧 Proyecto de solo audio — dale ▶ para escuchar ${voice?.url ? 'la voz' : 'la música'} ya con sus cortes aplicados`
              : clips.length === 0
                ? 'Agrega archivos y mándalos a la línea de tiempo'
                : 'Mueve el cursor en la línea de tiempo o selecciona un clip'}
          </div>
        )}
      </div>
      <div className="preview-controls">
        {seq == null && !audioOnly ? (
          <button
            className="primary"
            onClick={playAll}
            disabled={(clips.length === 0 && !voice?.url && !music?.url) || clips.some((c) => !c.url)}
            title="Reproduce desde el cursor rojo (con solo audio también funciona)"
          >
            ▶ Reproducir
          </button>
        ) : (
          <button className="primary" onClick={stopAll}>■ Detener</button>
        )}
        <button onClick={playSegment} disabled={!active?.url || seq != null} title="Reproduce solo el clip actual">
          ▶ Clip
        </button>
        <span className="preview-time">
          {formatTime(seq != null || audioOnly ? playhead : time)}
          {active && seq == null ? ` · clip: ${formatTime(segDuration)}` : ''}
          {seq != null ? ` · clip ${seq + 1}/${clips.length}` : ''}
        </span>
      </div>
      {voice?.url && <audio ref={voiceRef} src={voice.url} preload="auto" />}
      {music?.url && <audio ref={musicRef} src={music.url} preload="auto" />}
    </section>
  )
}
