---
name: pipeline-produccion-video
description: Pipeline integral de producción de video explicativo desde una idea abstracta hasta el render final 1080p con Remotion, TTS y verificación por contact sheet.
---

# Pipeline Integral de Producción de Video 2D

## Objetivo y alcance
Estandarizar el flujo de trabajo completo para transformar cualquier idea, guion o concepto abstracto en una producción audiovisual animada de alta gama en Remotion, garantizando orden de recursos, calidad visual consistente y verificación obligatoria previa al render.

## Cuándo usar / cuándo no usar
- **Usar cuando:** Se inicie la creación de un nuevo video desde cero (ej. "video sobre inteligencia artificial y regulación", "video sobre neurobiología", etc.) o se deba optimizar una producción existente.
- **No usar cuando:** Se trate de simples ajustes de estilos CSS o refactorizaciones sin generación de video.

---

## 1. Convención Estricta de Recursos y Directorios

Para evitar que los archivos queden dispersos, toda producción debe respetar la siguiente estructura canónica:

```text
video-studio/
└── projects/
    └── <nombre-del-proyecto>/          # Carpeta única y auto-contenida por proyecto
        ├── project.json                # Metadatos (título, descripción, resolución, versión)
        ├── storyboard.json             # Guion, capítulos, paletas y temporalidad mínima
        ├── timeline.json               # Timestamps exactos por frame y palabras
        ├── subtitles.srt               # Subtítulos cronometrados portables
        ├── prepare.py                  # Generación TTS, banda sonora procedural y sincronización
        ├── render.mjs                  # Orquestador autónomo de render Remotion
        ├── src/
        │   ├── index.tsx               # Entrypoint autónomo con registerRoot
        │   ├── Film.tsx                # Montaje, secuencias, cámara y subtítulos cinéticos
        │   ├── art.tsx                 # Biblioteca vectorial SVG, rigging IK y recursos reutilizables
        │   └── timeline.json           # Enlace local para bundler
        ├── public/
        │   ├── <scene_id>.mp3          # Locuciones por escena
        │   ├── score.wav               # Banda sonora procedural
        │   └── UbuntuSans.ttf          # Tipografía empaquetada
        └── renders/                    # Salidas de render (IGNORADO EN GIT)
            ├── contact-sheet.jpg       # Mosaico de control de calidad de todas las escenas
            ├── stills/                 # Capturas PNG individuales por escena
            ├── preview-720p.mp4        # Render borrador rápido
            └── master-1080p.mp4        # Video master final Full HD (1080x1920, CRF 17)
```

---

## 2. Flujo de Trabajo en 7 Fases

### Fase 1: Conceptualización y Arco Narrativo
1. Definir la **Tesis Central**: ¿Cuál es el mensaje que el espectador recordará?
2. Crear un arco en 5 actos:
   - *Gancho / Pregunta provocativa*: Captura inmediata de atención.
   - *Fundamento / Mecanismo dual*: Explicación del funcionamiento básico con metáforas comprensibles.
   - *Escalamiento / Contraste cuantitativo*: Comparación de escala (ej. 50-100x, órdenes de magnitud).
   - *El Riesgo o Inflexión*: Consecuencias invisibles, efectos adversos o dilemas.
   - *Cierre constructivo o de emergencia*: Acciones preventivas, soluciones o llamadas a la acción.

### Fase 2: Storyboard JSON (`storyboard.json`)
Desglosar el video en **12 a 18 escenas cortas** (duración por escena: entre 1.5 y 4.5 segundos).
Cada escena debe contener:
```json
{
  "id": "intro",
  "chapter": "EL DESAFÍO",
  "palette": "purple",
  "text": "¿Cómo decide un algoritmo lo que ves cada día?",
  "minSeconds": 3.5
}
```
*Paletas semánticas:* Utilizar esquemas de color contrastantes según el tono narrativo (`purple` para misterio/profundidad, `teal` para ciencia/tecnología/claridad, `gold` para placer/alerta/calidez).

