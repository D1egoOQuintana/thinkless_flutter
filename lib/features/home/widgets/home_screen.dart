part of '../../../main.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen — Warm Academic Minimal · estructura "Home / Hoy" (Stitch)
// Dos estados: con tareas (Today) / vacío (Empty Home).
// Constructor, datos y callbacks intactos.
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.tasks,
    required this.focusTotal,
    required this.focusTotalClock,
    required this.onOpenTask,
    required this.onToggleTask,
    required this.onNavigate,
    required this.onShowFreeTime,
    required this.onActivateFocusTotal,
    required this.onDeactivateFocusTotal,
    super.key,
  });

  final List<TaskItem> tasks;
  final FocusTotalConfig focusTotal;
  final ValueNotifier<DateTime> focusTotalClock;
  final ValueChanged<TaskItem> onOpenTask;
  final ValueChanged<String> onToggleTask;
  final ValueChanged<AppView> onNavigate;
  final VoidCallback onShowFreeTime;
  final VoidCallback onActivateFocusTotal;
  final VoidCallback onDeactivateFocusTotal;

  @override
  Widget build(BuildContext context) {
    final hasTasks  = tasks.isNotEmpty;
    final pending   = tasks.where((t) => !t.completada).toList()
      ..sort((a, b) {
        final p = _prioRank(a.prioridad).compareTo(_prioRank(b.prioridad));
        return p != 0 ? p : _timeRank(a.hora).compareTo(_timeRank(b.hora));
      });
    final completed = tasks.where((t) => t.completada).length;
    final total     = tasks.length;

    final urgent    = pending.where((t) => t.prioridad == 'urgente').toList();
    final suggested = pending.isNotEmpty ? pending.first : null;

    // "Tu día": pendientes no urgentes (ordenadas por hora) + completadas al final.
    final dayTasks = [
      ...pending
          .where((t) => t.prioridad != 'urgente')
          .toList()
        ..sort((a, b) => _timeRank(a.hora).compareTo(_timeRank(b.hora))),
      ...tasks.where((t) => t.completada),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: !hasTasks
            ? _EmptyHome(
                onAdd:     () => onNavigate(AppView.voice),
                onScanner: () => onNavigate(AppView.scanner),
                onVoice:   () => onNavigate(AppView.voice),
                onProfile: () => onNavigate(AppView.profile),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, 0, AppSpacing.xl, 130,
                ),
                children: [
                  // ── Top bar "Hoy" ──────────────────────────────────────────
                  _TodayTopBar(onProfile: () => onNavigate(AppView.profile)),
                  const SizedBox(height: AppSpacing.sm),

                  // ── Saludo + fecha + progreso del día ──────────────────────
                  _GreetingBlock(completed: completed, total: total),
                  const SizedBox(height: AppSpacing.xxl),

                  // ── Enfoque sugerido (hero) ────────────────────────────────
                  if (suggested != null) ...[
                    _SuggestedFocusCard(
                      task: suggested,
                      onOpen: () => onOpenTask(suggested),
                      onFocus: () => onNavigate(AppView.focus),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],

                  // ── Tareas urgentes ────────────────────────────────────────
                  if (urgent.isNotEmpty) ...[
                    _HomeSectionHeader(
                      label: 'Tareas urgentes',
                      dotColor: AppColors.accent,
                      action: 'Ver todas',
                      onAction: () => onNavigate(AppView.matrix),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...urgent.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _UrgentTaskCard(
                          task: t,
                          onTap: () => onOpenTask(t),
                          onToggle: () => onToggleTask(t.id),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],

                  // ── Tu día (timeline vertical) ─────────────────────────────
                  if (dayTasks.isNotEmpty) ...[
                    _HomeSectionHeader(label: 'Tu día'),
                    const SizedBox(height: AppSpacing.lg),
                    _HomeDayTimeline(
                      tasks: dayTasks,
                      onOpenTask: onOpenTask,
                      onToggleTask: onToggleTask,
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  // Orden por prioridad para la sugerencia de enfoque.
  int _prioRank(String p) => switch (p) {
    'urgente' => 0,
    'alta'    => 1,
    'media'   => 2,
    'baja'    => 3,
    _         => 2,
  };
}

// Hora "HH:MM" → minutos del día; sin hora → al final.
int _timeRank(String hora) {
  final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(hora);
  if (m == null) return 24 * 60 + 1;
  return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
}

bool _hasTime(String hora) => RegExp(r'\d{1,2}:\d{2}').hasMatch(hora);

// ─────────────────────────────────────────────────────────────────────────────
// Top bar "Hoy"
// ─────────────────────────────────────────────────────────────────────────────

class _TodayTopBar extends StatelessWidget {
  const _TodayTopBar({required this.onProfile});
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Text(
            'Hoy',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onProfile,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.account_circle_outlined,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Saludo + fecha + progreso del día
// ─────────────────────────────────────────────────────────────────────────────

class _GreetingBlock extends StatelessWidget {
  const _GreetingBlock({required this.completed, required this.total});
  final int completed;
  final int total;

  String _formattedDate() {
    final now = DateTime.now();
    const days = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
    ];
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return '${days[now.weekday - 1]}, ${now.day} de ${months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? completed / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hola, Alex',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            letterSpacing: -1,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formattedDate(),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        // Progreso del día
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'PROGRESO DEL DÍA',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Text(
              '$completed de $total completadas',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.secondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: AppColors.surfaceHighest,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Enfoque sugerido (hero bento card)
// ─────────────────────────────────────────────────────────────────────────────

class _SuggestedFocusCard extends StatelessWidget {
  const _SuggestedFocusCard({
    required this.task,
    required this.onOpen,
    required this.onFocus,
  });
  final TaskItem task;
  final VoidCallback onOpen;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    final mins = task.duracionMin ?? 45;
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: AppColors.surfaceLowest,
          borderRadius: BorderRadius.circular(AppRadius.xxl + 8),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.07),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PulsingDot(),
                const SizedBox(width: 6),
                Text(
                  'ENFOQUE SUGERIDO',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              task.titulo,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
                height: 1.2,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Bloque de estudio concentrado • ${task.materia}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        '$mins min',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  child: InkWell(
                    onTap: onFocus,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl, vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow_rounded,
                              size: 20, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'Enfoque',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header (con punto opcional y acción "Ver todas")
// ─────────────────────────────────────────────────────────────────────────────

class _HomeSectionHeader extends StatelessWidget {
  const _HomeSectionHeader({
    required this.label,
    this.dotColor,
    this.action,
    this.onAction,
  });
  final String label;
  final Color? dotColor;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (dotColor != null) ...[
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.secondary,
            letterSpacing: 1,
          ),
        ),
        const Spacer(),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta de tarea urgente (stripe coral a la izquierda)
// ─────────────────────────────────────────────────────────────────────────────

class _UrgentTaskCard extends StatelessWidget {
  const _UrgentTaskCard({
    required this.task,
    required this.onTap,
    required this.onToggle,
  });
  final TaskItem task;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final meta = [task.hora, task.materia]
        .where((s) => s.isNotEmpty && s != 'Sin hora' && s != 'Sin fecha')
        .join(' • ');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLowest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.outlineSubtle),
          boxShadow: AppShadow.sm,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(AppRadius.lg),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: onToggle,
                        behavior: HitTestBehavior.opaque,
                        child: const Icon(
                          Icons.radio_button_unchecked_rounded,
                          size: 22,
                          color: AppColors.outline,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              task.titulo,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface,
                                letterSpacing: -0.1,
                              ),
                            ),
                            if (meta.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                meta,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tu día — timeline vertical
// ─────────────────────────────────────────────────────────────────────────────

class _HomeDayTimeline extends StatelessWidget {
  const _HomeDayTimeline({
    required this.tasks,
    required this.onOpenTask,
    required this.onToggleTask,
  });
  final List<TaskItem> tasks;
  final ValueChanged<TaskItem> onOpenTask;
  final ValueChanged<String> onToggleTask;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Línea vertical del timeline.
        Positioned(
          left: 11, top: 6, bottom: 6,
          child: Container(width: 2, color: AppColors.surfaceHighest),
        ),
        Column(
          children: [
            for (var i = 0; i < tasks.length; i++)
              _TimelineRow(
                task: tasks[i],
                isLast: i == tasks.length - 1,
                onTap: () => onOpenTask(tasks[i]),
                onToggle: () => onToggleTask(tasks[i].id),
              ),
          ],
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.task,
    required this.isLast,
    required this.onTap,
    required this.onToggle,
  });
  final TaskItem task;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final done  = task.completada;
    final timed = _hasTime(task.hora);
    final meta = task.materia.isNotEmpty && task.materia != 'General'
        ? task.materia
        : '';

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nodo (checkbox del timeline)
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppColors.primary : AppColors.surfaceLowest,
                border: Border.all(
                  color: done ? AppColors.primary : AppColors.outlineVariant,
                  width: 2.5,
                ),
              ),
              child: done
                  ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // Contenido
          Expanded(
            child: Opacity(
              opacity: done ? 0.55 : 1,
              child: GestureDetector(
                onTap: onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (timed) ...[
                      Text(
                        task.hora,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                        border: Border.all(
                          color: AppColors.outlineVariant.withValues(alpha: 0.4),
                        ),
                        boxShadow: AppShadow.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.titulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                              letterSpacing: -0.2,
                              decoration:
                                  done ? TextDecoration.lineThrough : null,
                              decorationColor: AppColors.secondary,
                            ),
                          ),
                          if (meta.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.label_outline_rounded,
                                    size: 16, color: AppColors.secondary),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    meta,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty Home — "Todo en calma por ahora"
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyHome extends StatelessWidget {
  const _EmptyHome({
    required this.onAdd,
    required this.onScanner,
    required this.onVoice,
    required this.onProfile,
  });
  final VoidCallback onAdd;
  final VoidCallback onScanner;
  final VoidCallback onVoice;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top bar: perfil · saludo · (acción)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.md,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: onProfile,
                icon: const Icon(Icons.account_circle_outlined),
                color: AppColors.primary,
                iconSize: 26,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Hola, Alex',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _todayShort(),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 42),
            ],
          ),
        ),
        // Contenido centrado
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWarm,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF302F35).withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 56,
                    color: AppColors.primary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Todo en calma por ahora.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                    letterSpacing: -0.8,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '¿Qué te gustaría organizar hoy para\nliberar tu mente?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppColors.secondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl + AppSpacing.sm),
                // CTA principal
                SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    child: InkWell(
                      onTap: onAdd,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          boxShadow: AppShadow.brand(opacity: 0.2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_rounded,
                                size: 20, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Agregar primera tarea',
                              style: GoogleFonts.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Acciones secundarias (bento)
                Row(
                  children: [
                    Expanded(
                      child: _EmptyTile(
                        icon: Icons.document_scanner_rounded,
                        title: 'Escanear',
                        subtitle: 'Digitaliza tus apuntes',
                        onTap: onScanner,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: _EmptyTile(
                        icon: Icons.mic_rounded,
                        title: 'Usar voz',
                        subtitle: 'Captura rápida',
                        onTap: onVoice,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _todayShort() {
    final now = DateTime.now();
    const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    return '${days[now.weekday - 1]}, ${now.day} de ${months[now.month - 1]}';
  }
}

class _EmptyTile extends StatelessWidget {
  const _EmptyTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLowest,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.4),
            ),
            boxShadow: AppShadow.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: AppColors.secondary,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
