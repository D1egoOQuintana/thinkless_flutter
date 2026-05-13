part of '../../../main.dart';

/// Estima los minutos típicos de una tarea según su tipo.
///
/// Es una heurística determinista (sin estado, sin allocs) — segura para
/// usar dentro de filtros y sorts del UI thread.
int estimatedMinutes(TaskItem task) {
  return switch (task.tipo.toLowerCase()) {
    'examen' => 45,
    'proyecto' => 60,
    'laboratorio' => 45,
    'tarea' => 30,
    'lectura' => 20,
    'otro' => 25,
    _ => 25,
  };
}

/// Bottom sheet para registrar tiempo libre y obtener sugerencias.
///
/// El usuario elige cuánto tiempo tiene y el sheet filtra/ordena tareas
/// pendientes para sugerir hasta 3 que encajan en ese tiempo. Tocar una
/// sugerencia cierra el sheet y abre FocusScreen con esa tarea y duración.
class FreeTimeSheet extends StatefulWidget {
  const FreeTimeSheet({
    required this.tasks,
    required this.onStartFocus,
    super.key,
  });

  final List<TaskItem> tasks;
  final void Function(TaskItem? task, int minutes) onStartFocus;

  @override
  State<FreeTimeSheet> createState() => _FreeTimeSheetState();
}

class _FreeTimeSheetState extends State<FreeTimeSheet> {
  static const _presets = [15, 30, 60];
  int _minutes = 30;

  late final List<TaskItem> _pending = widget.tasks
      .where((t) => !t.completada)
      .toList(growable: false);

  List<TaskItem> get _suggestions {
    final rank = {'urgente': 0, 'alta': 1, 'media': 2, 'baja': 3};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final fitting = _pending
        .where((t) => estimatedMinutes(t) <= _minutes)
        .toList();

    fitting.sort((a, b) {
      final pa = rank[a.prioridad] ?? 2;
      final pb = rank[b.prioridad] ?? 2;
      if (pa != pb) return pa.compareTo(pb);

      final da = _taskDate(a).difference(today).inDays.abs();
      final db = _taskDate(b).difference(today).inDays.abs();
      if (da != db) return da.compareTo(db);

      return estimatedMinutes(b).compareTo(estimatedMinutes(a));
    });

    return fitting.take(3).toList();
  }

