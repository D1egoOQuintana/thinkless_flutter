part of '../../../main.dart';

enum CalendarMode { month, week, day }

/// Calendario premium con tres modos (Mes / Semana / Día).
///
/// Rango horario: 06:00 — 24:00 (18 bloques por día).
/// Performance: indexa todas las tareas en mapas (día → tareas, día×hora →
/// tareas) UNA sola vez por build, eliminando los O(n) por celda anteriores.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    required this.tasks,
    required this.onOpenTask,
    required this.onToggleTask,
    required this.noMolestar,
    super.key,
  });

  final List<TaskItem> tasks;
  final ValueChanged<TaskItem> onOpenTask;
  final ValueChanged<String> onToggleTask;
  final NoMolestarConfig noMolestar;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const int firstHour = 6;
  static const int lastHour = 24; // 12am
  static const int hourCount = lastHour - firstHour; // 18

  CalendarMode _mode = CalendarMode.month;
  DateTime _focusedDay = DateTime.now();

  // ─── Índices precomputados ──────────────────────────────────────────

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

  Map<int, List<TaskItem>> _hourBuckets(List<TaskItem> dayTasks) {
    final map = <int, List<TaskItem>>{};
    for (final t in dayTasks) {
      if (t.hora == 'Sin hora') continue;
      final h = _taskHour(t).clamp(firstHour, lastHour - 1);
      (map[h] ??= <TaskItem>[]).add(t);
    }
    return map;
  }

  // ─── Navegación ─────────────────────────────────────────────────────

  void _setMode(CalendarMode m) => setState(() => _mode = m);

  void _goToToday() => setState(() => _focusedDay = DateTime.now());

  void _shiftBy(int amount) {
    setState(() {
      _focusedDay = switch (_mode) {
        CalendarMode.month => DateTime(
          _focusedDay.year,
          _focusedDay.month + amount,
          1,
        ),
        CalendarMode.week => _focusedDay.add(Duration(days: 7 * amount)),
        CalendarMode.day => _focusedDay.add(Duration(days: amount)),
      };
    });
  }

  // ─── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final byDay = _indexByDay(widget.tasks);
    final silent = isNoMolestarActivo(widget.noMolestar);
    final todayCount = byDay[_dayKey(DateTime.now())]?.length ?? 0;
    final selectedCount = byDay[_dayKey(_focusedDay)]?.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _CalendarTopBar(
              mode: _mode,
              focusedDay: _focusedDay,
              todayCount: todayCount,
              selectedCount: selectedCount,
              silent: silent,
              onModeChanged: _setMode,
              onPrev: () => _shiftBy(-1),
              onNext: () => _shiftBy(1),
              onToday: _goToToday,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                child: KeyedSubtree(
                  key: ValueKey(_mode),
                  child: switch (_mode) {
                    CalendarMode.month => _MonthGrid(
                      focusedDay: _focusedDay,
                      byDay: byDay,
                      onDaySelected: (d) => setState(() {
                        _focusedDay = d;
                        _mode = CalendarMode.day;
                      }),
                    ),
                    CalendarMode.week => _WeekTimeline(
                      focusedDay: _focusedDay,
                      byDay: byDay,
                      firstHour: firstHour,
                      hourCount: hourCount,
                      onTaskTap: widget.onOpenTask,
                      onDayTap: (d) => setState(() {
                        _focusedDay = d;
                        _mode = CalendarMode.day;
                      }),
                    ),
                    CalendarMode.day => _DayTimeline(
                      day: _focusedDay,
                      dayTasks: byDay[_dayKey(_focusedDay)] ?? const [],
                      hourBuckets: _hourBuckets(
                        byDay[_dayKey(_focusedDay)] ?? const [],
                      ),
                      firstHour: firstHour,
                      hourCount: hourCount,
                      onTaskTap: widget.onOpenTask,
                      onToggleTask: widget.onToggleTask,
                    ),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Top bar: título, navegación, modo
// ─────────────────────────────────────────────────────────────────────────

class _CalendarTopBar extends StatelessWidget {
  const _CalendarTopBar({
    required this.mode,
    required this.focusedDay,
    required this.todayCount,
    required this.selectedCount,
    required this.silent,
    required this.onModeChanged,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final CalendarMode mode;
  final DateTime focusedDay;
  final int todayCount;
  final int selectedCount;
  final bool silent;
  final ValueChanged<CalendarMode> onModeChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  String _title() {
    return switch (mode) {
      CalendarMode.month =>
        '${_monthName(focusedDay.month)} ${focusedDay.year}',
      CalendarMode.week => _weekLabel(focusedDay),
      CalendarMode.day =>
        '${_shortDay(focusedDay.weekday)} ${focusedDay.day} ${_monthName(focusedDay.month).substring(0, 3).toLowerCase()}',
    };
  }

  static String _weekLabel(DateTime d) {
    final monday = d.subtract(Duration(days: d.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    if (monday.month == sunday.month) {
      return '${monday.day}–${sunday.day} ${_monthName(monday.month)}';
    }
    return '${monday.day} ${_monthName(monday.month).substring(0, 3).toLowerCase()} — ${sunday.day} ${_monthName(sunday.month).substring(0, 3).toLowerCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _sameDay(focusedDay, DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CALENDARIO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _title(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              _RoundIcon(icon: Icons.chevron_left_rounded, onTap: onPrev),
              const SizedBox(width: 8),
              _RoundIcon(icon: Icons.chevron_right_rounded, onTap: onNext),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ModeSegment(active: mode, onChanged: onModeChanged),
              ),
              const SizedBox(width: 10),
              _TodayPill(active: isToday, onTap: onToday),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniStat(
                icon: Icons.event_available_rounded,
                label: isToday
                    ? '$selectedCount hoy'
                    : '$selectedCount este día',
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              if (!isToday)
                _MiniStat(
                  icon: Icons.today_rounded,
                  label: '$todayCount hoy',
                  color: AppColors.mint,
                ),
              const Spacer(),
              if (silent)
                _MiniStat(
                  icon: Icons.notifications_off_rounded,
                  label: 'Silencio',
                  color: AppColors.onSurfaceVariant,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

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

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({required this.active, required this.onChanged});
  final CalendarMode active;
  final ValueChanged<CalendarMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _seg(CalendarMode.month, 'Mes'),
          _seg(CalendarMode.week, 'Semana'),
          _seg(CalendarMode.day, 'Día'),
        ],
      ),
    );
  }

  Expanded _seg(CalendarMode m, String label) {
    final isActive = m == active;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(m),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 38,
          decoration: BoxDecoration(
            color: isActive ? AppColors.surfaceLowest : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: isActive
                    ? AppColors.onSurface
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayPill extends StatelessWidget {
  const _TodayPill({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.today_rounded,
                size: 16,
                color: active ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Hoy',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: active ? AppColors.primary : AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
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
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Month grid (premium)
// ─────────────────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
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
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: AppColors.onSurfaceVariant,
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
                    gradient: isToday
                        ? const LinearGradient(
                            colors: [AppColors.primary, AppColors.indigo],
                          )
                        : null,
                    color: isToday ? null : Colors.transparent,
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isToday
                            ? Colors.white
                            : (inMonth
                                  ? AppColors.onSurface
                                  : AppColors.onSurfaceVariant.withValues(
                                      alpha: 0.6,
                                    )),
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
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurfaceVariant,
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

// ─────────────────────────────────────────────────────────────────────────
// Week timeline — vertical scroll, 7 columnas
// ─────────────────────────────────────────────────────────────────────────

class _WeekTimeline extends StatelessWidget {
  const _WeekTimeline({
    required this.focusedDay,
    required this.byDay,
    required this.firstHour,
    required this.hourCount,
    required this.onTaskTap,
    required this.onDayTap,
  });

  final DateTime focusedDay;
  final Map<int, List<TaskItem>> byDay;
  final int firstHour;
  final int hourCount;
  final ValueChanged<TaskItem> onTaskTap;
  final ValueChanged<DateTime> onDayTap;

  static const double _hourHeight = 64;
  static const double _gutterWidth = 44;

  int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  @override
  Widget build(BuildContext context) {
    final monday = focusedDay.subtract(Duration(days: focusedDay.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final today = DateTime.now();

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border(
              bottom: BorderSide(
                color: AppColors.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
          child: Row(
            children: [
              const SizedBox(width: _gutterWidth),
              for (final d in days)
                Expanded(
                  child: GestureDetector(
                    onTap: () => onDayTap(d),
                    behavior: HitTestBehavior.opaque,
                    child: _WeekDayHeader(
                      day: d,
                      isToday: _sameDay(d, today),
                      isFocused: _sameDay(d, focusedDay),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 110),
            child: SizedBox(
              height: hourCount * _hourHeight,
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: _gutterWidth,
                        child: Column(
                          children: [
                            for (var i = 0; i < hourCount; i++)
                              SizedBox(
                                height: _hourHeight,
                                child: _HourLabel(hour: firstHour + i),
                              ),
                          ],
                        ),
                      ),
                      for (final d in days)
                        Expanded(
                          child: _WeekDayColumn(
                            day: d,
                            firstHour: firstHour,
                            hourCount: hourCount,
                            hourHeight: _hourHeight,
                            tasks: byDay[_dayKey(d)] ?? const [],
                            onTaskTap: onTaskTap,
                            isToday: _sameDay(d, today),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekDayHeader extends StatelessWidget {
  const _WeekDayHeader({
    required this.day,
    required this.isToday,
    required this.isFocused,
  });

  final DateTime day;
  final bool isToday;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          _shortDay(day.weekday),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: isToday ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isToday
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.indigo],
                  )
                : null,
            color: isFocused && !isToday
                ? AppColors.surfaceContainer
                : Colors.transparent,
          ),
          child: Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isToday ? Colors.white : AppColors.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekDayColumn extends StatelessWidget {
  const _WeekDayColumn({
    required this.day,
    required this.firstHour,
    required this.hourCount,
    required this.hourHeight,
    required this.tasks,
    required this.onTaskTap,
    required this.isToday,
  });

  final DateTime day;
  final int firstHour;
  final int hourCount;
  final double hourHeight;
  final List<TaskItem> tasks;
  final ValueChanged<TaskItem> onTaskTap;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.primary.withValues(alpha: 0.04)
            : AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              for (var i = 0; i < hourCount; i++)
                SizedBox(
                  height: hourHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.outlineVariant.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (final task in tasks)
            if (task.hora != 'Sin hora')
              Positioned(
                left: 3,
                right: 3,
                top:
                    ((_taskMinutes(task) - firstHour * 60) / 60) * hourHeight,
                height: hourHeight - 4,
                child: _WeekTaskBlock(
                  task: task,
                  onTap: () => onTaskTap(task),
                ),
              ),
          if (isToday) _NowIndicator(firstHour: firstHour, height: hourHeight),
        ],
      ),
    );
  }
}

class _WeekTaskBlock extends StatelessWidget {
  const _WeekTaskBlock({required this.task, required this.onTap});
  final TaskItem task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = priorityColor(task.prioridad);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(color: accent, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                    height: 1.15,
                  ),
                ),
                if (task.hora != 'Sin hora') ...[
                  const SizedBox(height: 2),
                  Text(
                    task.hora,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Day timeline — vertical, premium
// ─────────────────────────────────────────────────────────────────────────

class _DayTimeline extends StatelessWidget {
  const _DayTimeline({
    required this.day,
    required this.dayTasks,
    required this.hourBuckets,
    required this.firstHour,
    required this.hourCount,
    required this.onTaskTap,
    required this.onToggleTask,
  });

  final DateTime day;
  final List<TaskItem> dayTasks;
  final Map<int, List<TaskItem>> hourBuckets;
  final int firstHour;
  final int hourCount;
  final ValueChanged<TaskItem> onTaskTap;
  final ValueChanged<String> onToggleTask;

  static const double _hourHeight = 80;
  static const double _gutterWidth = 56;

  @override
  Widget build(BuildContext context) {
    final untimed = dayTasks
        .where((t) => t.hora == 'Sin hora')
        .toList(growable: false);
    final isToday = _sameDay(day, DateTime.now());

    if (dayTasks.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: const [
          EmptyStateCard(
            icon: Icons.event_available,
            title: 'No hay tareas este día',
            body:
                'Agrega tareas con fecha y hora para verlas en la línea de tiempo.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      physics: const BouncingScrollPhysics(),
      children: [
        if (untimed.isNotEmpty) ...[
          const _SectionHead(label: 'Sin horario', icon: Icons.label_outline),
          const SizedBox(height: 8),
          for (final t in untimed)
            _UntimedTaskTile(
              task: t,
              onTap: () => onTaskTap(t),
              onToggle: () => onToggleTask(t.id),
            ),
          const SizedBox(height: 18),
        ],
        const _SectionHead(
          label: 'Línea de tiempo',
          icon: Icons.access_time_rounded,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: hourCount * _hourHeight + 8,
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: _gutterWidth,
                    child: Column(
                      children: [
                        for (var i = 0; i < hourCount; i++)
                          SizedBox(
                            height: _hourHeight,
                            child: _HourLabel(hour: firstHour + i, large: true),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            for (var i = 0; i < hourCount; i++)
                              SizedBox(
                                height: _hourHeight,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: AppColors.outlineVariant
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        for (final entry in hourBuckets.entries)
                          for (var i = 0; i < entry.value.length; i++)
                            Positioned(
                              left: 4,
                              right: 4,
                              top:
                                  ((_taskMinutes(entry.value[i]) -
                                              firstHour * 60) /
                                          60) *
                                      _hourHeight +
                                  (i * 4),
                              child: _DayTaskBlock(
                                task: entry.value[i],
                                onTap: () => onTaskTap(entry.value[i]),
                                onToggle: () =>
                                    onToggleTask(entry.value[i].id),
                              ),
                            ),
                        if (isToday)
                          _NowIndicator(
                            firstHour: firstHour,
                            height: _hourHeight,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _HourLabel extends StatelessWidget {
  const _HourLabel({required this.hour, this.large = false});
  final int hour;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final label = hour == 24 ? '00:00' : '${hour.toString().padLeft(2, '0')}:00';
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 2),
      child: Align(
        alignment: Alignment.topRight,
        child: Text(
          label,
          style: TextStyle(
            fontSize: large ? 12 : 11,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _DayTaskBlock extends StatelessWidget {
  const _DayTaskBlock({
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                        decoration: task.completada
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          task.hora,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: accent,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: AppColors.outlineVariant,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            task.materia,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: task.completada
                        ? AppColors.mint
                        : Colors.transparent,
                    border: Border.all(
                      color: task.completada
                          ? AppColors.mint
                          : AppColors.outlineVariant,
                      width: 1.6,
                    ),
                  ),
                  child: task.completada
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UntimedTaskTile extends StatelessWidget {
  const _UntimedTaskTile({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                      decoration: task.completada
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: task.completada
                          ? AppColors.mint
                          : Colors.transparent,
                      border: Border.all(
                        color: task.completada
                            ? AppColors.mint
                            : AppColors.outlineVariant,
                        width: 1.4,
                      ),
                    ),
                    child: task.completada
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
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

class _NowIndicator extends StatelessWidget {
  const _NowIndicator({required this.firstHour, required this.height});
  final int firstHour;
  final double height;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    final offset = ((minutes - firstHour * 60) / 60) * height;
    if (offset < 0) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      top: offset,
      child: IgnorePointer(
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(left: 0),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Container(
                height: 1.5,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
