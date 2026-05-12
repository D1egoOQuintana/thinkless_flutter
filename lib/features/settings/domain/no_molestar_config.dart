part of '../../../main.dart';

class NoMolestarConfig {
  const NoMolestarConfig({
    required this.activo,
    required this.horaInicio,
    required this.horaFin,
    required this.dias,
  });

  final bool activo;
  final String horaInicio;
  final String horaFin;
  final List<String> dias;

  factory NoMolestarConfig.defaults() => const NoMolestarConfig(
    activo: false,
    horaInicio: '08:00',
    horaFin: '13:00',
    dias: ['LUN', 'MAR', 'MIE', 'JUE', 'VIE'],
  );

  factory NoMolestarConfig.fromJson(Map<String, dynamic> json) {
    return NoMolestarConfig(
      activo: json['activo'] == true,
      horaInicio: json['horaInicio']?.toString() ?? '08:00',
      horaFin: json['horaFin']?.toString() ?? '13:00',
      dias:
          (json['dias'] as List<dynamic>? ??
                  ['LUN', 'MAR', 'MIE', 'JUE', 'VIE'])
              .map((day) => day.toString())
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'activo': activo,
    'horaInicio': horaInicio,
    'horaFin': horaFin,
    'dias': dias,
  };

  NoMolestarConfig copyWith({
    bool? activo,
    String? horaInicio,
    String? horaFin,
    List<String>? dias,
  }) {
    return NoMolestarConfig(
      activo: activo ?? this.activo,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFin: horaFin ?? this.horaFin,
      dias: dias ?? this.dias,
    );
  }
}

bool isNoMolestarActivo(NoMolestarConfig config, [DateTime? moment]) {
  if (!config.activo) return false;
  final now = moment ?? DateTime.now();
  const dayCodes = ['LUN', 'MAR', 'MIE', 'JUE', 'VIE', 'SAB', 'DOM'];
  final today = dayCodes[now.weekday - 1];
  if (!config.dias.contains(today)) return false;
  final currentMinutes = now.hour * 60 + now.minute;
  final start = _minutesFromClock(config.horaInicio);
  final end = _minutesFromClock(config.horaFin);
  if (start <= end) {
    return currentMinutes >= start && currentMinutes <= end;
  }
  return currentMinutes >= start || currentMinutes <= end;
}

int _minutesFromClock(String value) {
  final parts = value.split(':');
  final hour = int.tryParse(parts.first) ?? 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return hour * 60 + minute;
}
