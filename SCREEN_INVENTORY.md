# ThinkLess — Screen Inventory (para Google Stitch)

> Inventario **exhaustivo** de pantallas, pantallas secundarias, bottom sheets,
> modales y **todos sus estados** (vacío / loading / error / success). Basado en
> el código real (`AppView`, `_buildView`, widgets de `main.dart` y features).
> Stitch debe diseñar **todo lo marcado como [OBLIGATORIO]**.
>
> Convención de estados: **Default** · **Vacío** · **Loading** · **Error** · **Success**.
> Donde un estado "no aplica", se indica `n/a`.

---

## A. CHROME / NAVEGACIÓN GLOBAL

### A1. Bottom Navigation Bar [OBLIGATORIO]
5 destinos: **Tareas (Home) · Calendario · Enfoque · Matriz · Más (Perfil)**.
Ícono outline (inactivo) / filled (activo), label corto, indicador violeta en el
activo. Altura ~68. Aparece en pantallas principales, **no** en full-screen
(voz, escáner, detalle, prioridades, revisión, onboarding).

### A2. Floating Action Button (FAB) [OBLIGATORIO]
Botón **+** con gradiente de marca. Presente en **Home, Calendario, Matriz**.
Abre el bottom sheet de **Captura Rápida** (B1). No aparece en Enfoque ni Perfil.

### A3. App Header [OBLIGATORIO]
Encabezado superior con título, opcional botón leading (back) y acciones.
Reutilizado en casi todas las pantallas.

### A4. Banner de Enfoque Total (global) [OBLIGATORIO]
Banner que aparece **encima** del contenido en todas las pantallas con shell
cuando hay una sesión de Enfoque Total activa. Muestra temporizador en vivo,
toque para abrir, botón para detener.

### A5. Splash / Loading global [OBLIGATORIO]
Mientras carga la data inicial: **spinner centrado** sobre fondo base. (Estado
real único de carga global.)

---

## B. BOTTOM SHEETS Y MODALES

### B1. Captura Rápida — `QuickCaptureSheet` [OBLIGATORIO]
Bottom sheet con **3 modos** (tabs): **Texto · Voz · Escaneo**.
- **Texto:** campo de input + **chips inteligentes** (sugerencias de materia,
  fecha, prioridad), botón "Agregar".
- **Voz:** card que redirige a la pantalla de Voz (D1).
- **Escaneo:** card que redirige a la pantalla de Escáner (D2).
- **Estados:** Default (texto listo) · Success (tarea agregada → cierra) ·
  los modos voz/escaneo son redirecciones.

### B2. Editar Tarea — `TaskEditSheet` [OBLIGATORIO]
Bottom sheet de **edición completa**: título, materia, **prioridad** (pills:
urgente/alta/media/baja), **fecha** (presets + custom), **hora** (presets +
custom), **duración**, **etiquetas** (chips), **notas**. Botones guardar/cancelar.
- **Estados:** Default (con datos) · Vacío (tarea nueva, campos placeholder).

### B3. Tiempo Libre — `FreeTimeSheet` [OBLIGATORIO]
Sheet de sugerencias para un hueco: selector de duración (chips + duración
personalizada vía diálogo), lista de **SuggestionCard** (qué hacer).
- **Estados:** Default (sugerencias) · **Vacío** (`_EmptySuggestions`: sin
  sugerencias) · Success (al elegir → inicia enfoque).

### B4. Activar Enfoque Total — sheet [OBLIGATORIO]
Sheet para configurar/activar el modo Enfoque Total (duración, confirmación).
`_FocusTotalDurationGrid` con opciones de duración.

### B5. Selector de Tarea para Enfoque — `_TaskPickerSheet` [OBLIGATORIO]
Sheet con lista de tareas no completadas para asociar al Pomodoro.
- **Estados:** Default (lista) · Vacío (sin tareas) · opción "sin tarea".

