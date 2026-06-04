# ThinkLess — Design Brief (para Google Stitch)

> Paquete de contexto para rediseñar el **prototipo completo** de ThinkLess en
> Google Stitch **sin screenshots**. Este documento describe qué es la app, para
> quién, qué tono visual buscamos y las reglas que Stitch debe respetar.
> Acompaña a: `SCREEN_INVENTORY.md`, `USER_FLOWS.md`, `DESIGN_SYSTEM_TARGET.md`.

---

## 1. Qué es ThinkLess

App **móvil de productividad y gestión de tareas para estudiantes**. El usuario
captura tareas rápido (texto, **voz con IA**, o **escaneo de apuntes con IA**),
las organiza por prioridad, las ve en un **calendario**, trabaja con un
**temporizador de enfoque (Pomodoro)** y un **modo Enfoque Total**, y revisa su
día. Toda la data es **local** (sin cuentas ni backend hoy).

- **Plataforma objetivo:** móvil (mobile-first). Responsive real a tablet.
- **Tema actual:** dark mode premium estilo Linear/Arc.
- **Idioma de la UI:** **español**.
- **Marca:** acento violeta (`#7C5CFF`), tono tecnológico y calmado.

---

## 2. Público y necesidad

- **Usuario:** estudiante (secundaria/universidad) con sobrecarga de tareas.
- **Job-to-be-done:** "Quiero sacar lo que tengo en la cabeza rápido y que la app
  me diga qué hacer ahora sin pensar tanto" → de ahí el nombre **ThinkLess**
  ("Menos caos. Más hecho.").
- **Momentos de uso:** captura rápida entre clases, planificación nocturna
  (revisión del día), sesiones de estudio enfocado.

---

## 3. Principios de diseño (norte para Stitch)

1. **Menos fricción que decisión.** Capturar una tarea debe costar 1–2 toques.
2. **Jerarquía visual fuerte.** Tipografía grande y confiada para títulos; texto
   secundario claramente atenuado.
3. **Premium, no genérico.** Evitar el look "plantilla AI". Profundidad real por
   capas de superficie, no bordes planos sin vida.
4. **Calma productiva.** Color usado con intención (estado/acción/prioridad), no
   decorativo. Espaciado generoso y consistente (sistema 8pt).
5. **Microinteracciones suaves.** Transiciones fluidas, feedback inmediato,
   animaciones rápidas (~140–340ms). Nunca exageradas.
6. **Consistencia total.** Mismos componentes (cards, chips, botones, badges) en
   todas las pantallas.

**Inspiración visual:** Linear, Arc, Vercel, Stripe, Notion, Framer.

---

## 4. Identidad visual de referencia (estado actual)

> Esto describe el sistema **actual** para que Stitch tenga una base. La
> dirección final de color/tema se detalla en `DESIGN_SYSTEM_TARGET.md`.

- **Modo:** dark. Fondos slate azulado, **nunca negro puro** (`#0A0B11` base).
- **Jerarquía de superficies:** 7 niveles de profundidad (background → cards →
  hover/pressed) que dan sensación de capas.
- **Acento de marca:** violeta `#7C5CFF` + `violetLight #B7A4FF`, con *glow* suave.
- **Colores semánticos:** mint (éxito/hecho), blue (info), yellow (warning/media),
  pink (urgente/destacado), error/rojo (urgente).
- **Tipografía:** Plus Jakarta Sans (display/títulos, peso 700–800, tracking
  negativo) + Inter (cuerpo/labels). 
- **Forma:** radios moderados (8–20px), pills para chips. Sombras suaves y
  profundas; glow violeta en elementos de marca.
- **Iconografía:** Material Icons *rounded*.

---

## 5. Funcionalidades REALES que el diseño debe soportar

> Solo lo que existe en el código. No inventar features.

- Lista de tareas con completar/abrir/editar/eliminar.
- Prioridades: **urgente · alta · media · baja**.
- Captura rápida (bottom sheet) con 3 modos: **texto, voz, escaneo**.
- **Voz con IA** (dictado → IA estructura la tarea) con manejo de errores y
  "Modo Reunión" (push-to-talk cuando el micrófono está ocupado).
