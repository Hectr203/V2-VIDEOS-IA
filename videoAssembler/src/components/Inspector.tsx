import type { OverlayPosition } from '../lib/types.ts'
import type { ClipState, OverlayState, TrackState } from '../state.ts'
import { clipOutSeconds, formatTime } from '../state.ts'

const POSITIONS: OverlayPosition[] = [
  'top-left', 'top', 'top-right',
  'left', 'center', 'right',
  'bottom-left', 'bottom', 'bottom-right',
]

interface ClipProps {
  kind: 'clip'
  clip: ClipState
  index: number
  count: number
  onChange: (patch: Partial<ClipState>) => void
  onRemove: () => void
  onDuplicate: () => void
  onMove: (dir: -1 | 1) => void
}

interface TrackProps {
  kind: 'voice' | 'music'
  track: TrackState
  onChange: (patch: Partial<TrackState>) => void
  onRemove: () => void
}

interface OverlayProps {
  kind: 'overlay'
  overlay: OverlayState
  playhead: number
  onChange: (patch: Partial<OverlayState>) => void
  onRemove: () => void
}

type Props = ClipProps | TrackProps | OverlayProps | { kind: 'none' }

export function Inspector(props: Props) {
  if (props.kind === 'none') {
    return (
      <aside className="inspector">
        <div className="panel-head"><h2>Propiedades</h2></div>
        <p className="hint">
          Selecciona algo en la línea de tiempo. Para recortar: pon el cursor donde quieras y presiona{' '}
          <kbd>S</kbd>; borra el pedazo sobrante con <kbd>⌫</kbd>.
        </p>
      </aside>
    )
  }

  if (props.kind === 'clip') {
    const { clip, index, count, onChange, onRemove, onDuplicate, onMove } = props
    return (
      <aside className="inspector">
        <div className="panel-head"><h2>Clip {index + 1}</h2></div>
        <div className="insp-file" title={clip.file}>{clip.file}</div>
        <div className="insp-meta">
          {clip.width > 0 && `${clip.width}×${clip.height} · `}
          dura {formatTime(clipOutSeconds(clip))} en el video
          {(clip.trimIn > 0 || (clip.duration > 0 && clip.trimOut < clip.duration)) &&
            ` · usa ${clip.trimIn.toFixed(1)}s → ${clip.trimOut.toFixed(1)}s`}
        </div>
        {!clip.media && <p className="missing">Falta el archivo — agrégalo en «Archivos»</p>}

        <div className="insp-controls">
          <label>
            Velocidad <span className="val">×{clip.speed.toFixed(2)}</span>
            <input
              type="range"
              min={0.5}
              max={2}
              step={0.05}
              value={clip.speed}
              onChange={(e) => onChange({ speed: Number(e.target.value) })}
            />
          </label>
          <label className="check">
            <input
              type="checkbox"
              checked={clip.keepAudio}
              onChange={(e) => onChange({ keepAudio: e.target.checked })}
            />
            Conservar audio del clip
          </label>
          {clip.keepAudio && (
            <label>
              Vol. clip <span className="val">{Math.round(clip.audioVolume * 100)}%</span>
              <input
                type="range"
                min={0}
                max={2}
                step={0.01}
                value={clip.audioVolume}
                onChange={(e) => onChange({ audioVolume: Number(e.target.value) })}
              />
            </label>
          )}
        </div>

        <p className="hint">
          Recorta en la línea de tiempo: cursor + <kbd>S</kbd> corta, <kbd>⌫</kbd> borra el pedazo seleccionado.
        </p>

        <div className="insp-buttons">
          <button onClick={() => onMove(-1)} disabled={index === 0} title="Mover a la izquierda">←</button>
          <button onClick={() => onMove(1)} disabled={index === count - 1} title="Mover a la derecha">→</button>
          <button onClick={onDuplicate} title="Duplicar clip">⧉ Duplicar</button>
          <button className="danger" onClick={onRemove} title="Quitar de la línea de tiempo">✕ Quitar</button>
        </div>
      </aside>
    )
  }

  if (props.kind === 'overlay') {
    const { overlay, playhead, onChange, onRemove } = props
    const dur = overlay.end - overlay.start
    return (
      <aside className="inspector">
        <div className="panel-head"><h2>Capa</h2></div>
        <div className="insp-file" title={overlay.file}>{overlay.file}</div>
        <div className="insp-meta">
          aparece {formatTime(overlay.start)} → {formatTime(overlay.end)} · {dur.toFixed(1)}s
        </div>
        {!overlay.media && <p className="missing">Falta el archivo — agrégalo en «Archivos»</p>}
        <div className="insp-controls">
          <label className="num-row">
            Aparece en (s)
            <span className="num-inputs">
              <input
                type="number"
                min={0}
                step={0.1}
                value={Math.round(overlay.start * 10) / 10}
                onChange={(e) => {
                  const v = Math.max(0, Number(e.target.value) || 0)
                  onChange({ start: v, end: v + dur })
                }}
              />
              <button className="small" onClick={() => onChange({ start: playhead, end: playhead + dur })} title="Usar la posición del cursor rojo">
                ⟵ al cursor
              </button>
            </span>
          </label>
          <label className="num-row">
            Duración (s)
            <input
              type="number"
              min={0.2}
              step={0.1}
              value={Math.round(dur * 10) / 10}
              onChange={(e) => onChange({ end: overlay.start + Math.max(0.2, Number(e.target.value) || 0.2) })}
            />
          </label>
          <label className="num-row">
            Desde el seg. del archivo
            <input
              type="number"
              min={0}
              step={0.1}
              value={Math.round(overlay.trimIn * 10) / 10}
              onChange={(e) => onChange({ trimIn: Math.max(0, Number(e.target.value) || 0) })}
            />
          </label>
          <label>
            Tamaño <span className="val">{Math.round(overlay.scale * 100)}% del ancho</span>
            <input
              type="range"
              min={0.15}
              max={0.8}
              step={0.01}
              value={overlay.scale}
              onChange={(e) => onChange({ scale: Number(e.target.value) })}
            />
          </label>
          <div className="pos-grid-wrap">
            <span className="cut-label">Posición</span>
            <div className="pos-grid">
              {POSITIONS.map((pos) => (
                <button
                  key={pos}
                  className={`pos-cell${overlay.position === pos ? ' active' : ''}`}
                  onClick={() => onChange({ position: pos })}
                  title={pos}
                />
              ))}
            </div>
          </div>
        </div>
        <div className="insp-buttons">
          <button className="danger" onClick={onRemove}>✕ Quitar capa</button>
        </div>
      </aside>
    )
  }

  const { kind, track, onChange, onRemove } = props
  const title = kind === 'voice' ? 'Voz' : 'Música'
  return (
    <aside className="inspector">
      <div className="panel-head"><h2>{title}</h2></div>
      <div className="insp-file" title={track.file}>{track.file}</div>
      <div className="insp-meta">
        {track.duration > 0 && `archivo de ${formatTime(track.duration)}`}
        {(track.cuts?.length ?? 0) > 0 && ` · ${track.cuts.length} corte${track.cuts.length === 1 ? '' : 's'}`}
      </div>
      {!track.media && <p className="missing">Falta el archivo — agrégalo en «Archivos»</p>}
      {track.url && <audio src={track.url} controls preload="metadata" className="audio-preview" />}
      <div className="insp-controls">
        <label>
          Volumen <span className="val">{Math.round(track.volume * 100)}%</span>
          <input
            type="range"
            min={0}
            max={2}
            step={0.01}
            value={track.volume}
            onChange={(e) => onChange({ volume: Number(e.target.value) })}
          />
        </label>
      </div>
      <p className="hint">
        Recorta en la línea de tiempo: selecciona la pista, cursor + <kbd>S</kbd> corta, <kbd>⌫</kbd> borra el
        segmento seleccionado.
      </p>
      <div className="insp-buttons">
        <button className="danger" onClick={onRemove}>✕ Quitar pista</button>
      </div>
    </aside>
  )
}
