part of '../../../main.dart';

/// Fases visuales del FocusScreen.
enum _FocusPhase { idle, running, completed }

/// FocusScreen rediseñado con tres fases: Idle, Running, Completed.
///
/// Inspirado en Linear/Notion/Headspace: minimalista, jerarquía clara,
/// timer dominante en Running, celebración mesurada en Completed. La fase
/// Idle permite elegir tarea y duración antes de empezar.
///
/// API retrocompatible: si se construye con solo `noMolestar`, funciona
/// como un Pomodoro de 25 minutos sin tarea, igual que antes.
class FocusScreen extends StatefulWidget {
  const FocusScreen({
    required this.noMolestar,
    this.initialMinutes = 25,
    this.initialTaskTitle,
    this.initialTaskId,
    this.tasks = const [],
    this.sessionsToday = 0,
    this.minutesToday = 0,
    this.onSessionCompleted,
    this.onMarkTaskDone,
    this.onExit,
    super.key,
  });

  final NoMolestarConfig noMolestar;
  final int initialMinutes;
  final String? initialTaskTitle;
  final String? initialTaskId;
  final List<TaskItem> tasks;
  final int sessionsToday;
  final int minutesToday;
  final ValueChanged<int>? onSessionCompleted;
  final ValueChanged<String>? onMarkTaskDone;
  final VoidCallback? onExit;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with TickerProviderStateMixin {
  static const _presetDurations = [25, 45, 60];
  static const _plannedSessions = 4;

  _FocusPhase _phase = _FocusPhase.idle;
  int _durationMinutes = 25;
  TaskItem? _selectedTask;
  int _completedSessions = 0;

  Timer? _timer;
  late final ValueNotifier<int> _secondsLeft;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _durationMinutes = widget.initialMinutes;
    _secondsLeft = ValueNotifier<int>(_durationMinutes * 60);
    if (widget.initialTaskId != null) {
      _selectedTask = widget.tasks.firstWhereOrNull(
        (t) => t.id == widget.initialTaskId,
      );
    }
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _secondsLeft.dispose();
    _pulse.dispose();
    super.dispose();
  }

  // ─── Acciones ────────────────────────────────────────────────────────

  void _setDuration(int minutes) {
    if (_phase != _FocusPhase.idle) return;
    setState(() {
      _durationMinutes = minutes;
      _secondsLeft.value = minutes * 60;
    });
  }

  void _pickTask() async {
    final result = await showModalBottomSheet<TaskItem?>(
      context: context,
      backgroundColor: AppColors.surfaceLowest,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _TaskPickerSheet(
        tasks: widget.tasks.where((t) => !t.completada).toList(),
        currentId: _selectedTask?.id,
      ),
    );
    if (!mounted) return;
    if (result == null) return;
    setState(() => _selectedTask = result.id.isEmpty ? null : result);
  }

  void _start() {
    if (_phase == _FocusPhase.running) return;
    setState(() => _phase = _FocusPhase.running);
    _pulse.repeat(reverse: true);
    _runTimer();
  }

  void _pause() {
    _timer?.cancel();
    _pulse.stop();
    setState(() {});
  }

  bool get _isRunning => _timer?.isActive ?? false;

  void _resume() {
    if (_isRunning) return;
    _pulse.repeat(reverse: true);
    _runTimer();
    setState(() {});
  }

