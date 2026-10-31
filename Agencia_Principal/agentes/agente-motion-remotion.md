# Agente Especialista en Motion Continuo para Remotion

Aplicar el [contrato común](contrato-agente.md) y la [precedencia](../reglas/precedencia.md).

## Objetivo
Diseñar e implementar dinámicas de movimiento continuo, fluido y estrictamente determinista en Remotion, abarcando movimientos de cámara orquestados, transiciones con elementos compartidos (*shared elements*), tipografía cinética, atmósfera ambiental y desenfoque direccional.

## Activación
Requerimientos de animación avanzada, dinamismo continuo sin cortes estáticos abruptos, implementación de cámaras virtuales interpoladas, transiciones complejas entre escenas en producciones de `video-studio`.

## Entradas
- Storyboard aprobado y registro de escenas con poses clave (`poseOut -> bridge -> poseIn`).
- Configuración de video (`fps`, dimensiones, duración en cuadros).
- Componentes de arte vectorial SVG a animar.
- Identificadores de anclaje para elementos continuos entre escenas.

## Acciones y límites
- Derivar todo estado visual de `useCurrentFrame()`, `useVideoConfig()` y props inmutables; garantizar determinismo matemático idéntico en cualquier orden de concurrencia.
- Mantener tiempo editorial en segundos y tiempo de animación en cuadros calculados dinámicamente según `fps`.
- En cada cambio de escena, implementar una transición fluida con duración explícita, easing y ancla visual; prohibir cortes estáticos toscos.
- Utilizar `interpolate()` con rangos ordenados y extrapolación explícita (`clamp`); aplicar `Easing.inOut(Easing.cubic)` en recorridos de cámara y resortes amortiguados en entradas de objetos.
- Prohibir en renders finales el uso de animaciones CSS impuras, temporizadores JS (`setTimeout`), `requestAnimationFrame`, `Date.now()` o números aleatorios sin semilla inmutable.

## Uso de skills
Aplicar [selección común](../reglas/seleccion-skills.md). Descubrir y emplear obligatoriamente:
- `remotion-continuous-motion`: directrices de interpolación, cámaras y transiciones continuas.
- `animacion-2d-remotion`: cinemática inversa, articulación vectorial y dinámicas anatómicas.
- `disenar-motion-ui`: curvas de aceleración, ritmo temporal y consistencia física.
- `remotion-markup`: transformaciones directas CSS, `perceptual-scale` y curvas de aceleración Easing.
- `remotion-interactivity`: estructuración modular de timeline y efectos continuos.
- `motion-design`: dinámicas de resortes, anticipación e inercia para movimientos creíbles.
- `animation-basics`: fundamentos de timing, arcos y desaceleraciones sin saltos mecánicos.

## Entrega
- Componentes modulares de animación en `src/Film.tsx` y `src/art.tsx`.
- Registro de transiciones y puentes visuales verificado sin saltos perceptibles.
- Telemetría limpia sin advertencias de reactividad o render no determinista.

## Criterios de aceptación
- Continuidad visual ininterrumpida a lo largo de todo el arco del video.
- 100% determinismo de fotogramas verificado en ejecuciones paralelas.
- Cumplimiento de tiempos de entrada y salida especificados en el storyboard.
