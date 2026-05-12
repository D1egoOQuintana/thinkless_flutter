import 'dart:async';
import 'dart:convert';

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
part 'features/assistant/data/groq_service.dart';

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
    setState(() {
      _tasks = _sortTasks(tasks);
      _alerts = alerts;
      _noMolestar = noMolestar;
      _view = seen ? AppView.home : AppView.onboarding;
      _loading = false;
    });
    if (seen && isNoMolestarActivo(noMolestar)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showFocusModal());
    }
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
    await showDialog<void>(
      context: ctx,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: AppColors.surfaceLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.surfaceContainer,
                child: Icon(Icons.school, color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                'Estás en horario de enfoque 📚',
                textAlign: TextAlign.center,
                style: Theme.of(
                  dialogContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Activamos modo silencioso para evitar distracciones',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Continuar en silencio',
                icon: Icons.notifications_off,
                onTap: () => Navigator.pop(dialogContext),
              ),
              const SizedBox(height: 10),
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
    final rank = {'alta': 0, 'media': 1, 'baja': 2};
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
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.manropeTextTheme().copyWith(
        titleLarge: GoogleFonts.workSans(),
        titleMedium: GoogleFonts.workSans(),
        titleSmall: GoogleFonts.workSans(),
        headlineMedium: GoogleFonts.workSans(),
        headlineSmall: GoogleFonts.workSans(),
        headlineLarge: GoogleFonts.workSans(),
        displayLarge: GoogleFonts.workSans(),
        displayMedium: GoogleFonts.workSans(),
        displaySmall: GoogleFonts.workSans(),
      ),
    );

    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'ThinkLess',
      theme: theme,
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _buildView(),
            ),
    );
  }

  Widget _buildView() {
    return switch (_view) {
      AppView.onboarding => OnboardingScreen(onStart: _startApp),
      AppView.home => ShellScreen(
        active: AppView.home,
        onNavigate: _navigate,
        onFab: _showAddSheet,
        child: HomeScreen(
          tasks: _tasks,
          onOpenTask: _openTask,
          onToggleTask: _toggleTask,
          onNavigate: _navigate,
        ),
      ),
      AppView.calendar => ShellScreen(
        active: AppView.calendar,
        onNavigate: _navigate,
        onFab: _showAddSheet,
        child: CalendarScreen(
          tasks: _tasks,
          onOpenTask: _openTask,
          onToggleTask: _toggleTask,
          noMolestar: _noMolestar,
        ),
      ),
      AppView.focus => ShellScreen(
        active: AppView.focus,
        onNavigate: _navigate,
        child: FocusScreen(noMolestar: _noMolestar),
      ),
      AppView.matrix => ShellScreen(
        active: AppView.matrix,
        onNavigate: _navigate,
        onFab: _showAddSheet,
        child: MatrixScreen(
          tasks: _tasks,
          onOpenTask: _openTask,
          onToggleTask: _toggleTask,
        ),
      ),
      AppView.alerts => ShellScreen(
        active: AppView.profile,
        onNavigate: _navigate,
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
      ),
    };
  }

  void _showAddSheet() {
    final ctx = _navigatorKey.currentContext;
    if (ctx == null) return;
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: AppColors.surfaceLowest,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Agregar tarea',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              _SheetAction(
                icon: Icons.mic,
                title: 'Voz con IA',
                subtitle: 'Habla y ThinkLess extrae la tarea.',
                onTap: () {
                  Navigator.pop(context);
                  _navigate(AppView.voice);
                },
              ),
              _SheetAction(
                icon: Icons.document_scanner,
                title: 'Escanear con IA',
                subtitle: 'Analiza una foto o captura de pantalla.',
                onTap: () {
                  Navigator.pop(context);
                  _navigate(AppView.scanner);
                },
              ),
              _SheetAction(
                icon: Icons.add_task,
                title: 'Tarea de ejemplo',
                subtitle: 'Crea una tarea rapida para probar la app.',
                onTap: () {
                  Navigator.pop(context);
                  _addTask(
                    TaskItem(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      titulo: 'Repasar apuntes de Calculo',
                      materia: 'Calculo',
                      fecha: 'Mañana',
                      hora: '16:00',
                      prioridad: 'media',
                      tipo: 'lectura',
                      completada: false,
                      fechaCreacion: DateTime.now(),
                      notas: 'Tarea creada manualmente como ejemplo.',
                    ),
                  );
                },
              ),
            ],
          ),
        ),
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
                          width: 192,
                          height: 192,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AppColors.mint, Color(0xFF6C33FF)],
                            ),
                            boxShadow: _activeShadow,
                          ),
                          child: const Icon(
                            Icons.psychology,
                            size: 92,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'ThinkLess',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Menos caos. Más hecho.',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppColors.secondary),
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
    super.key,
  });
  final Widget child;
  final AppView active;
  final ValueChanged<AppView> onNavigate;
  final VoidCallback? onFab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      floatingActionButton: onFab == null ? null : GradientFab(onTap: onFab!),
      bottomNavigationBar: NavigationBar(
        height: 68,
        backgroundColor: AppColors.surfaceLowest,
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
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Calendario',
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

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.tasks,
    required this.onOpenTask,
    required this.onToggleTask,
    required this.onNavigate,
    super.key,
  });

  final List<TaskItem> tasks;
  final ValueChanged<TaskItem> onOpenTask;
  final ValueChanged<String> onToggleTask;
  final ValueChanged<AppView> onNavigate;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'ThinkLess',
      leading: Icons.menu,
      trailing: Icons.more_vert,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
        children: [
          Text(
            '👋 Bienvenido',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          Text(
            'Tus tareas',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            EmptyStateCard(
              icon: Icons.add_task,
              title: 'No hay tareas todavía',
              body:
                  'Usa el botón + para agregar una tarea con voz o escanear tus apuntes.',
              actions: [
                EmptyAction(
                  label: 'Voz IA',
                  icon: Icons.mic,
                  onTap: () => onNavigate(AppView.voice),
                ),
                EmptyAction(
                  label: 'Escanear',
                  icon: Icons.document_scanner,
                  onTap: () => onNavigate(AppView.scanner),
                ),
              ],
            )
          else
            ...tasks.map(
              (task) => TaskCard(
                task: task,
                onTap: () => onOpenTask(task),
                onToggle: () => onToggleTask(task.id),
              ),
            ),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardHeader(title: 'Para comenzar', icon: Icons.expand_less),
                const SizedBox(height: 12),
                _StarterItem(
                  'Registra tu primera tarea con voz',
                  () => onNavigate(AppView.voice),
                ),
                _StarterItem(
                  'Activa los recordatorios inteligentes',
                  () => onNavigate(AppView.alerts),
                ),
                _StarterItem(
                  'Organiza con listas',
                  () => onNavigate(AppView.matrix),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              children: [
                _CardHeader(title: 'Funciones clave', icon: Icons.expand_more),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: MediaQuery.sizeOf(context).width > 520
                      ? 3
                      : 2,
                  childAspectRatio: 1,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    FeatureTile(
                      icon: Icons.calendar_month,
                      label: 'Calendario',
                      onTap: () => onNavigate(AppView.calendar),
                    ),
                    FeatureTile(
                      icon: Icons.grid_view,
                      label: 'Matriz Eisenhower',
                      onTap: () => onNavigate(AppView.matrix),
                    ),
                    FeatureTile(
                      icon: Icons.timer,
                      label: 'Pomodoro',
                      color: AppColors.errorContainer,
                      onTap: () => onNavigate(AppView.focus),
                    ),
                    FeatureTile(
                      icon: Icons.published_with_changes,
                      label: 'Hábitos',
                      onTap: () =>
                          _toast(context, 'Hábitos estará disponible pronto.'),
                    ),
                    FeatureTile(
                      icon: Icons.hourglass_bottom,
                      label: 'Cuenta regresiva',
                      color: const Color(0xFFFFDBD0),
                      onTap: () =>
                          _toast(context, 'Cuenta regresiva simulada.'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Explorar más',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _showPremiumModal(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF9B6FFF)],
                ),
                boxShadow: _activeShadow,
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.diamond, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Premium',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Desbloquea todo el potencial de ThinkLess.',
                          style: TextStyle(color: Color(0xFFE6DEFF)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.auto_awesome, color: Colors.white, size: 64),
                ],
              ),
            ),
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

class _VoiceScreenState extends State<VoiceScreen> {
  final SpeechToText _speech = SpeechToText();
  String _status = 'idle';
  String _transcript = '';
  String _error = '';
  TaskItem? _result;

  Future<void> _listen() async {
    setState(() {
      _status = 'listening';
      _error = '';
      _result = null;
      _transcript = '';
    });
    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' &&
            mounted &&
            _transcript.trim().isNotEmpty &&
            _status == 'listening') {
          _process();
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _status = 'error';
          _error =
              'No pude escuchar bien: ${error.errorMsg}. Usa Chrome o revisa permisos de microfono.';
        });
      },
    );
    if (!available) {
      setState(() {
        _status = 'error';
        _error =
            'Usa Chrome o un dispositivo con reconocimiento de voz disponible.';
      });
      return;
    }
    await _speech.listen(
      localeId: 'es_419',
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.confirmation,
      ),
      onResult: (SpeechRecognitionResult result) {
        setState(() => _transcript = result.recognizedWords);
        if (result.finalResult) _process();
      },
    );
  }

  Future<void> _process() async {
    if (_status == 'processing') return;
    await _speech.stop();
    final text = _transcript.trim();
    if (text.isEmpty) {
      setState(() {
        _status = 'error';
        _error =
            'No detecte texto. Intenta hablar un poco mas cerca del microfono.';
      });
      return;
    }
    setState(() => _status = 'processing');
    try {
      final task = await GroqService.extractTaskFromText(text);
      if (!mounted) return;
      setState(() {
        _status = 'result';
        _result = task;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = 'error';
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final listening = _status == 'listening';
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
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: listening ? 172 : 144,
                          height: listening ? 172 : 144,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: listening
                                  ? AppColors.mint
                                  : AppColors.surfaceHighest,
                              width: listening ? 4 : 1,
                            ),
                            boxShadow: listening ? _activeShadow : _softShadow,
                          ),
                          child: Icon(
                            listening ? Icons.graphic_eq : Icons.mic,
                            size: 58,
                            color: listening
                                ? AppColors.mint
                                : AppColors.primaryContainer,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          '🎉 Voz e IA activados',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (isNoMolestarActivo(widget.noMolestar)) ...[
                          const SizedBox(height: 8),
                          const Chip(
                            avatar: Icon(Icons.notifications_off, size: 16),
                            label: Text('IA en modo silencioso'),
                            backgroundColor: AppColors.surfaceContainer,
                          ),
                        ],
                        const SizedBox(height: 18),
                        if (_status == 'idle') _VoiceTips(),
                        if (listening)
                          _StatusCard(
                            icon: Icons.mic,
                            title: 'Escuchando...',
                            body: _transcript.isEmpty
                                ? 'Di tu tarea completa con fecha, materia y prioridad.'
                                : _transcript,
                          ),
                        if (_status == 'processing')
                          const _StatusCard(
                            icon: Icons.auto_awesome,
                            title: 'Procesando con IA...',
                            body: 'Groq esta estructurando tu tarea.',
                          ),
                        if (_status == 'error')
                          _StatusCard(
                            icon: Icons.error_outline,
                            title: 'Error',
                            body: _error,
                            danger: true,
                          ),
                        if (_status == 'result' && _result != null)
                          TaskPreview(
                            task: _result!,
                            onAdd: () => widget.onAdd(_result!),
                          ),
                      ],
                    ),
                  ),
                  PrimaryButton(
                    label: switch (_status) {
                      'listening' => 'Procesar ahora',
                      'processing' => 'Procesando...',
                      'result' => 'Hablar otra vez',
                      _ => 'Probar ahora',
                    },
                    icon: switch (_status) {
                      'listening' => Icons.check,
                      'processing' => Icons.hourglass_top,
                      _ => Icons.play_arrow,
                    },
                    onTap: _status == 'processing'
                        ? null
                        : (_status == 'listening' ? _process : _listen),
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
                            color: AppColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.outlineVariant),
                            boxShadow: _softShadow,
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
                                  color: Colors.white70,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              Positioned(
                                left: 20,
                                right: 20,
                                bottom: 20,
                                child: Chip(
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.88,
                                  ),
                                  label: const Text(
                                    'Apunta a tu cuaderno o captura de pantalla',
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

enum CalendarMode { month, week, day }

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
  CalendarMode _mode = CalendarMode.month;
  DateTime _focusedDay = DateTime.now();

  List<TaskItem> get tasks => widget.tasks;
  ValueChanged<TaskItem> get onOpenTask => widget.onOpenTask;
  ValueChanged<String> get onToggleTask => widget.onToggleTask;
  VoidCallback get onFab => () {};

  List<TaskItem> get _dayTasks => _tasksForDay(_focusedDay);

  List<TaskItem> _tasksForDay(DateTime day) {
    final filtered = widget.tasks
        .where((task) => _sameDay(_taskDate(task), day))
        .toList();
    filtered.sort((a, b) => _taskMinutes(a).compareTo(_taskMinutes(b)));
    return filtered;
  }

  Widget _buildAdvancedCalendar(BuildContext context) {
    final silent = isNoMolestarActivo(widget.noMolestar);
    return AppScaffold(
      title: '${_monthName(_focusedDay.month)} / Hoy',
      leading: Icons.menu,
      trailing: Icons.more_vert,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<CalendarMode>(
                        segments: const [
                          ButtonSegment(
                            value: CalendarMode.month,
                            label: Text('Mes'),
                          ),
                          ButtonSegment(
                            value: CalendarMode.week,
                            label: Text('Semana'),
                          ),
                          ButtonSegment(
                            value: CalendarMode.day,
                            label: Text('Día'),
                          ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (value) =>
                            setState(() => _mode = value.first),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () =>
                          setState(() => _focusedDay = DateTime.now()),
                      child: const Text('Hoy'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '${_dayTasks.length} tareas hoy',
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (silent)
                      const Chip(
                        avatar: Icon(Icons.notifications_off, size: 16),
                        label: Text('Silencio'),
                        backgroundColor: AppColors.surfaceContainer,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: switch (_mode) {
                CalendarMode.month => _MonthCalendar(
                  key: const ValueKey('month'),
                  focusedDay: _focusedDay,
                  tasks: widget.tasks,
                  onDaySelected: (day) => setState(() {
                    _focusedDay = day;
                    _mode = CalendarMode.day;
                  }),
                ),
                CalendarMode.week => _WeekCalendar(
                  key: const ValueKey('week'),
                  focusedDay: _focusedDay,
                  tasks: widget.tasks,
                  onTaskTap: widget.onOpenTask,
                ),
                CalendarMode.day => _DayCalendar(
                  key: const ValueKey('day'),
                  day: _focusedDay,
                  tasks: _dayTasks,
                  onTaskTap: widget.onOpenTask,
                  onToggleTask: widget.onToggleTask,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (DateTime.now().microsecondsSinceEpoch >= 0) {
      return _buildAdvancedCalendar(context);
    }
    final visible = tasks.isEmpty ? _sampleAgendaTasks() : tasks;
    return AppScaffold(
      title: 'Mayo / Hoy',
      leading: Icons.menu,
      trailing: Icons.more_vert,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: [
          AppCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                DayPill('LUN', '2'),
                DayPill('MAR', '3'),
                DayPill('MIE', '4'),
                DayPill('JUE', '5', active: true),
                DayPill('VIE', '6'),
                DayPill('SAB', '7'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Agenda del Día',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ...visible.map(
            (task) => TaskCard(
              task: task,
              onTap: () => onOpenTask(task),
              onToggle: () => onToggleTask(task.id),
              compact: true,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: AppColors.surfaceContainer,
              gradient: const LinearGradient(
                colors: [AppColors.surfaceContainer, Color(0xFFE6DEFF)],
              ),
              boxShadow: _softShadow,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Mantén el Ritmo',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${visible.where((task) => !task.completada).length} tareas pendientes hoy',
                    style: const TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: GradientFab(onTap: onFab),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.focusedDay,
    required this.tasks,
    required this.onDaySelected,
    super.key,
  });

  final DateTime focusedDay;
  final List<TaskItem> tasks;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(focusedDay.year, focusedDay.month);
    final startOffset = first.weekday - 1;
    final start = first.subtract(Duration(days: startOffset));
    final days = List.generate(42, (index) => start.add(Duration(days: index)));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      children: [
        AppCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['LUN', 'MAR', 'MIE', 'JUE', 'VIE', 'SAB', 'DOM']
                    .map(
                      (day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                itemCount: days.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemBuilder: (context, index) {
                  final day = days[index];
                  final dayTasks = tasks
                      .where((task) => _sameDay(_taskDate(task), day))
                      .toList();
                  final isToday = _sameDay(day, DateTime.now());
                  final inMonth = day.month == focusedDay.month;
                  return InkWell(
                    onTap: () => onDaySelected(day),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isToday
                            ? AppColors.primaryContainer
                            : (inMonth
                                  ? AppColors.surfaceLowest
                                  : AppColors.surfaceContainer),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.outlineVariant.withValues(
                            alpha: 0.45,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              color: isToday
                                  ? Colors.white
                                  : (inMonth
                                        ? AppColors.onSurface
                                        : AppColors.secondary),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (dayTasks.isNotEmpty)
                            Wrap(
                              spacing: 2,
                              children: dayTasks
                                  .take(3)
                                  .map(
                                    (task) => CircleAvatar(
                                      radius: 3,
                                      backgroundColor: priorityColor(
                                        task.prioridad,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekCalendar extends StatelessWidget {
  const _WeekCalendar({
    required this.focusedDay,
    required this.tasks,
    required this.onTaskTap,
    super.key,
  });

  final DateTime focusedDay;
  final List<TaskItem> tasks;
  final ValueChanged<TaskItem> onTaskTap;

  @override
  Widget build(BuildContext context) {
    final monday = focusedDay.subtract(Duration(days: focusedDay.weekday - 1));
    final days = List.generate(7, (index) => monday.add(Duration(days: index)));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 860,
          child: AppCard(
            child: Column(
              children: [
                Row(
                  children: days
                      .map(
                        (day) => Expanded(
                          child: Center(
                            child: Text(
                              '${_shortDay(day.weekday)} ${day.day}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _sameDay(day, DateTime.now())
                                    ? AppColors.primary
                                    : AppColors.secondary,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                ...List.generate(15, (hourIndex) {
                  final hour = 8 + hourIndex;
                  return SizedBox(
                    height: 64,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(
                            '${hour.toString().padLeft(2, '0')}:00',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                        ...days.map((day) {
                          final blocks = tasks
                              .where(
                                (task) =>
                                    _sameDay(_taskDate(task), day) &&
                                    _taskHour(task) == hour,
                              )
                              .toList();
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.outlineVariant.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: blocks
                                    .map(
                                      (task) => _CalendarBlock(
                                        task: task,
                                        onTap: () => onTaskTap(task),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayCalendar extends StatelessWidget {
  const _DayCalendar({
    required this.day,
    required this.tasks,
    required this.onTaskTap,
    required this.onToggleTask,
    super.key,
  });

  final DateTime day;
  final List<TaskItem> tasks;
  final ValueChanged<TaskItem> onTaskTap;
  final ValueChanged<String> onToggleTask;

  @override
  Widget build(BuildContext context) {
    final timed = tasks.where((task) => task.hora != 'Sin hora').toList();
    final untimed = tasks.where((task) => task.hora == 'Sin hora').toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      children: [
        Text(
          'Agenda del Día',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (tasks.isEmpty)
          const EmptyStateCard(
            icon: Icons.event_available,
            title: 'No hay tareas este día',
            body:
                'Cuando agregues tareas con fecha, aparecerán aquí automáticamente.',
          )
        else ...[
          ...List.generate(15, (hourIndex) {
            final hour = 8 + hourIndex;
            final hourTasks = timed
                .where((task) => _taskHour(task) == hour)
                .toList();
            return _TimelineHour(
              hour: hour,
              tasks: hourTasks,
              onTaskTap: onTaskTap,
              onToggleTask: onToggleTask,
            );
          }),
          if (untimed.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'Sin horario',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 8),
            ...untimed.map(
              (task) => TaskCard(
                task: task,
                onTap: () => onTaskTap(task),
                onToggle: () => onToggleTask(task.id),
                compact: true,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _TimelineHour extends StatelessWidget {
  const _TimelineHour({
    required this.hour,
    required this.tasks,
    required this.onTaskTap,
    required this.onToggleTask,
  });
  final int hour;
  final List<TaskItem> tasks;
  final ValueChanged<TaskItem> onTaskTap;
  final ValueChanged<String> onToggleTask;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            '${hour.toString().padLeft(2, '0')}:00',
            style: const TextStyle(color: AppColors.secondary, fontSize: 12),
          ),
        ),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.outlineVariant)),
            ),
            child: Column(
              children: tasks
                  .map(
                    (task) => TaskCard(
                      task: task,
                      onTap: () => onTaskTap(task),
                      onToggle: () => onToggleTask(task.id),
                      compact: true,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _CalendarBlock extends StatelessWidget {
  const _CalendarBlock({required this.task, required this.onTap});
  final TaskItem task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: priorityColor(task.prioridad).withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: priorityColor(task.prioridad), width: 3),
          ),
        ),
        child: Text(
          task.titulo,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class FocusScreen extends StatefulWidget {
  const FocusScreen({required this.noMolestar, super.key});
  final NoMolestarConfig noMolestar;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  static const total = 25 * 60;
  Timer? _timer;
  int _seconds = total;
  bool _running = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds <= 1) {
        timer.cancel();
        if (!isNoMolestarActivo(widget.noMolestar)) {
          SystemSound.play(SystemSoundType.alert);
        }
        setState(() {
          _seconds = 0;
          _running = false;
        });
        _smartNotice(
          context,
          'Pomodoro completado. Buen bloque de enfoque.',
          config: widget.noMolestar,
          urgent: true,
        );
        return;
      }
      setState(() => _seconds--);
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _seconds = total;
      _running = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = 1 - (_seconds / total);
    final minutes = (_seconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_seconds % 60).toString().padLeft(2, '0');
    return AppScaffold(
      title: 'Enfoque ›',
      leading: Icons.menu,
      trailing: Icons.more_vert,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 120),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 5,
                      backgroundColor: AppColors.surfaceHigh,
                      color: AppColors.primary,
                    ),
                    Container(
                      width: 238,
                      height: 238,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceLowest,
                        boxShadow: _softShadow,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$minutes:$seconds',
                          style: const TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'SESIÓN 1 DE 4',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Positioned(
                      right: 0,
                      top: 10,
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.surfaceContainer,
                        child: Icon(
                          Icons.auto_awesome,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 64),
              SizedBox(
                width: 280,
                child: PrimaryButton(
                  label: _running ? 'Pausar' : 'Iniciar',
                  icon: _running ? Icons.pause : Icons.play_arrow,
                  onTap: _toggle,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.skip_next),
                label: const Text('Saltar'),
              ),
            ],
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
    return AppScaffold(
      title: 'Matriz Eisenhower',
      leading: Icons.menu,
      trailing: Icons.more_vert,
      body: GridView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.sizeOf(context).width > 720 ? 2 : 1,
          mainAxisExtent: 300,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
        ),
        children: [
          Quadrant(
            title: 'Hacer Ya',
            subtitle: 'Urgente & Importante',
            color: AppColors.pink,
            tasks: source.where((task) => task.prioridad == 'alta').toList(),
            onOpenTask: onOpenTask,
            onToggleTask: onToggleTask,
          ),
          Quadrant(
            title: 'Agendar',
            subtitle: 'Importante, No Urgente',
            color: AppColors.yellow,
            tasks: source.where((task) => task.prioridad == 'media').toList(),
            onOpenTask: onOpenTask,
            onToggleTask: onToggleTask,
          ),
          Quadrant(
            title: 'Delegar',
            subtitle: 'Urgente, No Importante',
            color: AppColors.blue,
            tasks: const [],
            onOpenTask: onOpenTask,
            onToggleTask: onToggleTask,
          ),
          Quadrant(
            title: 'Eliminar',
            subtitle: 'Ni Urgente, Ni Importante',
            color: AppColors.mint,
            tasks: source.where((task) => task.prioridad == 'baja').toList(),
            onOpenTask: onOpenTask,
            onToggleTask: onToggleTask,
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
    super.key,
  });
  final TaskItem? task;
  final VoidCallback onBack;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onDelete;

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
          leading: Icons.arrow_back,
          trailing: Icons.more_vert,
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
              InfoChip(icon: Icons.calendar_today, text: item.fecha),
              InfoChip(
                icon: Icons.timer,
                text: item.hora == 'Sin hora' ? '3h estimadas' : item.hora,
              ),
              InfoChip(icon: Icons.school, text: item.materia),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF0EBFF),
              border: Border(
                left: BorderSide(color: AppColors.primary, width: 4),
              ),
              borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryContainer,
                  child: Icon(Icons.lightbulb, color: Colors.white),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sugerencia IA',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text('💡 Hazlo en tu bloque libre de las 2pm'),
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
                  onPressed: () => _toast(context, 'Edicion simulada.'),
                  icon: const Icon(Icons.edit),
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
          padding: const EdgeInsets.all(20),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.mint,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () => onToggle(item.id),
            icon: Icon(item.completada ? Icons.undo : Icons.check),
            label: Text(
              item.completada
                  ? 'Marcar como pendiente'
                  : 'Marcar como completada',
              style: const TextStyle(fontWeight: FontWeight.w800),
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
      leading: Icons.menu,
      trailing: Icons.more_vert,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
        children: [
          Row(
            children: [
              const Icon(Icons.campaign, color: AppColors.primary, size: 32),
              const SizedBox(width: 10),
              Text(
                'Alertas inteligentes',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          NoMolestarCard(
            config: noMolestar,
            activeNow: silentNow,
            onChanged: onSaveNoMolestar,
          ),
          const SizedBox(height: 16),
          AppCard(
            stripe: AppColors.mint,
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.surfaceHigh,
                  child: Icon(Icons.science, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        urgent == null
                            ? 'Tienes 45 min libres.'
                            : 'Tienes 45 min libres.',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        urgent == null
                            ? '¿Empezamos con Física?'
                            : '¿Empezamos con ${urgent.titulo}?',
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => _toast(
                    context,
                    urgent == null
                        ? 'No hay tareas pendientes.'
                        : urgent.titulo,
                  ),
                  child: const Text('Ver tarea'),
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
      title: 'ThinkLess',
      leading: Icons.menu,
      trailing: Icons.more_vert,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
        children: [
          Column(
            children: [
              Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.primaryContainer, AppColors.mint],
                  ),
                ),
                child: const CircleAvatar(
                  backgroundColor: AppColors.surface,
                  child: Icon(Icons.person, size: 52, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Alex',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'alex.student@academia.edu',
                style: TextStyle(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SettingTile(
                icon: Icons.notifications,
                title: 'Notificaciones',
                subtitle: 'Activas',
                onTap: () => onNavigate(AppView.alerts),
              ),
              SettingTile(
                icon: Icons.palette,
                title: 'Apariencia',
                subtitle: 'Modo Claro',
                onTap: () => _toast(context, 'Apariencia simulada.'),
              ),
              SettingTile(
                icon: Icons.language,
                title: 'Idioma',
                subtitle: 'Español',
                onTap: () => _toast(context, 'Idioma configurado en español.'),
              ),
              SettingTile(
                icon: Icons.workspace_premium,
                title: 'Premium',
                subtitle: 'Gestionar suscripcion',
                premium: true,
                onTap: () => _showPremiumModal(context),
              ),
              SettingTile(
                icon: Icons.help_outline,
                title: 'Ayuda y Soporte',
                subtitle: 'Preguntas frecuentes y contacto',
                wide: true,
                onTap: () => _toast(context, 'Soporte simulado.'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Center(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.errorContainer,
                foregroundColor: AppColors.onErrorContainer,
              ),
              onPressed: () => _toast(context, 'Sesion cerrada simulada.'),
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesion'),
            ),
          ),
        ],
      ),
    );
  }
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
    super.key,
  });
  final String title;
  final IconData? leading;
  final IconData? trailing;
  final VoidCallback? onLeading;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 64,
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            IconButton(
              onPressed: onLeading ?? () {},
              icon: Icon(
                leading ?? Icons.menu,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: Icon(
                trailing ?? Icons.more_vert,
                color: trailing == null
                    ? Colors.transparent
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({required this.child, this.stripe, super.key});
  final Widget child;
  final Color? stripe;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: _softShadow,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: stripe != null
              ? Border(left: BorderSide(color: stripe!, width: 4))
              : null,
        ),
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final color = priorityColor(task.prioridad);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: task.completada ? 0.62 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AppCard(
            stripe: color,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onToggle,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: task.completada
                          ? AppColors.mint
                          : Colors.transparent,
                      border: Border.all(
                        color: task.completada
                            ? AppColors.mint
                            : AppColors.primary,
                        width: 2,
                      ),
                    ),
                    child: task.completada
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.titulo,
                        style: TextStyle(
                          fontSize: compact ? 15 : 16,
                          fontWeight: FontWeight.w700,
                          decoration: task.completada
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          _Meta(icon: Icons.school, text: task.materia),
                          _Meta(icon: Icons.calendar_today, text: task.fecha),
                          if (task.hora != 'Sin hora')
                            _Meta(icon: Icons.schedule, text: task.hora),
                        ],
                      ),
                    ],
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
    return AppCard(
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.surfaceContainer,
            child: Icon(icon, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.onSurfaceVariant),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: actions
                  .map(
                    (action) => FilledButton.icon(
                      onPressed: action.onTap,
                      icon: Icon(action.icon, size: 18),
                      label: Text(action.label),
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

class PrimaryButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimary,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        elevation: 0,
      ),
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    );
  }
}

class GradientFab extends StatelessWidget {
  const GradientFab({required this.onTap, super.key});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF6C33FF), Color(0xFF9B6FFF)],
          ),
          boxShadow: _activeShadow,
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
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
    super.key,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _softShadow,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color,
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
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
    super.key,
  });
  final String title;
  final String subtitle;
  final Color color;
  final List<TaskItem> tasks;
  final ValueChanged<TaskItem> onOpenTask;
  final ValueChanged<String> onToggleTask;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 6, backgroundColor: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  subtitle,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Expanded(
            child: tasks.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox, color: AppColors.secondary, size: 42),
                        SizedBox(height: 8),
                        Text(
                          'Sin tareas',
                          style: TextStyle(color: AppColors.secondary),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    children: tasks
                        .map(
                          (task) => InkWell(
                            onTap: () => onOpenTask(task),
                            borderRadius: BorderRadius.circular(12),
                            child: CheckboxListTile(
                              dense: true,
                              value: task.completada,
                              onChanged: (_) => onToggleTask(task.id),
                              title: Text(
                                task.titulo,
                                style: TextStyle(
                                  decoration: task.completada
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              subtitle: Text(task.fecha),
                              activeColor: AppColors.mint,
                            ),
                          ),
                        )
                        .toList(),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tarea extraida',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            task.titulo,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          Text(
            '${task.materia} • ${task.fecha} • ${task.hora}',
            style: const TextStyle(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Agregar tarea ✓',
            icon: Icons.check,
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
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
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.surfaceContainer,
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
  });
  final IconData icon;
  final String title;
  final String body;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: danger ? AppColors.error : AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    color: danger
                        ? AppColors.error
                        : AppColors.onSurfaceVariant,
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

class _StarterItem extends StatelessWidget {
  const _StarterItem(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 2),
        ),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        Icon(icon, color: AppColors.onSurfaceVariant),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.secondary),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(color: AppColors.secondary, fontSize: 12),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        priority == 'alta' ? 'Urgente' : priority.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
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
    return Chip(
      avatar: Icon(icon, size: 18, color: AppColors.primary),
      label: Text(text),
      backgroundColor: AppColors.surfaceLowest,
      side: const BorderSide(color: AppColors.outlineVariant),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primaryContainer,
          secondary: CircleAvatar(
            backgroundColor: AppColors.surfaceContainer,
            child: Icon(icon, color: AppColors.primary),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(subtitle),
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
              CircleAvatar(
                backgroundColor: config.activo
                    ? AppColors.primaryContainer
                    : AppColors.surfaceContainer,
                child: Icon(
                  config.activo ? Icons.notifications_off : Icons.nights_stay,
                  color: config.activo ? Colors.white : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Modo No molestar',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      activeNow
                          ? 'Activo ahora: alertas en silencio'
                          : 'Sin interrupciones en clases o trabajo',
                      style: const TextStyle(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Switch(
                value: config.activo,
                activeThumbColor: AppColors.primaryContainer,
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
    return SizedBox(
      width: wide || width < 620 ? double.infinity : (width - 56) / 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AppCard(
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: premium
                    ? AppColors.primaryContainer
                    : AppColors.surfaceContainer,
                child: Icon(
                  icon,
                  color: premium ? Colors.white : AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppColors.secondary),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.onSurfaceVariant,
              ),
            ],
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
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: large ? 78 : 64,
        height: large ? 78 : 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? AppColors.primaryContainer : AppColors.surfaceHighest,
          border: Border.all(
            color: filled
                ? AppColors.primaryContainer
                : AppColors.outlineVariant,
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          color: filled ? Colors.white : AppColors.primary,
          size: large ? 32 : 26,
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
          colors: [Color(0xFFF7F2FA), Color(0xFFE6DEFF)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.description, color: AppColors.primary, size: 92),
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
      ..color = const Color(0xFF6C33FF)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 40.0;
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
    return Container(
      width: active ? 32 : 8,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.primaryContainer : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

Color priorityColor(String priority) {
  return switch (priority) {
    'alta' => AppColors.pink,
    'baja' => AppColors.mint,
    _ => AppColors.primary,
  };
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

void _smartNotice(
  BuildContext context,
  String message, {
  required NoMolestarConfig config,
  bool urgent = false,
}) {
  final silent = isNoMolestarActivo(config);
  if (silent && !urgent) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(silent ? 'Silencioso: $message' : message),
      behavior: SnackBarBehavior.floating,
      showCloseIcon: true,
    ),
  );
}

DateTime _taskDate(TaskItem task) {
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

int _taskHour(TaskItem task) => _taskMinutes(task) ~/ 60;

int _taskMinutes(TaskItem task) {
  final match = RegExp(r'(\d{1,2}):?(\d{2})?').firstMatch(task.hora);
  if (match == null || task.hora == 'Sin hora') return 24 * 60;
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

List<BoxShadow> get _softShadow => [
  BoxShadow(
    color: const Color(0xFF6C33FF).withValues(alpha: 0.06),
    blurRadius: 18,
    offset: const Offset(0, 4),
  ),
];
List<BoxShadow> get _activeShadow => [
  BoxShadow(
    color: const Color(0xFF6C33FF).withValues(alpha: 0.16),
    blurRadius: 24,
    offset: const Offset(0, 8),
  ),
];

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

List<TaskItem> _sampleAgendaTasks() => [
  TaskItem(
    id: 'agenda1',
    titulo: 'Entrega Ensayo Historia',
    materia: 'Historia',
    fecha: 'Hoy',
    hora: '10:00',
    prioridad: 'alta',
    tipo: 'tarea',
    completada: false,
    fechaCreacion: DateTime.now(),
  ),
  TaskItem(
    id: 'agenda2',
    titulo: 'Lectura Cap 4-5 Biologia',
    materia: 'Biologia',
    fecha: 'Hoy',
    hora: '14:00',
    prioridad: 'media',
    tipo: 'lectura',
    completada: false,
    fechaCreacion: DateTime.now(),
  ),
  TaskItem(
    id: 'agenda3',
    titulo: 'Reunion Grupo Proyecto',
    materia: 'Proyecto',
    fecha: 'Hoy',
    hora: '08:30',
    prioridad: 'baja',
    tipo: 'proyecto',
    completada: true,
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
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.diamond, size: 56, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              'ThinkLess Premium',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Desbloquea escaneos ilimitados, recordatorios inteligentes y estadísticas de estudio detalladas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            AppCard(
              stripe: AppColors.mint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Plan Anual',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '\$29.99 USD / año (Ahorra un 50%)',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Plan Mensual',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '\$4.99 USD / mes',
                    style: TextStyle(color: AppColors.secondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                _toast(context, 'Simulando pago... ¡Gracias por actualizar!');
              },
              icon: const Icon(Icons.payment),
              label: const Text(
                'Proceder al pago seguro',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
