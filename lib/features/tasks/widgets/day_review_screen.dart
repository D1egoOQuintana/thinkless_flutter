part of '../../../main.dart';

/// Pantalla de revisión del día.
///
/// Muestra cuatro bloques verticales: métricas compactas, logros del día,
/// pendientes con acciones inline de reprogramación, y preview de mañana.
class DayReviewScreen extends StatelessWidget {
  const DayReviewScreen({
    required this.tasks,
    required this.onToggleTask,
    required this.onOpenTask,
    required this.onReschedule,
    required this.onBack,
    super.key,
  });

  final List<TaskItem> tasks;
  final ValueChanged<String> onToggleTask;
  final ValueChanged<TaskItem> onOpenTask;
  final Future<void> Function(String id, DateTime newDate) onReschedule;
  final VoidCallback onBack;

  static const _months = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  static const _weekdays = [
    'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final completedToday = <TaskItem>[];
    final pendingToday = <TaskItem>[];
    final plannedTomorrow = <TaskItem>[];

    for (final t in tasks) {
      final d = _taskDate(t);
      if (_sameDay(d, today)) {
        (t.completada ? completedToday : pendingToday).add(t);
      } else if (_sameDay(d, tomorrow) && !t.completada) {
        plannedTomorrow.add(t);
      }
    }

    pendingToday.sort((a, b) => _taskMinutes(a).compareTo(_taskMinutes(b)));
    plannedTomorrow.sort((a, b) => _taskMinutes(a).compareTo(_taskMinutes(b)));

    final dateLabel =
        '${_capitalize(_weekdays[today.weekday - 1])} ${today.day} de ${_months[today.month - 1]}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _ReviewHeader(
                date: dateLabel,
                onBack: onBack,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              sliver: SliverToBoxAdapter(
                child: DaySummaryMetrics(
                  completed: completedToday.length,
                  pending: pendingToday.length,
                  tomorrow: plannedTomorrow.length,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _SectionTitle(
                  icon: Icons.check_circle_rounded,
                  iconColor: AppColors.mint,
                  title: 'Logros del día',
                  count: completedToday.length,
                ),
              ),
            ),
            if (completedToday.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: _EmptyHint(
                    icon: Icons.spa_outlined,
                    text: 'Aún no completaste tareas hoy.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                sliver: SliverList.separated(
                  itemCount: completedToday.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _CompletedRow(
                    task: completedToday[i],
                    onTap: () => onOpenTask(completedToday[i]),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _SectionTitle(
                  icon: Icons.pending_actions_rounded,
                  iconColor: AppColors.yellow,
                  title: 'Quedaron pendientes',
                  count: pendingToday.length,
                ),
              ),
            ),
            if (pendingToday.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: _EmptyHint(
                    icon: Icons.celebration_outlined,
                    text: '¡Sin pendientes! Día limpio.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                sliver: SliverList.separated(
                  itemCount: pendingToday.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => RescheduleTaskRow(
                    task: pendingToday[i],
                    onToggleDone: () => onToggleTask(pendingToday[i].id),
                    onReschedule: (newDate) =>
                        onReschedule(pendingToday[i].id, newDate),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              sliver: SliverToBoxAdapter(
                child: _SectionTitle(
                  icon: Icons.wb_twilight_rounded,
                  iconColor: AppColors.primary,
                  title: 'Mañana',
                  count: plannedTomorrow.length,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              sliver: SliverToBoxAdapter(
                child: TomorrowPreviewCard(tasks: plannedTomorrow),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              sliver: SliverToBoxAdapter(
                child: PrimaryButton(
                  label: 'Cerrar el día',
                  icon: Icons.bedtime_rounded,
                  onTap: onBack,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _capitalize(String v) =>
      v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);
}

// ─────────────────────────────────────────────────────────────────────────
// Header con fecha prominente
// ─────────────────────────────────────────────────────────────────────────

class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader({required this.date, required this.onBack});
  final String date;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.onSurface,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REVISIÓN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6C33FF), Color(0xFF9B6FFF)],
              ),
            ),
            child: const Icon(
              Icons.nightlight_round,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// DaySummaryMetrics — 3 números grandes en fila
// ─────────────────────────────────────────────────────────────────────────

class DaySummaryMetrics extends StatelessWidget {
  const DaySummaryMetrics({
    required this.completed,
    required this.pending,
    required this.tomorrow,
    super.key,
  });

  final int completed;
  final int pending;
  final int tomorrow;

  @override
  Widget build(BuildContext context) {
    final total = completed + pending;
    final progress = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricBlock(
                  value: '$completed',
                  label: 'Completadas',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.mint,
                ),
              ),
              _Divider(),
              Expanded(
                child: _MetricBlock(
                  value: '$pending',
                  label: 'Pendientes',
                  icon: Icons.hourglass_bottom_rounded,
                  color: AppColors.yellow,
                ),
              ),
              _Divider(),
              Expanded(
                child: _MetricBlock(
                  value: '$tomorrow',
                  label: 'Mañana',
                  icon: Icons.event_rounded,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => Stack(
                        children: [
                          Container(
                            height: 6,
                            color: AppColors.surfaceContainer,
                          ),
                          FractionallySizedBox(
                            widthFactor: v.clamp(0.0, 1.0),
                            child: Container(
                              height: 6,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.mint,
                                    Color(0xFF6C33FF),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 56,
      color: AppColors.outlineVariant.withValues(alpha: 0.45),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Section title
// ─────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.onSurfaceVariant, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// CompletedRow — tarea hecha (muted)
// ─────────────────────────────────────────────────────────────────────────

class _CompletedRow extends StatelessWidget {
  const _CompletedRow({required this.task, required this.onTap});
  final TaskItem task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppColors.mint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface.withValues(alpha: 0.6),
                    decoration: TextDecoration.lineThrough,
                    decorationColor: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                task.materia,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// RescheduleTaskRow — pendiente con acciones inline
// ─────────────────────────────────────────────────────────────────────────

class RescheduleTaskRow extends StatelessWidget {
  const RescheduleTaskRow({
    required this.task,
    required this.onToggleDone,
    required this.onReschedule,
    super.key,
  });

  final TaskItem task;
  final VoidCallback onToggleDone;
  final Future<void> Function(DateTime newDate) onReschedule;

  @override
  Widget build(BuildContext context) {
    final accent = priorityColor(task.prioridad);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final endOfWeek = today.add(
      Duration(days: ((DateTime.friday - now.weekday + 7) % 7).clamp(2, 7)),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 38,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${task.materia} · ${priorityLabel(task.prioridad)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RoundCheck(onTap: onToggleDone),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RescheduleChip(
                  icon: Icons.wb_sunny_outlined,
                  label: 'Mañana',
                  onTap: () => onReschedule(tomorrow),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _RescheduleChip(
                  icon: Icons.weekend_outlined,
                  label: 'Viernes',
                  onTap: () => onReschedule(endOfWeek),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _RescheduleChip(
                  icon: Icons.event,
                  label: 'Otro',
                  onTap: () => _pickCustomDate(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, now.month, now.day),
      helpText: 'Reprogramar tarea',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
    );
    if (picked != null) {
      await onReschedule(
        DateTime(picked.year, picked.month, picked.day),
      );
    }
  }
}

class _RoundCheck extends StatelessWidget {
  const _RoundCheck({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.outlineVariant,
              width: 1.6,
            ),
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 18,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _RescheduleChip extends StatelessWidget {
  const _RescheduleChip({
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
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
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

// ─────────────────────────────────────────────────────────────────────────
// TomorrowPreviewCard — preview de tareas del día siguiente
// ─────────────────────────────────────────────────────────────────────────

class TomorrowPreviewCard extends StatelessWidget {
  const TomorrowPreviewCard({required this.tasks, super.key});

  final List<TaskItem> tasks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            const Color(0xFF9B6FFF).withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.wb_twilight_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                tasks.isEmpty
                    ? 'Mañana sin tareas programadas'
                    : '${tasks.length} tarea${tasks.length == 1 ? '' : 's'} para mañana',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (tasks.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final t in tasks.take(4)) ...[
              _TomorrowItem(task: t),
              const SizedBox(height: 6),
            ],
            if (tasks.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+ ${tasks.length - 4} más',
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              'Aprovecha para descansar o adelantar algo personal.',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TomorrowItem extends StatelessWidget {
  const _TomorrowItem({required this.task});
  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final accent = priorityColor(task.prioridad);
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            task.titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.onSurface,
            ),
          ),
        ),
        if (task.hora != 'Sin hora') ...[
          const SizedBox(width: 8),
          Text(
            task.hora,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}
