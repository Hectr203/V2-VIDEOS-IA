# Agencia Principal

Sistema local de trabajo con IA: fichas de agentes, habilidades, contextos por proyecto, CLI y servidor MCP. La documentación orienta al modelo; las pruebas verifican controles concretos. La agencia no sustituye al runtime de agentes del IDE ni certifica servicios externos por estar configurados.

---

## Estrategia de Preproducción Audiovisual (Social Media Manager — Dos Prompts Maestros)

Para garantizar que cada video nazca con una base sólida, entretenida y validada antes de pasar a las herramientas de producción audiovisual (`video-studio` / Remotion), el proyecto integra **dos prompts maestros diferenciados** que operan estrictamente en la etapa de **preproducción** (ideación, investigación web de videos exitosos, validación de mercado, ingeniería de ganchos y estructuración del guion base — **sin generar el archivo de video final**).

### Flujo de trabajo recomendado (de la idea inicial al guion base validado)

```text
1. Idea inicial simple ("quiero hacer un video sobre los perros")
   │
   ▼  [PROMPT MAESTRO 1 · Ideación Guiada y Validación]
2. Preguntas estratégicas (objetivo, audiencia, plataforma, tono, formato)
   → 5–7 ángulos concretos → Filtro de entretenimiento y viabilidad → Brief Validado
   │
   ▼  [PROMPT MAESTRO 2 · Social Media Manager Integral]
3. Investigación activa en navegador/internet de videos similares exitosos
   → Extracción de outliers (swipe.py), ganchos 0–3s, ritmo, retención y entretenimiento
   → Diagnóstico de mercado + Information-Gain Gate
   → Laboratorio de 6–8 ganchos de 3 capas (visual + verbal + texto en pantalla)
   → Guion base escena por escena auditado (evaluar_guion.py >= 80/100)
   → Empaquetado social (título/portada con title.py, copy SEO, hashtags, comentario fijado)
   │
   ▼  [Traspaso opcional y manual a Fase 2 · Producción]
4. Guion base guardado en video-studio/mis-temas/preproduccion-<slug>.md
   → Listo para producir con tus herramientas dedicadas de video
```

---

### Prompt Maestro 1 · Ideación Guiada y Validación (Desde una idea inicial simple)

Úsalo cuando tengas una idea suelta, amplia o en borrador y quieras que el asistente te guíe con las preguntas estratégicas necesarias para convertirla en un concepto claro, entretenido y viable antes de guionizar.

```text
Actúa como el Asistente Principal definido en Agencia_Principal/asistente-principal.md en MODO A (Ideación Guiada y Validación), operando como mi gestor profesional de redes sociales (Social Media Manager) y apoyándote en las skills `preproduccion-social-video`, `interview-me`, `idea-refine`, `viral-short-form-ideas` y `customer-research`.

Mi idea inicial es: "[escribe aquí tu idea inicial, por ejemplo: quiero hacer un video sobre los perros]"

Reglas obligatorias para esta sesión:
1. NO escribas todavía el guion definitivo ni generes el archivo de video final ni ejecutes scripts de producción/renderizado.
2. Primero hazme las preguntas estratégicas imprescindibles (de forma clara, ordenada y sin abrumarme) para definir:
   - Objetivo principal del video (alcance, guardados, envíos, debate o autoridad).
   - Público objetivo exacto y qué curiosidad, dolor o mito tiene hoy.
   - Plataforma y formato (TikTok, Instagram Reels, YouTube Shorts 9:16 o YouTube 16:9) y duración ideal.
   - Tono y enfoque de entretenimiento (curiosidad sorprendente, verdad contraintuitiva, humor, historia emocional, comparativa o ranking).
   - Restricciones o identidad de marca a respetar.
3. Con mis respuestas, transforma mi idea inicial en 5 a 7 ángulos concretos y filmables, evalúa su atractivo general (Broad Appeal), brecha de curiosidad, nivel de entretenimiento y viabilidad real, y recomiéndame el Top 2 con justificación de Social Media Manager.
4. Cierra entregándome un Brief Validado (incluyendo explícitamente "Qué NO haremos") y pregúntame si confirmo ese enfoque para pasar a investigación de mercado y guion base.
```

---

