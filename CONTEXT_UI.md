# ThinkLess — Documento de Contexto (para rediseño radical de UI)

> App Flutter de productividad/gestión de tareas para estudiantes. Dark mode,
> arquitectura modular por features, estado central en `_ThinkLessAppState`.
> Este documento mapea **toda la app** para planear un cambio radical de UI sin
> romper la lógica existente.

---

## 1. Stack y dependencias

- **Flutter SDK** `^3.11.0`, Material 3 (`useMaterial3: true`).
- **Fuentes:** `google_fonts` → Plus Jakarta Sans (display/títulos) + Inter (body/labels).
- **Persistencia:** `shared_preferences` (no backend, todo local en JSON).
- **IA / voz:** `http` + Groq API (`GroqService`), `speech_to_text` (dictado), `image_picker` (escaneo OCR vía IA).
- **Sin** state manager externo (Provider/Riverpod/Bloc). Estado con `StatefulWidget` + `setState` + `ValueNotifier`.

---

## 2. Arquitectura de archivos

`lib/main.dart` es el **monolito** (5753 líneas). Todos los demás archivos son
`part of` main.dart (no tienen imports propios). Estructura lógica por feature:

```
lib/
├── main.dart                         # App, tema, navegación, ~50 widgets de UI
├── app/
│   ├── theme/app_colors.dart         # DESIGN TOKENS (clave para rediseño)
│   └── navigation/app_view.dart      # enum AppView (rutas)
└── features/
    ├── tasks/
    │   ├── domain/task_item.dart     # modelo TaskItem
    │   ├── data/task_store.dart      # persistencia SharedPreferences
    │   └── widgets/
    │       ├── quick_capture_sheet.dart      # captura rápida (bottom sheet)
    │       ├── task_edit_sheet.dart          # edición completa de tarea
    │       ├── priority_organizer_screen.dart# organizar prioridades (swipe)
    │       ├── free_time_sheet.dart          # sugerencias tiempo libre
    │       └── day_review_screen.dart        # revisión del día
    ├── calendar/widgets/calendar_screen.dart # calendario mes/semana/día
    ├── focus/
    │   ├── domain/focus_total_config.dart    # config modo enfoque total
    │   └── widgets/focus_screen.dart         # pantalla pomodoro/enfoque
    ├── settings/domain/no_molestar_config.dart # config No Molestar
    └── assistant/data/groq_service.dart      # cliente IA Groq
```

> **Nota de rediseño:** como todo es `part of main.dart`, los tokens de
> `app_colors.dart` y los widgets compartidos en `main.dart` son el punto de
> apalancamiento. Cambiar tokens propaga el restyle a casi toda la app.

---

## 3. Design tokens actuales (`app_colors.dart`)

Inspiración declarada: **Linear, Vercel, Stripe, Arc**. Dark mode con jerarquía
de superficies (slate azulado, nunca negro puro).

**Superficies:** `background #0A0B11` → `surfaceLowest #0D0F16` (nav/modales) →
`surface #11131B` → `surfaceContainer #161924` (cards) → `surfaceVariant #1B1E2B`
→ `surfaceHigh #1F2330` (hover/inputs) → `surfaceHighest #272B3A` (pressed).

**Bordes:** `outlineVariant #252938`, `outline #323748`, `outlineSubtle #1D2030`.

**Texto:** `onSurface #F4F5FA`, `onSurfaceVariant #B0B5C7`, `secondary #7A7F92`.

**Marca (violeta Linear-like):** `primary #7C5CFF`, `primaryHover #8E72FF`,
`primaryPressed #6A48F0`, `primaryContainer #231B4D`, `violetLight #B7A4FF`,
`indigo #5B6CFF`.

**Acentos semánticos:** `mint #3DDC97` (éxito), `blue #5B9DFF` (info),
`yellow #FFB547` (warning), `pink #FF6FA8`, `error #FF5C72` (urgente). Cada uno
con su variante `*Soft` para fondos tinteados.

**Otros sistemas de tokens (mismo archivo):**
- `AppSpacing` — sistema 8pt: xs 4, sm 8, md 12, lg 16, xl 20, xxl 24, xxxl 32.
- `AppRadius` — xs 8, sm 10, md 12, lg 14, xl 16, xxl 20, pill 999.
- `AppMotion` — fast 140ms, base 220ms, slow 340ms; curvas easeOutCubic/easeOutQuart.
- `AppShadow` — `sm`/`md`/`lg` (sombras negras) + `brand(opacity)` (glow violeta).

**Tema global** (`_buildAppTheme` en main.dart ~L87): `ColorScheme.dark` mapeado
a los tokens, `TextTheme` completo (Jakarta + Inter), y temas de NavigationBar,
Dialog, BottomSheet, InputDecoration, Checkbox (mint), Chip, Switch, botones,
SegmentedButton, SnackBar, ProgressIndicator, Tooltip.

