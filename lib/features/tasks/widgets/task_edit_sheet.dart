part of '../../../main.dart';

/// Bottom sheet full-screen para editar una tarea existente.
///
/// Diseño premium: secciones claras, jerarquía limpia, validación suave.
/// Mantiene rendimiento con state local + un único save al final.
class TaskEditSheet extends StatefulWidget {
  const TaskEditSheet({
    required this.task,
    required this.onSave,
    this.onDelete,
    this.suggestedMaterias = const [],
    this.suggestedEtiquetas = const [],
    super.key,
  });

  final TaskItem task;
  final ValueChanged<TaskItem> onSave;
  final VoidCallback? onDelete;
  final List<String> suggestedMaterias;
  final List<String> suggestedEtiquetas;

  @override
  State<TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends State<TaskEditSheet> {
  static const _priorities = ['urgente', 'alta', 'media', 'baja'];
  static const _tipos = [
    'examen',
    'tarea',
    'laboratorio',
    'proyecto',
    'lectura',
    'otro',
  ];
  static const _duracionPresets = [15, 30, 45, 60, 90, 120];

  late final TextEditingController _tituloCtrl;
  late final TextEditingController _notasCtrl;
  late final TextEditingController _materiaCtrl;
  late final TextEditingController _etiquetaCtrl;
  late final FocusNode _etiquetaFocus;

  late String _prioridad;
  late String _tipo;
  late bool _completada;
  late int? _duracionMin;
  late List<String> _etiquetas;

  DateTime? _fechaDate; // null = sin fecha
  TimeOfDay? _horaTime; // null = sin hora

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _tituloCtrl = TextEditingController(text: t.titulo);
    _notasCtrl = TextEditingController(text: t.notas);
    _materiaCtrl = TextEditingController(text: t.materia);
    _etiquetaCtrl = TextEditingController();
    _etiquetaFocus = FocusNode();
    _prioridad = t.prioridad;
    _tipo = _tipos.contains(t.tipo) ? t.tipo : 'otro';
    _completada = t.completada;
    _duracionMin = t.duracionMin;
    _etiquetas = [...t.etiquetas];

    final parsed = DateTime.tryParse(t.fecha);
    if (parsed != null) {
      _fechaDate = DateTime(parsed.year, parsed.month, parsed.day);
    }
    if (t.hora != 'Sin hora') {
      final parts = t.hora.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) {
          _horaTime = TimeOfDay(hour: h, minute: m);
        }
      }
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _notasCtrl.dispose();
    _materiaCtrl.dispose();
    _etiquetaCtrl.dispose();
    _etiquetaFocus.dispose();
    super.dispose();
  }

  bool get _isValid => _tituloCtrl.text.trim().isNotEmpty;

  Future<void> _pickDate() async {
    final initial = _fechaDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surfaceContainer,
            onSurface: AppColors.onSurface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _fechaDate = picked);
  }

  Future<void> _pickTime() async {
    final initial = _horaTime ?? const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surfaceContainer,
            onSurface: AppColors.onSurface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _horaTime = picked);
  }

  void _addEtiqueta(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty) return;
    if (_etiquetas.any((e) => e.toLowerCase() == tag.toLowerCase())) {
      _etiquetaCtrl.clear();
      return;
    }
    setState(() {
      _etiquetas = [..._etiquetas, tag];
      _etiquetaCtrl.clear();
    });
  }

  void _removeEtiqueta(String tag) {
    setState(() {
      _etiquetas = _etiquetas.where((e) => e != tag).toList();
    });
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    if (!_isValid || _saving) return;
    setState(() => _saving = true);
    final updated = widget.task.copyWith(
      titulo: _tituloCtrl.text.trim(),
      notas: _notasCtrl.text.trim(),
      materia: _materiaCtrl.text.trim().isEmpty
          ? 'General'
          : _materiaCtrl.text.trim(),
      prioridad: _prioridad,
      tipo: _tipo,
      completada: _completada,
      fecha: _fechaDate == null ? 'Sin fecha' : _formatDate(_fechaDate!),
      hora: _horaTime == null ? 'Sin hora' : _formatTime(_horaTime!),
      duracionMin: _duracionMin,
      clearDuracion: _duracionMin == null,
      etiquetas: _etiquetas,
    );
    widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxHeight = mq.size.height * 0.92;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                children: [
                  _buildTitulo(),
                  const SizedBox(height: AppSpacing.xl),
                  _SectionHeader(label: 'Descripción'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildNotas(),
                  const SizedBox(height: AppSpacing.xl),
                  _SectionHeader(label: 'Prioridad'),
                  const SizedBox(height: AppSpacing.sm + 2),
                  _buildPrioridad(),
                  const SizedBox(height: AppSpacing.xl),
                  _SectionHeader(label: 'Categoría'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildMateria(),
                  const SizedBox(height: AppSpacing.xl),
                  _SectionHeader(label: 'Tipo'),
                  const SizedBox(height: AppSpacing.sm + 2),
                  _buildTipo(),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionHeader(label: 'Fecha'),
                            const SizedBox(height: AppSpacing.sm),
                            _buildFecha(),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionHeader(label: 'Hora'),
                            const SizedBox(height: AppSpacing.sm),
                            _buildHora(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _SectionHeader(label: 'Duración estimada'),
                  const SizedBox(height: AppSpacing.sm + 2),
                  _buildDuracion(),
                  const SizedBox(height: AppSpacing.xl),
                  _SectionHeader(label: 'Etiquetas'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildEtiquetas(),
                  const SizedBox(height: AppSpacing.xl),
                  _SectionHeader(label: 'Estado'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildEstado(),
                ],
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm + 4,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          Expanded(
            child: Text(
              'Editar tarea',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
                letterSpacing: -0.2,
              ),
            ),
          ),
          AnimatedOpacity(
            duration: AppMotion.fast,
            opacity: _isValid && !_saving ? 1 : 0.45,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isValid && !_saving ? _save : null,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.indigo],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    boxShadow: _isValid && !_saving
                        ? AppShadow.brand(opacity: 0.25)
                        : null,
                  ),
                  child: Text(
                    'Guardar',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Título ────────────────────────────────────────────────────────────

  Widget _buildTitulo() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant, width: 0.6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
      child: TextField(
        controller: _tituloCtrl,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
          letterSpacing: -0.3,
        ),
        decoration: InputDecoration(
          hintText: '¿Qué tienes que hacer?',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.secondary,
            letterSpacing: -0.3,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ─── Notas ─────────────────────────────────────────────────────────────

  Widget _buildNotas() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant, width: 0.6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 2),
      child: TextField(
        controller: _notasCtrl,
        maxLines: 4,
        minLines: 2,
        textCapitalization: TextCapitalization.sentences,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.onSurface,
          height: 1.5,
        ),
        decoration: InputDecoration(
          hintText: 'Agrega notas, contexto o pasos…',
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.secondary,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  // ─── Prioridad ─────────────────────────────────────────────────────────

  Widget _buildPrioridad() {
    return Row(
      children: [
        for (var i = 0; i < _priorities.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _PriorityPill(
              priority: _priorities[i],
              selected: _prioridad == _priorities[i],
              onTap: () => setState(() => _prioridad = _priorities[i]),
            ),
          ),
        ],
      ],
    );
  }

  // ─── Materia ───────────────────────────────────────────────────────────

  Widget _buildMateria() {
    final suggestions = widget.suggestedMaterias
        .where((m) =>
            m.isNotEmpty &&
            m.toLowerCase() != _materiaCtrl.text.trim().toLowerCase())
        .take(5)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.outlineVariant, width: 0.6),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 2,
          ),
          child: Row(
            children: [
              const Icon(Icons.school_rounded, size: 17, color: AppColors.violetLight),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _materiaCtrl,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ej: Matemáticas, Trabajo, Personal…',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.secondary,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: suggestions
                .map(
                  (m) => _SuggestionChip(
                    label: m,
                    onTap: () => setState(() => _materiaCtrl.text = m),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  // ─── Tipo ──────────────────────────────────────────────────────────────

  Widget _buildTipo() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: _tipos
          .map(
            (t) => _ChoicePill(
              label: _tipoLabel(t),
              selected: _tipo == t,
              icon: _tipoIcon(t),
              onTap: () => setState(() => _tipo = t),
            ),
          )
          .toList(),
    );
  }

  // ─── Fecha / Hora ──────────────────────────────────────────────────────

  Widget _buildFecha() {
    return _FieldTile(
      icon: Icons.calendar_today_rounded,
      value: _fechaDate == null ? 'Sin fecha' : _formatDate(_fechaDate!),
      muted: _fechaDate == null,
      onTap: _pickDate,
      onClear: _fechaDate == null
          ? null
          : () => setState(() => _fechaDate = null),
    );
  }

  Widget _buildHora() {
    return _FieldTile(
      icon: Icons.schedule_rounded,
      value: _horaTime == null ? 'Sin hora' : _formatTime(_horaTime!),
      muted: _horaTime == null,
      onTap: _pickTime,
      onClear: _horaTime == null
          ? null
          : () => setState(() => _horaTime = null),
    );
  }

  // ─── Duración ──────────────────────────────────────────────────────────

  Widget _buildDuracion() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _ChoicePill(
          label: 'Ninguna',
          selected: _duracionMin == null,
          onTap: () => setState(() => _duracionMin = null),
        ),
        ..._duracionPresets.map(
          (m) => _ChoicePill(
            label: m >= 60
                ? (m % 60 == 0 ? '${m ~/ 60} h' : '${m ~/ 60}h ${m % 60}m')
                : '$m min',
            selected: _duracionMin == m,
            onTap: () => setState(() => _duracionMin = m),
          ),
        ),
      ],
    );
  }

  // ─── Etiquetas ─────────────────────────────────────────────────────────

  Widget _buildEtiquetas() {
    final suggestionsToShow = widget.suggestedEtiquetas
        .where((e) =>
            !_etiquetas.any((t) => t.toLowerCase() == e.toLowerCase()))
        .take(6)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.outlineVariant, width: 0.6),
          ),
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm + 2, 6, AppSpacing.sm + 2),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ..._etiquetas.map(
                (tag) => _TagChip(label: tag, onRemove: () => _removeEtiqueta(tag)),
              ),
              IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 100, maxWidth: 220),
                  child: TextField(
                    controller: _etiquetaCtrl,
                    focusNode: _etiquetaFocus,
                    onSubmitted: _addEtiqueta,
                    textInputAction: TextInputAction.done,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: _etiquetas.isEmpty ? 'Añade una etiqueta…' : '+ etiqueta',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.secondary,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (suggestionsToShow.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: suggestionsToShow
                .map(
                  (e) => _SuggestionChip(
                    label: '+ $e',
                    onTap: () => _addEtiqueta(e),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  // ─── Estado ────────────────────────────────────────────────────────────

  Widget _buildEstado() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant, width: 0.6),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _completada
                  ? AppColors.mint.withValues(alpha: 0.14)
                  : AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              _completada
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: _completada ? AppColors.mint : AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _completada ? 'Completada' : 'Pendiente',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  _completada
                      ? 'La tarea se marcará como hecha'
                      : 'Sigue activa en tu lista',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _completada,
            onChanged: (v) => setState(() => _completada = v),
          ),
        ],
      ),
    );
  }

  // ─── Footer (delete) ───────────────────────────────────────────────────

  Widget _buildFooter(BuildContext context) {
    if (widget.onDelete == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm + 2,
          AppSpacing.xl,
          AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.outlineVariant, width: 0.5),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Eliminar tarea'),
                  content: Text(
                    '¿Seguro que quieres eliminar "${widget.task.titulo}"? Esta acción no se puede deshacer.',
                    style: GoogleFonts.inter(fontSize: 13.5, height: 1.4),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                widget.onDelete!();
              }
            },
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.30),
                  width: 0.6,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.delete_outline_rounded, size: 17, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text(
                    'Eliminar tarea',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────

  String _tipoLabel(String t) => switch (t) {
        'examen' => 'Examen',
        'tarea' => 'Tarea',
        'laboratorio' => 'Laboratorio',
        'proyecto' => 'Proyecto',
        'lectura' => 'Lectura',
        _ => 'Otro',
      };

  IconData _tipoIcon(String t) => switch (t) {
        'examen' => Icons.fact_check_rounded,
        'tarea' => Icons.assignment_rounded,
        'laboratorio' => Icons.science_rounded,
        'proyecto' => Icons.workspaces_rounded,
        'lectura' => Icons.menu_book_rounded,
        _ => Icons.label_rounded,
      };
}

// ─── Subcomponentes locales ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.secondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _PriorityPill extends StatelessWidget {
  const _PriorityPill({
    required this.priority,
    required this.selected,
    required this.onTap,
  });

  final String priority;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(priority);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.16)
                : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.55)
                  : AppColors.outlineVariant,
              width: selected ? 1 : 0.6,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: selected
                      ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)]
                      : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                priorityLabel(priority),
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : AppColors.onSurface,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          padding: EdgeInsets.symmetric(
            horizontal: icon == null ? 14 : 11,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.14)
                : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : AppColors.outlineVariant,
              width: selected ? 1 : 0.6,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: selected ? AppColors.violetLight : AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.violetLight : AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.icon,
    required this.value,
    required this.onTap,
    this.onClear,
    this.muted = false,
  });

  final IconData icon;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.outlineVariant, width: 0.6),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: AppColors.violetLight),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: muted ? AppColors.secondary : AppColors.onSurface,
                  ),
                ),
              ),
              if (onClear != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClear,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.secondary,
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

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.outlineVariant, width: 0.6),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 5, 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.violetLight,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              child: const Icon(
                Icons.close_rounded,
                size: 12,
                color: AppColors.violetLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
