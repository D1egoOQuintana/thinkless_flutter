part of '../../../main.dart';

/// Modos de captura disponibles en el QuickCaptureSheet.
enum CaptureMode { texto, voz, scan }

enum _DatePreset { hoy, manana, semana, custom, sin }

enum _TimePreset { sin, t9, t14, t18, custom }

/// Sheet modal para captura ultra-rápida de tareas.
///
/// Diseño inspirado en Linear/Vercel: tabs limpias, jerarquía clara,
/// smart chips para fecha y prioridad, transiciones suaves entre modos.
class QuickCaptureSheet extends StatefulWidget {
  const QuickCaptureSheet({
    required this.onAddTask,
    required this.onOpenVoice,
    required this.onOpenScanner,
    super.key,
  });

  final ValueChanged<TaskItem> onAddTask;
  final VoidCallback onOpenVoice;
  final VoidCallback onOpenScanner;

  @override
  State<QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends State<QuickCaptureSheet> {
  final _titleController = TextEditingController();
  final _materiaController = TextEditingController();
  final _titleFocus = FocusNode();

  CaptureMode _mode = CaptureMode.texto;
  _DatePreset _datePreset = _DatePreset.hoy;
  DateTime? _customDate;
  _TimePreset _timePreset = _TimePreset.sin;
  TimeOfDay? _customTime;
  String _prioridad = 'media';

  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _mode == CaptureMode.texto) _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _materiaController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  void _setMode(CaptureMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    if (mode == CaptureMode.texto) {
      Future.delayed(const Duration(milliseconds: 220), () {
        if (mounted) _titleFocus.requestFocus();
      });
    } else {
      _titleFocus.unfocus();
    }
  }