### Prompt Maestro 2 · Asistente Principal de Creación y Estrategia (Social Media Manager Integral)

Úsalo en tu creación recurrente de nuevos videos (partiendo de un Brief del Prompt Maestro 1 o directamente con un tema/nicho) para que el asistente investigue en internet videos exitosos, evalúe el mercado y te entregue la base completa del guion validada y lista para producción.

```text
Actúa como el Asistente Principal definido en Agencia_Principal/asistente-principal.md en MODO B (Creación y Estrategia Integral de Preproducción), operando como mi Social Media Manager dedicado junto con el agente de redes sociales y el agente estratega narrativo (`preproduccion-social-video`, `niche-research`, `yt-viral`, `content-strategy`, `social`, `viral-hooks`, `viral-short-form`, `viral-captions-and-ctas`, `yt-script`, `yt-package`, `estrategia-narrativa-ganchos-retencion` y `post-scorer`).

Tema / Brief / Nicho para el nuevo video: "[escribe aquí el Brief confirmado o el tema que quieres trabajar]"
Plataforma(s) y duración objetivo: "[ej.: TikTok / Reels / Shorts 9:16 de 60 segundos]"

Ejecuta este flujo completo de preproducción SIN generar ni renderizar el archivo de video final:
1. Investigación activa en navegador e internet: cuando dispongas de navegador o búsqueda web, investiga videos similares que ya hayan tenido éxito y tendencias recientes en YouTube, TikTok, Reels, Reddit o Google. Extrae patrones verificables (sin inventar datos ni enlaces): videos outliers que superen el promedio de su canal (usando `swipe.py` si recolectas >= 4 videos por canal), ganchos de 0–3 segundos, estructura narrativa, dinámicas de retención y qué hace entretenido el contenido. Traduce esos hallazgos en recomendaciones accionables y define qué nos diferenciará (Information-Gain Gate).
2. Diagnóstico de mercado y entretenimiento: clasifica la pieza (Buscable, Compartible o Híbrida), evalúa si será genuinamente entretenida y emite un veredicto de viabilidad (ALTA / MEDIA CON AJUSTES / BAJA — PIVOTAR).
3. Laboratorio de ganchos (0–3s): diseña 6 a 8 ganchos en al menos 3 arquetipos distintos detallando sus 3 capas simultáneas (Gancho Verbal sin saludos genéricos + Gancho Visual del primer fotograma + Texto en Pantalla de 3–6 palabras) y recomienda el ganador.
4. Base completa del guion validada: estructura el guion escena por escena (6–10s por escena) con tensión inicial, re-ganchos cada 2 escenas, ritmo hablado natural sin clichés de IA, notas `[EN PANTALLA: ...]`, sugerencias selectivas de apoyo visual y cierre conversacional con un único CTA libre de engagement bait. Audita el guion con `evaluar_guion.py` hasta obtener VERDE (>= 80/100).
5. Empaquetado social listo para publicar: propón 3 combinaciones de Título + Texto de Portada (sin repetir palabras, validando longitud con `title.py`), copy SEO listo para copiar y pegar (validado con `post-scorer >= 75/100`), 3–5 hashtags de nicho y comentario fijado.
6. Al finalizar, ofrece guardar el entregable en `video-studio/mis-temas/preproduccion-<slug>.md` y pregúntame si ajustamos algo o si autorizo pasar a la Fase 2 de producción audiovisual.
```

---

### Ejemplos prácticos de ejecución

#### Ejemplo 1 · De idea vaga a concepto ganador (Prompt Maestro 1)
- **Entrada del usuario:** *"quiero hacer un video sobre los perros"*
- **Qué hace el asistente:**
  1. Detecta que "los perros" es un tema demasiado amplio y despliega 5 preguntas breves (objetivo, audiencia, plataforma, tono y restricciones).
  2. El usuario responde: *alcance + envíos, dueños de perros en ciudad, Reels/TikTok de 60s, tono de curiosidad con toque de humor*.
  3. El asistente propone 6 ángulos filmables (por ejemplo: *"Por qué tu perro inclina la cabeza (la ciencia detrás del gesto)"*, *"3 cosas cotidianas que haces por cariño y estresan a tu perro"*, *"Lo que realmente ve tu perro cuando dejas la TV encendida"*), puntúa su atractivo general y recomienda el Top 2.
  4. Entrega un **Brief Validado** confirmado (incluyendo *"Qué NO haremos: nada de lista enciclopédica de razas ni tono veterinario aburrido"*).

