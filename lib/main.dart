import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

part 'app/theme/app_colors.dart';
part 'app/navigation/app_view.dart';
part 'features/tasks/domain/task_item.dart';
part 'features/tasks/data/task_store.dart';
part 'features/settings/domain/no_molestar_config.dart';
part 'features/focus/domain/focus_total_config.dart';
part 'features/assistant/data/groq_service.dart';
part 'features/tasks/widgets/quick_capture_sheet.dart';
part 'features/tasks/widgets/task_edit_sheet.dart';
part 'features/tasks/widgets/priority_organizer_screen.dart';
part 'features/tasks/widgets/free_time_sheet.dart';
part 'features/focus/widgets/focus_screen.dart';
part 'features/tasks/widgets/day_review_screen.dart';
part 'features/calendar/widgets/calendar_screen.dart';
part 'features/home/widgets/home_screen.dart';

void main() {
  runApp(const ThinkLessApp());
}

class ThinkLessApp extends StatefulWidget {
  const ThinkLessApp({super.key});

  @override
  State<ThinkLessApp> createState() => _ThinkLessAppState();
}

class _ThinkLessAppState extends State<ThinkLessApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  AppView _view = AppView.onboarding;
  AppView _previousView = AppView.home;
  List<TaskItem> _tasks = [];
  TaskItem? _selectedTask;
  bool _loading = true;
  Map<String, dynamic> _alerts = {};
  NoMolestarConfig _noMolestar = NoMolestarConfig.defaults();
  FocusTotalConfig _focusTotal = FocusTotalConfig.idle();
  Timer? _focusTotalTicker;
  final ValueNotifier<DateTime> _focusTotalClock = ValueNotifier<DateTime>(
    DateTime.now(),
  );
  int _focusMinutes = 25;
  String? _focusTaskTitle;
  String? _focusTaskId;
  int _focusSessionToken = 0;
  int _focusSessionsToday = 0;
  int _focusMinutesToday = 0;
  String _focusStatsDate = _todayKey();

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  void _ensureFreshFocusStats() {
    final today = _todayKey();
    if (today != _focusStatsDate) {
      _focusStatsDate = today;
      _focusSessionsToday = 0;
      _focusMinutesToday = 0;
    }
  }

  void _onFocusSessionCompleted(int minutes) {
    _ensureFreshFocusStats();
    setState(() {
      _focusSessionsToday++;
      _focusMinutesToday += minutes;
    });
  }

  late final ThemeData _appTheme = _buildAppTheme();

  ThemeData _buildAppTheme() {
    const cs = ColorScheme.light(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.primary,
      secondary: AppColors.accent,
      onSecondary: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      surfaceContainerLowest: AppColors.surfaceLowest,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceHigh,
      surfaceContainerHighest: AppColors.surfaceHighest,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      error: AppColors.error,
      onError: AppColors.onPrimary,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      secondaryContainer: AppColors.surfaceVariant,
    );

    final tt = TextTheme(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 40, fontWeight: FontWeight.w800, color: AppColors.onSurface, letterSpacing: -1.4, height: 1.05,
      ),
      displayMedium: GoogleFonts.plusJakartaSans(
        fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.onSurface, letterSpacing: -1.0, height: 1.08,
      ),
      displaySmall: GoogleFonts.plusJakartaSans(
        fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.onSurface, letterSpacing: -0.7, height: 1.1,
      ),
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.onSurface, letterSpacing: -0.5, height: 1.15,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.onSurface, letterSpacing: -0.35, height: 1.2,
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface, letterSpacing: -0.2, height: 1.25,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface, letterSpacing: -0.15, height: 1.3,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface, letterSpacing: -0.1, height: 1.35,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant, letterSpacing: 0.1, height: 1.35,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.onSurface, height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.onSurface, height: 1.5,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12.5, fontWeight: FontWeight.w400, color: AppColors.onSurfaceVariant, height: 1.5,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface, letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant, letterSpacing: 0.2,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondary, letterSpacing: 0.4,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      textTheme: tt,
      primaryTextTheme: tt,
      splashFactory: InkSparkle.splashFactory,
      hoverColor: AppColors.surfaceHigh.withValues(alpha: 0.6),
      highlightColor: AppColors.primary.withValues(alpha: 0.06),
      splashColor: AppColors.primary.withValues(alpha: 0.08),
      dividerTheme: const DividerThemeData(
        color: AppColors.outlineSubtle,
        thickness: 0.5,
        space: 0.5,
      ),
      cardColor: AppColors.surfaceLowest,
      iconTheme: const IconThemeData(color: AppColors.onSurfaceVariant, size: 20),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceWarm,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primary.withValues(alpha: 0.14),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 22);
          }
          return const IconThemeData(color: AppColors.secondary, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.1,
            );
          }
          return GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.secondary, letterSpacing: 0.1,
          );
        }),
        height: 70,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLowest,
        modalBackgroundColor: AppColors.surfaceLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        elevation: 0,
        dragHandleColor: AppColors.outlineVariant,
        dragHandleSize: Size(36, 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceWarm,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        hintStyle: GoogleFonts.inter(color: AppColors.secondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: AppColors.outline, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceContainer,
        selectedColor: AppColors.primary.withValues(alpha: 0.14),
        disabledColor: AppColors.surfaceContainer,
        labelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.onSurface),
        secondaryLabelStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary),
        side: const BorderSide(color: AppColors.outlineSubtle),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        showCheckmark: false,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.surfaceHigh;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.1),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          side: const BorderSide(color: AppColors.outlineVariant),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColors.surfaceContainer,
          selectedBackgroundColor: AppColors.primary.withValues(alpha: 0.14),
          selectedForegroundColor: AppColors.primary,
          foregroundColor: AppColors.onSurfaceVariant,
          side: const BorderSide(color: AppColors.outlineVariant),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.onSurface,
        contentTextStyle: GoogleFonts.inter(color: AppColors.surfaceLowest, fontWeight: FontWeight.w500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        elevation: 0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceHigh,
        circularTrackColor: AppColors.surfaceHigh,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.onSurface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: GoogleFonts.inter(color: AppColors.surfaceLowest, fontSize: 12),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tasks = await TaskStore.loadTasks();
    final seen = await TaskStore.hasSeenOnboarding();
    final alerts = await TaskStore.loadAlerts();
    final noMolestar = await TaskStore.loadNoMolestar();
    final focusTotal = await TaskStore.loadFocusTotal();
    final restoredFocusTotal = focusTotal.expired
        ? focusTotal.copyWith(active: false, clearStartedAt: true)
        : focusTotal;
    if (focusTotal.expired) {
      await TaskStore.saveFocusTotal(restoredFocusTotal);
    }
    setState(() {
      _tasks = _sortTasks(tasks);
      _alerts = alerts;
      _noMolestar = noMolestar;
      _focusTotal = restoredFocusTotal;
      _view = seen ? AppView.home : AppView.onboarding;
      _loading = false;
    });
    if (restoredFocusTotal.active) _startFocusTotalTicker();
    if (seen && isNoMolestarActivo(noMolestar)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showFocusModal());
    }
  }

  @override
  void dispose() {
    _focusTotalTicker?.cancel();
    _focusTotalClock.dispose();
    super.dispose();
  }

  void _startFocusTotalTicker() {
    _focusTotalTicker?.cancel();
    if (_focusTotal.unlimited) return; // sin countdown, no necesita tick
    _focusTotalTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      if (_focusTotal.expiredAt(now)) {
        _focusTotalTicker?.cancel();
        _setFocusTotal(
          _focusTotal.copyWith(active: false, clearStartedAt: true),
          notify: true,
        );
      } else {
        _focusTotalClock.value = now;
      }
    });
  }

  Future<void> _setFocusTotal(FocusTotalConfig config, {bool notify = false}) async {
    _focusTotalClock.value = DateTime.now();
    setState(() => _focusTotal = config);
    await TaskStore.saveFocusTotal(config);
    if (!config.active) {
      _focusTotalTicker?.cancel();
      _focusTotalTicker = null;
      if (notify) {
        final ctx = _navigatorKey.currentContext;
        if (ctx != null && mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text('Sesión de Concentración Total finalizada'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      _startFocusTotalTicker();
    }
  }

  Future<void> _activateFocusTotal(int minutes) async {
    final config = FocusTotalConfig(
      active: true,
      durationMinutes: minutes,
      startedAt: DateTime.now(),
    );
    await _setFocusTotal(config);
    // Activa silencio en NoMolestar de forma forzada visualmente
    if (!_noMolestar.activo) {
      await _saveNoMolestar(_noMolestar.copyWith(activo: true));
    }
  }

  Future<void> _deactivateFocusTotal() async {
    await _setFocusTotal(
      _focusTotal.copyWith(active: false, clearStartedAt: true),
    );
  }

  Future<void> _startApp() async {
    await TaskStore.setSeenOnboarding();
    setState(() => _view = AppView.home);
  }

  Future<void> _addTask(TaskItem task) async {
    final next = _sortTasks([..._tasks, task]);
    setState(() {
      _tasks = next;
      _view = AppView.home;
    });
    await TaskStore.saveTasks(next);
  }

  Future<void> _addTasks(List<TaskItem> tasks) async {
    final next = _sortTasks([..._tasks, ...tasks]);
    setState(() {
      _tasks = next;
      _view = AppView.home;
    });
    await TaskStore.saveTasks(next);
  }

  void _startFocus({required int minutes, String? title, String? taskId}) {
    setState(() {
      _focusMinutes = minutes;
      _focusTaskTitle = title;
      _focusTaskId = taskId;
      _focusSessionToken++;
    });
    _navigate(AppView.focus);
  }

  Future<void> _rescheduleTask(String id, DateTime newDate) async {
    final iso =
        '${newDate.year.toString().padLeft(4, '0')}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}';
    final next = _sortTasks(
      _tasks.map((task) {
        if (task.id != id) return task;
        return task.copyWith(fecha: iso);
      }).toList(),
    );
    setState(() => _tasks = next);
    await TaskStore.saveTasks(next);
  }

  Future<void> _updateTask(TaskItem updated) async {
    final next = _sortTasks(
      _tasks.map((task) => task.id == updated.id ? updated : task).toList(),
    );
    setState(() {
      _tasks = next;
      _selectedTask = next.firstWhere(
        (t) => t.id == updated.id,
        orElse: () => updated,
      );
    });
    await TaskStore.saveTasks(next);
  }

  void _openEditSheet(TaskItem task) {
    final ctx = _navigatorKey.currentContext;
    if (ctx == null) return;
    final materias = _tasks
        .map((t) => t.materia)
        .where((m) => m.isNotEmpty && m != 'General')
        .toSet()
        .toList();
    final etiquetas = _tasks
        .expand((t) => t.etiquetas)
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: AppColors.surfaceLowest,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => TaskEditSheet(
        task: task,
        suggestedMaterias: materias,
        suggestedEtiquetas: etiquetas,
        onSave: (updated) {
          Navigator.pop(sheetCtx);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _updateTask(updated),
          );
        },
        onDelete: () {
          Navigator.pop(sheetCtx);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _deleteTask(task.id),
          );
        },
      ),
    );
  }

  Future<void> _updatePriority(String id, String priority) async {
    final next = _sortTasks(
      _tasks.map((task) {
        if (task.id != id) return task;
        return task.copyWith(prioridad: priority);
      }).toList(),
    );
    setState(() {
      _tasks = next;
      _selectedTask = next.where((task) => task.id == id).firstOrNull;
    });
    await TaskStore.saveTasks(next);
  }

  Future<void> _toggleTask(String id) async {
    final next = _sortTasks(
      _tasks.map((task) {
        if (task.id != id) return task;
        return task.copyWith(completada: !task.completada);
      }).toList(),
    );
    setState(() {
      _tasks = next;
      _selectedTask = next.where((task) => task.id == id).firstOrNull;
    });
    await TaskStore.saveTasks(next);
  }

  Future<void> _deleteTask(String id) async {
    final next = _tasks.where((task) => task.id != id).toList();
    setState(() {
      _tasks = next;
      _selectedTask = null;
      _view = AppView.home;
    });
    await TaskStore.saveTasks(next);
  }

  Future<void> _saveAlerts(Map<String, dynamic> alerts) async {
    setState(() => _alerts = alerts);
    await TaskStore.saveAlerts(alerts);
  }

  Future<void> _saveNoMolestar(NoMolestarConfig config) async {
    setState(() => _noMolestar = config);
    await TaskStore.saveNoMolestar(config);
  }

  Future<void> _showFocusModal() async {
    if (!mounted || !isNoMolestarActivo(_noMolestar)) return;
    final ctx = _navigatorKey.currentContext;
    if (ctx == null) return;
    await showGeneralDialog<void>(
      context: ctx,
      barrierDismissible: false,
      barrierLabel: 'Horario de enfoque',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (dialogContext, anim, _) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: PopScope(
          canPop: false,
          child: Dialog(
            insetPadding: const EdgeInsets.all(AppSpacing.xxl),
            backgroundColor: AppColors.surfaceLowest,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
            elevation: 0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.xxl),
                border: Border.all(color: AppColors.outlineSubtle, width: 1),
                boxShadow: AppShadow.md,
              ),
              padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.30),
                    width: 0.6,
                  ),
                ),
                child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 30),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Horario de enfoque',
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Activamos modo silencioso para evitar distracciones.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Continuar en silencio',
                icon: Icons.notifications_off_rounded,
                onTap: () => Navigator.pop(dialogContext),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _saveNoMolestar(_noMolestar.copyWith(activo: false));
                },
                child: const Text('Desactivar por ahora'),
              ),
            ],
          ),
        ),
      ),
        ),
      ),
    );
  }

  void _navigate(AppView view) {
    setState(() {
      if (_view != AppView.voice &&
          _view != AppView.scanner &&
          _view != AppView.detail) {
        _previousView = _view;
      }
      _view = view;
    });
  }

  void _openTask(TaskItem task) {
    setState(() {
      _selectedTask = task;
      _previousView = _view;
      _view = AppView.detail;
    });
  }

  List<TaskItem> _sortTasks(List<TaskItem> tasks) {
    final rank = {'urgente': 0, 'alta': 1, 'media': 2, 'baja': 3};
    tasks.sort((a, b) {
      if (a.completada != b.completada) return a.completada ? 1 : -1;
      final priority = (rank[a.prioridad] ?? 1).compareTo(
        rank[b.prioridad] ?? 1,
      );
      if (priority != 0) return priority;
      return b.fechaCreacion.compareTo(a.fechaCreacion);
    });
    return tasks;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'ThinkLess',
      theme: _appTheme,
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _buildView(),
            ),
    );
  }

  Widget _buildView() {
    final shellExtras = <String, dynamic>{
      'focusTotal': _focusTotal,
      'focusTotalClock': _focusTotalClock,
      'onOpenFocusTotal': () => _navigate(AppView.focus),
      'onStopFocusTotal': _deactivateFocusTotal,
    };
    return switch (_view) {
      AppView.onboarding => OnboardingScreen(onStart: _startApp),
      AppView.home => ShellScreen(
        active: AppView.home,
        onNavigate: _navigate,
        onFab: _showAddSheet,
        focusTotal: shellExtras['focusTotal'] as FocusTotalConfig,
        focusTotalClock: shellExtras['focusTotalClock'] as ValueNotifier<DateTime>,
        onOpenFocusTotal: shellExtras['onOpenFocusTotal'] as VoidCallback,
        onStopFocusTotal: shellExtras['onStopFocusTotal'] as VoidCallback,
        child: HomeScreen(
          tasks: _tasks,
          focusTotal: _focusTotal,
          focusTotalClock: _focusTotalClock,
          onOpenTask: _openTask,
          onToggleTask: _toggleTask,
          onNavigate: _navigate,
          onShowFreeTime: _showFreeTimeSheet,
          onActivateFocusTotal: () => _showFocusTotalSheet(
            _navigatorKey.currentContext!,
            onActivate: _activateFocusTotal,
          ),
          onDeactivateFocusTotal: _deactivateFocusTotal,
        ),
      ),
      AppView.calendar => ShellScreen(
        active: AppView.calendar,
        onNavigate: _navigate,
        onFab: _showAddSheet,
        focusTotal: shellExtras['focusTotal'] as FocusTotalConfig,
        focusTotalClock: shellExtras['focusTotalClock'] as ValueNotifier<DateTime>,
        onOpenFocusTotal: shellExtras['onOpenFocusTotal'] as VoidCallback,
        onStopFocusTotal: shellExtras['onStopFocusTotal'] as VoidCallback,
        child: CalendarScreen(
          tasks: _tasks,
          onOpenTask: _openTask,
          onToggleTask: _toggleTask,
          noMolestar: _noMolestar,
          onAddTask: _showAddSheet,
        ),
      ),
      AppView.focus => ShellScreen(
        active: AppView.focus,
        onNavigate: _navigate,
        focusTotal: shellExtras['focusTotal'] as FocusTotalConfig,
        focusTotalClock: shellExtras['focusTotalClock'] as ValueNotifier<DateTime>,
        onOpenFocusTotal: shellExtras['onOpenFocusTotal'] as VoidCallback,
        onStopFocusTotal: shellExtras['onStopFocusTotal'] as VoidCallback,
        child: FocusScreen(
          key: ValueKey(_focusSessionToken),
          noMolestar: _noMolestar,
          initialMinutes: _focusMinutes,
          initialTaskTitle: _focusTaskTitle,
          initialTaskId: _focusTaskId,
          tasks: _tasks,
          sessionsToday: _focusSessionsToday,
          minutesToday: _focusMinutesToday,
          onSessionCompleted: _onFocusSessionCompleted,
          onMarkTaskDone: _toggleTask,
          onExit: () => _navigate(AppView.home),
        ),
      ),
      AppView.matrix => ShellScreen(
        active: AppView.matrix,
        onNavigate: _navigate,
        onFab: _showAddSheet,
        focusTotal: shellExtras['focusTotal'] as FocusTotalConfig,
        focusTotalClock: shellExtras['focusTotalClock'] as ValueNotifier<DateTime>,
        onOpenFocusTotal: shellExtras['onOpenFocusTotal'] as VoidCallback,
        onStopFocusTotal: shellExtras['onStopFocusTotal'] as VoidCallback,
        child: MatrixScreen(
          tasks: _tasks,
          onOpenTask: _openTask,
          onToggleTask: _toggleTask,
        ),
      ),
      AppView.alerts => ShellScreen(
        active: AppView.profile,
        onNavigate: _navigate,
        focusTotal: shellExtras['focusTotal'] as FocusTotalConfig,
        focusTotalClock: shellExtras['focusTotalClock'] as ValueNotifier<DateTime>,
        onOpenFocusTotal: shellExtras['onOpenFocusTotal'] as VoidCallback,
        onStopFocusTotal: shellExtras['onStopFocusTotal'] as VoidCallback,
        child: AlertsScreen(
          tasks: _tasks,
          alerts: _alerts,
          noMolestar: _noMolestar,
          onSave: _saveAlerts,
          onSaveNoMolestar: _saveNoMolestar,
        ),
      ),
      AppView.profile => ShellScreen(
        active: AppView.profile,
        onNavigate: _navigate,
        focusTotal: shellExtras['focusTotal'] as FocusTotalConfig,
        focusTotalClock: shellExtras['focusTotalClock'] as ValueNotifier<DateTime>,
        onOpenFocusTotal: shellExtras['onOpenFocusTotal'] as VoidCallback,
        onStopFocusTotal: shellExtras['onStopFocusTotal'] as VoidCallback,
        child: ProfileScreen(onNavigate: _navigate),
      ),
      AppView.voice => VoiceScreen(
        onClose: () => _navigate(_previousView),
        onAdd: _addTask,
        noMolestar: _noMolestar,
      ),
      AppView.scanner => ScannerScreen(
        onClose: () => _navigate(_previousView),
        onAdd: _addTasks,
      ),
      AppView.detail => DetailScreen(
        task: _selectedTask,
        onBack: () => _navigate(_previousView),
        onToggle: _toggleTask,
        onDelete: _deleteTask,
        onEdit: _openEditSheet,
      ),
      AppView.priorities => PriorityOrganizerScreen(
        tasks: _tasks,
        onUpdatePriority: _updatePriority,
        onBack: () => _navigate(_previousView),
      ),
      AppView.review => DayReviewScreen(
        tasks: _tasks,
        onToggleTask: _toggleTask,
        onOpenTask: _openTask,
        onReschedule: _rescheduleTask,
        onBack: () => _navigate(AppView.home),
      ),
    };
  }

  void _showFreeTimeSheet() {
    final ctx = _navigatorKey.currentContext;
    if (ctx == null) return;
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: AppColors.surfaceLowest,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => FreeTimeSheet(
        tasks: _tasks,
        onStartFocus: (task, minutes) {
          Navigator.pop(context);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startFocus(minutes: minutes, title: task?.titulo);
          });
        },
      ),
    );
  }

  void _showAddSheet() {
    final ctx = _navigatorKey.currentContext;
    if (ctx == null) return;
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: AppColors.surfaceLowest,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => QuickCaptureSheet(
        onAddTask: (task) {
          Navigator.pop(context);
          WidgetsBinding.instance.addPostFrameCallback((_) => _addTask(task));
        },
        onOpenVoice: () {
          Navigator.pop(context);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _navigate(AppView.voice),
          );
        },
        onOpenScanner: () {
          Navigator.pop(context);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _navigate(AppView.scanner),
          );
        },
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({required this.onStart, super.key});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 168,
                          height: 168,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                            boxShadow: AppShadow.brand(opacity: 0.28),
                          ),
                          child: const Icon(
                            Icons.psychology_rounded,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          'ThinkLess',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Menos caos. Más hecho.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Dot(active: true),
                      _Dot(active: false),
                      _Dot(active: false),
                    ],
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Comenzar',
                    icon: Icons.arrow_forward,
                    onTap: onStart,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ShellScreen extends StatelessWidget {
  const ShellScreen({
    required this.child,
    required this.active,
    required this.onNavigate,
    this.onFab,
    this.focusTotal,
    this.focusTotalClock,
    this.onOpenFocusTotal,
    this.onStopFocusTotal,
    super.key,
  });
  final Widget child;
  final AppView active;
  final ValueChanged<AppView> onNavigate;
  final VoidCallback? onFab;
  final FocusTotalConfig? focusTotal;
  final ValueNotifier<DateTime>? focusTotalClock;
  final VoidCallback? onOpenFocusTotal;
  final VoidCallback? onStopFocusTotal;

  @override
  Widget build(BuildContext context) {
    final ft = focusTotal;
    final showBanner = ft != null && ft.active;
    return Scaffold(
      body: Column(
        children: [
          AnimatedSize(
            duration: AppMotion.base,
            curve: AppMotion.standard,
            alignment: Alignment.topCenter,
            child: showBanner
                ? SafeArea(
                    bottom: false,
                    child: FocusTotalBanner(
                      config: ft,
                      clock: focusTotalClock,
                      onTap: onOpenFocusTotal ?? () {},
                      onStop: onStopFocusTotal ?? () {},
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(child: child),
        ],
      ),
      floatingActionButton: onFab == null ? null : GradientFab(onTap: onFab!),
      bottomNavigationBar: NavigationBar(
        height: 68,
        backgroundColor: AppColors.surfaceWarm,
        selectedIndex: switch (active) {
          AppView.home => 0,
          AppView.calendar => 1,
          AppView.focus => 2,
          AppView.matrix => 3,
          _ => 4,
        },
        onDestinationSelected: (index) {
          onNavigate(
            [
              AppView.home,
              AppView.calendar,
              AppView.focus,
              AppView.matrix,
              AppView.profile,
            ][index],
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Tareas',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_week_outlined),
            selectedIcon: Icon(Icons.view_week_rounded),
            label: 'Semana',
          ),
          NavigationDestination(
            icon: Icon(Icons.center_focus_strong_outlined),
            selectedIcon: Icon(Icons.center_focus_strong),
            label: 'Enfoque',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Matriz',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Más',
          ),
        ],
      ),
    );
  }
}


class VoiceScreen extends StatefulWidget {
  const VoiceScreen({
    required this.onClose,
    required this.onAdd,
    required this.noMolestar,
    super.key,
  });
  final VoidCallback onClose;
  final ValueChanged<TaskItem> onAdd;
  final NoMolestarConfig noMolestar;

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

// Estados: idle | requesting | listening | busy | reconnecting | processing | result | error | meetingMode
class _VoiceScreenState extends State<VoiceScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();

  String _status = 'idle';
  String _transcript = '';
  String _errorMsg = '';
  TaskItem? _result;

  // Meeting mode
  bool _meetingMode = false;
  final ValueNotifier<bool> _isHolding = ValueNotifier(false);
  Timer? _pttTimeout;
  static const Duration _pttMaxDuration = Duration(seconds: 5);
  int _busyRetryCount = 0;
  static const int _maxBusyBeforeMeeting = 2;

  // Normal retry
  Timer? _retryTimer;
  int _retryCount = 0;
  int _retrySecondsLeft = 0;
  Timer? _retryCountdownTimer;
  static const int _maxRetries = 4;

  // Orb pulse animation (solo activo durante PTT hold)
  late AnimationController _orbController;
  late Animation<double> _orbPulse;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _orbPulse = Tween<double>(begin: 1.0, end: 1.13).animate(
      CurvedAnimation(parent: _orbController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _retryCountdownTimer?.cancel();
    _pttTimeout?.cancel();
    _isHolding.dispose();
    _orbController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_meetingMode) {
        // En modo reunión: intentar silenciosamente si el mic se liberó
        _tryExitMeetingMode();
      } else if (_status == 'busy' || _status == 'reconnecting') {
        debugPrint('[VoiceScreen] App resumed, retrying mic...');
        _retryTimer?.cancel();
        _retryCountdownTimer?.cancel();
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && (_status == 'busy' || _status == 'reconnecting')) {
            _startListening();
          }
        });
      }
    } else if (state == AppLifecycleState.paused) {
      _retryTimer?.cancel();
      _retryCountdownTimer?.cancel();
    }
  }

  // ─── Error helpers ──────────────────────────────────────────────────────────

  String _mapError(String errorMsg) {
    final e = errorMsg.toLowerCase();
    if (e.contains('audio') || e.contains('busy') || e.contains('7')) {
      return 'Micrófono ocupado por otra app (Meet, Zoom, Discord).';
    }
    if (e.contains('permission') || e.contains('denied')) {
      return 'Permiso denegado. Ve a Configuración › Permisos › Micrófono.';
    }
    if (e.contains('network') || e.contains('timeout')) {
      return 'Sin internet. Verifica tu conexión.';
    }
    if (e.contains('no_match') || e.contains('speech_timeout')) {
      return 'No se detectó voz. Habla más cerca del micrófono.';
    }
    return 'Error de audio: $errorMsg';
  }

  bool _isMicBusy(String errorMsg) {
    final e = errorMsg.toLowerCase();
    return e.contains('audio') || e.contains('busy') ||
        e.contains('error_audio') || e == '3' || e.contains('7');
  }

  bool _isRecoverable(String errorMsg) {
    final e = errorMsg.toLowerCase();
    return !e.contains('permission') && !e.contains('denied');
  }

  // ─── Meeting mode ────────────────────────────────────────────────────────────

  void _enterMeetingMode() {
    debugPrint('[VoiceScreen] → Entering meeting mode');
    _retryTimer?.cancel();
    _retryCountdownTimer?.cancel();
    if (mounted) {
      setState(() {
        _meetingMode = true;
        _status = 'meetingMode';
        _errorMsg = '';
      });
    }
  }

  void _tryExitMeetingMode() {
    debugPrint('[VoiceScreen] → Trying to exit meeting mode...');
    _busyRetryCount = 0;
    _retryCount = 0;
    if (mounted) setState(() { _meetingMode = false; });
    _listen();
  }

  // ─── PTT (Push-to-Talk) ─────────────────────────────────────────────────────

  void _onHoldStart() {
    if (_status == 'processing') return;
    _isHolding.value = true;
    _orbController.repeat(reverse: true);
    _startPttCapture();
    // Seguridad: auto-stop tras duración máxima
    _pttTimeout?.cancel();
    _pttTimeout = Timer(_pttMaxDuration, () {
      if (_isHolding.value) _onHoldEnd();
    });
  }

  void _onHoldEnd() {
    if (!_isHolding.value) return;
    _isHolding.value = false;
    _pttTimeout?.cancel();
    _orbController.animateBack(0, duration: const Duration(milliseconds: 250));
    _processPtt();
  }

  Future<void> _startPttCapture() async {
    if (!mounted) return;
    setState(() { _status = 'listening'; _transcript = ''; _errorMsg = ''; });

    final available = await _speech.initialize(
      onStatus: (s) => debugPrint('[PTT] status: $s'),
      onError: (error) {
        if (!mounted) return;
        debugPrint('[PTT] error: ${error.errorMsg}');
        if (_isMicBusy(error.errorMsg)) {
          _isHolding.value = false;
          _pttTimeout?.cancel();
          _orbController.stop();
          if (mounted) {
            setState(() {
              _status = 'meetingMode';
              _errorMsg = 'Micrófono aún ocupado. Inténtalo en un momento.';
            });
          }
        }
      },
    );

    if (!available || !mounted) {
      _isHolding.value = false;
      _orbController.stop();
      return;
    }

    await _speech.listen(
      localeId: 'es_419',
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: false,
      ),
      onResult: (result) {
        if (!mounted) return;
        setState(() => _transcript = result.recognizedWords);
      },
    );
  }

  Future<void> _processPtt() async {
    // Liberar micrófono inmediatamente al soltar
    await _speech.stop();
    if (!mounted || _status == 'processing') return;

    final text = _transcript.trim();
    if (text.isEmpty) {
      setState(() { _status = 'meetingMode'; _errorMsg = ''; });
      return;
    }

    setState(() => _status = 'processing');
    try {
      final task = await GroqService.extractTaskFromText(text);
      if (!mounted) return;
      setState(() { _status = 'result'; _result = task; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _meetingMode ? 'meetingMode' : 'error';
        _errorMsg = e.toString();
      });
    }
  }

  // ─── Normal flow ─────────────────────────────────────────────────────────────

  void _scheduleRetry({bool fromBusy = false}) {
    if (fromBusy) {
      _busyRetryCount++;
      if (_busyRetryCount >= _maxBusyBeforeMeeting) {
        _enterMeetingMode();
        return;
      }
    }

    if (_retryCount >= _maxRetries) {
      if (mounted) {
        setState(() {
          _status = 'error';
          _errorMsg = fromBusy
              ? 'Micrófono sigue ocupado. Activa modo reunión.'
              : 'No se pudo conectar el micrófono.';
        });
      }
      return;
    }

    final delaySec = (2 * (1 << _retryCount.clamp(0, 4)));
    _retryCount++;
    if (mounted) setState(() { _status = 'reconnecting'; _retrySecondsLeft = delaySec; });

    _retryCountdownTimer?.cancel();
    _retryCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() { _retrySecondsLeft = (_retrySecondsLeft - 1).clamp(0, delaySec); });
      if (_retrySecondsLeft <= 0) t.cancel();
    });

    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: delaySec), () {
      if (mounted && (_status == 'reconnecting' || _status == 'busy')) {
        _startListening();
      }
    });
    debugPrint('[VoiceScreen] Retry #$_retryCount en ${delaySec}s');
  }

  Future<void> _listen() async {
    _retryCount = 0;
    _busyRetryCount = 0;
    _retryTimer?.cancel();
    _retryCountdownTimer?.cancel();
    if (mounted) {
      setState(() {
        _meetingMode = false;
        _status = 'requesting';
        _errorMsg = '';
        _result = null;
        _transcript = '';
      });
    }
    await _startListening();
  }

  Future<void> _startListening() async {
    if (!mounted) return;
    if (mounted) setState(() { _status = 'requesting'; _errorMsg = ''; });

    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        debugPrint('[VoiceScreen] status: $status');
        if ((status == 'done' || status == 'notListening') && _status == 'listening') {
          if (_transcript.trim().isNotEmpty) {
            _process();
          } else {
            _scheduleRetry();
          }
        }
      },
      onError: (error) {
        if (!mounted) return;
        final errStr = error.errorMsg;
        debugPrint('[VoiceScreen] error: $errStr (permanent: ${error.permanent})');
        if (_isMicBusy(errStr)) {
          if (mounted) setState(() => _status = 'busy');
          _scheduleRetry(fromBusy: true);
        } else if (error.permanent || !_isRecoverable(errStr)) {
          if (mounted) setState(() { _status = 'error'; _errorMsg = _mapError(errStr); });
        } else {
          _scheduleRetry();
        }
      },
    );

    if (!available) {
      if (!mounted) return;
      setState(() {
        _status = 'error';
        _errorMsg = 'Reconocimiento de voz no disponible en este dispositivo.';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _status = 'listening');

    await _speech.listen(
      localeId: 'es_419',
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.confirmation,
        cancelOnError: false,
      ),
      onResult: (SpeechRecognitionResult result) {
        if (!mounted) return;
        setState(() => _transcript = result.recognizedWords);
        if (result.finalResult && _transcript.trim().isNotEmpty) {
          _process();
        }
      },
    );
  }

  Future<void> _process() async {
    if (_status == 'processing') return;
    _retryTimer?.cancel();
    _retryCountdownTimer?.cancel();
    await _speech.stop();
    final text = _transcript.trim();
    if (text.isEmpty) {
      setState(() { _status = 'error'; _errorMsg = 'No se detectó texto.'; });
      return;
    }
    setState(() => _status = 'processing');
    try {
      final task = await GroqService.extractTaskFromText(text);
      if (!mounted) return;
      setState(() { _status = 'result'; _result = task; _retryCount = 0; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _status = 'error'; _errorMsg = error.toString(); });
    }
  }

  // ─── UI helpers ──────────────────────────────────────────────────────────────

  Color get _statusColor {
    if (_meetingMode || _status == 'meetingMode') return const Color(0xFF3B82F6);
    return switch (_status) {
      'listening' => AppColors.mint,
      'busy' || 'reconnecting' => const Color(0xFFF59E0B),
      'error' => AppColors.error,
      'processing' => AppColors.primary,
      _ => AppColors.violetLight,
    };
  }

  IconData get _statusIcon {
    if (_meetingMode || _status == 'meetingMode') return Icons.videocam_rounded;
    return switch (_status) {
      'listening' => Icons.graphic_eq_rounded,
      'requesting' => Icons.settings_voice_rounded,
      'busy' => Icons.mic_off_rounded,
      'reconnecting' => Icons.refresh_rounded,
      'processing' => Icons.auto_awesome,
      'error' => Icons.error_outline_rounded,
      'result' => Icons.check_circle_rounded,
      _ => Icons.mic_rounded,
    };
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final inMeeting = _meetingMode || _status == 'meetingMode';
    final color = _statusColor;

    return Scaffold(
      backgroundColor: AppColors.background.withValues(alpha: 0.96),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Header
                  Row(
                    children: [
                      if (inMeeting)
                        const _MeetingModeBadge()
                      else
                        const Spacer(),
                      const Spacer(),
                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 24),
                          if (inMeeting)
                            _buildMeetingMode(color)
                          else
                            _buildNormalMode(color),
                        ],
                      ),
                    ),
                  ),

                  // Footer buttons
                  if (!inMeeting) ...[
                    PrimaryButton(
                      label: switch (_status) {
                        'listening' => 'Procesar ahora',
                        'processing' => 'Procesando...',
                        'requesting' => 'Iniciando...',
                        'reconnecting' => 'Reintentar ahora',
                        'result' => 'Hablar otra vez',
                        _ => 'Iniciar captura',
                      },
                      icon: switch (_status) {
                        'listening' => Icons.check,
                        'processing' => Icons.hourglass_top,
                        'reconnecting' => Icons.refresh,
                        _ => Icons.play_arrow,
                      },
                      onTap: switch (_status) {
                        'processing' || 'requesting' => null,
                        'listening' => _process,
                        'reconnecting' => _listen,
                        _ => _listen,
                      },
                    ),
                  ] else ...[
                    if (_status == 'result')
                      PrimaryButton(
                        label: 'Hablar de nuevo',
                        icon: Icons.mic_rounded,
                        onTap: () => setState(() {
                          _status = 'meetingMode';
                          _result = null;
                          _transcript = '';
                        }),
                      ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _tryExitMeetingMode,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_tethering_rounded, size: 15, color: AppColors.secondary),
                          const SizedBox(width: 6),
                          Text(
                            'Intentar modo normal',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.secondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNormalMode(Color color) {
    final isActive = _status == 'listening';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: AppMotion.slow,
          curve: AppMotion.standard,
          width: isActive ? 168 : 140,
          height: isActive ? 168 : 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: isActive ? 0.22 : 0.12),
                AppColors.surfaceContainer,
              ],
            ),
            border: Border.all(
              color: color.withValues(alpha: isActive ? 0.75 : 0.35),
              width: isActive ? 2 : 1,
            ),
            boxShadow: isActive
                ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 32, spreadRadius: 2)]
                : AppShadow.brand(opacity: 0.18),
          ),
          child: _status == 'requesting'
              ? const Padding(padding: EdgeInsets.all(44), child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(_statusIcon, size: 56, color: color),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text('Voz e IA activadas', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
        if (isNoMolestarActivo(widget.noMolestar)) ...[
          const SizedBox(height: AppSpacing.sm + 2),
          InfoChip(icon: Icons.notifications_off_rounded, text: 'IA en modo silencioso'),
        ],
        const SizedBox(height: 18),
        if (_status == 'idle') _VoiceTips(),
        if (_status == 'requesting')
          const _StatusCard(icon: Icons.settings_voice_rounded, title: 'Iniciando micrófono...', body: 'Preparando el motor de reconocimiento.'),
        if (isActive)
          _StatusCard(
            icon: Icons.mic,
            title: 'Escuchando...',
            body: _transcript.isEmpty ? 'Di tu tarea con fecha, materia y prioridad.' : _transcript,
          ),
        if (_status == 'busy')
          _StatusCard(
            icon: Icons.mic_off_rounded,
            title: 'Micrófono ocupado',
            body: 'Meet/Zoom/Discord está usando el mic. Cambiando a Modo Reunión...',
            color: const Color(0xFFF59E0B),
          ),
        if (_status == 'reconnecting')
          _StatusCard(
            icon: Icons.refresh_rounded,
            title: 'Reconectando audio...',
            body: 'Reintento #$_retryCount en $_retrySecondsLeft s.',
            color: const Color(0xFFF59E0B),
          ),
        if (_status == 'processing')
          const _StatusCard(icon: Icons.auto_awesome, title: 'Procesando con IA...', body: 'Groq está estructurando tu tarea.'),
        if (_status == 'error')
          _StatusCard(icon: Icons.error_outline, title: 'Error', body: _errorMsg, danger: true),
        if (_status == 'result' && _result != null)
          TaskPreview(task: _result!, onAdd: () => widget.onAdd(_result!)),
      ],
    );
  }

  Widget _buildMeetingMode(Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Orb con animación PTT
        ValueListenableBuilder<bool>(
          valueListenable: _isHolding,
          builder: (_, holding, __) {
            return AnimatedBuilder(
              animation: _orbPulse,
              builder: (_, __) {
                final scale = holding ? _orbPulse.value : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: holding ? 152 : 128,
                    height: holding ? 152 : 128,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          color.withValues(alpha: holding ? 0.28 : 0.10),
                          AppColors.surfaceContainer,
                        ],
                      ),
                      border: Border.all(
                        color: color.withValues(alpha: holding ? 0.90 : 0.28),
                        width: holding ? 2.5 : 1.5,
                      ),
                      boxShadow: holding
                          ? [
                              BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 44, spreadRadius: 4),
                              BoxShadow(color: color.withValues(alpha: 0.20), blurRadius: 16),
                            ]
                          : null,
                    ),
                    child: _status == 'processing'
                        ? const Padding(padding: EdgeInsets.all(38), child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(
                            holding ? Icons.graphic_eq_rounded : Icons.videocam_rounded,
                            size: 48,
                            color: color,
                          ),
                  ),
                );
              },
            );
          },
        ),

        const SizedBox(height: 16),

        // Waveform — visible solo mientras escucha
        ValueListenableBuilder<bool>(
          valueListenable: _isHolding,
          builder: (_, holding, __) {
            return AnimatedOpacity(
              opacity: holding ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 180),
              child: _WaveformBars(color: color, active: holding),
            );
          },
        ),

        const SizedBox(height: 20),

        // Transcript o hint
        if (_status != 'result' && _status != 'processing') ...[
          ValueListenableBuilder<bool>(
            valueListenable: _isHolding,
            builder: (_, holding, __) {
              final text = holding
                  ? (_transcript.isEmpty ? 'Escuchando...' : _transcript)
                  : 'Micrófono ocupado por otra app.\nUsa el botón para capturar rápido.';
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  text,
                  key: ValueKey(holding),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: holding ? FontWeight.w500 : FontWeight.w400,
                    color: holding ? AppColors.onSurface : AppColors.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
          if (_errorMsg.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _errorMsg,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFF59E0B)),
            ),
          ],
          const SizedBox(height: 36),
          // Botón PTT grande
          _PttButton(
            isHolding: _isHolding,
            onHoldStart: _onHoldStart,
            onHoldEnd: _onHoldEnd,
            color: color,
          ),
          const SizedBox(height: 32),
        ],

        if (_status == 'processing')
          const _StatusCard(icon: Icons.auto_awesome, title: 'Procesando con IA...', body: 'Groq está estructurando tu tarea.'),

        if (_status == 'result' && _result != null) ...[
          TaskPreview(task: _result!, onAdd: () => widget.onAdd(_result!)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

// ─── Badge "Modo Reunión" ─────────────────────────────────────────────────────

class _MeetingModeBadge extends StatelessWidget {
  const _MeetingModeBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF3B82F6)),
          ),
          const SizedBox(width: 6),
          Text(
            'Modo Reunión',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF3B82F6)),
          ),
        ],
      ),
    );
  }
}

