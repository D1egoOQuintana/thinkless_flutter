part of '../../../main.dart';

/// Estado persistente del modo "Concentración Total".
///
/// Cuando [active] es true, la app:
/// - Muestra un banner global con countdown
/// - Silencia [_smartNotice]/[_toast] (excepto urgentes)
/// - Fuerza Modo No Molestar visualmente
///
/// [durationMinutes] = 0 significa sin límite (hasta apagado manual).
class FocusTotalConfig {
  const FocusTotalConfig({
    required this.active,
    required this.durationMinutes,
    this.startedAt,
  });

  factory FocusTotalConfig.idle() =>
      const FocusTotalConfig(active: false, durationMinutes: 60);

  final bool active;
  final int durationMinutes;
  final DateTime? startedAt;

  bool get unlimited => durationMinutes <= 0;

  Duration? get remaining {
    return remainingAt(DateTime.now());
  }

  Duration? remainingAt(DateTime now) {
    if (!active || startedAt == null || unlimited) return null;
    final end = startedAt!.add(Duration(minutes: durationMinutes));
    final left = end.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  bool get expired {
    return expiredAt(DateTime.now());
  }

  bool expiredAt(DateTime now) {
    final r = remainingAt(now);
    return r != null && r.inSeconds <= 0;
  }

  FocusTotalConfig copyWith({
    bool? active,
    int? durationMinutes,
    DateTime? startedAt,
    bool clearStartedAt = false,
  }) {
    return FocusTotalConfig(
      active: active ?? this.active,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'active': active,
    'durationMinutes': durationMinutes,
    'startedAt': startedAt?.toIso8601String(),
  };

  factory FocusTotalConfig.fromJson(Map<String, dynamic> json) {
    return FocusTotalConfig(
      active: json['active'] == true,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 60,
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? ''),
    );
  }
}