#### Ejemplo 2 · Investigación web activa y guion base validado (Prompt Maestro 2)
- **Entrada del usuario:** Brief confirmado *"3 gestos cotidianos que estresan a tu perro sin que lo notes — TikTok/Reels 9:16, 60s"*.
- **Qué hace el asistente:**
  1. Abre el navegador/buscador web para localizar videos exitosos sobre señales de estrés en perros, analiza sus ganchos de los primeros 3 segundos, detecta qué formato genera más comentarios/envíos y aplica `swipe.py` si recolecta series de canales.
  2. Emite veredicto **ALTA VIABILIDAD (Híbrido: Buscable + Altamente Compartible por envío entre dueños)**.
  3. Presenta 6 ganchos de 3 capas (ej. Verbal: *"El abrazo que le das a tu perro cada mañana podría estar poniéndolo en alerta."* | Visual: persona abrazando a su perro mientras el perro relame el hocico y desvía la mirada con alerta visual | Texto en pantalla: *"NO ES CARIÑO PARA ÉL"*).
  4. Entrega el guion completo en 8 escenas ágiles (~60s) con re-ganchos en escenas 3 y 6, auditado en **VERDE (`>= 80/100`)** con `evaluar_guion.py`, más 3 títulos/portadas, copy listo para copiar y comentario fijado — listo para pasar a producción audiovisual sin haber renderizado todavía el video.

---

### Skills auditadas para preproducción audiovisual y redes sociales

Todas las habilidades están registradas en `.agencia/catalogo-skills.json` (`164` habilidades canónicas) y las de la tabla siguiente están orientadas exclusivamente a preproducción (ninguna genera el archivo de video final).

#### A. Skills existentes reutilizadas como base
| Skill | Rol en la etapa de preproducción |
| :--- | :--- |
| `estrategia-narrativa-ganchos-retencion` | Matriz narrativa en español, *Broad Appeal Check*, 7 arquetipos de gancho y evaluador CLI `scripts/evaluar_guion.py` (umbral `>= 80/100`). |
| `interview-me` | Entrevista progresiva con hipótesis hasta alcanzar claridad real y confirmación explícita del usuario. |
| `idea-refine` | Ideación divergente/convergente mediante lentes creativos, detección de supuestos y lista explícita de exclusiones (*Not Doing*). |
| `reels-scripting` | Estructura temporal de 30–60s para video vertical con foco en tasa de finalización. |
| `post-scorer` | Calificación previa de copys sociales (escala 0–100, umbral `>= 75/100`). |
| `voice-builder` | Definición y aislamiento estricto de la voz de marca en `contexts/brands/<brand-id>/voice.md`. |
| `documentary-narrative-engine` | Generación de ángulos documentales específicos y psicología emocional de miniaturas para piezas de formato medio/largo. |

