part of '../../../main.dart';

class TaskStore {
  static const _tasksKey = 'tareas';
  static const _legacyTasksKey = 'thinkless_tasks';
  static const _seenKey = 'thinkless_seen_onboarding';
  static const _alertsKey = 'thinkless_alerts';
  static const _dndKey = 'modo_no_molestar_config';

  static Future<List<TaskItem>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tasksKey) ?? prefs.getString(_legacyTasksKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    final tasks = decoded
        .map(
          (item) => TaskItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    await saveTasks(tasks);
    return tasks;
  }

  static Future<void> saveTasks(List<TaskItem> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _tasksKey,
      jsonEncode(tasks.map((task) => task.toJson()).toList()),
    );
  }

  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  static Future<void> setSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }

  static Future<Map<String, dynamic>> loadAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_alertsKey);
    if (raw == null) {
      return {
        'urgent': true,
        'daily': true,
        'breaks': false,
        'intensity': 'Insistente',
      };
    }
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  static Future<void> saveAlerts(Map<String, dynamic> state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_alertsKey, jsonEncode(state));
  }

  static Future<NoMolestarConfig> loadNoMolestar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dndKey);
    if (raw == null || raw.isEmpty) return NoMolestarConfig.defaults();
    return NoMolestarConfig.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw)),
    );
  }

  static Future<void> saveNoMolestar(NoMolestarConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dndKey, jsonEncode(config.toJson()));
  }
}
