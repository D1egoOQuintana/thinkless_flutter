part of '../../../main.dart';

/// Pantalla completa para organizar prioridades de tareas pendientes.
///
/// UX inspirada en Linear/Vercel: una tarea a la vez, gesto horizontal
/// para saltar, 4 acciones rápidas para asignar prioridad. Las tarjetas
/// salen con animación elegante hacia arriba al asignar.
class PriorityOrganizerScreen extends StatefulWidget {
  const PriorityOrganizerScreen({
    required this.tasks,
    required this.onUpdatePriority,
    required this.onBack,
    super.key,
  });

  final List<TaskItem> tasks;
  final Future<void> Function(String id, String priority) onUpdatePriority;
  final VoidCallback onBack;

  @override
  State<PriorityOrganizerScreen> createState() =>
      _PriorityOrganizerScreenState();
}

class _PriorityOrganizerScreenState extends State<PriorityOrganizerScreen>
    with SingleTickerProviderStateMixin {
  static const _levels = ['urgente', 'alta', 'media', 'baja'];

  late final List<TaskItem> _queue;
  late final int _initialPending;
  int _index = 0;
  int _organized = 0;

  // Drag state — ValueNotifier para evitar rebuilds del scaffold.
  final _drag = ValueNotifier<Offset>(Offset.zero);

  late final AnimationController _exit;
  Offset _exitTarget = Offset.zero;

  @override
  void initState() {
    super.initState();
    _queue = widget.tasks.where((t) => !t.completada).toList();
    _initialPending = _queue.length;
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addStatusListener(_onExitStatus);
  }

  @override
  void dispose() {
    _exit.removeStatusListener(_onExitStatus);
    _exit.dispose();
    _drag.dispose();
    super.dispose();
  }

  void _onExitStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() => _index++);
      _drag.value = Offset.zero;
      _exit.reset();
    }
  }

  TaskItem? get _current => _index < _queue.length ? _queue[_index] : null;
  TaskItem? get _next => _index + 1 < _queue.length ? _queue[_index + 1] : null;

  bool get _busy => _exit.isAnimating;

  void _assign(String priority) {
    final t = _current;
    if (t == null || _busy) return;
    _exitTarget = const Offset(0, -1.25);
    _organized++;
    widget.onUpdatePriority(t.id, priority);
    _exit.forward(from: 0);
  }

  void _skip([double direction = -1]) {
    if (_current == null || _busy) return;
    _exitTarget = Offset(direction.sign == 0 ? -1 : direction.sign * 1.4, 0);
    _exit.forward(from: 0);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_busy) return;
    _drag.value = _drag.value + d.delta;
  }

  void _onPanEnd(DragEndDetails d) {
    if (_busy) return;
    final dx = _drag.value.dx;
    if (dx.abs() > 130) {
      _skip(dx);
    } else {
      _drag.value = Offset.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _OrganizerHeader(
              onBack: widget.onBack,
              onSkip: _current == null ? null : _skip,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: PriorityProgressBar(
                done: _organized,
                total: _initialPending,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _current == null
                  ? _EmptyState(
                      onBack: widget.onBack,
                      organized: _organized,
                    )
                  : _buildDeck(),
            ),
            if (_current != null)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: _PriorityActionRow(
                    levels: _levels,
                    onTap: _busy ? null : _assign,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeck() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth - 40;
        final cardHeight = constraints.maxHeight - 24;
        return Center(
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_next != null)
                  _PeekCard(
                    task: _next!,
                    width: cardWidth,
                    height: cardHeight,
                    exit: _exit,
                  ),
                _ActiveCard(
                  task: _current!,
                  width: cardWidth,
                  height: cardHeight,
                  drag: _drag,
                  exit: _exit,
                  exitTarget: _exitTarget,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Header — back + skip
// ─────────────────────────────────────────────────────────────────────────

class _OrganizerHeader extends StatelessWidget {
  const _OrganizerHeader({required this.onBack, required this.onSkip});

  final VoidCallback onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.close_rounded),
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
                Text(
                  'Priorizar',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                const Text(
                  '¿Qué importa más?',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onSkip == null ? null : () => onSkip!.call(),
            icon: const Icon(Icons.skip_next_rounded, size: 18),
            label: const Text(
              'Saltar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// PriorityProgressBar — barra animada de progreso
// ─────────────────────────────────────────────────────────────────────────

class PriorityProgressBar extends StatelessWidget {
  const PriorityProgressBar({
    required this.done,
    required this.total,
    super.key,
  });

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 1.0 : (done / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$done de $total organizadas',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              '${(progress * 100).round()}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Stack(
              children: [
                Container(
                  height: 6,
                  color: AppColors.surfaceContainer,
                ),
                FractionallySizedBox(
                  widthFactor: value,
                  child: Container(
                    height: 6,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.indigo],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _ActiveCard — tarjeta superior, draggable + animación de salida
// ─────────────────────────────────────────────────────────────────────────

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({
    required this.task,
    required this.width,
    required this.height,
    required this.drag,
    required this.exit,
    required this.exitTarget,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final TaskItem task;
  final double width;
  final double height;
  final ValueNotifier<Offset> drag;
  final AnimationController exit;
  final Offset exitTarget;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([drag, exit]),
      builder: (context, child) {
        final dragOffset = drag.value;
        final t = exit.value;
        final exitOffset = exit.status == AnimationStatus.dismissed
            ? Offset.zero
            : Offset(
                exitTarget.dx * width * 1.2 * t,
                exitTarget.dy * height * 1.1 * t,
              );
        final combined = dragOffset + exitOffset;
        final rotation = (combined.dx / width) * 0.16;
        final hint = _dragHint(dragOffset.dx);
        return Transform.translate(
          offset: combined,
          child: Transform.rotate(
            angle: rotation,
            child: GestureDetector(
              onPanUpdate: onPanUpdate,
              onPanEnd: onPanEnd,
              behavior: HitTestBehavior.opaque,
              child: TaskSwipeCard(
                task: task,
                width: width,
                height: height,
                hintLabel: hint?.label,
                hintStrength: hint?.strength ?? 0,
              ),
            ),
          ),
        );
      },
    );
  }

  _SwipeHint? _dragHint(double dx) {
    if (dx.abs() < 30) return null;
    return _SwipeHint(label: 'Saltar', strength: (dx.abs() / 130).clamp(0, 1));
  }
}

class _PeekCard extends StatelessWidget {
  const _PeekCard({
    required this.task,
    required this.width,
    required this.height,
    required this.exit,
  });

  final TaskItem task;
  final double width;
  final double height;
  final AnimationController exit;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: exit,
      builder: (context, _) {
        final t = exit.value;
        final scale = 0.93 + (0.07 * t);
        final opacity = 0.55 + (0.45 * t);
        return Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: IgnorePointer(
                child: TaskSwipeCard(
                  task: task,
                  width: width,
                  height: height,
                  muted: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// TaskSwipeCard — tarjeta visual reutilizable
// ─────────────────────────────────────────────────────────────────────────

class TaskSwipeCard extends StatelessWidget {
  const TaskSwipeCard({
    required this.task,
    this.width,
    this.height,
    this.muted = false,
    this.hintLabel,
    this.hintStrength = 0,
    super.key,
  });

  final TaskItem task;
  final double? width;
  final double? height;
  final bool muted;
  final String? hintLabel;
  final double hintStrength;

  @override
  Widget build(BuildContext context) {
    final accent = priorityColor(task.prioridad);
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.surfaceLowest,
          borderRadius: BorderRadius.circular(28),
          boxShadow: muted
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 5, color: accent),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _MetaPill(
                        icon: Icons.school_outlined,
                        label: task.materia,
                      ),
                      const Spacer(),
                      PriorityBadge(priority: task.prioridad),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    task.titulo,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaPill(
                        icon: Icons.calendar_today_rounded,
                        label: _humanDate(task),
                      ),
                      if (task.hora != 'Sin hora')
                        _MetaPill(
                          icon: Icons.access_time,
                          label: task.hora,
                        ),
                      _MetaPill(
                        icon: Icons.label_outline,
                        label: task.tipo,
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (task.notas.trim().isNotEmpty)
                    Text(
                      task.notas,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    )
                  else
                    Text(
                      'Desliza horizontal para saltar · toca una prioridad abajo',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        ),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            if (hintLabel != null && hintStrength > 0)
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Opacity(
                    opacity: hintStrength.clamp(0.0, 1.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.onSurface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        hintLabel!.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _humanDate(TaskItem task) {
    if (task.fecha == 'Sin fecha') return 'Sin fecha';
    final date = _taskDate(task);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = date.difference(today).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Mañana';
    if (diff == -1) return 'Ayer';
    if (diff > 1 && diff < 7) return 'En $diff días';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _SwipeHint {
  const _SwipeHint({required this.label, required this.strength});
  final String label;
  final double strength;
}

// ─────────────────────────────────────────────────────────────────────────
// Acciones de prioridad — 4 botones inferior
// ─────────────────────────────────────────────────────────────────────────

class _PriorityActionRow extends StatelessWidget {
  const _PriorityActionRow({required this.levels, required this.onTap});

  final List<String> levels;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < levels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _PriorityActionButton(
              priority: levels[i],
              onTap: onTap == null ? null : () => onTap!(levels[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _PriorityActionButton extends StatelessWidget {
  const _PriorityActionButton({required this.priority, required this.onTap});

  final String priority;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(priority);
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: disabled
                ? AppColors.surfaceContainer
                : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: disabled
                  ? Colors.transparent
                  : color.withValues(alpha: 0.45),
              width: 1.4,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: disabled ? AppColors.surfaceHigh : color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                priorityLabel(priority),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: disabled ? AppColors.onSurfaceVariant : color,
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
// Estado vacío — celebración al terminar
// ─────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onBack, required this.organized});

  final VoidCallback onBack;
  final int organized;

  @override
  Widget build(BuildContext context) {
    final allDone = organized > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.indigo],
              ),
              boxShadow: _activeShadow,
            ),
            child: Icon(
              allDone ? Icons.celebration_rounded : Icons.task_alt_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            allDone ? '¡Todo organizado!' : 'Nada que priorizar',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            allDone
                ? 'Asignaste prioridad a $organized tarea${organized == 1 ? '' : 's'}.'
                : 'No tienes tareas pendientes por organizar ahora.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Volver',
              icon: Icons.arrow_back_rounded,
              onTap: onBack,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Pildora de metadata reutilizada en TaskSwipeCard
// ─────────────────────────────────────────────────────────────────────────

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