  Future<void> _pickCustom() async {
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => _CustomDurationDialog(initial: _minutes),
    );
    if (result != null && mounted) {
      setState(() => _minutes = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(),
              const SizedBox(height: 16),
              TimeChipSelector(
                presets: _presets,
                selectedMinutes: _minutes,
                onChanged: (m) => setState(() => _minutes = m),
                onPickCustom: _pickCustom,
              ),
              const SizedBox(height: 24),
              _SectionLabel(
                label: suggestions.isEmpty
                    ? 'Sin coincidencias'
                    : 'Sugerido para ti',
                count: suggestions.length,
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                child: suggestions.isEmpty
                    ? _EmptySuggestions(
                        key: const ValueKey('empty'),
                        minutes: _minutes,
                        onStartGeneral: () =>
                            widget.onStartFocus(null, _minutes),
                      )
                    : Column(
                        key: ValueKey('list-${suggestions.length}-$_minutes'),
                        children: [
                          for (final t in suggestions) ...[
                            SuggestionCard(
                              task: t,
                              estimated: estimatedMinutes(t),
                              onStart: () => widget.onStartFocus(t, _minutes),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 8),
              if (suggestions.isNotEmpty)
                Center(
                  child: TextButton.icon(
                    onPressed: () => widget.onStartFocus(null, _minutes),
                    icon: const Icon(Icons.timer_outlined, size: 18),
                    label: const Text(
                      'Solo enfocar sin tarea',
                      style: TextStyle(fontWeight: FontWeight.w700),
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
// TimeChipSelector — chips de duración + personalizar
// ─────────────────────────────────────────────────────────────────────────

class TimeChipSelector extends StatelessWidget {
  const TimeChipSelector({
    required this.presets,
    required this.selectedMinutes,
    required this.onChanged,
    required this.onPickCustom,
    super.key,
  });

  final List<int> presets;
  final int selectedMinutes;
  final ValueChanged<int> onChanged;
  final VoidCallback onPickCustom;

  @override
  Widget build(BuildContext context) {
    final isCustom = !presets.contains(selectedMinutes);
    return Row(
      children: [
        for (final p in presets) ...[
          Expanded(
            child: _TimeChip(
              label: _formatMinutes(p),
              active: selectedMinutes == p && !isCustom,
              onTap: () => onChanged(p),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: _TimeChip(
            label: isCustom ? _formatMinutes(selectedMinutes) : 'Personalizar',
            icon: isCustom ? Icons.tune : Icons.add,
            active: isCustom,
            onTap: onPickCustom,
          ),
        ),
      ],
    );
  }

  static String _formatMinutes(int m) {
    if (m >= 60 && m % 60 == 0) return '${m ~/ 60} h';
    if (m >= 60) return '${(m / 60).toStringAsFixed(1)} h';
    return '$m min';
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.10)
                : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              width: 1.4,
              color: active
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: active
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: active ? AppColors.primary : AppColors.onSurface,
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
// SuggestionCard — una tarea sugerida con CTA
// ─────────────────────────────────────────────────────────────────────────

class SuggestionCard extends StatelessWidget {
  const SuggestionCard({
    required this.task,
    required this.estimated,
    required this.onStart,
    super.key,
  });

  final TaskItem task;
  final int estimated;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final accent = priorityColor(task.prioridad);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onStart,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceLowest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _DotMeta(
                          icon: Icons.school_outlined,
                          label: task.materia,
                        ),
                        _DotSeparator(),
                        _DotMeta(
                          icon: Icons.schedule,
                          label: '~$estimated min',
                        ),
                        _DotSeparator(),
                        Flexible(
                          child: Text(
                            priorityLabel(task.prioridad),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: accent,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C33FF), Color(0xFF9B6FFF)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _softShadow,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DotMeta extends StatelessWidget {
  const _DotMeta({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotSeparator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: AppColors.outlineVariant,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Otros privados
// ─────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tengo tiempo libre',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '¿Cuánto tiempo tienes ahora?',
          style: TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 13,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
      ],
    );
  }
}

class _EmptySuggestions extends StatelessWidget {
  const _EmptySuggestions({
    required this.minutes,
    required this.onStartGeneral,
    super.key,
  });

  final int minutes;
  final VoidCallback onStartGeneral;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.spa_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sin tareas que encajen',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Aprovecha para un repaso libre de $minutes min.',
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Iniciar enfoque de $minutes min',
            icon: Icons.play_arrow_rounded,
            onTap: onStartGeneral,
          ),
        ],
      ),
    );
  }
}

class _CustomDurationDialog extends StatefulWidget {
  const _CustomDurationDialog({required this.initial});
  final int initial;

  @override
  State<_CustomDurationDialog> createState() => _CustomDurationDialogState();
}

class _CustomDurationDialogState extends State<_CustomDurationDialog> {
  late double _value = widget.initial.toDouble().clamp(5, 120);

  @override
  Widget build(BuildContext context) {
    final minutes = _value.round();
    return Dialog(
      backgroundColor: AppColors.surfaceLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tiempo personalizado',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Desliza para elegir cuántos minutos tienes.',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$minutes',
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'min',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.surfaceContainer,
                thumbColor: AppColors.primary,
                overlayColor: AppColors.primary.withValues(alpha: 0.12),
                trackHeight: 6,
              ),
              child: Slider(
                value: _value,
                min: 5,
                max: 120,
                divisions: 23,
                onChanged: (v) => setState(() => _value = v),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, minutes),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Listo',
                    style: TextStyle(fontWeight: FontWeight.w800),
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