### Fase 3: Locución y Audio Procedural (`prepare.py`)
1. Generar audio con Edge TTS utilizando el parámetro `boundary="WordBoundary"` para capturar los offsets de cada palabra.
2. Calcular la duración exacta en frames (`FPS = 30`) para cada escena y exportar `timeline.json`.
3. Sintetizar la música y efectos en `score.wav` utilizando generadores de audio deterministas (arpegios suaves en frecuencias armónicas, ruidos blancos filtrados para transiciones y pulsos sonoros).

### Fase 4: Arte Vectorial SVG (`art.tsx` y `shared-art/`)
1. Implementar las funciones de animación matemática: `clamp`, `ease`, `mix`, `wave`, `seeded`.
2. Modelar al personaje principal con articulación de cinemática inversa (`joint`), ojos reactivos con parpadeo, respiración en el torso y mechones de pelo con retardo.
3. Reutilizar rigs comunes desde `video-studio/shared-art/` (`HandRigs`, `ParticleSystems`, etc.) para componentes anatómicos genéricos.
4. Dibujar desde cero los elementos técnicos y pedagógicos en SVG con gradientes y sombras (sin emojis ni iconos de fuentes genéricas).

### Fase 5: Montaje y Composición (`Film.tsx`)
1. Montar las escenas mediante `<Sequence>` en Remotion con `start` y `frames` tomados de `timeline.json`.
2. Asignar las pistas de audio por escena y la pista maestra de música de fondo (`score.wav`).
3. Integrar los subtítulos cinéticos con resaltado dinámico de la palabra actual.
4. Aplicar dinamismo de cámara (`scale(1 + ease(f/scene.frames) * 0.018)`).
5. Configurar el punto de entrada autónomo en `src/index.tsx` registrando el `ProjectRoot`.

### Fase 6: Control de Calidad Visual Obligatorio (Contact Sheet)
**REGLA CRÍTICA:** Ningún render final puede lanzarse sin antes generar e inspeccionar visualmente la hoja de contactos de todas las escenas:

```bash
# 1. Renderizar stills y generar el mosaico de control automáticamente:
node video-studio/projects/<nombre-del-proyecto>/render.mjs --stills
```
*Checklist de inspección:*
- ¿Hay superposición o desborde de textos y subtítulos?
- ¿El personaje y los objetos están centrados y con escala equilibrada?
- ¿Los contrastes cromáticos entre fondo y primer plano son legibles?

### Fase 7: Renderizado Estratificado y Multi-Aspecto
1. **Render Borrador Rápido (Draft 720p)**:
   ```bash
   node video-studio/projects/<nombre-del-proyecto>/render.mjs --draft
   ```
   Valida en menos de 1 minuto que audio, video y subtítulos fluyan sin caídas de frames.
2. **Render Master Vertical 9:16 (TikTok, Reels, Shorts)**:
   ```bash
   node video-studio/projects/<nombre-del-proyecto>/render.mjs
   ```
   Genera el video definitivo en `1080×1920` (CRF 17) en `renders/master-1080p.mp4`.
3. **Render Master Horizontal 16:9 (YouTube Widescreen)**:
   ```bash
   node video-studio/projects/<nombre-del-proyecto>/render.mjs --horizontal
   ```
   Genera el video en `1920×1080` (CRF 17) en `renders/master-16-9-1080p.mp4`.
4. **Render de Ambos Formatos**:
   ```bash
   node video-studio/projects/<nombre-del-proyecto>/render.mjs --aspect=both
   ```

---

## 3. Entrega, Verificación y Documentación Técnica
- El comando `ffprobe` debe validar que la duración coincida exactamente con `timeline.durationInFrames / 30`.
- El árbol de git debe permanecer limpio ignorando los archivos temporales de `renders/`.
- Para manual operativo detallado y mapa anti-alucinación de dependencias:
  - Leer [`docs/GUIA_COMPLETA_PRODUCCION_2D.md`](../../docs/GUIA_COMPLETA_PRODUCCION_2D.md)
  - Consultar el manual de agentes en [`README.md`](../../README.md)

