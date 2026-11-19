# Guía y Catálogo de Locomotion Templates (Remotion)

Librería de **61 templates de animación en Remotion** (`React` + `TypeScript`, 30 fps) importada desde `https://github.com/Thedurancode/locomotion-templates.git`. Cada template es una composición modular (`src/templates/<id>/Composition.tsx`) con props editables para texto, colores, datos y variante visual.

---

## 1. Sistema de 6 Variantes Visuales (`src/lib/styles.ts` y `src/lib/useStyle.ts`)

Todos los templates que importan `getCompositionStyles(variant)` soportan 6 estilos intercambiables mediante la prop `variant`:

| Variante (`variant`) | Estilo Visual |
| :--- | :--- |
| `default` | Limpio, esquinas de `12px`, tipografía equilibrada |
| `brutalist` | Bordes marcados (`3px`), esquinas rectas, alto contraste |
| `rounded` | Esquinas suaves (`24px`), estética amigable |
| `minimal` | Ultra delgado, radio mínimo (`4px`), aireado |
| `glass` | Superficies translúcidas tipo glassmorphism |
| `neo` | Sombras sólidas/coloreadas estilo neo-brutalismo moderno |

> Al integrar un template en `video-studio/projects/<slug>/src/`, copia `src/lib/styles.ts` y `src/lib/useStyle.ts` o reemplaza `getCompositionStyles` por la paleta y tipografía definidas con `ui-ux-pro-max` e `impeccable`.

---

## 2. Catálogo Completo (61 Templates en 15 Categorías)

### Text (5)
- `fade-slide-up` (`FadeSlideUp`, 1s) — Entrada suave con desplazamiento vertical y opacidad.
- `spring-scale-in` (`SpringScaleIn`, 1s) — Aparición elástica con resorte (`spring`).
- `typewriter-reveal` (`TypewriterReveal`, 3s) — Revelado progresivo tipo máquina de escribir.
- `staggered-words` (`StaggeredWords`, 3s) — Aparición escalonada palabra por palabra.
- `gradient-text` (`GradientText`, 3s) — Tipografía animada con degradado dinámico.

### SaaS (7)
- `modal-explainer` (`ModalExplainer`, 5s) — Explicación de producto centrada en ventana modal.
- `drag-drop-demo` (`DragDropDemo`, 5s) — Simulación animada de arrastrar y soltar.
- `feature-showcase` (`FeatureShowcase`, 5s) — Presentación secuencial de funcionalidades clave.
- `pricing-comparison` (`PricingComparison`, 3s) — Comparativa animada de planes y precios.
- `onboarding-flow` (`OnboardingFlow`, 5s) — Flujo paso a paso de bienvenida/onboarding.
- `saas-hero` (`SaasHero`, 3s) — Hero con título, subtítulo, métricas con contador y CTA.
- `changelog` (`Changelog`, 3s) — Anuncio animado de novedades y lanzamientos.

### Explainer (3)
- `step-explainer` (`StepExplainer`, 3s) — Desglose visual por pasos numerados.
- `concept-breakdown` (`ConceptBreakdown`, 4s) — Descomposición estructurada de un concepto.
- `before-after` (`BeforeAfter`, 3s) — Comparativa directa Antes vs. Después.

### Data (4)
- `bar-chart-reveal` (`BarChartReveal`, 3s) — Gráfico de barras con crecimiento animado.
- `stats-dashboard` (`StatsDashboard`, 3s) — Panel de múltiples KPIs animados.
- `metric-card` (`MetricCard`, 3s) — Tarjeta de métrica con contador y tendencia.
- `day-summary` (`DaySummary`, 3s) — Resumen visual de actividad diaria.

### Social (8)
- `bold-text-punch` (`BoldTextPunch`, 1s) — Impacto tipográfico breve de alto contraste.
- `quote-card` (`QuoteCard`, 3s) — Tarjeta animada de cita o frase destacada.
- `product-hunt` (`ProductHunt`, 3s) — Celebración/lanzamiento estilo Product Hunt.
- `milestone-counter` (`MilestoneCounter`, 3s) — Contador animado de hitos y seguidores.
- `testimonial-card` (`TestimonialCard`, 3s) — Tarjeta de testimonio con cita y autor.
- `social-post` (`SocialPost`, 3s) — Tarjeta de publicación social con interacciones.
- `profile-card` (`ProfileCard`, 3s) — Tarjeta de perfil / presentación personal.
- `meme-card` (`MemeCard`, 3s) — Formato visual tipo meme / gancho social.