  void _runTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = _secondsLeft.value;
      if (current <= 1) {
        _secondsLeft.value = 0;
        _timer?.cancel();
        _pulse.stop();
        _onCompleted();
        return;
      }
      _secondsLeft.value = current - 1;
    });
  }

  void _onCompleted() {
    if (!isNoMolestarActivo(widget.noMolestar)) {
      SystemSound.play(SystemSoundType.alert);
    }
    _completedSessions++;
    widget.onSessionCompleted?.call(_durationMinutes);
    if (mounted) {
      _smartNotice(
        context,
        'Sesión completada: $_durationMinutes min de enfoque.',
        config: widget.noMolestar,
        urgent: true,
      );
    }
    setState(() => _phase = _FocusPhase.completed);
  }

  void _skip() {
    _timer?.cancel();
    _pulse.stop();
    _onCompleted();
  }

  void _newSession() {
    setState(() {
      _phase = _FocusPhase.idle;
      _secondsLeft.value = _durationMinutes * 60;
    });
  }

  void _markCurrentTaskDone() {
    final id = _selectedTask?.id;
    if (id == null) return;
    widget.onMarkTaskDone?.call(id);
    setState(() => _selectedTask = null);
    widget.onExit?.call();
  }

  void _abandon() {
    _timer?.cancel();
    _pulse.stop();
    setState(() {
      _phase = _FocusPhase.idle;
      _secondsLeft.value = _durationMinutes * 60;
    });
  }

  // ─── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _phase == _FocusPhase.running
          ? AppColors.background
          : AppColors.background,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(_phase),
            child: switch (_phase) {
              _FocusPhase.idle => _buildIdle(),
              _FocusPhase.running => _buildRunning(),
              _FocusPhase.completed => _buildCompleted(),
            },
          ),
        ),
      ),
    );
  }

  // ─── Idle ────────────────────────────────────────────────────────────

  Widget _buildIdle() {
    final sessions = widget.sessionsToday + _completedSessions;
    final minutes = widget.minutesToday;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _IdleHeader(onClose: widget.onExit),
          const SizedBox(height: 28),
          Text(
            'Listo para enfocarte',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Elige una tarea, fija tu tiempo y empieza.',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          _TaskSelectorTile(
            task: _selectedTask,
            onTap: widget.tasks.isEmpty ? null : _pickTask,
            onClear: _selectedTask == null
                ? null
                : () => setState(() => _selectedTask = null),
          ),
          const SizedBox(height: 20),
          const _FocusSectionLabel(label: 'Duración'),
          const SizedBox(height: 10),
          _DurationChips(
            presets: _presetDurations,
            selected: _durationMinutes,
            onChanged: _setDuration,
          ),
          const SizedBox(height: 28),
          _StatsCard(sessions: sessions, minutes: minutes),
          const SizedBox(height: 28),
          _StartButton(
            onTap: _start,
            label: 'Iniciar sesión',
            minutes: _durationMinutes,
          ),
        ],
      ),
    );
  }

  // ─── Running ─────────────────────────────────────────────────────────

  Widget _buildRunning() {
    final total = _durationMinutes * 60;
    final sessionLabel =
        'Sesión ${(_completedSessions + 1).clamp(1, _plannedSessions)} de $_plannedSessions';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        children: [
          Row(
            children: [
              _DarkIconButton(
                icon: Icons.close_rounded,
                onTap: _abandon,
              ),
              const Spacer(),
              if (_selectedTask != null)
                Flexible(
                  child: _ActiveTaskChip(task: _selectedTask!),
                ),
              const Spacer(),
              _DarkIconButton(
                icon: Icons.skip_next_rounded,
                onTap: _skip,
              ),
            ],
          ),
          const Spacer(),
          ValueListenableBuilder<int>(
            valueListenable: _secondsLeft,
            builder: (context, seconds, _) {
              return _TimerRing(
                seconds: seconds,
                total: total,
                pulse: _pulse,
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            sessionLabel.toUpperCase(),
            style: const TextStyle(
              color: AppColors.secondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 18),
          _PlannedDots(
            planned: _plannedSessions,
            done: _completedSessions,
          ),
          const Spacer(),
          AnimatedBuilder(
            animation: Listenable.merge([
              if (_timer != null) const AlwaysStoppedAnimation(0),
            ]),
            builder: (_, _) => _RunningControls(
              running: _isRunning,
              onToggle: _isRunning ? _pause : _resume,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Completed ───────────────────────────────────────────────────────

  Widget _buildCompleted() {
    final sessions = widget.sessionsToday + _completedSessions;
    final minutes = widget.minutesToday;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _IdleHeader(onClose: widget.onExit),
          ),
          const SizedBox(height: 32),
          const _SparkleBadge(),
          const SizedBox(height: 28),
          Text(
            '¡Sesión completada!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedTask == null
                ? '$_durationMinutes min de enfoque profundo'
                : '$_durationMinutes min · ${_selectedTask!.titulo}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          _StatsCard(sessions: sessions, minutes: minutes, accent: true),
          const SizedBox(height: 28),
          if (_selectedTask != null)
            _PrimaryAction(
              icon: Icons.check_circle_rounded,
              label: 'Marcar tarea como lista',
              onTap: _markCurrentTaskDone,
            ),
          const SizedBox(height: 10),
          _SecondaryAction(
            icon: Icons.replay_rounded,
            label: 'Otra sesión',
            onTap: _newSession,
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: widget.onExit,
              child: const Text(
                'Volver al inicio',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Idle widgets
// ─────────────────────────────────────────────────────────────────────────

class _IdleHeader extends StatelessWidget {
  const _IdleHeader({this.onClose});
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.center_focus_strong_rounded,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Enfoque',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppColors.onSurface,
          ),
        ),
        const Spacer(),
        if (onClose != null)
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            color: AppColors.onSurfaceVariant,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceContainer,
            ),
          ),
      ],
    );
  }
}

class _FocusSectionLabel extends StatelessWidget {
  const _FocusSectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: AppColors.onSurfaceVariant,
      ),
    );
  }
}

class _TaskSelectorTile extends StatelessWidget {
  const _TaskSelectorTile({
    required this.task,
    required this.onTap,
    required this.onClear,
  });

