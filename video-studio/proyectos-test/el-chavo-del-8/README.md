# Proyecto Test: El Chavo del 8 (2D Vectorial y Animado)

Ubicación oficial: `video-studio/proyectos-test/el-chavo-del-8/`

Este proyecto test contiene la implementación, rigging y puesta en escena animada de **El Chavo del 8**, estructurado en dos ejemplos completos conforme a las directrices de la agencia.

---

## Ejemplos Disponibles

### 1. Ejemplo 1: Réplica Fiel de Referencia (`ChavoScene.tsx`)
- **Descripción:** El Chavo sentado en el piso de la vecindad junto al barril de madera, sujetando el carrito de juguete rojo con parabrisas celeste y pernera extendida.
- **Renderizado de comprobación:** `renders/ejemplo-1-sentado-carrito.png`
- **Composición Remotion:** `ChavoEjemplo1Sentado`

### 2. Ejemplo 2: Asomado en el Barril (`ChavoBarrelScene.tsx`)
- **Descripción:** El Chavo ubicado dentro de su barril con profundidad por capas (interior -> cuerpo -> madera frontal -> manos en el borde -> cabeza con gorro). Cuenta con ciclo animado de asomarse (*peek-a-boo*), mirar con curiosidad de lado a lado, sonreír, hablar y ocultarse.
- **Renderizado de comprobación:** `renders/ejemplo-2-asomado-barril.png`
- **Composición Remotion:** `ChavoEjemplo2Barril`

---

## Estructura de Archivos

```
video-studio/proyectos-test/el-chavo-del-8/
├── README.md                           (Esta documentación)
├── preview.html                        (Visor interactivo en navegador para conmutar Ejemplo 1 y 2 a 60 FPS)
├── src/
│   ├── ChavoRig.tsx                    (Rig vectorial anatómico del personaje con todas las expresiones y poses)
│   ├── ChavoScene.tsx                  (Escena del Ejemplo 1)
│   ├── ChavoBarrelScene.tsx            (Escena del Ejemplo 2)
│   └── index.ts                        (Punto de entrada exportable)
└── renders/
    ├── ejemplo-1-sentado-carrito.png   (Render de comprobación E1)
    └── ejemplo-2-asomado-barril.png    (Render de comprobación E2)
```

---

## Cómo Ejecutar y Probar

1. **Visor Interactivo HTML:**
   Abre directamente `preview.html` en cualquier navegador web. Permite alternar entre los dos ejemplos en tiempo real, pausar la animación, cambiar estados de ánimo (neutral, sonrisa, hablar, llorar) y mover la dirección de la mirada.

2. **Renderizado o Preview con Remotion:**
   Desde la carpeta `video-studio/remotion`:
   ```bash
   # Previsualizar en Remotion Studio
   npm start

   # Renderizar un still del Ejemplo 1
   npx remotion still src/index.ts ChavoEjemplo1Sentado renders/test-e1.png

   # Renderizar un still del Ejemplo 2
   npx remotion still src/index.ts ChavoEjemplo2Barril renders/test-e2.png
   ```
