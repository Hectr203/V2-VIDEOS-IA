---
name: openverse-audio
description: Búsqueda y descarga segura de más de 5 millones de efectos de sonido (SFX), ambientes y pistas de audio con licencia abierta (CC0, dominio público PDM y CC-BY) directamente desde la API oficial de Openverse (WordPress Foundation), sin clave obligatoria ni proxys de terceros. Incluye filtrado por duración, medición automática de sonoridad LUFS/True Peak con FFmpeg y generación automática de openverse_manifest.json y CREDITS.md. Usar cuando falte un sonido real en la biblioteca local de video-studio/assets/ o se necesite SFX auténtico con licencia verificable. No usar para descargar audio con restricciones NC/ND/SA ni para eludir derechos de autor.
---

# Búsqueda y Descarga de Audio Abierto con Openverse (`openverse-audio`)

## Objetivo y alcance
Dar a los agentes audiovisuales acceso directo, seguro y trazable al catálogo de más de 5 millones de audios de **Openverse** (`https://api.openverse.org/v1/audio/`, mantenido por WordPress Foundation bajo licencia MIT), sin intermediarios de terceros y con verificación estricta de licencias comerciales.

- **Licencias permitidas por el CLI:**
  - `--licencia cc0` *(por defecto)*: **CC0** y **Public Domain Mark (PDM)** — uso comercial libre sin atribución obligatoria.
  - `--licencia comercial`: **CC0 + PDM + CC-BY** (cuando se descarga un audio `CC-BY`, el script registra automáticamente la línea de atribución obligatoria en `CREDITS.md`).
- **Licencias bloqueadas automáticamente:** `NC` (no comercial), `ND` (sin derivadas), `SA` (compartir igual) y licencias no verificadas.

## Cuándo usar / cuándo no usar
- **Usar cuando:**
  - Un video en `video-studio` necesita un efecto sonoro real (whoosh, click mecánico, papel, puerta, ambiente, foley específico) que no está en los 414 audios locales de `video-studio/assets/`.
  - Se desea alimentar a `real-sfx` o `real-sound` con grabaciones auténticas en lugar de sonidos sintéticos genéricos.
- **No usar cuando:**
  - El sonido requerido ya existe y está fresco en `video-studio/assets/` (`buscar_audio.py --historia --evitar-recientes`).
  - Se requiere una locución hablada o música con derechos comerciales cerrados.

## Entradas y requisitos
- Python 3.10+ (solo biblioteca estándar), `ffmpeg` y `ffprobe` en `PATH` (opcionales para medir LUFS y True Peak automáticamente).
- Acceso HTTPS saliente a `api.openverse.org` y dominios oficiales de preview/descarga (ej. `cdn.freesound.org`).
- **Sin API key obligatoria:** Funciona de inmediato en modo anónimo (límite de cortesía de la API oficial). Si el usuario configura `OPENVERSE_ACCESS_TOKEN` en su entorno, el CLI lo utiliza automáticamente sin guardarlo en archivos del proyecto.

## Procedimiento

### 1. Buscar efectos de sonido reales (en inglés para máxima cobertura)
```bash
python3 Agencia_Principal/skills/audio-pro-skills/openverse-audio/scripts/buscar_openverse.py \
  --buscar "whoosh transition" --licencia cc0 --max-dur 2.5 --limite 8
```

### 2. Descargar y medir automáticamente en la carpeta del proyecto
```bash
python3 Agencia_Principal/skills/audio-pro-skills/openverse-audio/scripts/buscar_openverse.py \
  --buscar "mechanical keyboard click" --licencia cc0 --max-dur 1.5 \
  --descargar 1,2 --salida "video-studio/projects/<fecha>/<slug>/public/sfx"
```

El comando:
1. Verifica que la URL sea `https://`, que el `Content-Type` corresponda a audio y que el archivo no supere 50 MB.
2. Guarda los audios en la carpeta destino (rechazando *symlinks* y *path traversal*).
3. Mide duración exacta, códec, *sample rate*, **LUFS integrado** y **True Peak (dBFS)** con `ffprobe`/`ffmpeg`.
4. Genera/actualiza `openverse_manifest.json` y `CREDITS.md` en la carpeta destino.

### 3. Integración con `earshot` y `real-sfx`
- Tras descargar, inspeccionar/validar sonoridad y ataque con `earshot measure <archivo>` o `real-sfx/scripts/search.py`.
- Antes de mezclar en Remotion o `real-sfx`, normalizar SFX a `-22 LUFS` / pico máximo `-6 dBFS` para no tapar nunca la voz narradora.

## Entrega y validación
- Archivos de audio descargados con licencia verificada (`CC0`, `PDM` o `CC-BY`), telemetría LUFS/dBFS real y archivo `CREDITS.md` actualizado junto a `openverse_manifest.json`.
- Nunca afirmar que se descargó un audio sin haber ejecutado el script ni inventar URLs o licencias.

## Recursos, procedencia y mantenimiento
- **Script ejecutable:** `scripts/buscar_openverse.py` (sin dependencias externas de Python).
- **API oficial:** WordPress Foundation Openverse API (`https://api.openverse.org/v1/audio/`, MIT).
- **Contrato:** Aplicar `agentes/contrato-agente.md` y `reglas/seleccion-skills.md`.
