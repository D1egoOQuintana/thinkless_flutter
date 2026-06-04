part of '../../../main.dart';

enum _SemanaMode { week, day }

/// Experiencia "Semana" — planificador semanal (no un calendario genérico).
///
/// Source of truth: frames Stitch MCP "Semana (Carga Baja/Alta)",
/// "Detalle del Día (Vacío/Con Tareas)" y "Selector de Mes (Modal)".
///
/// - Week planner con resumen inteligente que se adapta a la carga.
/// - Detalle de día seleccionado (urgentes / bloques agendados / sin hora).
/// - Estado vacío del día.
/// - Selector de mes como bottom sheet modal.
///
/// Los datos de fecha/hora de las tareas siguen alimentando toda la UI vía los
/// helpers globales (`_taskDate`, `_taskMinutes`, `priorityColor`).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    required this.tasks,
    required this.onOpenTask,
    required this.onToggleTask,
    required this.noMolestar,
    this.onAddTask,
    super.key,
  });

  final List<TaskItem> tasks;
  final ValueChanged<TaskItem> onOpenTask;
  final ValueChanged<String> onToggleTask;
  final NoMolestarConfig noMolestar;

  /// Reutiliza el flujo de alta de tareas existente (Shell `_showAddSheet`).
  final VoidCallback? onAddTask;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  _SemanaMode _mode = _SemanaMode.week;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  Map<int, List<TaskItem>> _indexByDay(List<TaskItem> tasks) {
    final map = <int, List<TaskItem>>{};
    for (final t in tasks) {
      final k = _dayKey(_taskDate(t));
      (map[k] ??= <TaskItem>[]).add(t);
    }
    for (final list in map.values) {
      list.sort((a, b) => _taskMinutes(a).compareTo(_taskMinutes(b)));
    }
    return map;
  }

  // ─── Navegación ─────────────────────────────────────────────────────

  void _shiftWeek(int amount) =>
      setState(() => _focusedDay = _focusedDay.add(Duration(days: 7 * amount)));

  void _openDay(DateTime day) => setState(() {
    _selectedDay = day;
    _mode = _SemanaMode.day;
  });

  void _backToWeek() => setState(() => _mode = _SemanaMode.week);

  Future<void> _openMonthPicker(Map<int, List<TaskItem>> byDay) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MonthPickerSheet(
        initialMonth: _focusedDay,
        byDay: byDay,
        onPick: (d) {
          Navigator.of(context).pop();
          setState(() {
            _focusedDay = d;
            _mode = _SemanaMode.week;
          });
        },
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final byDay = _indexByDay(widget.tasks);
    final silent = isNoMolestarActivo(widget.noMolestar);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: AppMotion.base,
          switchInCurve: AppMotion.emphasized,
          switchOutCurve: Curves.easeIn,
          child: KeyedSubtree(
            key: ValueKey(_mode == _SemanaMode.day ? _dayKey(_selectedDay) : -1),
            child: _mode == _SemanaMode.week
                ? _WeekPlanner(
                    focusedDay: _focusedDay,
                    byDay: byDay,
                    silent: silent,
                    onPrevWeek: () => _shiftWeek(-1),
                    onNextWeek: () => _shiftWeek(1),
                    onOpenMonth: () => _openMonthPicker(byDay),
                    onDayTap: _openDay,
                    onTaskTap: widget.onOpenTask,
                  )
                : _DayDetail(
                    day: _selectedDay,
                    tasks: byDay[_dayKey(_selectedDay)] ?? const [],
                    onBack: _backToWeek,
                    onTaskTap: widget.onOpenTask,
                    onToggleTask: widget.onToggleTask,
                    onAddTask: widget.onAddTask,
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Métricas de la semana
// ─────────────────────────────────────────────────────────────────────────

class _WeekStats {
  const _WeekStats({
    required this.total,
    required this.urgent,
    required this.freeDays,
    required this.estimatedMin,
  });

  final int total;
  final int urgent;
  final int freeDays;
  final int estimatedMin;

  bool get highLoad => total >= 6 || urgent >= 3;
}

_WeekStats _computeWeekStats(List<DateTime> days, Map<int, List<TaskItem>> byDay) {
  int total = 0, urgent = 0, free = 0, minutes = 0;
  for (final d in days) {
    final tasks = byDay[d.year * 10000 + d.month * 100 + d.day] ?? const [];
    if (tasks.isEmpty) {
      free++;
      continue;
    }
    total += tasks.length;
    for (final t in tasks) {
      if (t.prioridad == 'urgente' || t.prioridad == 'alta') urgent++;
      minutes += t.duracionMin ?? 30;
    }
  }
  return _WeekStats(total: total, urgent: urgent, freeDays: free, estimatedMin: minutes);
}

String _fmtDuration(int minutes) {
  if (minutes <= 0) return '0m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

bool _isUrgent(TaskItem t) => t.prioridad == 'urgente' || t.prioridad == 'alta';

IconData _semanaTipoIcon(String t) => switch (t) {
  'examen' => Icons.fact_check_rounded,
  'tarea' => Icons.assignment_rounded,
  'laboratorio' => Icons.science_rounded,
  'proyecto' => Icons.workspaces_rounded,
  'lectura' => Icons.menu_book_rounded,
  _ => Icons.label_rounded,
};

// ─────────────────────────────────────────────────────────────────────────
// Week planner
// ─────────────────────────────────────────────────────────────────────────

class _WeekPlanner extends StatelessWidget {
  const _WeekPlanner({
    required this.focusedDay,
    required this.byDay,
    required this.silent,
    required this.onPrevWeek,
    required this.onNextWeek,
    required this.onOpenMonth,
    required this.onDayTap,
    required this.onTaskTap,
  });

  final DateTime focusedDay;
  final Map<int, List<TaskItem>> byDay;
  final bool silent;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;
  final VoidCallback onOpenMonth;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<TaskItem> onTaskTap;

  int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  String _rangeLabel(DateTime monday, DateTime sunday) {
    if (monday.month == sunday.month) {
      return '${monday.day} – ${sunday.day} ${_monthName(monday.month)}';
    }
    return '${monday.day} ${_monthName(monday.month)} – ${sunday.day} ${_monthName(sunday.month)}';
  }

  @override
  Widget build(BuildContext context) {
    final monday = focusedDay.subtract(Duration(days: focusedDay.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final sunday = days.last;
    final today = DateTime.now();
    final stats = _computeWeekStats(days, byDay);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        // ── Header de contexto ──
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _rangeLabel(monday, sunday).toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Esta semana',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            _RoundIcon(icon: Icons.chevron_left_rounded, onTap: onPrevWeek),
            const SizedBox(width: 8),
            _RoundIcon(icon: Icons.chevron_right_rounded, onTap: onNextWeek),
          ],
        ),
        const SizedBox(height: 16),
        // ── Acción mes + silencio ──
        Row(
          children: [
            _PillButton(
              icon: Icons.calendar_month_rounded,
              label: 'Mes',
              onTap: onOpenMonth,
            ),
            const Spacer(),
            if (silent)
              _MiniBadge(
                icon: Icons.notifications_off_rounded,
                label: 'Silencio',
                color: AppColors.secondary,
              ),
          ],
        ),
        const SizedBox(height: 20),
        // ── Resumen inteligente (carga baja vs alta) ──
        if (stats.highLoad)
          _SummaryHighLoad(stats: stats)
        else
          _SummaryLowLoad(stats: stats),
        const SizedBox(height: 24),
        // ── Panorama semanal ──
        Text(
          'PANORAMA SEMANAL',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 14),
        for (final d in days)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: stats.highLoad
                ? _DayRowHigh(
                    day: d,
                    tasks: byDay[_dayKey(d)] ?? const [],
                    isToday: _sameDay(d, today),
                    onTap: () => onDayTap(d),
                  )
                : _DayRowLow(
                    day: d,
                    tasks: byDay[_dayKey(d)] ?? const [],
                    isToday: _sameDay(d, today),
                    onTap: () => onDayTap(d),
                    onTaskTap: onTaskTap,
                  ),
          ),
      ],
    );
  }
}

// ─── Resumen: carga baja ────────────────────────────────────────────────

class _SummaryLowLoad extends StatelessWidget {
  const _SummaryLowLoad({required this.stats});
  final _WeekStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Hero: días libres detectados
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.outlineSubtle),
            boxShadow: AppShadow.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stats.freeDays > 0
                          ? '${stats.freeDays} día${stats.freeDays == 1 ? '' : 's'} libre${stats.freeDays == 1 ? '' : 's'}'
                          : 'Semana ligera',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tiempo para descansar y recargar energía.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.spa_rounded,
                    color: AppColors.primary, size: 24),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MiniStatCard(
                value: '${stats.total}',
                label: 'tareas esta semana',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniStatCard(
                value: _fmtDuration(stats.estimatedMin),
                label: 'estimados',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Resumen: carga alta ────────────────────────────────────────────────

class _SummaryHighLoad extends StatelessWidget {
  const _SummaryHighLoad({required this.stats});
  final _WeekStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.errorContainer,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.18)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Semana de alta carga',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Prepárate para un volumen intenso. Prioriza el descanso entre sesiones.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.onErrorContainer.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MiniStatCard(
                icon: Icons.assignment_outlined,
                iconColor: AppColors.primary,
                value: '${stats.total}',
                label: 'tareas esta semana',
                alignStart: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniStatCard(
                icon: Icons.priority_high_rounded,
                iconColor: AppColors.accent,
                value: '${stats.urgent}',
                label: 'urgentes',
                alignStart: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.outlineSubtle),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 18, color: AppColors.secondary),
              const SizedBox(width: 10),
              Text(
                'Carga estimada',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                _fmtDuration(stats.estimatedMin),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
    this.alignStart = false,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 100),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.outlineSubtle),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment:
            alignStart ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22, color: iconColor ?? AppColors.primary),
            const Spacer(),
          ],
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: icon != null ? 22 : 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: alignStart ? TextAlign.start : TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Fila de día: carga baja (timeline) ─────────────────────────────────