> El restyle global más eficiente = editar `AppColors` + `_buildAppTheme`.

---

## 4. Modelo de dominio

### `TaskItem` (task_item.dart)
Campos: `id, titulo, materia, fecha, hora, prioridad, tipo, completada,
fechaCreacion, notas, duracionMin?, etiquetas[]`. Inmutable con `copyWith`,
`fromJson`/`toJson`. Prioridades normalizadas: `urgente | alta | media | baja`.

### Configs
- `NoMolestarConfig` — modo No Molestar (silencio/horarios).
- `FocusTotalConfig` — sesión de "enfoque total" persistente (banner global).

### Persistencia (`TaskStore`)
Claves SharedPreferences: `tareas` (+ legacy `thinkless_tasks`),
`thinkless_seen_onboarding`, `thinkless_alerts`, `modo_no_molestar_config`,
`focus_total_config`. Todo JSON local, sin red.

---

## 5. Navegación y estado central

**Enum `AppView`:** `onboarding, home, calendar, focus, matrix, alerts,
profile, voice, scanner, detail, priorities, review`.

**`_ThinkLessAppState`** (main.dart L41-915) es el **cerebro**: mantiene
`_tasks`, `_view`/`_previousView`, `_selectedTask`, alerts, noMolestar,
focusTotal (con `Timer` + `ValueNotifier<DateTime>` para el reloj), stats de
enfoque del día.

Métodos clave (acciones de negocio — **no tocar en el rediseño**):
`_load`, `_navigate`, `_addTask`/`_addTasks`, `_updateTask`, `_toggleTask`,
`_deleteTask`, `_updatePriority`, `_rescheduleTask`, `_openTask`, `_openEditSheet`,
`_startFocus`, `_activate/_deactivateFocusTotal`, `_setFocusTotal`,
`_saveAlerts`, `_saveNoMolestar`, `_sortTasks`, `_showAddSheet`,
`_showFreeTimeSheet`, `_showFocusModal`.

**Routing:** `_buildView()` hace `switch (_view)` y envuelve cada pantalla
principal en `ShellScreen` (excepto voice/scanner/detail/priorities/review que
son full-screen). La navegación es **manual por enum + setState**, no usa
`Navigator` con rutas (salvo bottom sheets y el navigatorKey para contexto).

**`ShellScreen`** (L993): `Scaffold` con (1) banner opcional de Enfoque Total
arriba, (2) el `child`, (3) `GradientFab` opcional, (4) `NavigationBar` inferior
de 5 destinos: **Tareas (home) · Calendario · Enfoque · Matriz · Más (profile)**.

---

## 6. Pantallas (inventario por feature)

### Home / Tareas — `HomeScreen` (main.dart L1094)
Lista principal de tareas + secciones, banner de enfoque total, FAB de captura.

### Calendario — `calendar_screen.dart` (1433 L)
`CalendarScreen` + `enum CalendarMode` (mes/semana/día). Subwidgets:
`_CalendarTopBar`, `_ModeSegment`, `_TodayPill`, `_MiniStat`, `_MonthGrid`,
`_MonthCell`, `_WeekTimeline`, `_WeekDayColumn`, `_WeekTaskBlock`, `_DayTimeline`,
`_HourLabel`, `_DayTaskBlock`, `_UntimedTaskTile`, `_NowIndicator`.
Regla de negocio (CLAUDE.md): soporte 6 AM–12 AM, scroll fluido, estilo Google
Calendar + Linear.

### Enfoque — `focus_screen.dart` (1434 L)
`FocusScreen` + `enum _FocusPhase`. Pomodoro con `_TimerRing`, `_DurationChips`,
`_StatsCard`, `_TaskSelectorTile`, `_StartButton`, `_RunningControls`,
`_TaskPickerSheet`, `_SparkleBadge`. Stats de sesiones/minutos del día.
Banner global de "Enfoque Total": `FocusTotalBanner`, `FocusTotalCard`,
`_FocusTotalDurationGrid` (en main.dart L5205+).

### Matriz Eisenhower — `MatrixScreen` (main.dart L2531)
4 cuadrantes (`Quadrant`, `TaskPreview`) urgente/importante.

### Voz — `VoiceScreen`/`_VoiceScreenState` (main.dart L1371)
Dictado con `speech_to_text` → Groq parsea a tareas. `_MeetingModeBadge`,
`_PttButton` (push-to-talk), `_WaveformBars` (animación de ondas), `_VoiceTips`.

### Escáner — `ScannerScreen` (main.dart L2274)
`image_picker` → OCR/IA Groq extrae tareas. `_ScannerPlaceholder`, `_ScanCorners`,
`_CornerPainter`.

### Detalle — `DetailScreen` (main.dart L2599)
Vista de una tarea con toggle/editar/eliminar.

### Alertas / Ajustes — `AlertsScreen` (main.dart L2856) + `ProfileScreen` (L3021)
Config de notificaciones, No Molestar (`NoMolestarCard`, `TimeField`,
`SettingTile`), perfil.

