# ThinkLess — User Flows (para Google Stitch)

> Flujos de navegación **reales** (derivados de `AppView`, `_buildView`,
> `_navigate`, callbacks y bottom sheets). Sirven para que Stitch conecte las
> pantallas del prototipo correctamente, sin inventar rutas.
>
> Notación: `→` navega a · `⤢` abre bottom sheet/modal · `⏎` vuelve atrás ·
> `[FAB]` botón +, `[nav]` barra inferior.

---

## 0. Modelo de navegación (cómo funciona)

- Navegación **por estado** (enum `AppView`), no stack tradicional. Hay un
  `_previousView` para volver desde pantallas full-screen.
- **Con bottom nav (shell):** Home, Calendario, Enfoque, Matriz, Más/Perfil.
- **Full-screen (sin nav):** Onboarding, Voz, Escáner, Detalle, Prioridades,
  Revisión del día. Estas vuelven a la pantalla previa con back.
- **Bottom sheets/modales** se abren sobre cualquier pantalla.

```
Bottom Nav: [ Tareas ] [ Calendario ] [ Enfoque ] [ Matriz ] [ Más ]
FAB (+) visible en: Tareas, Calendario, Matriz
```

---

## FLUJO 1 — Arranque y onboarding
```
App abre
  → Loading global (spinner)
  → ¿Primera vez? 
        Sí → Onboarding → [Comenzar] → Home
        No → Home
```

---

## FLUJO 2 — Captura rápida de tarea (núcleo del producto)
```
Cualquier pantalla con [FAB]
  ⤢ Captura Rápida (sheet)
       ├─ Modo Texto:  escribe + chips → [Agregar] → ⏎ (tarea creada) → Home actualizado
       ├─ Modo Voz:    → Pantalla Voz e IA   (ver Flujo 3)
       └─ Modo Escaneo:→ Pantalla Escáner    (ver Flujo 4)
```

---

## FLUJO 3 — Crear tarea por VOZ (IA)
```
Captura Rápida ▸ Voz   (o Home vacío ▸ "Voz IA")
  → Voz e IA
       idle → (hablar) → listening → processing → result
                                                      → [Agregar] → ⏎ tarea creada
       Ramas de error:
         busy → Modo Reunión (push-to-talk) → processing → result
         reconnecting → reintenta → listening
         error (permiso/red/sin voz) → card de error → reintentar
  ⏎ back → vuelve a pantalla previa
```

---

## FLUJO 4 — Crear tareas por ESCANEO (IA)
```
Captura Rápida ▸ Escaneo   (o Home vacío ▸ "Escanear")
  → Escáner
       [Cámara/Galería] → Loading → 
            éxito → lista de tareas detectadas (selección múltiple)
                       → [Agregar seleccionadas] → ⏎ tareas creadas
            error → mensaje + tareas de ejemplo (fallback)
  ⏎ back → pantalla previa
```

---

## FLUJO 5 — Ver / editar / completar / eliminar una tarea
```
Home (o Matriz, Calendario) ▸ toca una tarea
  → Detalle de Tarea
       ├─ [Marcar completada/pendiente]  (toggle, barra inferior)
       ├─ [Editar] ⤢ Editar Tarea (sheet) → [Guardar] → ⏎ actualizada
       └─ [Eliminar] → ⏎ Home (tarea removida)
  ⏎ back
```

---

## FLUJO 6 — Priorizar tareas (swipe)
```
Home ▸ "Priorizar"  (FeatureTile)
  → Organizador de Prioridades
       carta activa → swipe/acción asigna prioridad → siguiente carta
       sin más cartas → estado vacío "todo priorizado"
  ⏎ back → Home
```

---

## FLUJO 7 — Enfoque / Pomodoro
```
[nav] Enfoque   (o Home ▸ "Pomodoro")
  → Enfoque (idle)
       ⤢ seleccionar tarea (_TaskPickerSheet)  [opcional]
       elegir duración 25/45/60
       [Iniciar] → running (TimerRing)
            ├─ [Pausar] → paused → [Reanudar]
            └─ fin de tiempo → sesión completada (stats +1)
```

### 7b — Enfoque Total (modo persistente)
```
Home ▸ FocusTotalCard ▸ [Activar]
  ⤢ sheet Activar Enfoque Total (elige duración) → activa
  → Banner global de Enfoque Total visible en todas las pantallas (shell)
       toca banner → abre Enfoque
       [Detener] en banner → desactiva
```

---

## FLUJO 8 — Calendario
```
[nav] Calendario
  → Calendario
       selector de modo: Mes ⇄ Semana ⇄ Día
       toca un día/bloque → (abre tarea / detalle según vista)
  [FAB] ⤢ Captura Rápida
```

---

## FLUJO 9 — Matriz Eisenhower
```
[nav] Matriz   (o Home ▸ "Matriz Eisenhower")
  → Matriz (4 cuadrantes: Hacer Ya / Agendar / Delegar / Eliminar)
       toca tarea → Detalle  ·  toggle completa
  [FAB] ⤢ Captura Rápida
```

---

## FLUJO 10 — Tiempo libre
```
Home ▸ "Tiempo libre"
  ⤢ Tiempo Libre (sheet)
       elige duración (chips / personalizada)
       elige una SuggestionCard → inicia Enfoque con esa tarea/duración
       (sin sugerencias → estado vacío)
```

---

## FLUJO 11 — Revisión del día
```
Home ▸ "Revisión del día"
  → Revisión del Día
       ve métricas + completadas
       reprograma tareas (chips)
       ve preview de mañana
       (sin datos → estado vacío)
  ⏎ back → Home
```

---

## FLUJO 12 — Más / Perfil / Ajustes
```
[nav] Más
  → Perfil
       ├─ Notificaciones → Alertas (Flujo 13)
       ├─ Apariencia / Idioma / Ayuda → toast (simulado)
       ├─ Premium → ⤢ Modal Premium
       └─ Cerrar sesión → toast (simulado)
```

---

## FLUJO 13 — Alertas y No Molestar
```
Perfil ▸ Notificaciones  (o entrada directa a Alertas)
  → Alertas
       ├─ No Molestar (NoMolestarCard) → editar horarios → guarda
       ├─ Intensidad: Suave / Normal / Insistente
       └─ Toggles: Tareas urgentes · Repaso diario · Pausas activas
```

---

## FLUJO 14 — Premium (informativo)
```
Home ▸ card "Premium"   o   Perfil ▸ Premium
  ⤢ Modal Premium (beneficios, CTA — sin pago real)
```

---

## MAPA RESUMEN DE NAVEGACIÓN

```
Onboarding ──► Home ◄──────────────┐
                │  ▲                │
   [nav]────────┼──┴── Calendario   │
                │      Enfoque ◄─ Enfoque Total (banner global)
                │      Matriz       │
                │      Más ─► Perfil ─► Alertas
                │
   [FAB]►Captura Rápida ─► (Texto) / Voz / Escáner
                │
   tocar tarea ─► Detalle ─► Editar (sheet)
                │
   Home tiles ─► Priorizar / Tiempo libre / Revisión del día / Pomodoro
```

**Destinos terminales que siempre vuelven atrás (⏎):** Voz, Escáner, Detalle,
Prioridades, Revisión del día.

**Puntos de entrada a "crear tarea":** FAB (todas), Home vacío (Voz/Escanear),
Captura Rápida (3 modos).