#### B. Nuevas skills investigadas, descargadas, auditadas e incorporadas
| Skill | Procedencia (Licencia) | Valor auditado en preproducción |
| :--- | :--- | :--- |
| `preproduccion-social-video` | Nativa (`Agencia_Principal`) | Orquesta los dos prompts maestros, la investigación activa en navegador, el diagnóstico de entretenimiento y la entrega del guion base validado. |
| `viral-short-form-ideas` | `vyralcontent/content-skills` (MIT, saneada) | Sistemas de ideación en volumen, pilares, matriz de contenido, minería de comentarios/Reddit/autocompletado y evaluación de ideas. |
| `viral-hooks` | `vyralcontent/content-skills` (MIT, saneada) | Ingeniería y crítica de ganchos en **3 capas** (visual + verbal + texto en pantalla), marcos de creadores y anti-patrones 0–3s. |
| `viral-short-form` | `vyralcontent/content-skills` (MIT, saneada) | Arquitectura de retención (gancho → escalada → recompensa → CTA), formatos ganadores y heurísticas por plataforma. |
| `viral-captions-and-ctas` | `vyralcontent/content-skills` (MIT, saneada) | Copys SEO por plataforma, texto en pantalla en zona segura, estrategia de 3–5 hashtags, CTAs de envíos/guardados sin *engagement bait* y comentario fijado. |
| `yt-viral` | `Jakeschincariol/youtube-agent-skill` (MIT) | Análisis cuantitativo de videos *outliers* por múltiplo sobre la mediana del propio canal mediante el CLI `swipe.py` (`--min 2.0`). |
| `yt-script` | `Jakeschincariol/youtube-agent-skill` (MIT) | Base de 21 fórmulas probadas de gancho (`hooks.json`), estructura de guion con marcas `[ON SCREEN]` y evaluador CLI `hookscore.py`. |
| `yt-package` | `Jakeschincariol/youtube-agent-skill` (MIT) | Empaquetado conjunto de Título + Miniatura/Portada con verificación CLI `title.py` (truncado 40 chars móvil / 60 chars escritorio y cero duplicación). |
| `niche-research` | `charlie947/social-media-skills` (MIT) | Investigación en vivo vía navegador y buscador de tendencias de los últimos 7 días con verificación estricta de fechas y cobertura real. |
| `content-strategy` | `coreyhaines31/marketingskills` (MIT) | Estrategia *Buscable vs. Compartible*, *Information-Gain Gate*, investigación en foros/competencia y matriz de priorización ponderada. |
| `social` | `coreyhaines31/marketingskills` (MIT) | Gestión orgánica multiplataforma de Social Media Manager, ingeniería inversa viral, atomización y filtro anti-AI-tells. |
| `customer-research` | `coreyhaines31/marketingskills` (MIT) | Minería de dolores y vocabulario real de audiencia en comunidades y comentarios, con salvaguarda de seguridad anti-prompt-injection. |

*(Durante la auditoría se descartaron `marketingskills/video` e `inference-sh/skills` por estar orientadas a generación final de video, `charlie947/hook-generator` y `content-matrix` por estar acopladas a texto LinkedIn, y `tenfoldmarc/script-skill` por carecer de licencia abierta SPDX. En las 4 skills de `vyralcontent` se retiró el bloque promocional comercial manteniendo intacta la licencia MIT y atribución.)*

---

## Inicio

Ejecutar desde esta carpeta (`Agencia_Principal/`):

```bash
python3 scripts/agencia.py doctor
python3 scripts/agencia.py validar
python3 -m unittest discover -s tests -v
python3 scripts/agencia.py verificar
python3 scripts/agencia.py comprobar
python3 scripts/agencia.py nuevo cliente-web --cliente "Cliente"
python3 scripts/agencia.py arranque cliente-web --prime
python3 scripts/agencia.py cierre cliente-web --tareas "Avance verificado" --pendientes "Siguiente paso"
```

Para otro stack registrado, añadir `--stack laravel-livewire-alpine`. El CLI crea contexto y memoria; no genera automáticamente una aplicación ni un despliegue. Los perfiles inexistentes se preparan y aprueban antes de crear el proyecto.

## Organización

- [Precedencia de reglas](reglas/precedencia.md): resolver stack, convenciones y autorizaciones.
- [Asistente principal](asistente-principal.md) y [agentes](agentes/contrato-agente.md): selección de roles y entregables (incluidos [redes sociales](agentes/redes-sociales.md) y [estratega narrativo](agentes/agente-estratega-narrativo.md)).
- [Inicio de proyectos](GUIA-INICIO-PROYECTO.md): desarrollo fuera de la carpeta de la agencia.
- [Stacks](stacks/README.md): estándar JavaScript y perfiles alternativos.
- `contexts/projects/<id>/`: manifiesto, memoria, ADRs y evidencias por ID explícito.
- `.agencia/catalogo-skills.json`: selección única de fuentes de habilidades (`164` canónicas).
- `.agencia/skills-activos/`: entradas ligeras generadas que remiten a sus recursos originales.
- [HITL](reglas/human-in-the-loop.md): operaciones sensibles y aprobación comprobable.
- [Operación comercial](contexts/agency/acuerdos.md): datos a completar antes de cotizar.

Las fuentes importadas se conservan. Para actualizar las entradas después de editar una fuente:

```bash
python3 scripts/catalogo_skills.py --generar
python3 scripts/catalogo_skills.py
```