class _DayRowLow extends StatelessWidget {
  const _DayRowLow({
    required this.day,
    required this.tasks,
    required this.isToday,
    required this.onTap,
    required this.onTaskTap,
  });

  final DateTime day;
  final List<TaskItem> tasks;
  final bool isToday;
  final VoidCallback onTap;
  final ValueChanged<TaskItem> onTaskTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Columna fecha
        SizedBox(
          width: 48,
          child: Column(
            children: [
              const SizedBox(height: 6),
              Text(
                _shortDay(day.weekday),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: isToday ? AppColors.primary : AppColors.secondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${day.day}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: tasks.isEmpty
                      ? AppColors.secondary
                      : AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Tarjeta de día
        Expanded(
          child: tasks.isEmpty
              ? _FreeDayCard(onTap: onTap)
              : Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: AppColors.outlineSubtle),
                        boxShadow: AppShadow.sm,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (var i = 0; i < tasks.length && i < 3; i++)
                            _MiniTaskLine(
                              task: tasks[i],
                              showDivider: i > 0,
                              onTap: () => onTaskTap(tasks[i]),
                            ),
                          if (tasks.length > 3)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '+${tasks.length - 3} más',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _MiniTaskLine extends StatelessWidget {
  const _MiniTaskLine({
    required this.task,
    required this.showDivider,
    required this.onTap,
  });

  final TaskItem task;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = priorityColor(task.prioridad);
    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(top: BorderSide(color: AppColors.outlineSubtle))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          task.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                            decoration: task.completada
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (task.hora != 'Sin hora')
                              _TaskChip(label: task.hora),
                            if (task.hora != 'Sin hora')
                              const SizedBox(width: 6),
                            _TaskChip(
                              icon: _semanaTipoIcon(task.tipo),
                              label: task.materia,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskChip extends StatelessWidget {
  const _TaskChip({required this.label, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: AppColors.secondary),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeDayCard extends StatelessWidget {
  const _FreeDayCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.surfaceWarm.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.self_improvement_rounded,
                    size: 20, color: AppColors.secondary.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                Text(
                  'Libre',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Fila de día: carga alta (barra de densidad) ────────────────────────

class _DayRowHigh extends StatelessWidget {
  const _DayRowHigh({
    required this.day,
    required this.tasks,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final List<TaskItem> tasks;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasUrgent = tasks.any(_isUrgent);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLowest,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: isToday
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.outlineSubtle,
              width: isToday ? 1.4 : 1,
            ),
            boxShadow: AppShadow.sm,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Column(
                  children: [
                    Text(
                      _shortDay(day.weekday),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isToday ? AppColors.primary : AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${day.day}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          tasks.isEmpty
                              ? 'Libre'
                              : '${tasks.length} tarea${tasks.length == 1 ? '' : 's'}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: tasks.isEmpty
                                ? AppColors.secondary
                                : AppColors.onSurface,
                          ),
                        ),
                        const Spacer(),
                        if (hasUrgent)
                          const Icon(Icons.error_rounded,
                              size: 16, color: AppColors.accent),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _LoadBar(tasks: tasks),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadBar extends StatelessWidget {
  const _LoadBar({required this.tasks});
  final List<TaskItem> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(100),
        ),
      );
    }
    final segments = tasks.take(6).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                child: ColoredBox(color: priorityColor(segments[i].prioridad)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Detalle del día
// ─────────────────────────────────────────────────────────────────────────

class _DayDetail extends StatelessWidget {
  const _DayDetail({
    required this.day,
    required this.tasks,
    required this.onBack,
    required this.onTaskTap,
    required this.onToggleTask,
    required this.onAddTask,
  });

  final DateTime day;
  final List<TaskItem> tasks;
  final VoidCallback onBack;
  final ValueChanged<TaskItem> onTaskTap;
  final ValueChanged<String> onToggleTask;
  final VoidCallback? onAddTask;

  String _title() {
    final today = DateTime.now();
    final prefix = _sameDay(day, today) ? 'Hoy · ' : '';
    final weekday = _weekdayLong(day.weekday);
    final month = _monthName(day.month).substring(0, 3);
    return '$prefix$weekday ${day.day} $month';
  }

  @override
  Widget build(BuildContext context) {
    final urgent = tasks.where(_isUrgent).toList(growable: false);
    final scheduled = tasks
        .where((t) => !_isUrgent(t) && t.hora != 'Sin hora')
        .toList(growable: false);
    final untimed = tasks
        .where((t) => !_isUrgent(t) && t.hora == 'Sin hora')
        .toList(growable: false);

    return Column(
      children: [
        // ── Top bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
          child: Row(
            children: [
              _RoundIcon(icon: Icons.arrow_back_rounded, onTap: onBack),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _title(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: tasks.isEmpty
              ? _DayEmptyState(day: day, onAddTask: onAddTask)
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  children: [
                    if (urgent.isNotEmpty) ...[
                      _DetailSectionHead(
                        label: 'Prioridad urgente',
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.accent,
                      ),
                      const SizedBox(height: 12),
                      for (final t in urgent)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DayUrgentCard(
                            task: t,
                            onTap: () => onTaskTap(t),
                            onToggle: () => onToggleTask(t.id),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                    if (scheduled.isNotEmpty) ...[
                      _DetailSectionHead(
                        label: 'Bloques agendados',
                        icon: Icons.schedule_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 12),
                      _ScheduledTimeline(
                        tasks: scheduled,
                        onTaskTap: onTaskTap,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (untimed.isNotEmpty) ...[
                      _DetailSectionHead(
                        label: 'Tareas sin hora',
                        icon: Icons.label_outline_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 12),
                      for (final t in untimed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _UntimedTaskRow(
                            task: t,
                            onTap: () => onTaskTap(t),
                            onToggle: () => onToggleTask(t.id),
                          ),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _DetailSectionHead extends StatelessWidget {
  const _DetailSectionHead({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _DayUrgentCard extends StatelessWidget {
  const _DayUrgentCard({
    required this.task,
    required this.onTap,
    required this.onToggle,
  });

  final TaskItem task;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final accent = priorityColor(task.prioridad);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLowest,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.outlineSubtle),
            boxShadow: AppShadow.sm,
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CheckCircle(
                          done: task.completada,
                          onTap: onToggle,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.titulo,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                  decoration: task.completada
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (task.hora != 'Sin hora') ...[
                                    Icon(Icons.schedule_rounded,
                                        size: 14, color: AppColors.secondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      task.hora,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Flexible(
                                    child: _TaskChip(label: task.materia),
                                  ),
                                ],
                              ),
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
      ),
    );
  }
}

class _ScheduledTimeline extends StatelessWidget {
  const _ScheduledTimeline({required this.tasks, required this.onTaskTap});

  final List<TaskItem> tasks;
  final ValueChanged<TaskItem> onTaskTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        children: [
          for (var i = 0; i < tasks.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Riel + nodo
                  SizedBox(
                    width: 24,
                    child: Column(
                      children: [
                        const SizedBox(height: 4),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: priorityColor(tasks[i].prioridad),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.background,
                              width: 3,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            width: 2,
                            color: i == tasks.length - 1
                                ? Colors.transparent
                                : AppColors.surfaceHigh,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onTaskTap(tasks[i]),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceWarm,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.outlineSubtle),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tasks[i].hora,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tasks[i].titulo,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSurface,
                                    decoration: tasks[i].completada
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(_semanaTipoIcon(tasks[i].tipo),
                                        size: 14, color: AppColors.secondary),
                                    const SizedBox(width: 6),
                                    Text(
                                      tasks[i].materia,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _UntimedTaskRow extends StatelessWidget {
  const _UntimedTaskRow({
    required this.task,
    required this.onTap,
    required this.onToggle,
  });

  final TaskItem task;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLowest,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.outlineSubtle),
            boxShadow: AppShadow.sm,
          ),
          child: Row(
            children: [
              _CheckCircle(done: task.completada, onTap: onToggle, small: true),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                    decoration: task.completada
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _TaskChip(label: task.materia),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({
    required this.done,
    required this.onTap,
    this.small = false,
  });

  final bool done;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 22.0 : 24.0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? AppColors.mint : Colors.transparent,
          border: Border.all(
            color: done ? AppColors.mint : AppColors.outlineVariant,
            width: 1.6,
          ),
        ),
        child: done
            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
            : null,
      ),
    );
  }
}

// ─── Estado vacío del día ───────────────────────────────────────────────

class _DayEmptyState extends StatelessWidget {
  const _DayEmptyState({required this.day, required this.onAddTask});

  final DateTime day;
  final VoidCallback? onAddTask;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.outlineSubtle),
                    boxShadow: AppShadow.md,
                  ),
                  child: const Icon(Icons.local_cafe_rounded,
                      size: 56, color: AppColors.primary),
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLowest,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.outlineSubtle),
                      boxShadow: AppShadow.sm,
                    ),
                    child: const Icon(Icons.spa_rounded,
                        size: 16, color: AppColors.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              '${_weekdayLong(day.weekday)} ${day.day} ${_monthName(day.month).substring(0, 3)}',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Día libre de tareas agendadas. ¿Quieres adelantar algo de la próxima semana?',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 28),
            if (onAddTask != null)
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Agregar tarea',
                  icon: Icons.add_rounded,
                  onTap: onAddTask,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Botones / chips compartidos del header
// ─────────────────────────────────────────────────────────────────────────

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: AppColors.onSurface),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.onSurface),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

String _weekdayLong(int weekday) {
  const names = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  return names[weekday - 1];
}

// ─────────────────────────────────────────────────────────────────────────
// Selector de mes (modal) — reutilizado como bottom sheet
// ─────────────────────────────────────────────────────────────────────────

class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({
    required this.initialMonth,
    required this.byDay,
    required this.onPick,
  });
  final DateTime initialMonth;
  final Map<int, List<TaskItem>> byDay;
  final ValueChanged<DateTime> onPick;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late DateTime _month = DateTime(
    widget.initialMonth.year,
    widget.initialMonth.month,
  );

  void _shift(int amount) =>
      setState(() => _month = DateTime(_month.year, _month.month + amount));

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.66,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Seleccionar semana',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                _RoundIcon(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => _shift(-1),
                ),
                const SizedBox(width: 8),
                _RoundIcon(
                  icon: Icons.chevron_right_rounded,
                  onTap: () => _shift(1),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_monthName(_month.month)} ${_month.year}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ),
          Flexible(
            child: _MonthGrid(
              focusedDay: _month,
              byDay: widget.byDay,
              onDaySelected: widget.onPick,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.focusedDay,
    required this.byDay,
    required this.onDaySelected,
  });

  final DateTime focusedDay;
  final Map<int, List<TaskItem>> byDay;
  final ValueChanged<DateTime> onDaySelected;

  int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(focusedDay.year, focusedDay.month);
    final startOffset = first.weekday - 1;
    final start = first.subtract(Duration(days: startOffset));
    final days = List.generate(42, (i) => start.add(Duration(days: i)));
    final today = DateTime.now();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: const [
              _DayHeader('LUN'),
              _DayHeader('MAR'),
              _DayHeader('MIE'),
              _DayHeader('JUE'),
              _DayHeader('VIE'),
              _DayHeader('SÁB'),
              _DayHeader('DOM'),
            ],
          ),
        ),
        GridView.builder(
          itemCount: days.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (context, index) {
            final day = days[index];
            final dayTasks = byDay[_dayKey(day)] ?? const <TaskItem>[];
            final isToday = _sameDay(day, today);
            final inMonth = day.month == focusedDay.month;
            return _MonthCell(
              day: day,
              tasks: dayTasks,
              isToday: isToday,
              inMonth: inMonth,
              onTap: () => onDaySelected(day),
            );
          },
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: AppColors.secondary,
          ),
        ),
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.day,
    required this.tasks,
    required this.isToday,
    required this.inMonth,
    required this.onTap,
  });

  final DateTime day;
  final List<TaskItem> tasks;
  final bool isToday;
  final bool inMonth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accentDots = tasks.take(3).toList();
    final extra = tasks.length - accentDots.length;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: inMonth
                ? AppColors.surfaceLowest
                : AppColors.surfaceContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isToday
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : AppColors.outlineVariant.withValues(alpha: 0.45),
              width: isToday ? 1.6 : 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isToday ? AppColors.primary : Colors.transparent,
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isToday
                            ? Colors.white
                            : (inMonth
                                ? AppColors.onSurface
                                : AppColors.secondary.withValues(alpha: 0.6)),
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (accentDots.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < accentDots.length; i++) ...[
                      if (i > 0) const SizedBox(width: 3),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: priorityColor(accentDots[i].prioridad),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                    if (extra > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '+$extra',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