### B6. Modal Premium [OBLIGATORIO]
Modal informativo de Premium (beneficios, CTA). Sin pago real.

### B7. Diálogo Duración Personalizada — `_CustomDurationDialog` [SECUNDARIO]
Diálogo para ingresar minutos personalizados (usado por B3 y enfoque).

### B8. SnackBars / Toasts [OBLIGATORIO]
Feedback flotante para acciones simuladas o confirmaciones (ej. "Sesión cerrada
simulada.", "Idioma configurado en español."). Diseñar el estilo de toast.

---

## C. PANTALLAS PRINCIPALES (con bottom nav)

### C1. Onboarding — `OnboardingScreen` [OBLIGATORIO]
1 pantalla: logo circular con gradiente + icono, título **"ThinkLess"**,
subtítulo **"Menos caos. Más hecho."**, 3 dots de paginación (solo 1 activo),
botón primario **"Comenzar"**.
- **Estados:** Default único.

### C2. Home / Tareas — `HomeScreen` [OBLIGATORIO]
Secciones (scroll vertical):
1. Header bienvenida: "Bienvenido" / "Tu día, organizado".
2. **FocusTotalCard** (activar/ver Enfoque Total).
3. **"Tus tareas"** (+ contador): lista de **TaskCard**.
4. **"Para comenzar"**: lista de starters (voz, recordatorios, listas).
5. **"Funciones clave"**: grid de 6 **FeatureTile** → Calendario, Matriz
   Eisenhower, Priorizar, Tiempo libre, Revisión del día, Pomodoro.
6. **"Explorar más"**: card Premium con gradiente → modal Premium (B6).
- **Estados:**
  - **Default:** con tareas (TaskCards).
  - **Vacío:** `EmptyStateCard` "No hay tareas todavía" + acciones "Voz IA" y
    "Escanear". (El resto de secciones se mantiene.)
  - Loading/Error: n/a local (carga es global A5).

### C3. Calendario — `CalendarScreen` [OBLIGATORIO]
Top bar con **selector de modo** (Mes · Semana · Día), pill "Hoy", mini-stats.
- **Vista Mes:** grid de celdas con indicadores de tareas por día.
- **Vista Semana:** timeline 6 AM–12 AM con columnas por día y bloques de tarea.
- **Vista Día:** timeline con etiquetas horarias, bloques de tarea, **indicador
  "ahora"**, tareas sin hora (untimed).
- **Estados:** Default (con bloques) · **Vacío** (día/semana sin tareas) ·
  Loading/Error n/a.

### C4. Enfoque / Pomodoro — `FocusScreen` [OBLIGATORIO]
Fases: **idle · running · paused**.
- **Idle:** header, selector de tarea (`_TaskSelectorTile`), **chips de duración
  (25/45/60)**, **StatsCard** (sesiones y minutos de hoy), botón "Iniciar".
- **Running:** **TimerRing** animado con cuenta regresiva, chip de tarea activa,
  **dots de sesiones planificadas** (4), controles (pausar/detener).
- **Paused:** mismo ring detenido, controles reanudar/detener.
- **Estados:** Idle (vacío de sesión) · Running (success en progreso) ·
  Completado (sesión terminada → stats +1).

### C5. Matriz Eisenhower — `MatrixScreen` [OBLIGATORIO]
4 cuadrantes en grid: **Hacer Ya** (urgente+alta, pink) · **Agendar** (media,
yellow) · **Delegar** (blue, hoy siempre vacío) · **Eliminar** (baja, mint).
Cada cuadrante lista **TaskPreview** con toggle/abrir.
- **Estados:** Default (con tareas) · **Vacío** (sin tareas reales → hoy usa
  **tareas de ejemplo**; diseñar también un vacío honesto como *propuesta*).

### C6. Más / Perfil — `ProfileScreen` [OBLIGATORIO]
Avatar circular con gradiente, nombre ("Alex" — *simulado*), email (*simulado*),
grid de **SettingTile**: Notificaciones (→ Alertas), Apariencia (simulado),
Idioma (simulado), Premium (→ modal), Ayuda y Soporte (simulado), botón "Cerrar
sesión" (simulado).
- **Estados:** Default único.

---

## D. PANTALLAS SECUNDARIAS (full-screen, sin bottom nav)

### D1. Voz e IA — `VoiceScreen` [OBLIGATORIO]
Captura por dictado. Orbe central animado + tarjetas de estado. **Muchos estados
reales** (diseñar todos):
- **idle:** "Voz e IA activadas" + tips (`_VoiceTips`).
- **requesting:** "Iniciando micrófono…" (spinner en el orbe).
- **listening:** orbe expandido + "Escuchando…" + transcript en vivo.
- **processing:** "Procesando con IA… Groq está estructurando tu tarea."
- **result (success):** **TaskPreview** de la tarea detectada + botón agregar.
- **busy (error recuperable):** "Micrófono ocupado" (Meet/Zoom/Discord) → pasa a
  Modo Reunión.
- **reconnecting:** "Reconectando audio… Reintento #n en Xs."
- **error:** card de error con mensaje mapeado (permiso, red, sin voz, etc.).
- **Modo Reunión (PTT):** orbe con **push-to-talk** (mantener para hablar),
  badge `_MeetingModeBadge`, animación al sostener.
- Chip "IA en modo silencioso" si No Molestar activo.

### D2. Escáner — `ScannerScreen` [OBLIGATORIO]
Captura de apuntes con cámara/galería → IA detecta varias tareas.
- **Default (inicio):** placeholder de cámara con esquinas de encuadre +
  tareas de ejemplo preseleccionadas.
- **Loading:** overlay oscuro + spinner ("procesando 2s + IA").
- **Success:** imagen + **lista de tareas detectadas** con selección múltiple
  (checkboxes), botón para agregar las seleccionadas.
- **Error:** mensaje de error + fallback a tareas de ejemplo.
- **Vacío:** sin detección (lista vacía).

### D3. Detalle de Tarea — `DetailScreen` [OBLIGATORIO]
Header con título, **PriorityBadge**, **InfoChips** (fecha, hora, materia,
duración), etiquetas (#tag), **card Sugerencia IA** (hoy texto fijo), card de
**Notas**, botones **Editar / Eliminar**, y barra inferior **Marcar como
completada / pendiente** (gradiente mint).
- **Estados:** Default (tarea) · **Error/Vacío:** "Tarea no encontrada."
  (cuando no hay tarea seleccionada) · Success (toggle completada).

### D4. Organizador de Prioridades — `PriorityOrganizerScreen` [OBLIGATORIO]
Flujo tipo **cartas con swipe**: **TaskSwipeCard** activa + card "peek" detrás,
**PriorityProgressBar**, hint de swipe, fila de acciones de prioridad.
- **Estados:** Default (cartas) · **Vacío** (`_EmptyState`: todo priorizado) ·
  Success (al asignar prioridad avanza).

### D5. Revisión del Día — `DayReviewScreen` [OBLIGATORIO]
Header, **DaySummaryMetrics** (métricas: completadas, pendientes, etc.),
sección de completadas (`_CompletedRow`), filas para **reprogramar**
(`RescheduleTaskRow` con chips de reprogramación), **TomorrowPreviewCard**
(vista de mañana).
- **Estados:** Default (con datos) · **Vacío** (`_EmptyHint`: nada que revisar).

---

## E. COMPONENTES REUTILIZABLES (design system) [OBLIGATORIO diseñarlos como kit]

> Stitch debe definir estos componentes una vez y reutilizarlos en todas las
> pantallas para garantizar consistencia.

**Layout / contenedores**
- `AppScaffold` — estructura de pantalla con header.
- `AppHeader` + botón de header (`_AppHeaderBtn`).
- `AppCard` — card base (con opción de "stripe" de color lateral).

**Tareas**
- `TaskCard` — fila de tarea con checkbox, título, meta (materia/fecha), punto de
  prioridad (`_PriorityDot`), chips (`_MetaChip`). Estados: pendiente / completada.
- `TaskPreview` — versión compacta (matriz, resultado de voz).
- `PriorityBadge` — etiqueta de prioridad con color.
- `InfoChip` / `_MetaChip` — chips de metadato.

**Acciones**
- `PrimaryButton` — botón primario (con icono opcional).
- `GradientFab` — FAB con gradiente.
- `CircleIconButton` — botón circular de icono.
- Botones secundarios (outlined) y de peligro (errorContainer).

**Estados vacíos / onboarding de sección**
- `EmptyStateCard` + `EmptyAction` — card de estado vacío con acciones.
- `FeatureTile` — tile de función (grid Home).
- `_StatusCard` — tarjeta de estado (voz): icono + título + cuerpo (+ variantes
  warning / danger).

**Específicos de feature**
- `FocusTotalCard` / `FocusTotalBanner` — enfoque total.
- `TimerRing` — anillo de temporizador.
- `NoMolestarCard` + `TimeField` — config No Molestar.
- `SettingTile` — fila de ajuste (perfil).
- `_AlertTile` — fila de alerta con switch.
- `DayPill`, `_HomeSectionLabel`, `_StarterItem` — auxiliares de Home/Calendario.
- Indicadores animados: `_PulsingDot`, `_NowIndicator`, `_WaveformBars`,
  `_SparkleBadge`.

---

## F. ALERTAS / AJUSTES (bajo "Más")

### F1. Alertas inteligentes — `AlertsScreen` [OBLIGATORIO]
Header "Alertas inteligentes", **NoMolestarCard** (No Molestar con horarios y
estado activo/inactivo), card "Tienes 45 min libres" (*simulado*) con CTA,
**Intensidad** (SegmentedButton: Suave/Normal/Insistente), toggles
(`_AlertTile`): Tareas urgentes, Repaso diario, Pausas activas.
- **Estados:** Default · No Molestar activo (estado visual distinto).

---

## RESUMEN DE COBERTURA OBLIGATORIA

| # | Pantalla / elemento | Tipo | Estados a diseñar |
|---|---------------------|------|-------------------|
| A1 | Bottom Nav | chrome | activo/inactivo (5) |
| A2 | FAB (+) | chrome | default |
| A3 | App Header | chrome | con/sin back |
| A4 | Banner Enfoque Total | chrome | activo |
| A5 | Loading global | chrome | spinner |
| B1 | Captura Rápida | sheet | texto/voz/escaneo/success |
| B2 | Editar Tarea | sheet | default/nueva |
| B3 | Tiempo Libre | sheet | default/vacío/success |
| B4 | Activar Enfoque Total | sheet | default |
| B5 | Picker de tarea (enfoque) | sheet | default/vacío |
| B6 | Modal Premium | modal | default |
| B7 | Duración personalizada | dialog | default |
| B8 | SnackBar/Toast | feedback | default |
| C1 | Onboarding | principal | default |
| C2 | Home/Tareas | principal | default/vacío |
| C3 | Calendario | principal | mes/semana/día + vacío |
| C4 | Enfoque/Pomodoro | principal | idle/running/paused/completado |
| C5 | Matriz | principal | default/vacío |
| C6 | Más/Perfil | principal | default |
| D1 | Voz e IA | secundaria | 9 estados (idle…error + reunión) |
| D2 | Escáner | secundaria | default/loading/success/error/vacío |
| D3 | Detalle de Tarea | secundaria | default/no encontrada/completada |
| D4 | Prioridades (swipe) | secundaria | default/vacío |
| D5 | Revisión del Día | secundaria | default/vacío |
| F1 | Alertas | secundaria | default/No Molestar activo |
| E | Kit de componentes | sistema | todos |