- **Escaneo con IA** (foto de apuntes → IA detecta varias tareas; selección
  múltiple antes de agregar).
- **Calendario** en 3 vistas: mes / semana / día (rango 6 AM – 12 AM).
- **Matriz Eisenhower** (4 cuadrantes).
- **Organizador de prioridades** por swipe (estilo cartas).
- **Enfoque / Pomodoro** (duraciones 25/45/60, sesiones planificadas, stats del
  día) + **Enfoque Total** (modo persistente con banner global y temporizador).
- **Tiempo libre** (sugerencias de qué hacer en un hueco).
- **Revisión del día** (métricas, completadas, reprogramar, vista de mañana).
- **Alertas** (intensidad Suave/Normal/Insistente, toggles, **No Molestar** con
  horarios) — varios valores hoy son simulados.
- **Perfil/Ajustes** (avatar, ajustes, premium) — varios ítems simulados.
- **Onboarding** de 1 pantalla.
- **Premium** (modal informativo, sin pago real).

---

## 6. Restricciones que Stitch NO debe romper

- **No agregar features inexistentes** (ej. login social, sync en la nube,
  bloqueo real de apps). Si se proponen, marcarlas como *propuesta*.
- **Navegación de 5 destinos** en barra inferior: Tareas · Calendario · Enfoque ·
  Matriz · Más. Mantener este modelo (ver `USER_FLOWS.md`).
- **Mobile-first.** Cada pantalla debe verse perfecta en una columna estrecha.
- **Idioma español** en todos los textos.
- **Estados completos:** cada pantalla con datos debe diseñar también su estado
  **vacío, loading, error y success** (ver `SCREEN_INVENTORY.md`).
- **Sin texto placeholder tipo "Lorem ipsum".** Usar copy realista en español.

---

## 7. Datos reales para poblar mockups (usar estos, no inventar otros)

- **Prioridades y colores:** urgente=rojo/pink, alta=pink, media=yellow, baja=mint.
- **Campos de tarea:** título, materia, fecha, hora, prioridad, tipo, duración
  (min), etiquetas, notas, completada.
- **Ejemplos de copy existentes:**
  - Bienvenida: "Bienvenido" / "Tu día, organizado".
  - Vacío de tareas: "No hay tareas todavía" + acciones "Voz IA" y "Escanear".
  - Cuadrantes matriz: "Hacer Ya / Agendar / Delegar / Eliminar".
  - Alertas: "Tienes 45 min libres", intensidad "Suave/Normal/Insistente".
  - Onboarding: "ThinkLess — Menos caos. Más hecho. — Comenzar".

---

## 8. Entregable esperado de Stitch

Un **prototipo navegable completo** que cubra **todas** las pantallas de
`SCREEN_INVENTORY.md` (principales + secundarias + bottom sheets + estados),
conectadas según `USER_FLOWS.md`, aplicando el sistema visual de
`DESIGN_SYSTEM_TARGET.md`, en **dark mode móvil, español**.

---

## 9. Propuestas de mejora UX (OPCIONALES — no son requisitos)

> Separadas a propósito. Stitch puede explorarlas, pero no deben reemplazar las
> pantallas reales ni implicar lógica nueva.

- **P1.** Unificar "Alertas" y "Perfil/Ajustes" hoy ambos viven bajo "Más"; el
  destino "Más" podría ser un hub de ajustes claro.
- **P2.** Reemplazar datos simulados (nombre "Alex", "45 min libres", sugerencia
  IA fija) por estados reales o placeholders honestos.
- **P3.** Estado vacío con más guía en Matriz (hoy muestra tareas de ejemplo).
- **P4.** Onboarding de 3 pasos (hoy los 3 puntos sugieren pasos pero hay 1 solo).
- **P5.** Indicadores de carga/skeleton consistentes (hoy es un spinner global).