  DateTime? _resolvedDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_datePreset) {
      _DatePreset.hoy => today,
      _DatePreset.manana => today.add(const Duration(days: 1)),
      _DatePreset.semana => today.add(const Duration(days: 7)),
      _DatePreset.custom => _customDate,
      _DatePreset.sin => null,
    };
  }

  TimeOfDay? _resolvedTime() {
    return switch (_timePreset) {
      _TimePreset.sin => null,
      _TimePreset.t9 => const TimeOfDay(hour: 9, minute: 0),
      _TimePreset.t14 => const TimeOfDay(hour: 14, minute: 0),
      _TimePreset.t18 => const TimeOfDay(hour: 18, minute: 0),
      _TimePreset.custom => _customTime,
    };
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _two(int v) => v.toString().padLeft(2, '0');

  String _formatDateChipLabel(DateTime d) => '${d.day} ${_meses[d.month - 1]}';

  String _formatTimeChipLabel(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _customDate ?? _resolvedDate() ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, now.month, now.day),
      helpText: 'Elegir fecha',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
    );
    if (picked != null && mounted) {
      setState(() {
        _customDate = DateTime(picked.year, picked.month, picked.day);
        _datePreset = _DatePreset.custom;
      });
    }
  }

  Future<void> _pickTime() async {
    final initial = _customTime ?? _resolvedTime() ?? const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Elegir hora',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
    );
    if (picked != null && mounted) {
      setState(() {
        _customTime = picked;
        _timePreset = _TimePreset.custom;
      });
    }
  }

  void _submit() {
    final titulo = _titleController.text.trim();
    if (titulo.isEmpty) {
      _titleFocus.requestFocus();
      return;
    }
    final materia = _materiaController.text.trim();
    final date = _resolvedDate();
    final time = _resolvedTime();
    final task = TaskItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      titulo: titulo,
      materia: materia.isEmpty ? 'General' : materia,
      fecha: date == null ? 'Sin fecha' : _isoDate(date),
      hora: time == null ? 'Sin hora' : '${_two(time.hour)}:${_two(time.minute)}',
      prioridad: _prioridad,
      tipo: 'tarea',
      completada: false,
      fechaCreacion: DateTime.now(),
      notas: '',
    );
    widget.onAddTask(task);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
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
                _buildHeader(context),
                const SizedBox(height: 16),
                CaptureModeTabs(active: _mode, onChange: _setMode),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_mode),
                    child: _buildBody(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nueva tarea',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Captura rápida — elige cómo quieres registrarla.',
          style: TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 13,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    return switch (_mode) {
      CaptureMode.texto => _buildTextoMode(context),
      CaptureMode.voz => _ModeRedirectCard(
        icon: Icons.mic,
        title: 'Captura por voz',
        body:
            'Habla naturalmente y ThinkLess extraerá título, materia, fecha y prioridad con IA.',
        cta: 'Abrir captura de voz',
        onTap: widget.onOpenVoice,
      ),
      CaptureMode.scan => _ModeRedirectCard(
        icon: Icons.document_scanner,
        title: 'Escanear apuntes',
        body:
            'Toma una foto de tus apuntes o pizarra y la IA detectará todas las tareas accionables.',
        cta: 'Abrir escáner',
        onTap: widget.onOpenScanner,
      ),
    };
  }

  Widget _buildTextoMode(BuildContext context) {
    final dateOptions = const [
      'hoy',
      'manana',
      'semana',
      'custom',
      'sin',
    ];
    final timeOptions = const [
      'sin',
      't9',
      't14',
      't18',
      'custom',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CaptureInputField(
          controller: _titleController,
          focusNode: _titleFocus,
          hint: 'Ej: Entregar reporte de cálculo',
          icon: Icons.edit_note,
          autofocus: true,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 10),
        _CaptureInputField(
          controller: _materiaController,
          hint: 'Materia (opcional)',
          icon: Icons.school_outlined,
          compact: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 20),
        const _ChipsSectionLabel(label: 'Cuándo'),
        const SizedBox(height: 8),
        SmartChipRow(
          options: dateOptions,
          selected: _datePreset.name,
          labels: _dateLabels(),
          onChanged: _onDateChipTap,
          iconBuilder: _dateIcon,
        ),
        const SizedBox(height: 18),
        const _ChipsSectionLabel(label: 'Hora'),
        const SizedBox(height: 8),
        SmartChipRow(
          options: timeOptions,
          selected: _timePreset.name,
          labels: _timeLabels(),
          onChanged: _onTimeChipTap,
          iconBuilder: _timeIcon,
          accentBuilder: (_) => AppColors.blue,
        ),
        const SizedBox(height: 18),
        const _ChipsSectionLabel(label: 'Prioridad'),
        const SizedBox(height: 8),
        SmartChipRow(
          options: const ['alta', 'media', 'baja'],
          labels: const {'alta': 'Alta', 'media': 'Media', 'baja': 'Baja'},
          selected: _prioridad,
          onChanged: (value) => setState(() => _prioridad = value),
          accentBuilder: _prioridadAccent,
          iconBuilder: (_) => Icons.flag_outlined,
        ),
        const SizedBox(height: 24),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _titleController,
          builder: (context, value, _) => _AddButton(
            enabled: value.text.trim().isNotEmpty,
            onTap: _submit,
          ),
        ),
      ],
    );
  }

  Map<String, String> _dateLabels() {
    final customLabel = _customDate != null
        ? _formatDateChipLabel(_customDate!)
        : 'Personalizar';
    return {
      'hoy': 'Hoy',
      'manana': 'Mañana',
      'semana': '+7 días',
      'custom': customLabel,
      'sin': 'Sin fecha',
    };
  }

  Map<String, String> _timeLabels() {
    final customLabel = _customTime != null
        ? _formatTimeChipLabel(_customTime!)
        : 'Personalizar';
    return {
      'sin': 'Sin hora',
      't9': '09:00',
      't14': '14:00',
      't18': '18:00',
      'custom': customLabel,
    };
  }

  void _onDateChipTap(String value) {
    if (value == 'custom') {
      _pickDate();
      return;
    }
    setState(() {
      _datePreset = _DatePreset.values.byName(value);
    });
  }

  void _onTimeChipTap(String value) {
    if (value == 'custom') {
      _pickTime();
      return;
    }
    setState(() {
      _timePreset = _TimePreset.values.byName(value);
    });
  }

  IconData _dateIcon(String v) => switch (v) {
    'hoy' => Icons.today,
    'manana' => Icons.wb_sunny_outlined,
    'semana' => Icons.date_range,
    'custom' => Icons.event,
    _ => Icons.event_busy_outlined,
  };

  IconData _timeIcon(String v) => switch (v) {
    'sin' => Icons.schedule_outlined,
    'custom' => Icons.more_time,
    _ => Icons.access_time,
  };

  Color _prioridadAccent(String v) => switch (v) {
    'alta' => AppColors.pink,
    'media' => AppColors.yellow,
    _ => AppColors.mint,
  };
}