### Sheets (bottom sheets)
- `QuickCaptureSheet` (853 L) — captura rápida con tabs/chips inteligentes.
  `CaptureModeTabs`, `SmartChipRow`, `_CaptureInputField`, `enum CaptureMode`.
- `TaskEditSheet` (1129 L) — edición completa. `_PriorityPill`, `_ChoicePill`,
  `_FieldTile`, `_SuggestionChip`, `_TagChip`, `enum _DatePreset/_TimePreset`.
- `FreeTimeSheet` (692 L) — sugerencias para tiempo libre. `SuggestionCard`,
  `TimeChipSelector`, `_CustomDurationDialog`.
- `PriorityOrganizerScreen` (817 L) — organizar por swipe. `TaskSwipeCard`,
  `PriorityProgressBar`, `_SwipeHint`.
- `DayReviewScreen` (945 L) — revisión del día. `DaySummaryMetrics`,
  `RescheduleTaskRow`, `TomorrowPreviewCard`.

---

## 7. Widgets compartidos / design system (en main.dart)

Estos son los **componentes reutilizables** que definen el look actual. Son el
segundo punto de apalancamiento para el rediseño:

- **Layout:** `AppScaffold` (L3130), `AppHeader` + `_AppHeaderBtn` (L3167),
  `AppCard` (L3273).
- **Tareas:** `TaskCard`/`_TaskCardState` (L3331), `_PriorityDot`, `_MetaChip`,
  `PriorityBadge` (L4269), `InfoChip` (L4310).
- **Acciones:** `PrimaryButton` (L3641), `GradientFab` (L3712), `CircleIconButton`
  (L4689).
- **Estados vacíos:** `EmptyStateCard` (L3534), `EmptyAction`, `FeatureTile` (L3753).
- **Home:** `_StatusCard`, `_StarterItem`, `_HomeSectionLabel`, `DayPill`,
  `_AlertTile`.
- **Misc:** `_VoiceTips`, `_Tip`, `_Dot`, `_PulsingDot` (animado).

---

## 8. Reglas de producto (de CLAUDE.md) relevantes a UI

- Diseño premium moderno, empresarial; evitar interfaces genéricas "estilo AI".
- Jerarquía visual fuerte, espaciado limpio, microinteracciones y animaciones
  suaves (sin exceso). Mobile-first, responsive real, dark mode elegante.
- Inspiración: Linear, Vercel, Stripe, Notion, Framer, Arc.
- Animaciones priorizando rendimiento sobre efectos; evitar rebuilds innecesarios.
- Reutilizar componentes antes de crear nuevos; no romper funcionalidad existente.

---

## 9. Riesgos y guía para el rediseño radical

1. **Monolito de 5753 líneas:** `main.dart` mezcla tema, navegación, estado y ~50
   widgets. Un rediseño radical idealmente extrae el design system a archivos
   propios, pero el patrón `part of` lo permite sin refactor lógico.
2. **Punto de apalancamiento #1 — tokens:** editar `AppColors`, `AppRadius`,
   `AppShadow`, `AppMotion` + `_buildAppTheme` cambia el 80% del look sin tocar
   widgets uno a uno.
3. **Punto de apalancamiento #2 — componentes compartidos** (sección 7): si se
   rediseñan `AppCard`, `TaskCard`, `AppHeader`, botones y chips, propaga a todas
   las pantallas.
4. **No tocar la lógica:** los métodos de `_ThinkLessAppState` (sección 5) y la
   capa data/domain son agnósticos a la UI. El rediseño debe respetar sus firmas
   (callbacks `onNavigate`, `onAddTask`, `onToggleTask`, etc.).
5. **Navegación por enum:** cualquier nueva pantalla o reordenamiento del bottom
   nav pasa por `AppView`, `_buildView()` y `ShellScreen`.
6. **Sin tests de UI** y sin assets propios (solo Material Icons + Google Fonts):
   el rediseño es de bajo riesgo de romper assets, pero hay que validar overflow/
   responsive manualmente (regla Playwright de CLAUDE.md).
7. **Animaciones existentes:** `_WaveformBars`, `_PulsingDot`, `_SparkleBadge`,
   `_TimerRing`, `_NowIndicator` usan `AnimationController`; revisarlas al cambiar
   motion tokens.

---

## 10. Resumen ejecutivo

ThinkLess = app de tareas para estudiantes, dark mode estilo Linear, monolítica
en `main.dart` con features modulares vía `part of`. Estado central manual con
`setState`, navegación por enum `AppView`, persistencia local en SharedPreferences,
IA Groq para voz/escaneo. **Para rediseñar la UI radicalmente sin romper nada:
trabaja sobre los design tokens (`app_colors.dart` + `_buildAppTheme`) y los
componentes compartidos de `main.dart`, manteniendo intactas las firmas de los
callbacks y la capa de datos.**
