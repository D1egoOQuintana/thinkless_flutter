# ThinkLess — Design System Target (para Google Stitch)

> Sistema de diseño objetivo para el prototipo en Stitch. La **base** son los
> tokens reales del código (`app_colors.dart` + `_buildAppTheme`), para que el
> rediseño sea coherente con la marca. Al final hay una sección de **propuestas
> de evolución** claramente separada.
>
> Modo objetivo: **Dark mode, mobile-first, español.**

---

## 1. Fundamentos

- **Modo:** dark. Fondos **slate azulado**, nunca negro puro.
- **Marca:** violeta tecnológico `#7C5CFF` con *glow* sutil.
- **Tono:** premium, calmado, productivo (Linear / Arc / Stripe).
- **Densidad:** media-baja, mucho aire, jerarquía por tamaño y peso de fuente.
- **Esquinas:** radios moderados (8–20px), pills para chips/badges.
- **Profundidad:** lograda por **capas de superficie** + sombras suaves, no por
  bordes duros.

---

## 2. Color tokens (reales — usar tal cual)

### Superficies (jerarquía de profundidad, de fondo a primer plano)
| Token | HEX | Uso |
|-------|-----|-----|
| background | `#0A0B11` | shell de la app |
| surfaceLowest | `#0D0F16` | bottom nav, modales, sheets |
| surface | `#11131B` | base de pantalla |
| surfaceContainer | `#161924` | cards primarias |
| surfaceVariant | `#1B1E2B` | cards alternas |
| surfaceHigh | `#1F2330` | hover, inputs |
| surfaceHighest | `#272B3A` | pressed, overlays |

### Bordes
| Token | HEX | Uso |
|-------|-----|-----|
| outlineSubtle | `#1D2030` | hairlines |
| outlineVariant | `#252938` | borde sutil (default de cards) |
| outline | `#323748` | borde marcado |

### Texto
| Token | HEX | Uso |
|-------|-----|-----|
| onSurface | `#F4F5FA` | texto primario |
| onSurfaceVariant | `#B0B5C7` | texto secundario |
| secondary | `#7A7F92` | terciario / muted |
| onPrimary | `#FFFFFF` | sobre acento |

### Marca (violeta)
| Token | HEX | Uso |
|-------|-----|-----|
| primary | `#7C5CFF` | acción principal, acento |
| primaryHover | `#8E72FF` | hover |
| primaryPressed | `#6A48F0` | pressed |
| primaryContainer | `#231B4D` | fondo tinteado |
| violetLight | `#B7A4FF` | íconos/labels sobre tinte |
| indigo | `#5B6CFF` | gradientes |

### Semánticos (cada uno con variante *Soft* para fondos tinteados)
| Token | HEX | Soft | Significado |
|-------|-----|------|-------------|
| mint | `#3DDC97` | `#153026` | éxito / completada |
| blue | `#5B9DFF` | `#12233D` | info / accent |
| yellow | `#FFB547` | `#332512` | warning / prioridad media |
| pink | `#FF6FA8` | `#331824` | destacado / urgente |
| error | `#FF5C72` | `#301318` | urgente / error / destructivo |

### Mapeo de prioridad → color (consistencia obligatoria)
- **urgente** → error/pink (rojo) · **alta** → pink · **media** → yellow ·
  **baja** → mint.

---

## 3. Tipografía

- **Display / títulos:** **Plus Jakarta Sans**, pesos 700–800, *tracking
  negativo* (−0.2 a −1.4), interlineado ajustado (1.05–1.3).
- **Cuerpo / labels:** **Inter**, pesos 400–600.

Escala (referencia del TextTheme real):

| Rol | Fuente | Tamaño | Peso | Tracking |
|-----|--------|--------|------|----------|
| displayLarge | Jakarta | 40 | 800 | −1.4 |
| displayMedium | Jakarta | 32 | 800 | −1.0 |
| displaySmall | Jakarta | 26 | 800 | −0.7 |
| headlineLarge | Jakarta | 22 | 800 | −0.5 |
| headlineMedium | Jakarta | 19 | 700 | −0.35 |
| headlineSmall | Jakarta | 16 | 700 | −0.2 |
| titleLarge | Jakarta | 15 | 700 | −0.15 |
| titleMedium | Inter | 14 | 600 | −0.1 |
| bodyLarge | Inter | 15 | 400 | — (línea 1.5) |
| bodyMedium | Inter | 14 | 400 | — (línea 1.5) |
| bodySmall | Inter | 12.5 | 400 | — |
| label* | Inter | 11–13 | 600 | +0.1 a +0.4 |

---

## 4. Espaciado (sistema 8pt)

`xs 4 · sm 8 · md 12 · lg 16 · xl 20 · xxl 24 · xxxl 32`.
Padding de pantalla típico: **20px** horizontal. Padding de card: **16–20px**.

---

## 5. Radios

`xs 8 · sm 10 · md 12 · lg 14 · xl 16 · xxl 20 · pill 999`.
- Cards: 12–16. Sheets/modales: 24–28 (solo esquinas superiores). Chips/badges:
  pill. Inputs: 12.

