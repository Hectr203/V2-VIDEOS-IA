import type { BinItem } from '../state.ts'
import { formatTime } from '../state.ts'

interface Props {
  items: BinItem[]
  folderName: string | null
  canConnectFolder: boolean
  onConnectFolder: () => void
  onAddFiles: (files: FileList | null) => void
  onAddToTimeline: (item: BinItem) => void
  onAddOverlay: (item: BinItem) => void
  onAssignVoice: (item: BinItem) => void
  onAssignMusic: (item: BinItem) => void
  onRemove: (item: BinItem) => void
}

export function MediaBin({ items, folderName, canConnectFolder, onConnectFolder, onAddFiles, onAddToTimeline, onAddOverlay, onAssignVoice, onAssignMusic, onRemove }: Props) {
  return (
    <aside className="media-bin">
      <div className="panel-head">
        <h2>Archivos</h2>
        <label className="btn primary small">
          + Agregar
          <input
            type="file"
            accept="video/*,audio/*,.mov,.mp4,.m4v,.webm,.wav,.mp3,.m4a,.aac,.ogg,.flac"
            multiple
            onChange={(e) => {
              onAddFiles(e.target.files)
              e.target.value = ''
            }}
          />
        </label>
      </div>
      {canConnectFolder && (
        <button
          className="small folder-btn"
          onClick={onConnectFolder}
          title={
            folderName
              ? `Carpeta conectada: al abrir un manifiesto, los archivos se cargan solos desde «${folderName}». Clic para cambiarla.`
              : 'Conecta tu carpeta de videos: al abrir un manifiesto, los archivos se cargarán solos'
          }
        >
          📂 {folderName ? `${folderName} ✓` : 'Conectar carpeta…'}
        </button>
      )}
      {items.length === 0 && (
        <p className="hint">Agrega tus videos y audios aquí. Luego mándalos a la línea de tiempo o asígnalos como voz/música.</p>
      )}
      <div className="bin-list">
        {items.map((item) => (
          <div key={item.id} className={`bin-item${item.media ? '' : ' bin-missing'}`}>
            {item.kind === 'video' && item.url ? (
              <video className="bin-thumb" src={`${item.url}#t=0.5`} preload="metadata" muted />
            ) : (
              <div className="bin-thumb bin-thumb-icon">{item.kind === 'audio' ? '🎵' : '🎞'}</div>
            )}
            <div className="bin-info">
              <span className="bin-name" title={item.name}>{item.name}</span>
              <span className="bin-meta">
                {!item.media
                  ? 'falta el archivo'
                  : item.duration > 0
                    ? `${formatTime(item.duration)}${item.width ? ` · ${item.width}×${item.height}` : ''}`
                    : '…'}
              </span>
              <div className="bin-actions">
                {item.kind === 'video' ? (
                  <>
                    <button className="small" disabled={!item.media} onClick={() => onAddToTimeline(item)} title="Agregar a la línea de tiempo">
                      + Timeline
                    </button>
                    <button className="small" disabled={!item.media} onClick={() => onAddOverlay(item)} title="Agregar como capa encima del video, en la posición del cursor">
                      + Capa
                    </button>
                  </>
                ) : (
                  <>
                    <button className="small" disabled={!item.media} onClick={() => onAssignVoice(item)} title="Usar como pista de voz">
                      Voz
                    </button>
                    <button className="small" disabled={!item.media} onClick={() => onAssignMusic(item)} title="Usar como música de fondo">
                      Música
                    </button>
                  </>
                )}
                <button className="small danger" onClick={() => onRemove(item)} title="Quitar de la biblioteca">✕</button>
              </div>
            </div>
          </div>
        ))}
      </div>
      <p className="bin-footer">Render pesado: guarda el manifiesto y usa el CLI.</p>
    </aside>
  )
}