  final TaskItem? task;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasTask = task != null;
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: hasTask
                ? AppColors.primary.withValues(alpha: 0.06)
                : AppColors.surfaceLowest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasTask
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.outlineVariant.withValues(alpha: 0.6),
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: hasTask
                      ? AppColors.primary.withValues(alpha: 0.14)
                      : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  hasTask
                      ? Icons.assignment_turned_in_rounded
                      : Icons.add_task_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasTask ? task!.titulo : 'Elige una tarea',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasTask
                          ? '${task!.materia} · ${priorityLabel(task!.prioridad)}'
                          : disabled
                                ? 'No hay tareas pendientes'
                                : 'Opcional · enfoca en lo importante',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasTask && onClear != null)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.onSurfaceVariant,
                )
              else
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationChips extends StatelessWidget {
  const _DurationChips({
    required this.presets,
    required this.selected,
    required this.onChanged,
  });

  final List<int> presets;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < presets.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _DurationChip(
              minutes: presets[i],
              active: presets[i] == selected,
              onTap: () => onChanged(presets[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.minutes,
    required this.active,
    required this.onTap,
  });

  final int minutes;
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
          padding: const EdgeInsets.symmetric(vertical: 16),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$minutes',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: active ? AppColors.primary : AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'min',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: active
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.sessions,
    required this.minutes,
    this.accent = false,
  });

  final int sessions;
  final int minutes;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: accent
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1.4,
              )
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatBlock(
              icon: Icons.local_fire_department_rounded,
              value: '$sessions',
              label: 'Sesiones hoy',
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
          Expanded(
            child: _StatBlock(
              icon: Icons.bolt_rounded,
              value: '$minutes',
              label: 'Minutos hoy',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 2),
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

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.onTap,
    required this.label,
    required this.minutes,
  });

  final VoidCallback onTap;
  final String label;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.indigo],
            ),
            boxShadow: _activeShadow,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 26,
              ),
              const SizedBox(width: 6),
              Text(
                '$label · $minutes min',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 0.3,
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
// Running widgets — fondo oscuro inmersivo
// ─────────────────────────────────────────────────────────────────────────

class _DarkIconButton extends StatelessWidget {
  const _DarkIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Icon(icon, color: AppColors.onSurfaceVariant, size: 20),
        ),
      ),
    );
  }
}

class _ActiveTaskChip extends StatelessWidget {
  const _ActiveTaskChip({required this.task});
  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final accent = priorityColor(task.prioridad);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              task.titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerRing extends StatelessWidget {
  const _TimerRing({
    required this.seconds,
    required this.total,
    required this.pulse,
  });

  final int seconds;
  final int total;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : 1 - (seconds / total);
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final glow = 0.4 + (pulse.value * 0.6);
        return SizedBox(
          width: 280,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary
                          .withValues(alpha: 0.18 * glow),
                      blurRadius: 60,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 260,
                height: 260,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: progress, end: progress),
                  duration: const Duration(milliseconds: 950),
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    backgroundColor: AppColors.surfaceHigh,
                    valueColor: const AlwaysStoppedAnimation(
                      AppColors.primary,
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$m:$s',
                    style: const TextStyle(
                      fontSize: 66,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                      letterSpacing: -1.5,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlannedDots extends StatelessWidget {
  const _PlannedDots({required this.planned, required this.done});
  final int planned;
  final int done;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < planned; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            width: i == done ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i < done
                  ? AppColors.primary
                  : i == done
                        ? AppColors.primary.withValues(alpha: 0.55)
                        : AppColors.outlineVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ],
      ],
    );
  }
}

class _RunningControls extends StatelessWidget {
  const _RunningControls({required this.running, required this.onToggle});
  final bool running;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.indigo],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Icon(
            running ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Completed widgets
// ─────────────────────────────────────────────────────────────────────────

class _SparkleBadge extends StatefulWidget {
  const _SparkleBadge();

  @override
  State<_SparkleBadge> createState() => _SparkleBadgeState();
}

class _SparkleBadgeState extends State<_SparkleBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final scale = Curves.elasticOut.transform(_c.value).clamp(0.0, 1.2);
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.indigo],
                ),
                boxShadow: _activeShadow,
              ),
              child: const Icon(
                Icons.celebration_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
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
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.indigo],
            ),
            boxShadow: _activeShadow,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
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
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            color: AppColors.surfaceContainer,
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.onSurface),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
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
// Task picker sheet (Idle → seleccionar tarea)
// ─────────────────────────────────────────────────────────────────────────

class _TaskPickerSheet extends StatelessWidget {
  const _TaskPickerSheet({required this.tasks, required this.currentId});

  final List<TaskItem> tasks;
  final String? currentId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Elige una tarea',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Solo se muestran tareas pendientes.',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: tasks.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'No hay tareas pendientes',
                            style: TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: tasks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final t = tasks[index];
                          final selected = t.id == currentId;
                          return _PickerTile(
                            task: t,
                            selected: selected,
                            onTap: () => Navigator.pop(context, t),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  TaskItem(
                    id: '',
                    titulo: '',
                    materia: '',
                    fecha: '',
                    hora: '',
                    prioridad: 'media',
                    tipo: 'otro',
                    completada: false,
                    fechaCreacion: DateTime.now(),
                  ),
                ),
                icon: const Icon(Icons.clear_rounded, size: 18),
                label: const Text(
                  'Sin tarea (enfoque libre)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.task,
    required this.selected,
    required this.onTap,
  });

  final TaskItem task;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = priorityColor(task.prioridad);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 36,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${task.materia} · ${priorityLabel(task.prioridad)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _IterableFirstOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