// ─────────────────────────────────────────────────────────────────────────
// CaptureModeTabs — selector segmentado de 3 modos
// ─────────────────────────────────────────────────────────────────────────

class CaptureModeTabs extends StatelessWidget {
  const CaptureModeTabs({
    required this.active,
    required this.onChange,
    super.key,
  });

  final CaptureMode active;
  final ValueChanged<CaptureMode> onChange;

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
          _tab(CaptureMode.texto, Icons.keyboard_alt_outlined, 'Texto'),
          _tab(CaptureMode.voz, Icons.mic_none, 'Voz'),
          _tab(CaptureMode.scan, Icons.document_scanner_outlined, 'Scan'),
        ],
      ),
    );
  }

  Expanded _tab(CaptureMode mode, IconData icon, String label) {
    final isActive = mode == active;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChange(mode),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 42,
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isActive
                      ? AppColors.onSurface
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

// ─────────────────────────────────────────────────────────────────────────
// SmartChipRow — fila de chips seleccionables con scroll horizontal
// ─────────────────────────────────────────────────────────────────────────

class SmartChipRow extends StatelessWidget {
  const SmartChipRow({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.labels,
    this.iconBuilder,
    this.accentBuilder,
    super.key,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  final Map<String, String>? labels;
  final IconData Function(String)? iconBuilder;
  final Color Function(String)? accentBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = options[index];
          final isActive = value == selected;
          final accent = accentBuilder?.call(value) ?? AppColors.primary;
          final label = labels?[value] ?? value;
          final icon = iconBuilder?.call(value);

          return GestureDetector(
            onTap: () => onChanged(value),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: icon == null ? 16 : 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? accent.withValues(alpha: 0.12)
                    : AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  width: 1.4,
                  color: isActive
                      ? accent.withValues(alpha: 0.55)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 15,
                      color: isActive ? accent : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isActive ? accent : AppColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Privados de presentación
// ─────────────────────────────────────────────────────────────────────────

class _CaptureInputField extends StatelessWidget {
  const _CaptureInputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.focusNode,
    this.compact = false,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final IconData icon;
  final bool compact;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant, width: 0.6),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: compact ? 2 : 6,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.violetLight),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              style: TextStyle(
                fontSize: compact ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  fontSize: compact ? 14 : 16,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: compact ? 12 : 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipsSectionLabel extends StatelessWidget {
  const _ChipsSectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: AppColors.onSurfaceVariant,
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.base,
      curve: AppMotion.standard,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        gradient: enabled
            ? const LinearGradient(
                colors: [AppColors.primary, AppColors.indigo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: enabled ? null : AppColors.surfaceHigh,
        border: Border.all(
          color: enabled
              ? Colors.white.withValues(alpha: 0.10)
              : AppColors.outlineVariant,
          width: 0.6,
        ),
        boxShadow: enabled ? AppShadow.brand(opacity: 0.30) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: enabled ? onTap : null,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: 19,
                  color: enabled ? Colors.white : AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm + 2),
                Text(
                  'Agregar tarea',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    letterSpacing: -0.15,
                    color: enabled ? Colors.white : AppColors.onSurfaceVariant,
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

class _ModeRedirectCard extends StatelessWidget {
  const _ModeRedirectCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.cta,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final String cta;
  final VoidCallback onTap;

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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          _LabeledPrimaryButton(label: cta, onTap: onTap),
        ],
      ),
    );
  }
}

class _LabeledPrimaryButton extends StatelessWidget {
  const _LabeledPrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.indigo],
        ),
        boxShadow: _activeShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: onTap,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