// ─── Botón Push-to-Talk ───────────────────────────────────────────────────────

class _PttButton extends StatelessWidget {
  const _PttButton({
    required this.isHolding,
    required this.onHoldStart,
    required this.onHoldEnd,
    required this.color,
  });

  final ValueNotifier<bool> isHolding;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: isHolding,
          builder: (_, holding, __) {
            return GestureDetector(
              // onTapDown/Up para respuesta inmediata (sin delay de long press)
              onTapDown: (_) => onHoldStart(),
              onTapUp: (_) => onHoldEnd(),
              onTapCancel: onHoldEnd,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: holding ? 96 : 82,
                height: holding ? 96 : 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: holding
                        ? [color, color.withValues(alpha: 0.75)]
                        : [color.withValues(alpha: 0.55), color.withValues(alpha: 0.75)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: holding ? 0.55 : 0.2),
                      blurRadius: holding ? 28 : 10,
                      spreadRadius: holding ? 2 : 0,
                    ),
                  ],
                ),
                child: Icon(
                  holding ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<bool>(
          valueListenable: isHolding,
          builder: (_, holding, __) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                holding ? 'Suelta para procesar' : 'Mantén pulsado para hablar',
                key: ValueKey(holding),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: holding ? color : AppColors.onSurfaceVariant,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─── Waveform bars animadas ───────────────────────────────────────────────────

class _WaveformBars extends StatefulWidget {
  const _WaveformBars({required this.color, required this.active});
  final Color color;
  final bool active;

  @override
  State<_WaveformBars> createState() => _WaveformBarsState();
}

class _WaveformBarsState extends State<_WaveformBars> with TickerProviderStateMixin {
  static const _barCount = 5;
  final List<AnimationController> _controllers = [];
  final List<Animation<double>> _animations = [];

  @override
  void initState() {
    super.initState();
    final heights = [14.0, 28.0, 20.0, 32.0, 16.0];
    for (int i = 0; i < _barCount; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 380 + i * 70),
      );
      _controllers.add(ctrl);
      _animations.add(
        Tween<double>(begin: 4, end: heights[i]).animate(
          CurvedAnimation(parent: ctrl, curve: Curves.easeInOut),
        ),
      );
      if (widget.active) {
        Future.delayed(Duration(milliseconds: i * 55), () {
          if (mounted) ctrl.repeat(reverse: true);
        });
      }
    }
  }

  @override
  void didUpdateWidget(_WaveformBars old) {
    super.didUpdateWidget(old);
    if (widget.active == old.active) return;
    for (int i = 0; i < _barCount; i++) {
      if (widget.active) {
        Future.delayed(Duration(milliseconds: i * 55), () {
          if (mounted) _controllers[i].repeat(reverse: true);
        });
      } else {
        _controllers[i].animateTo(0, duration: const Duration(milliseconds: 200));
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_barCount * 2 - 1, (i) {
          if (i.isOdd) return const SizedBox(width: 5);
          final idx = i ~/ 2;
          return AnimatedBuilder(
            animation: _animations[idx],
            builder: (_, __) => Container(
              width: 4,
              height: _animations[idx].value,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({required this.onClose, required this.onAdd, super.key});
  final VoidCallback onClose;
  final ValueChanged<List<TaskItem>> onAdd;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _picker = ImagePicker();
  Uint8List? _image;
  bool _loading = false;
  String _error = '';
  List<TaskItem> _detected = _sampleScanTasks();
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _selected.addAll(_detected.take(2).map((task) => task.id));
  }

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 78,
      maxWidth: 1600,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _image = bytes;
      _loading = true;
      _error = '';
      _detected = [];
      _selected.clear();
    });
    await Future<void>.delayed(const Duration(seconds: 2));
    try {
      final tasks = await GroqService.extractTasksFromImage(bytes);
      if (!mounted) return;
      setState(() {
        _detected = tasks;
        _selected.addAll(tasks.map((task) => task.id));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _detected = _sampleScanTasks();
        _selected.addAll(_detected.take(2).map((task) => task.id));
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final columns = MediaQuery.sizeOf(context).width > 760;
    return AppScaffold(
      title: 'Escanear',
      leading: Icons.arrow_back,
      onLeading: widget.onClose,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Flex(
              direction: columns ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: columns ? 1 : 0,
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 4 / 5,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(AppRadius.xxl),
                            border: Border.all(color: AppColors.outlineVariant, width: 0.6),
                            boxShadow: AppShadow.md,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (_image != null)
                                Image.memory(_image!, fit: BoxFit.cover)
                              else
                                const _ScannerPlaceholder(),
                              const _ScanCorners(),
                              if (_loading)
                                Container(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.violetLight,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ),
                              Positioned(
                                left: AppSpacing.lg,
                                right: AppSpacing.lg,
                                bottom: AppSpacing.lg,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceLowest.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                    border: Border.all(
                                      color: AppColors.outlineVariant,
                                      width: 0.6,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.center_focus_strong_rounded,
                                          size: 14, color: AppColors.violetLight),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Apunta a tu cuaderno o captura',
                                          style: GoogleFonts.inter(
                                            color: AppColors.onSurface,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
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
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleIconButton(
                            icon: Icons.photo_library,
                            onTap: () => _pick(ImageSource.gallery),
                          ),
                          const SizedBox(width: 18),
                          CircleIconButton(
                            icon: Icons.camera_alt,
                            large: true,
                            filled: true,
                            onTap: () => _pick(ImageSource.camera),
                          ),
                          const SizedBox(width: 18),
                          CircleIconButton(
                            icon: Icons.flash_off,
                            onTap: () => _toast(
                              context,
                              'Flash simulado en este prototipo.',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: columns ? 24 : 0, height: columns ? 0 : 24),
                Expanded(
                  flex: columns ? 1 : 0,
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.document_scanner,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tareas Extraidas',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Revisa y selecciona las tareas detectadas en la imagen.',
                          style: TextStyle(color: AppColors.onSurfaceVariant),
                        ),
                        if (_error.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              'Aviso: $_error\nMostrando ejemplos editables para no romper el flujo.',
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        const SizedBox(height: 14),
                        ..._detected.map(
                          (task) => CheckboxListTile(
                            value: _selected.contains(task.id),
                            onChanged: (value) => setState(
                              () => value == true
                                  ? _selected.add(task.id)
                                  : _selected.remove(task.id),
                            ),
                            title: Text(
                              task.titulo,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${task.materia} • ${task.fecha} • ${task.prioridad}',
                            ),
                            activeColor: AppColors.mint,
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label:
                              'Agregar tareas seleccionadas (${_selected.length})',
                          icon: Icons.add_task,
                          onTap: _selected.isEmpty
                              ? null
                              : () => widget.onAdd(
                                  _detected
                                      .where(
                                        (task) => _selected.contains(task.id),
                                      )
                                      .toList(),
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


class MatrixScreen extends StatelessWidget {
  const MatrixScreen({
    required this.tasks,
    required this.onOpenTask,
    required this.onToggleTask,
    super.key,
  });
  final List<TaskItem> tasks;
  final ValueChanged<TaskItem> onOpenTask;
  final ValueChanged<String> onToggleTask;

  @override
  Widget build(BuildContext context) {
    final source = tasks.isEmpty ? _sampleMatrixTasks() : tasks;
    final hacer = source
        .where((t) => t.prioridad == 'urgente' || t.prioridad == 'alta')
        .toList();
    final agendar = source.where((t) => t.prioridad == 'media').toList();
    final delegar = source.where((t) => t.prioridad == 'baja').toList();
    final extent = MediaQuery.sizeOf(context).width > 720 ? 220.0 : 196.0;

    return AppScaffold(
      title: 'Matriz Eisenhower',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Encabezado estratégico ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Decide con claridad',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Prioriza tus tareas por urgencia e importancia.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
              physics: const BouncingScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: extent,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              children: [
                Quadrant(
                  title: 'Hacer ya',
                  subtitle: 'Urgente e importante',
                  color: AppColors.pink,
                  icon: Icons.error_outline_rounded,
                  tasks: hacer,
                  onOpenTask: onOpenTask,
                  onToggleTask: onToggleTask,
                ),
                Quadrant(
                  title: 'Agendar',
                  subtitle: 'Importante, no urgente',
                  color: AppColors.yellow,
                  icon: Icons.event_outlined,
                  tasks: agendar,
                  onOpenTask: onOpenTask,
                  onToggleTask: onToggleTask,
                ),
                Quadrant(
                  title: 'Delegar',
                  subtitle: 'Urgente, no importante',
                  color: AppColors.blue,
                  icon: Icons.groups_outlined,
                  tasks: const [],
                  onOpenTask: onOpenTask,
                  onToggleTask: onToggleTask,
                ),
                Quadrant(
                  title: 'Eliminar',
                  subtitle: 'Ni urgente, ni importante',
                  color: AppColors.mint,
                  icon: Icons.delete_outline_rounded,
                  tasks: delegar,
                  onOpenTask: onOpenTask,
                  onToggleTask: onToggleTask,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  const DetailScreen({
    required this.task,
    required this.onBack,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    super.key,
  });
  final TaskItem? task;
  final VoidCallback onBack;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onDelete;
  final ValueChanged<TaskItem> onEdit;

  @override
  Widget build(BuildContext context) {
    final item = task;
    if (item == null) {
      return AppScaffold(
        title: 'Detalle',
        leading: Icons.arrow_back,
        onLeading: onBack,
        body: const Center(child: Text('Tarea no encontrada.')),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: AppHeader(
          title: item.titulo,
          leading: Icons.arrow_back_rounded,
          onLeading: onBack,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: PriorityBadge(priority: item.prioridad),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoChip(icon: Icons.calendar_today_rounded, text: item.fecha),
              if (item.hora != 'Sin hora')
                InfoChip(icon: Icons.schedule_rounded, text: item.hora),
              InfoChip(icon: Icons.school_rounded, text: item.materia),
              if (item.duracionMin != null)
                InfoChip(
                  icon: Icons.hourglass_top_rounded,
                  text: item.duracionMin! >= 60
                      ? (item.duracionMin! % 60 == 0
                          ? '${item.duracionMin! ~/ 60} h'
                          : '${item.duracionMin! ~/ 60}h ${item.duracionMin! % 60}m')
                      : '${item.duracionMin} min',
                ),
            ],
          ),
          if (item.etiquetas.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: item.etiquetas
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.30),
                          width: 0.6,
                        ),
                      ),
                      child: Text(
                        '#$tag',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.violetLight,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.22),
                width: 0.6,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: AppColors.violetLight, size: 18),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sugerencia IA',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: AppColors.violetLight,
                          fontSize: 12.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hazlo en tu bloque libre de las 2pm.',
                        style: GoogleFonts.inter(
                          color: AppColors.onSurface,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notes, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Notas',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.notas.isEmpty
                      ? 'Materia: ${item.materia}\nTipo: ${item.tipo}\nPrioridad: ${item.prioridad}\n\nPuedes editar esta tarea en una futura version.'
                      : item.notas,
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onEdit(item),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Editar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.errorContainer,
                    foregroundColor: AppColors.onErrorContainer,
                  ),
                  onPressed: () => onDelete(item.id),
                  icon: const Icon(Icons.delete),
                  label: const Text('Eliminar'),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: GestureDetector(
            onTap: () => onToggle(item.id),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: item.completada
                      ? [AppColors.surfaceHigh, AppColors.surfaceContainer]
                      : [AppColors.mint, AppColors.mint.withValues(alpha: 0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: item.completada ? AppColors.outlineVariant : Colors.white.withValues(alpha: 0.10),
                  width: 0.6,
                ),
                boxShadow: item.completada
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.mint.withValues(alpha: 0.30),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.completada ? Icons.undo_rounded : Icons.check_rounded,
                    color: Colors.white, size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Text(
                    item.completada ? 'Marcar como pendiente' : 'Marcar como completada',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      letterSpacing: -0.15,
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
}

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({
    required this.tasks,
    required this.alerts,
    required this.noMolestar,
    required this.onSave,
    required this.onSaveNoMolestar,
    super.key,
  });
  final List<TaskItem> tasks;
  final Map<String, dynamic> alerts;
  final NoMolestarConfig noMolestar;
  final ValueChanged<Map<String, dynamic>> onSave;
  final ValueChanged<NoMolestarConfig> onSaveNoMolestar;

  @override
  Widget build(BuildContext context) {
    final urgent = tasks.where((task) => !task.completada).firstOrNull;
    final intensity = alerts['intensity']?.toString() ?? 'Insistente';
    final silentNow = isNoMolestarActivo(noMolestar);
    return AppScaffold(
      title: 'ThinkLess',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    width: 0.6,
                  ),
                ),
                child: const Icon(Icons.campaign_rounded, color: AppColors.violetLight, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Alertas inteligentes',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          NoMolestarCard(
            config: noMolestar,
            activeNow: silentNow,
            onChanged: onSaveNoMolestar,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            stripe: AppColors.mint,
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.mint.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: AppColors.mint.withValues(alpha: 0.30),
                      width: 0.6,
                    ),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: AppColors.mint, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tienes 45 min libres',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        urgent == null
                            ? '¿Empezamos con Física?'
                            : '¿Empezamos con ${urgent.titulo}?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: () => _toast(
                    context,
                    urgent == null
                        ? 'No hay tareas pendientes.'
                        : urgent.titulo,
                  ),
                  child: const Text('Ver'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Intensidad de alertas',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Suave', label: Text('Suave')),
              ButtonSegment(value: 'Normal', label: Text('Normal')),
              ButtonSegment(value: 'Insistente', label: Text('Insistente')),
            ],
            selected: {intensity},
            onSelectionChanged: (value) =>
                onSave({...alerts, 'intensity': value.first}),
          ),
          const SizedBox(height: 8),
          const Text(
            'Te recordaremos las tareas urgentes hasta que las marques como completadas.',
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          _AlertTile(
            icon: Icons.warning,
            title: 'Tareas urgentes',
            subtitle: 'Notificar 2h antes del cierre',
            value: alerts['urgent'] == true,
            onChanged: (value) => onSave({...alerts, 'urgent': value}),
          ),
          _AlertTile(
            icon: Icons.schedule,
            title: 'Repaso diario',
            subtitle: 'Resumen a las 19:00 hrs',
            value: alerts['daily'] == true,
            onChanged: (value) => onSave({...alerts, 'daily': value}),
          ),
          _AlertTile(
            icon: Icons.water_drop,
            title: 'Pausas activas',
            subtitle: 'Sugerir descansos cortos',
            value: alerts['breaks'] == true,
            onChanged: (value) => onSave({...alerts, 'breaks': value}),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.onNavigate, super.key});
  final ValueChanged<AppView> onNavigate;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Perfil',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
        children: [
          // ── Cabecera: avatar + nombre + modo enfoque ──────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceLowest,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.outlineSubtle),
              boxShadow: AppShadow.sm,
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primary, AppColors.violetLight],
                        ),
                        boxShadow: AppShadow.brand(opacity: 0.22),
                      ),
                      child: const Center(
                        child: Icon(Icons.person_rounded, size: 34, color: Colors.white),
                      ),
                    ),
                    Positioned(
                      right: -2, bottom: -2,
                      child: Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLowest,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.outlineSubtle),
                        ),
                        child: const Icon(Icons.edit_rounded, size: 12, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alex Doe',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Estudiante · 3er año',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.mintSoft,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.mint, shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'En modo enfoque',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.mint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // ── Stats ──────────────────────────────────────────────────────────
          Row(
            children: const [
              Expanded(
                child: _ProfileStatCard(
                  icon: Icons.task_alt_rounded,
                  value: '42',
                  label: 'Tareas completadas',
                  accent: AppColors.primary,
                ),
              ),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _ProfileStatCard(
                  icon: Icons.timer_outlined,
                  value: '18h',
                  label: 'Tiempo de enfoque',
                  accent: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // ── Meta semanal ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppShadow.brand(opacity: 0.20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meta semanal',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '85% completado',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 56, height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 56, height: 56,
                        child: CircularProgressIndicator(
                          value: 0.85,
                          strokeWidth: 5,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      Text(
                        '85%',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          // ── Ajustes ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.md),
            child: Text(
              'AJUSTES',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.secondary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceLowest,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.outlineSubtle),
              boxShadow: AppShadow.sm,
            ),
            child: Column(
              children: [
                _ProfileSettingRow(
                  icon: Icons.notifications_outlined,
                  title: 'Notificaciones',
                  value: 'Activas',
                  onTap: () => onNavigate(AppView.alerts),
                ),
                const _ProfileRowDivider(),
                _ProfileSettingRow(
                  icon: Icons.palette_outlined,
                  title: 'Apariencia',
                  value: 'Claro',
                  onTap: () => _toast(context, 'Apariencia simulada.'),
                ),
                const _ProfileRowDivider(),
                _ProfileSettingRow(
                  icon: Icons.language_rounded,
                  title: 'Idioma',
                  value: 'Español',
                  onTap: () => _toast(context, 'Idioma configurado en español.'),
                ),
                const _ProfileRowDivider(),
                _ProfileSettingRow(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Premium',
                  value: 'Gestionar',
                  highlight: true,
                  onTap: () => _showPremiumModal(context),
                ),
                const _ProfileRowDivider(),
                _ProfileSettingRow(
                  icon: Icons.help_outline_rounded,
                  title: 'Ayuda y soporte',
                  onTap: () => _toast(context, 'Soporte simulado.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
              onPressed: () => _toast(context, 'Sesion cerrada simulada.'),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(
                'Cerrar sesión',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.outlineSubtle),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSettingRow extends StatelessWidget {
  const _ProfileSettingRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.value,
    this.highlight = false,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: highlight
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: highlight ? AppColors.primary : AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: highlight ? AppColors.primary : AppColors.onSurface,
                  ),
                ),
              ),
              if (value != null) ...[
                Text(
                  value!,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.secondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileRowDivider extends StatelessWidget {
  const _ProfileRowDivider();
  @override
  Widget build(BuildContext context) => const Divider(
    height: 0.5,
    thickness: 0.5,
    color: AppColors.outlineSubtle,
    indent: 62,
    endIndent: AppSpacing.lg,
  );
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.body,
    this.leading,
    this.trailing,
    this.onLeading,
    this.floatingActionButton,
    super.key,
  });

  final String title;
  final Widget body;
  final IconData? leading;
  final IconData? trailing;
  final VoidCallback? onLeading;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: AppHeader(
          title: title,
          leading: leading,
          trailing: trailing,
          onLeading: onLeading,
        ),
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.title,
    this.leading,
    this.trailing,
    this.onLeading,
    this.onTrailing,
    this.subtitle,
    super.key,
  });
  final String title;
  final IconData? leading;
  final IconData? trailing;
  final VoidCallback? onLeading;
  final VoidCallback? onTrailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 60,
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(
            bottom: BorderSide(color: AppColors.outlineSubtle, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _AppHeaderBtn(
              icon: leading ?? Icons.menu_rounded,
              onTap: onLeading,
              visible: leading != null,
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _AppHeaderBtn(
              icon: trailing ?? Icons.more_horiz_rounded,
              onTap: onTrailing,
              visible: trailing != null,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppHeaderBtn extends StatelessWidget {
  const _AppHeaderBtn({required this.icon, required this.onTap, required this.visible});
  final IconData icon;
  final VoidCallback? onTap;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox(width: 38, height: 38);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.outlineVariant, width: 0.6),
          ),
          child: Icon(icon, size: 18, color: AppColors.onSurfaceVariant),
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.stripe,
    this.padding,
    this.elevated = false,
    super.key,
  });
  final Widget child;
  final Color? stripe;
  final EdgeInsetsGeometry? padding;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outlineSubtle, width: 1),
        boxShadow: elevated ? AppShadow.sm : null,
      ),
      child: stripe != null
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          stripe!,
                          stripe!.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
                      child: child,
                    ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
              child: child,
            ),
    );
  }
}

class TaskCard extends StatefulWidget {
  const TaskCard({
    required this.task,
    required this.onTap,
    required this.onToggle,
    this.compact = false,
    super.key,
  });
  final TaskItem task;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final bool compact;

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(widget.task.prioridad);
    final done = widget.task.completada;
    return AnimatedOpacity(
      duration: AppMotion.base,
      opacity: done ? 0.55 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.985 : 1,
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceLowest,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: _pressed ? AppColors.outlineVariant : AppColors.outlineSubtle,
                  width: 1,
                ),
                boxShadow: _pressed ? null : AppShadow.sm,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [color, color.withValues(alpha: 0.4)],
                        ),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(AppRadius.lg)),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: widget.compact ? AppSpacing.md : AppSpacing.md + 2,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: widget.onToggle,
                              behavior: HitTestBehavior.opaque,
                              child: AnimatedContainer(
                                duration: AppMotion.fast,
                                curve: AppMotion.standard,
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: done ? AppColors.primary : Colors.transparent,
                                  border: Border.all(
                                    color: done ? AppColors.primary : AppColors.outlineVariant,
                                    width: 1.5,
                                  ),
                                  boxShadow: done
                                      ? [BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.25),
                                          blurRadius: 8, spreadRadius: 0)]
                                      : null,
                                ),
                                child: done
                                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.task.titulo,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: widget.compact ? 14 : 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onSurface,
                                      letterSpacing: -0.1,
                                      decoration: done ? TextDecoration.lineThrough : null,
                                      decorationColor: AppColors.secondary,
                                      decorationThickness: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Wrap(
                                    spacing: AppSpacing.sm,
                                    runSpacing: 4,
                                    children: [
                                      _MetaChip(icon: Icons.school_rounded, text: widget.task.materia),
                                      _MetaChip(icon: Icons.calendar_today_rounded, text: widget.task.fecha),
                                      if (widget.task.hora != 'Sin hora')
                                        _MetaChip(icon: Icons.schedule_rounded, text: widget.task.hora),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _PriorityDot(color: color),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 8, spreadRadius: 0.5),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppColors.secondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: AppColors.secondary,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.05,
          ),
        ),
      ],
    );
  }
}

class EmptyAction {
  const EmptyAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    required this.icon,
    required this.title,
    required this.body,
    this.actions = const [],
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<EmptyAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outlineSubtle, width: 1),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Icon(icon, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.secondary,
              height: 1.5,
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: actions
                  .map(
                    (action) => GestureDetector(
                      onTap: action.onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.outlineSubtle, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(action.icon, size: 15, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              action.label,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
    super.key,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        child: AnimatedOpacity(
          duration: AppMotion.fast,
          opacity: enabled ? 1 : 0.55,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.indigo.withValues(alpha: 0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.6),
              boxShadow: enabled ? AppShadow.brand(opacity: 0.28) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: Colors.white, size: 19),
                const SizedBox(width: AppSpacing.sm + 2),
                Text(
                  widget.label,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    letterSpacing: -0.15,
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

class GradientFab extends StatefulWidget {
  const GradientFab({required this.onTap, super.key});
  final VoidCallback onTap;

  @override
  State<GradientFab> createState() => _GradientFabState();
}

class _GradientFabState extends State<GradientFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1,
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadow.brand(opacity: 0.30),
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

class FeatureTile extends StatelessWidget {
  const FeatureTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.surfaceContainer,
    this.accent,
    super.key,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final iconColor = accent ?? AppColors.violetLight;
    final bgColor = accent != null
        ? accent!.withValues(alpha: 0.14)
        : AppColors.primary.withValues(alpha: 0.10);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        splashColor: iconColor.withValues(alpha: 0.10),
        highlightColor: iconColor.withValues(alpha: 0.05),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLowest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.outlineSubtle, width: 1),
            boxShadow: AppShadow.sm,
          ),
          padding: const EdgeInsets.all(AppSpacing.md + 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const Spacer(),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                  height: 1.3,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Quadrant extends StatelessWidget {
  const Quadrant({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.tasks,
    required this.onOpenTask,
    required this.onToggleTask,
    this.icon,
    super.key,
  });
  final String title;
  final String subtitle;
  final Color color;
  final IconData? icon;
  final List<TaskItem> tasks;
  final ValueChanged<TaskItem> onOpenTask;
  final ValueChanged<String> onToggleTask;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outlineSubtle),
        boxShadow: AppShadow.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                ),
                child: Icon(icon ?? Icons.circle, color: color, size: 15),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (tasks.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              color: AppColors.secondary,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: AppColors.outlineSubtle),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                          color: AppColors.outlineVariant,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sin tareas',
                          style: GoogleFonts.inter(
                            color: AppColors.secondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tasks.length > 3 ? 4 : tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      if (tasks.length > 3 && i == 3) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 2, left: 2),
                          child: Text(
                            '+${tasks.length - 3} más',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        );
                      }
                      final task = tasks[i];
                      return Material(
                        color: AppColors.surfaceWarm,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: InkWell(
                          onTap: () => onOpenTask(task),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border(
                                left: BorderSide(color: color, width: 3),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 9),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => onToggleTask(task.id),
                                  child: Container(
                                    width: 16, height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: task.completada ? AppColors.mint : Colors.transparent,
                                      border: Border.all(
                                        color: task.completada ? AppColors.mint : AppColors.outline,
                                        width: 1.4,
                                      ),
                                    ),
                                    child: task.completada
                                        ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    task.titulo,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      height: 1.2,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onSurface,
                                      decoration: task.completada ? TextDecoration.lineThrough : null,
                                      decorationColor: AppColors.secondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class TaskPreview extends StatelessWidget {
  const TaskPreview({required this.task, required this.onAdd, super.key});
  final TaskItem task;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      stripe: priorityColor(task.prioridad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.violetLight, size: 14),
              const SizedBox(width: 6),
              Text(
                'TAREA EXTRAÍDA',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.violetLight,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            task.titulo,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            '${task.materia}  •  ${task.fecha}  •  ${task.hora}',
            style: GoogleFonts.inter(
              color: AppColors.onSurfaceVariant,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Agregar tarea',
            icon: Icons.check_rounded,
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}

class _VoiceTips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: const [
          _Tip(
            icon: Icons.check_circle,
            text:
                'Captura de voz: activa el Modo IA para transcribir tus tareas al instante.',
          ),
          SizedBox(height: 10),
          _Tip(
            icon: Icons.check_circle,
            text:
                'Resúmenes de audio: convierte notas largas en acciones organizadas.',
          ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.mint),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.body,
    this.danger = false,
    this.color,
  });
  final IconData icon;
  final String title;
  final String body;
  final bool danger;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? (danger ? AppColors.error : AppColors.violetLight);
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: danger ? AppColors.onErrorContainer : AppColors.onSurfaceVariant,
                    height: 1.45,
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



class DayPill extends StatelessWidget {
  const DayPill(this.day, this.number, {this.active = false, super.key});
  final String day;
  final String number;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: active ? 12 : 4,
        vertical: active ? 8 : 4,
      ),
      decoration: BoxDecoration(
        color: active ? AppColors.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Column(
        children: [
          Text(
            day,
            style: TextStyle(
              color: active ? Colors.white : AppColors.secondary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          Text(
            number,
            style: TextStyle(
              color: active ? Colors.white : AppColors.onSurface,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              fontSize: active ? 20 : 16,
            ),
          ),
        ],
      ),
    );
  }
}

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({required this.priority, super.key});
  final String priority;

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            priorityLabel(priority).toUpperCase(),
            style: GoogleFonts.inter(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  const InfoChip({required this.icon, required this.text, super.key});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.outlineVariant, width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.violetLight),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.outlineVariant, width: 0.6),
              ),
              child: Icon(icon, color: AppColors.violetLight, size: 18),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class NoMolestarCard extends StatelessWidget {
  const NoMolestarCard({
    required this.config,
    required this.activeNow,
    required this.onChanged,
    super.key,
  });

  final NoMolestarConfig config;
  final bool activeNow;
  final ValueChanged<NoMolestarConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    const days = ['LUN', 'MAR', 'MIE', 'JUE', 'VIE', 'SAB', 'DOM'];
    return AppCard(
      stripe: config.activo ? AppColors.primary : AppColors.outlineVariant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: config.activo
                      ? AppColors.primary.withValues(alpha: 0.16)
                      : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: config.activo
                        ? AppColors.primary.withValues(alpha: 0.30)
                        : AppColors.outlineVariant,
                    width: 0.6,
                  ),
                ),
                child: Icon(
                  config.activo ? Icons.notifications_off_rounded : Icons.nights_stay_rounded,
                  color: config.activo ? AppColors.violetLight : AppColors.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modo No molestar',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeNow
                          ? 'Activo ahora — alertas en silencio'
                          : 'Sin interrupciones en clases o trabajo',
                      style: GoogleFonts.inter(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: config.activo,
                onChanged: (value) => onChanged(config.copyWith(activo: value)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TimeField(
                  label: 'Inicio',
                  value: config.horaInicio,
                  onChanged: (value) =>
                      onChanged(config.copyWith(horaInicio: value)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TimeField(
                  label: 'Fin',
                  value: config.horaFin,
                  onChanged: (value) =>
                      onChanged(config.copyWith(horaFin: value)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: days.map((day) {
              final selected = config.dias.contains(day);
              return FilterChip(
                selected: selected,
                label: Text(day),
                selectedColor: AppColors.primaryContainer.withValues(
                  alpha: 0.22,
                ),
                checkmarkColor: AppColors.primary,
                onSelected: (value) {
                  final next = [...config.dias];
                  value ? next.add(day) : next.remove(day);
                  onChanged(config.copyWith(dias: next.toSet().toList()));
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class TimeField extends StatelessWidget {
  const TimeField({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _timeOfDay(value),
        );
        if (picked != null) {
          onChanged(
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
          );
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingTile extends StatelessWidget {
  const SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.premium = false,
    this.wide = false,
    super.key,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool premium;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final accentColor = premium ? AppColors.violetLight : AppColors.violetLight;
    return SizedBox(
      width: wide || width < 620 ? double.infinity : (width - 56) / 2,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md + 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: premium
                    ? AppColors.primary.withValues(alpha: 0.30)
                    : AppColors.outlineVariant,
                width: 0.6,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: premium
                        ? AppColors.primary.withValues(alpha: 0.18)
                        : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: premium
                          ? AppColors.primary.withValues(alpha: 0.30)
                          : AppColors.outlineVariant,
                      width: 0.6,
                    ),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          color: AppColors.secondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.secondary,
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

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    required this.icon,
    required this.onTap,
    this.large = false,
    this.filled = false,
    super.key,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool large;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: large ? 72 : 56,
          height: large ? 72 : 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: filled
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.indigo],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: filled ? null : AppColors.surfaceContainer,
            border: Border.all(
              color: filled
                  ? Colors.white.withValues(alpha: 0.10)
                  : AppColors.outlineVariant,
              width: filled ? 0.8 : 0.6,
            ),
            boxShadow: filled ? AppShadow.brand(opacity: 0.32) : null,
          ),
          child: Icon(
            icon,
            color: filled ? Colors.white : AppColors.violetLight,
            size: large ? 28 : 22,
          ),
        ),
      ),
    );
  }
}

class _ScannerPlaceholder extends StatelessWidget {
  const _ScannerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14172A), Color(0xFF0F1117)],
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: const Icon(Icons.document_scanner_rounded, color: AppColors.violetLight, size: 56),
        ),
      ),
    );
  }
}

class _ScanCorners extends StatelessWidget {
  const _ScanCorners();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: CustomPaint(painter: _CornerPainter()),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.violetLight
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 32.0;
    canvas.drawLine(Offset.zero, const Offset(len, 0), paint);
    canvas.drawLine(Offset.zero, const Offset(0, len), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - len),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - len, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.base,
      curve: AppMotion.standard,
      width: active ? 28 : 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.surfaceHighest,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
  }
}

Color priorityColor(String priority) {
  return switch (priority) {
    'urgente' => AppColors.error,
    'alta'    => AppColors.accent,
    'media'   => AppColors.primary,
    'baja'    => AppColors.mint,
    _         => AppColors.primary,
  };
}

String priorityLabel(String priority) => switch (priority) {
  'urgente' => 'Urgente',
  'alta' => 'Alta',
  'media' => 'Media',
  'baja' => 'Baja',
  _ => priority,
};

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

void _smartNotice(
  BuildContext context,
  String message, {
  required NoMolestarConfig config,
  FocusTotalConfig? focusTotal,
  bool urgent = false,
}) {
  final silent = isNoMolestarActivo(config) || (focusTotal?.active ?? false);
  if (silent && !urgent) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(silent ? 'Silencioso: $message' : message),
      behavior: SnackBarBehavior.floating,
      showCloseIcon: true,
    ),
  );
}

final Expando<DateTime> _taskDateCache = Expando<DateTime>('taskDate');
final Expando<int> _taskMinutesCache = Expando<int>('taskMinutes');

DateTime _taskDate(TaskItem task) {
  final cached = _taskDateCache[task];
  if (cached != null) return cached;
  final computed = _computeTaskDate(task);
  _taskDateCache[task] = computed;
  return computed;
}

DateTime _computeTaskDate(TaskItem task) {
  final raw = task.fecha.toLowerCase().trim();
  final now = DateTime.now();
  if (raw.contains('hoy')) return DateTime(now.year, now.month, now.day);
  if (raw.contains('mañana') || raw.contains('maã±ana')) {
    final tomorrow = now.add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
  }
  final iso = DateTime.tryParse(raw);
  if (iso != null) return DateTime(iso.year, iso.month, iso.day);
  final slash = RegExp(
    r'(\d{1,2})[\/\-](\d{1,2})(?:[\/\-](\d{2,4}))?',
  ).firstMatch(raw);
  if (slash != null) {
    final day = int.tryParse(slash.group(1)!) ?? now.day;
    final month = int.tryParse(slash.group(2)!) ?? now.month;
    final yearRaw = slash.group(3);
    final year = yearRaw == null
        ? now.year
        : int.parse(yearRaw.length == 2 ? '20$yearRaw' : yearRaw);
    return DateTime(year, month, day);
  }
  const weekdays = {
    'lunes': 1,
    'martes': 2,
    'miercoles': 3,
    'miércoles': 3,
    'jueves': 4,
    'viernes': 5,
    'sabado': 6,
    'sábado': 6,
    'domingo': 7,
  };
  for (final entry in weekdays.entries) {
    if (raw.contains(entry.key)) {
      var delta = entry.value - now.weekday;
      if (delta < 0) delta += 7;
      final date = now.add(Duration(days: delta));
      return DateTime(date.year, date.month, date.day);
    }
  }
  return DateTime(
    task.fechaCreacion.year,
    task.fechaCreacion.month,
    task.fechaCreacion.day,
  );
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int _taskMinutes(TaskItem task) {
  final cached = _taskMinutesCache[task];
  if (cached != null) return cached;
  final computed = _computeTaskMinutes(task);
  _taskMinutesCache[task] = computed;
  return computed;
}

int _computeTaskMinutes(TaskItem task) {
  if (task.hora == 'Sin hora') return 24 * 60;
  final match = RegExp(r'(\d{1,2}):?(\d{2})?').firstMatch(task.hora);
  if (match == null) return 24 * 60;
  final hour = int.tryParse(match.group(1) ?? '') ?? 23;
  final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
  return hour * 60 + minute;
}

TimeOfDay _timeOfDay(String value) {
  final parts = value.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts.first) ?? 8,
    minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
  );
}

String _monthName(int month) {
  const names = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  return names[month - 1];
}

String _shortDay(int weekday) {
  const names = ['LUN', 'MAR', 'MIE', 'JUE', 'VIE', 'SAB', 'DOM'];
  return names[weekday - 1];
}

List<BoxShadow> get _softShadow => AppShadow.md;
List<BoxShadow> get _activeShadow => AppShadow.brand(opacity: 0.32);

List<TaskItem> _sampleScanTasks() => [
  TaskItem(
    id: 'scan1',
    titulo: 'Leer capitulo 4 de Historia',
    materia: 'Historia',
    fecha: 'Viernes',
    hora: 'Sin hora',
    prioridad: 'media',
    tipo: 'lectura',
    completada: false,
    fechaCreacion: DateTime.now(),
    notas: 'Detectada desde ejemplo de escaner.',
  ),
  TaskItem(
    id: 'scan2',
    titulo: 'Preparar presentacion de Fisica',
    materia: 'Fisica',
    fecha: 'Mañana',
    hora: '15:00',
    prioridad: 'alta',
    tipo: 'proyecto',
    completada: false,
    fechaCreacion: DateTime.now(),
    notas: 'Urgente detectado.',
  ),
  TaskItem(
    id: 'scan3',
    titulo: 'Comprar materiales para maqueta',
    materia: 'Arte',
    fecha: 'Sin fecha',
    hora: 'Sin hora',
    prioridad: 'baja',
    tipo: 'otro',
    completada: false,
    fechaCreacion: DateTime.now(),
  ),
];

List<TaskItem> _sampleMatrixTasks() => [
  TaskItem(
    id: 'matrix1',
    titulo: 'Entregar ensayo de Historia',
    materia: 'Historia',
    fecha: 'Hoy, 23:59',
    hora: '23:59',
    prioridad: 'alta',
    tipo: 'tarea',
    completada: false,
    fechaCreacion: DateTime.now(),
  ),
  TaskItem(
    id: 'matrix2',
    titulo: 'Investigar proyecto final',
    materia: 'Metodologia',
    fecha: 'Proxima semana',
    hora: 'Sin hora',
    prioridad: 'media',
    tipo: 'proyecto',
    completada: false,
    fechaCreacion: DateTime.now(),
  ),
  TaskItem(
    id: 'matrix3',
    titulo: 'Ordenar escritorio digital',
    materia: 'Personal',
    fecha: 'Sin fecha',
    hora: 'Sin hora',
    prioridad: 'baja',
    tipo: 'otro',
    completada: false,
    fechaCreacion: DateTime.now(),
  ),
];

void _showPremiumModal(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceLowest,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.sm, AppSpacing.xxl, AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.indigo],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadow.brand(opacity: 0.30),
                ),
                child: const Icon(Icons.diamond_rounded, color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'ThinkLess Premium',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Desbloquea escaneos ilimitados, recordatorios inteligentes y estadísticas de estudio detalladas.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.onSurfaceVariant,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppCard(
              stripe: AppColors.mint,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Plan Anual',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.onSurface,
                            )),
                        const SizedBox(height: 4),
                        Text(
                          '\$29.99 USD / año',
                          style: GoogleFonts.inter(
                            color: AppColors.mint,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.mint.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '−50%',
                      style: GoogleFonts.inter(
                        color: AppColors.mint,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Plan Mensual',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.onSurface,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    '\$4.99 USD / mes',
                    style: GoogleFonts.inter(color: AppColors.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              label: 'Proceder al pago seguro',
              icon: Icons.lock_rounded,
              onTap: () {
                Navigator.pop(context);
                _toast(context, 'Simulando pago... ¡Gracias por actualizar!');
              },
            ),
          ],
        ),
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// Concentración Total — banner global + card de activación + sheet
// ═════════════════════════════════════════════════════════════════════════

/// Banner persistente que aparece en el tope de toda pantalla con shell
/// cuando Concentración Total está activa.
class FocusTotalBanner extends StatelessWidget {
  const FocusTotalBanner({
    required this.config,
    this.clock,
    required this.onTap,
    required this.onStop,
    super.key,
  });

  final FocusTotalConfig config;
  final ValueListenable<DateTime>? clock;
  final VoidCallback onTap;
  final VoidCallback onStop;

  String _formatRemaining(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = GoogleFonts.inter(
      fontSize: 11,
      color: AppColors.violetLight,
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.22),
                  AppColors.indigo.withValues(alpha: 0.16),
                  AppColors.primaryContainer,
                ],
              ),
              border: const Border(
                bottom: BorderSide(color: AppColors.outlineVariant, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                _PulsingDot(),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Concentración Total',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                          letterSpacing: -0.1,
                        ),
                      ),
                      if (config.unlimited || clock == null)
                        Text(
                          config.unlimited
                              ? 'Notificaciones en silencio'
                              : 'Restante · ${_formatRemaining(config.remaining ?? Duration.zero)}',
                          style: subtitleStyle,
                        )
                      else
                        ValueListenableBuilder<DateTime>(
                          valueListenable: clock!,
                          builder: (_, now, __) {
                            final remaining = config.remainingAt(now) ?? Duration.zero;
                            return Text(
                              'Restante · ${_formatRemaining(remaining)}',
                              style: subtitleStyle,
                            );
                          },
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onStop,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLowest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.outlineVariant, width: 0.6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stop_rounded, size: 13, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          'Salir',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
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

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _ctrl.value;
          return SizedBox(
            width: 22, height: 22,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 8 + (t * 14),
                  height: 8 + (t * 14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.violetLight.withValues(alpha: 0.35 * (1 - t)),
                  ),
                ),
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.violetLight,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.violetLight.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Card prominente en Home para activar/desactivar Concentración Total.
class FocusTotalCard extends StatelessWidget {
  const FocusTotalCard({
    required this.config,
    this.clock,
    required this.onActivate,
    required this.onDeactivate,
    super.key,
  });

  final FocusTotalConfig config;
  final ValueListenable<DateTime>? clock;
  final VoidCallback onActivate;
  final VoidCallback onDeactivate;

  String _label(Duration? remaining) {
    if (remaining == null) return 'Activo · sin límite';
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return 'Restante · $h:$m:$s';
    return 'Restante · $m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final active = config.active;
    final subtitleStyle = GoogleFonts.inter(
      fontSize: 12,
      color: active ? AppColors.violetLight : AppColors.onSurfaceVariant,
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: active ? onDeactivate : onActivate,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: AppMotion.base,
          curve: AppMotion.standard,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            gradient: active
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1B1546),
                      Color(0xFF231B4D),
                      Color(0xFF181B2A),
                    ],
                  )
                : null,
            color: active ? null : AppColors.surfaceContainer,
            border: Border.all(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : AppColors.outlineVariant,
              width: 0.8,
            ),
            boxShadow: active ? AppShadow.brand(opacity: 0.22) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.indigo],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: active ? AppShadow.brand(opacity: 0.4) : null,
                ),
                child: Icon(
                  active ? Icons.do_not_disturb_on_rounded : Icons.shield_moon_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Concentración Total',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (active)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.mint.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                color: AppColors.mint.withValues(alpha: 0.4),
                                width: 0.6,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5, height: 5,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.mint,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'ACTIVO',
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.mint,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (!active)
                      Text(
                        'Silencia notificaciones y reduce distracciones',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: subtitleStyle,
                      )
                    else if (config.unlimited || clock == null)
                      Text(
                        _label(config.remaining),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: subtitleStyle,
                      )
                    else
                      ValueListenableBuilder<DateTime>(
                        valueListenable: clock!,
                        builder: (_, now, __) {
                          return Text(
                            _label(config.remainingAt(now)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: subtitleStyle,
                          );
                        },
                      ),
                  ],
                ),
              ),
              Icon(
                active ? Icons.power_settings_new_rounded : Icons.chevron_right_rounded,
                color: active ? AppColors.error : AppColors.secondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sheet de activación con presets de duración.
Future<void> _showFocusTotalSheet(
  BuildContext context, {
  required ValueChanged<int> onActivate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceLowest,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl, AppSpacing.sm, AppSpacing.xxl, AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.indigo],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadow.brand(opacity: 0.32),
                ),
                child: const Icon(Icons.shield_moon_rounded, color: Colors.white, size: 26),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Concentración Total',
              textAlign: TextAlign.center,
              style: Theme.of(sheetCtx).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Silencia notificaciones, oculta alertas y mantiene un indicador discreto durante tu sesión.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'DURACIÓN',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.secondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _FocusTotalDurationGrid(onSelect: (minutes) {
              Navigator.pop(sheetCtx);
              onActivate(minutes);
            }),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.outlineVariant, width: 0.6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.violetLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Activará automáticamente Modo No Molestar. Puedes salir en cualquier momento.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: AppColors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FocusTotalDurationGrid extends StatelessWidget {
  const _FocusTotalDurationGrid({required this.onSelect});
  final ValueChanged<int> onSelect;

  static const _presets = <(String, String, int)>[
    ('25 min', 'Pomodoro', 25),
    ('45 min', 'Profundo', 45),
    ('1 h', 'Sesión', 60),
    ('2 h', 'Estudio largo', 120),
    ('4 h', 'Maratón', 240),
    ('∞', 'Sin límite', 0),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _presets.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm + 2,
        mainAxisSpacing: AppSpacing.sm + 2,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (_, i) {
        final (title, subtitle, minutes) = _presets[i];
        final unlimited = minutes == 0;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSelect(minutes),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: unlimited
                      ? AppColors.primary.withValues(alpha: 0.35)
                      : AppColors.outlineVariant,
                  width: 0.6,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: unlimited ? AppColors.violetLight : AppColors.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