### Branding (6)
- `logo-reveal` (`LogoReveal`, 2s) — Revelado animado de marca/logotipo.
- `intro-outro` (`IntroOutro`, 3s) — Cortinilla modular de entrada o salida.
- `toggle-switch` (`ToggleSwitch`, 3s) — Transición visual mediante interruptor animado.
- `bento-grid` (`BentoGrid`, 3s) — Retícula modular tipo Bento con entrada escalonada.
- `launch-day` (`LaunchDay`, 3s) — Pieza de anuncio para día de lanzamiento.
- `collab-card` (`CollabCard`, 3s) — Tarjeta de colaboración entre marcas/equipos.

### Product (3)
- `app-feature-callout` (`AppFeatureCallout`, 3s) — Señalización animada de característica en app.
- `ui-walkthrough` (`UiWalkthrough`, 4s) — Recorrido guiado por interfaz de usuario.
- `screen-showcase` (`ScreenShowcase`, 3s) — Vitrina animada de pantalla o mockup.

### E-commerce (4)
- `product-reveal` (`ProductReveal`, 3s) — Presentación destacada de producto físico/digital.
- `discount-countdown` (`DiscountCountdown`, 3s) — Cuenta regresiva de oferta o descuento.
- `cart-animation` (`CartAnimation`, 3s) — Flujo animado de agregar al carrito.
- `sales-card` (`SalesCard`, 3s) — Tarjeta de ventas e ingresos en tiempo real.

### Education (3)
- `lesson-intro` (`LessonIntro`, 3s) — Portada animada de lección o módulo educativo.
- `flashcard-flip` (`FlashcardFlip`, 3s) — Tarjeta didáctica con giro animado.
- `quiz-result` (`QuizResult`, 3s) — Pantalla animada de resultado de evaluación.

### Finance (3)
- `stock-ticker` (`StockTicker`, 3s) — Cinta/tarjeta de cotización financiera.
- `portfolio-breakdown` (`PortfolioBreakdown`, 3s) — Desglose animado de portafolio.
- `payment-flow` (`PaymentFlow`, 3s) — Confirmación y flujo animado de pago.

### Healthcare (3)
- `patient-journey` (`PatientJourney`, 3s) — Línea de progreso de atención al paciente.
- `appointment-booking` (`AppointmentBooking`, 3s) — Tarjeta de reserva de cita médica.
- `wellness-stats` (`WellnessStats`, 3s) — Estadísticas de salud y bienestar.

### Real Estate (3)
- `property-tour` (`PropertyTour`, 3s) — Presentación animada de propiedad.
- `listing-card` (`ListingCard`, 3s) — Ficha inmobiliaria con precio y características.
- `virtual-walkthrough` (`VirtualWalkthrough`, 4s) — Recorrido virtual guiado.

### Recruitment (3)
- `job-posting` (`JobPosting`, 3s) — Tarjeta animada de vacante laboral.
- `team-intro` (`TeamIntro`, 3s) — Presentación de integrantes de equipo.
- `culture-reel` (`CultureReel`, 3s) — Pieza de cultura organizacional.

### Events (3)
- `countdown-timer` (`CountdownTimer`, 3s) — Temporizador regresivo para eventos.
- `agenda-reveal` (`AgendaReveal`, 3s) — Revelado animado de agenda o itinerario.
- `speaker-card` (`SpeakerCard`, 3s) — Tarjeta de presentación de ponente.

### Gaming (3)
- `achievement-unlock` (`AchievementUnlock`, 3s) — Banner animado de logro desbloqueado.
- `leaderboard` (`Leaderboard`, 3s) — Tabla de posiciones animada.
- `level-up` (`LevelUp`, 3s) — Animación de subida de nivel.

---

## 3. Reglas de Adaptación en Agencia Principal

1. **Adaptación Vertical (`1080x1920`) y Horizontal (`1920x1080`):** Los templates originales están diseñados para `1920x1080`. Al usarlos en `9:16`, redistribuir filas anchas a columnas (`flexDirection: 'column'`), escalar tipografía y respetar la zona libre inferior para subtítulos cinéticos (`top: 1040` en adelante).
2. **Integración con el Estándar 2D:** Consultar `src/templates/index.ts` para revisar las `editableProps` exactas de cada template antes de instanciarlo o modificarlo.
3. **Personalización Total:** No limitarse a copiar sin editar; adaptar colores, tipografías, duraciones (`fps * segundos`), cámaras y puentes visuales para mantener continuidad en `Film.tsx`.
