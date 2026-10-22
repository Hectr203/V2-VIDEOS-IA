import { useEffect } from 'react'
import manifiestoDoc from '../../manifiesto.md?raw'
import { downloadBlob } from '../lib/wasm.ts'

interface Props {
  onClose: () => void
}

export function ManifestHelp({ onClose }: Props) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <h3>¿Qué es el manifiesto?</h3>
          <button className="danger" onClick={onClose} title="Cerrar (Esc)">✕</button>
        </div>

        <div className="modal-body">
          <p>
            El manifiesto es un archivo <strong>JSON</strong> que describe la <strong>receta completa de tu video</strong>:
            qué clips van, en qué orden, cómo se recortan, a qué velocidad, y qué voz y música llevan con sus
            volúmenes y cortes. <strong>No contiene los videos</strong> — solo las instrucciones (pesa unos KB).
          </p>

          <h4>Guardar y abrir</h4>
          <ul>
            <li>
              <strong>Guardar manifiesto</strong> toma una foto del estado actual del editor. Es tu forma de
              «guardar el proyecto»: guárdalo junto a tus archivos de video.
            </li>
            <li>
              <strong>Abrir manifiesto</strong> (o simplemente <strong>arrástralo y suéltalo</strong> sobre la
              ventana) reconstruye todo el proyecto. Los archivos se reconectan por
              nombre: si ya están en «Archivos» se enlazan solos; si no, agrégalos y se emparejan automáticamente.
            </li>
            <li>
              <strong>📂 Conectar carpeta</strong> (panel «Archivos»): conecta tu carpeta de videos una sola vez
              y al abrir cualquier manifiesto los archivos se cargan <em>solos</em>, sin re-seleccionarlos. Ideal
              para abrir manifiestos creados por una IA.
            </li>
          </ul>

          <h4>📂 Cómo funciona la carpeta conectada</h4>
          <ul>
            <li>
              La búsqueda es <strong>recursiva</strong>: los archivos pueden estar en cualquier subcarpeta.
            </li>
            <li>
              El emparejamiento es por <strong>nombre exacto de archivo</strong>. Si hay varios archivos con el
              mismo nombre en subcarpetas distintas (ej. varios <code>untitled.wav</code>), se usa el primero que
              se encuentre — dale nombre propio a cada nota de voz para evitar sorpresas.
            </li>
            <li>
              La conexión sobrevive al cierre del navegador; en cada sesión nueva solo pedirá un clic de
              confirmación (banner azul «Cargar archivos») la primera vez que la use.
            </li>
            <li>
              Disponible en navegadores Chromium (Opera, Chrome, Edge). En Safari/Firefox el botón no aparece y
              los archivos se agregan a mano (se emparejan por nombre igual).
            </li>
          </ul>

          <h4>Así se ve por dentro</h4>
          <pre className="modal-code">{`{
  "name": "mi-video",
  "clips": [
    { "file": "IMG_3360.mov", "trimIn": 1, "trimOut": 4,
      "speed": 1.5, "keepAudio": false, "audioVolume": 1,
      "cuts": [{ "from": 2, "to": 3 }] }
  ],
  "voice": { "file": "voz.wav", "trimIn": 0, "trimOut": null,
    "volume": 1, "cuts": [{ "from": 83, "to": 94 }] },
  "music": { "file": "track.mp3", "trimIn": 0, "trimOut": null,
    "volume": 0.15 },
  "outputs": ["vertical"]
}`}</pre>
          <p className="modal-note">
            Tiempos en segundos del archivo original. <code>cuts</code> son pedazos internos que se eliminan
            (lo que haces con la tecla S) y el material se re-empata solo. <code>trimOut: null</code> en audio
            = hasta el final. También hay <code>overlays</code>: capas de video encima del principal (botón
            «+ Capa» en Archivos), con su rango de aparición, tamaño y posición.
          </p>

          <h4>🤖 Trabajarlo con IA (Claude Code)</h4>
          <p>
            Como el manifiesto es texto, una IA puede <strong>escribirlo, editarlo y renderizarlo por ti</strong> sin
            que abras este editor. En una terminal con Claude Code, prueba cosas como:
          </p>
          <ul>
            <li>
              <em>«Ármame un manifiesto con los clips X y Y, recorta el inicio del primero, ponle la voz del
              proyecto 20 y renderízalo»</em>
            </li>
            <li>
              <em>«A este manifiesto córtale la voz del 1:23 al 1:34 y vuelve a renderizar»</em>
            </li>
            <li>
              <em>«Renderiza mi-video.json también en horizontal»</em>
            </li>
          </ul>
          <p>
            El render por terminal usa ffmpeg nativo y es <strong>mucho más rápido</strong> que el navegador
            (ideal para clips 4K o videos largos):
          </p>
          <pre className="modal-code">node cli/render.ts mi-video.json --base ~/Documents/Videos</pre>
          <p className="modal-note">
            Los tres flujos son intercambiables: editas aquí y renderiza la IA, arma la IA y ajustas aquí, o
            todo en un solo lado. El manifiesto es el mismo idioma en ambos mundos.
          </p>

          <h4>📄 Especificación completa</h4>
          <p>
            Este cuadro es el resumen. La especificación detallada (cada campo, las reglas de tiempos, el CLI y
            una guía para IA con ejemplos) vive en <code>manifiesto.md</code>. Descárgalo y pégaselo a cualquier
            IA junto con tu manifiesto — con eso tiene todo para trabajarlo sin adivinar:
          </p>
          <button
            className="primary"
            onClick={() => downloadBlob('manifiesto.md', manifiestoDoc, 'text/markdown')}
          >
            ⬇ Descargar manifiesto.md
          </button>
        </div>
      </div>
    </div>
  )
}
