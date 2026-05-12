part of '../../../main.dart';

class TaskItem {
  TaskItem({
    required this.id,
    required this.titulo,
    required this.materia,
    required this.fecha,
    required this.hora,
    required this.prioridad,
    required this.tipo,
    required this.completada,
    required this.fechaCreacion,
    this.notas = '',
  });

  final String id;
  final String titulo;
  final String materia;
  final String fecha;
  final String hora;
  final String prioridad;
  final String tipo;
  final bool completada;
  final DateTime fechaCreacion;
  final String notas;

  TaskItem copyWith({
    String? id,
    String? titulo,
    String? materia,
    String? fecha,
    String? hora,
    String? prioridad,
    String? tipo,
    bool? completada,
    DateTime? fechaCreacion,
    String? notas,
  }) {
    return TaskItem(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      materia: materia ?? this.materia,
      fecha: fecha ?? this.fecha,
      hora: hora ?? this.hora,
      prioridad: prioridad ?? this.prioridad,
      tipo: tipo ?? this.tipo,
      completada: completada ?? this.completada,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      notas: notas ?? this.notas,
    );
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id:
          json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      titulo: json['titulo']?.toString().trim().isNotEmpty == true
          ? json['titulo'].toString()
          : 'Tarea sin titulo',
      materia: json['materia']?.toString().trim().isNotEmpty == true
          ? json['materia'].toString()
          : 'General',
      fecha: json['fecha']?.toString().trim().isNotEmpty == true
          ? json['fecha'].toString()
          : 'Sin fecha',
      hora: json['hora']?.toString().trim().isNotEmpty == true
          ? json['hora'].toString()
          : 'Sin hora',
      prioridad: _normalizePriority(json['prioridad']?.toString()),
      tipo: json['tipo']?.toString().trim().isNotEmpty == true
          ? json['tipo'].toString()
          : 'otro',
      completada: json['completada'] == true,
      fechaCreacion:
          DateTime.tryParse(json['fechaCreacion']?.toString() ?? '') ??
          DateTime.now(),
      notas: json['notas']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'titulo': titulo,
    'materia': materia,
    'fecha': fecha,
    'hora': hora,
    'prioridad': prioridad,
    'tipo': tipo,
    'completada': completada,
    'fechaCreacion': fechaCreacion.toIso8601String(),
    'notas': notas,
  };

  static String _normalizePriority(String? value) {
    final normalized = (value ?? 'media').toLowerCase().trim();
    if (normalized.contains('alta')) return 'alta';
    if (normalized.contains('baja')) return 'baja';
    return 'media';
  }
}