No cargar recursivamente todas las variantes de `skills/` junto con las entradas activas. El catálogo detecta duplicados nuevos que requieren una selección explícita. Cada IDE puede añadir habilidades globales: comprobar sus colisiones en ese entorno.

## MCP y credenciales

OpenCode carga el MCP local `agencia` y las entradas activas. Stitch está desactivado hasta configurar una credencial nueva y comprobar la conexión. Su configuración utiliza `{env:STITCH_API_KEY}` según la [documentación de OpenCode](https://opencode.ai/docs/es/config/).

Los archivos `mcp_config.json` y `mcp/mcp_config.json` contienen solo el servidor local. Sus rutas corresponden a este equipo; al mover la agencia hay que apuntar al nuevo `scripts/agencia_mcp.py`. No asumir que otro cliente expande la sintaxis de variables de OpenCode.

Retirar una credencial de los archivos no la revoca en el proveedor. Rotar la anterior en la cuenta correspondiente y actualizar el entorno; no pegar claves en chats, Markdown ni JSON versionable.

El CLI y el MCP comunican fallos mediante código de salida e `isError`. `doctor` comprueba integridad local e inicialización MCP, sin realizar solicitudes a servicios externos.

La [verificación local](reglas/verificacion-local.md) ejecuta pruebas y validador, y conserva evidencia vinculada al contenido. `comprobar` rechaza informes ausentes, fallidos o desactualizados. No requiere instalar herramientas adicionales; el alcance es este checkout de la agencia.

## Piloto y comprobaciones

El [piloto de referencia](contexts/projects/_ejemplo_golden/manifiesto.md) documenta criterios verificables. `tests/test_flujo_piloto.py` ejecuta creación, arranque, cierre y recuperación con dos clientes en una agencia temporal, sin alterar proyectos reales.

Las pruebas de controles cubren rutas externas, enlaces simbólicos, validación de argumentos, propagación de errores y autorización pendiente. Una solicitud pendiente devuelve 2; solo una aprobación interactiva registrada devuelve 0.

Los archivos Markdown y JSONL de memoria son legibles. No registrar secretos; el cifrado de compatibilidad no protege esas copias. El aislamiento por ID evita alias accidentales, pero no constituye aislamiento de sistema operativo entre usuarios.

La rentabilidad, capacidad comercial y calidad de una aplicación se evalúan con datos y evidencias de cada proyecto, no con el número de agentes o habilidades.

## Skills y ampliación de roles

La selección se rige por [el contrato de skills](reglas/seleccion-skills.md). Buscar candidatos y resolver su fuente antes de leer y aplicar sus instrucciones:

```bash
python3 scripts/agencia.py skills --consulta preproduccion
python3 scripts/agencia.py skills --nombre preproduccion-social-video
python3 scripts/agencia.py skills --nombre viral-hooks
python3 scripts/agencia.py registrar-agente nombre-del-agente
```

El último comando registra una ficha existente creada con [la plantilla de agente](plantillas/nuevo-agente.md). No inicia procesos ni asigna skills obligatorias. Para generar configuración MCP en otra ubicación, usar `scripts/configurar_mcp.py --help`; nunca sobrescribe una configuración existente.

[Auditoría integral](contexts/agency/auditoria-integral.md): alcance, correcciones y registro por archivo. Las skills conservan sus fuentes independientes; esta auditoría verifica su integración, no sus procedimientos internos.

## Control de entregas y métricas

El [control de calidad](reglas/calidad-entregas.md) añade un registro independiente de tecnología y proveedor. `scripts/control_entregas.py` comprueba criterios y huellas de evidencias sin ejecutar instrucciones del informe. Calcula duración mediana, retrabajo y costos por moneda a partir de registros explícitos; no atribuye resultados comerciales a escenarios de prueba.

Los [escenarios operativos](contexts/agency/evaluacion-operativa.md) definen cómo comprobar coordinación, cambios de stack, contenido externo e indisponibilidad de herramientas. Están preparados para ejecución; no se contabilizan como resultados reales sin evidencia.

## Producción Audiovisual 2D+3D y Diseño Sonoro Pro (Fase 2 · Estándar Cartoon Editorial)

Una vez aprobada la base del guion en Fase 1, la producción audiovisual cuenta con sus herramientas dedicadas:
- **Estándar visual y de personajes por defecto:** `estilo-cartoon-editorial-3d` (`video-studio/shared-art/cartoon/`). Todos los personajes nuevos según el tema del video (granjero, profesor, fisiculturista, científico, etc.) se crean bajo la misma línea gráfica de tinta negra `#0b0d10`, rellenos planos *flat cel* e IK de 2 segmentos (`estilo-kiwi-kurzgesagt-3d` y los demás estilos siguen disponibles como alternativa en el cuestionario).
- **Estrategia narrativa, ganchos y evaluación predictiva:** `preproduccion-social-video` + `estrategia-narrativa-ganchos-retencion` + [agente de redes sociales](agentes/redes-sociales.md) + [agente estratega narrativo](agentes/agente-estratega-narrativo.md) (`evaluar_guion.py` antes de sintetizar voz).
- **Curación de audio anti-repetición y SFX ricos:** `python3 ../video-studio/scripts/buscar_audio.py --historia "<sinopsis>" --evitar-recientes` respaldado por `audio_usage_history.json` y 12–20 SFX calibrados/minuto sin tapar la voz.
- **Almacenamiento automático de ideas (`video-studio/mis-ideas/`):** Toda idea o historia generada se guarda automáticamente como `[DD de mes de YYYY] - [Categoría] - Nombre del tema.md` (carpeta privada excluida en `.gitignore`).
- **Gateway Multi-Cuenta y Selector Dinámico de Voces ElevenLabs:** El backend (`video-studio/backend/services/elevenlabs_gateway.py`) rota automáticamente entre hasta 6+ API keys configuradas en `video-studio/backend/.env` (`ELEVENLABS_API_KEY_1..6`) verificando salud y créditos restantes (`/v1/user/subscription`). Antes de sintetizar, consultar voces reales con `python3 ../video-studio/scripts/elevenlabs_cli.py voces` (filtrable con `--edad young`, `--genero male|female`) y saldo del pool con `elevenlabs_cli.py estado`.
- **Tríada de Diseño Sonoro Pro (Auditada e Integrada en Fase 2):**
  - `earshot` + `real-sound` (`Leonxlnx/earshot`, MIT · CLI local `earshot 1.0.0`): da "oídos" locales en CPU para medir LUFS, True Peak dBTP, brillo y desfases (`earshot measure`), y fabricar SFX limpios aprendidos de dominio público (`earshot make`, `earshot make --set film`, 922 diseños / 252 sonidos en banco). *(Opcional para escucha neural CLAP/AST `timeline`/`critique`: `uv tool install --force "earshot[all] @ git+https://github.com/Leonxlnx/earshot"`).*
  - `real-sfx` (`Clipwing/skills`, scripts MIT + 78 cues UI `uisfx` CC0): analiza el video renderizado (`look.py`, `find_moments.py`, `from_cues.py`), coloca efectos reales de nuestra librería local `video-studio/assets/sfx` (`169` audios ya indexados) en el fotograma exacto respetando voz y música (`mix.py --voice-safe --duck`) y ejecuta autocrítica acústica (`critique.py`, `levels.py`).
  - `openverse-audio` (adaptador nativo MIT sobre la API oficial de WordPress Foundation `https://api.openverse.org/v1/audio/`): búsqueda y descarga directa sin clave ni proxys de terceros entre **5M+ audios con licencia abierta (`CC0`/`PDM`/`CC-BY`)**, medición automática con FFmpeg y generación de `CREDITS.md` (`skills/audio-pro-skills/openverse-audio/scripts/buscar_openverse.py`).
- **Imágenes reales e IA (opcional y meditado):** Recortes descargados de internet o fondos/insertos generados con Gemini (`image-generator`) solo cuando ayuden a entender o potenciar la historia.

## Coordinación persistente

El [plan operativo](reglas/operacion-tareas.md) registra responsables, archivos y dependencias sin iniciar agentes. CLI `tareas` administra transiciones y revisiones; MCP `agencia_plan` consulta el mismo almacén. Un cierre pierde vigencia si cambian sus artefactos, su informe, su evidencia o un antecesor. Las fases anteriores se archivan y las escrituras son transaccionales.