---

## 6. Sombras y glow

- **sm:** negro 20%, blur 8, y+2 → cards sutiles.
- **md:** negro 28%+18%, blur 16/4 → cards elevadas.
- **lg:** negro 40%+20%, blur 28/8 → modales/FAB.
- **brand(glow):** violeta `#7C5CFF` (opacidad ~22–45%), blur 24, y+8 → elementos
  de marca (FAB, Premium, logo). Usar con moderación.

---

## 7. Motion

- Duraciones: **fast 140ms · base 220ms · slow 340ms**.
- Curvas: `easeOutCubic` (emphasized), `easeOutQuart` (standard).
- Transición entre pantallas: fade/switch ~220ms.
- Microinteracciones: escala suave en press, pulse en orbe de voz y timer ring,
  "now indicator" en calendario.

---

## 8. Componentes (especificación visual mínima)

| Componente | Forma | Notas |
|------------|-------|-------|
| **AppCard** | radius 14–16, surfaceContainer, borde outlineVariant | opción "stripe" lateral de color (estado/categoría) |
| **TaskCard** | fila: checkbox mint + título + meta + punto prioridad | estado completada = texto tachado/atenuado, check mint |
| **PriorityBadge** | pill tinteado | color según prioridad (§2) |
| **InfoChip / MetaChip** | pill, icono + texto, fondo tinteado | metadatos (fecha, hora, materia, duración) |
| **PrimaryButton / FilledButton** | radius 12, violeta, texto blanco 700 | sin elevación, padding 18×14 |
| **OutlinedButton** | radius 12, borde outline | secundario |
| **Botón destructivo** | fondo errorContainer, texto onErrorContainer | eliminar |
| **GradientFab** | círculo, gradiente violeta→indigo + glow | acción "+" |
| **Bottom Nav** | surfaceLowest, indicador violeta 16% en activo | ícono outline/filled, label 11px |
| **Input** | filled surfaceContainer, radius 12, foco borde violeta 1.4 | hint en secondary |
| **Chip seleccionable** | pill, selección = tinte violeta 18% | sin checkmark |
| **Switch** | track violeta on / surfaceHighest off | thumb blanco |
| **SegmentedButton** | selección tinte violeta 20%, texto violetLight | intensidad de alertas, modos de calendario |
| **TimerRing** | anillo progresivo violeta | cuenta regresiva, pulse |
| **EmptyStateCard** | card con icono + título + cuerpo + acciones | estados vacíos |
| **_StatusCard** | icono + título + cuerpo, variantes warning/danger | estados de voz |
| **SnackBar** | surfaceHigh, flotante, radius 12 | feedback |

---

## 9. Reglas de aplicación

- **Una sola fuente de verdad de color por prioridad** (§2). No mezclar.
- **Texto secundario siempre atenuado** (onSurfaceVariant/secondary), nunca
  blanco pleno para metadatos.
- **Glow violeta** reservado a marca/acción principal; no en todo.
- **Cada pantalla con lista** define su **estado vacío** con `EmptyStateCard`.
- **Iconografía:** Material Icons *rounded*, tamaño base 20–22.
- **Contraste:** cumplir legibilidad sobre fondos slate (texto ≥ onSurfaceVariant).

---

## 10. PROPUESTAS DE EVOLUCIÓN (opcionales — no son el sistema actual)

> Stitch puede explorar estas direcciones como *variantes*, manteniendo los
> tokens base como fallback. Marcar claramente cualquier mockup que las use.

- **EV1 — Glass/Depth:** introducir blur sutil (glassmorphism) en sheets, banner
  de Enfoque Total y nav, reforzando la sensación de capas de Arc/visionOS.
- **EV2 — Acento dual:** complementar el violeta con un secundario frío (blue
  `#5B9DFF`) para datos/calendario, dando más riqueza sin romper la marca.
- **EV3 — Tema claro (light):** definir el set de tokens en light mode para
  paridad (hoy "Apariencia" es simulada). Solo si se confirma soporte.
- **EV4 — Skeletons:** reemplazar el spinner global por skeletons por sección
  (Home, Calendario) para percepción de velocidad.
- **EV5 — Densidad configurable:** variante compacta de TaskCard para usuarios
  con muchas tareas.
- **EV6 — Tipografía display más audaz:** subir el peso/tamaño del título de Home
  para más personalidad (manteniendo Jakarta).

---

## 11. Checklist para Stitch (token compliance)

- [ ] Dark mode con jerarquía de 7 superficies.
- [ ] Violeta `#7C5CFF` como único acento de marca.
- [ ] Colores de prioridad consistentes en TODA la app.
- [ ] Jakarta (títulos) + Inter (cuerpo), con la escala de §3.
- [ ] Espaciado 8pt, padding de pantalla 20px.
- [ ] Radios y sombras según §5–§6.
- [ ] Estados vacío/loading/error/success por pantalla (ver `SCREEN_INVENTORY.md`).
- [ ] Componentes reutilizados (no rediseñar el mismo elemento dos veces).
- [ ] Español en todo el copy.
