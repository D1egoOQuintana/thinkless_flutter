part of '../../../main.dart';

class GroqService {
  static const _apiKey = String.fromEnvironment('GROQ_API_KEY');
  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';

  static bool get configured => _apiKey.trim().isNotEmpty;

  static Future<TaskItem> extractTaskFromText(String text) async {
    if (!configured) {
      throw Exception(
        'Falta GROQ_API_KEY. Ejecuta con --dart-define=GROQ_API_KEY=tu_clave.',
      );
    }

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {
            'role': 'user',
            'content':
                '''
Extrae la informacion de esta tarea universitaria y responde SOLO con JSON valido, sin texto adicional. Hoy es ${DateTime.now().toString().split(' ')[0]}.
Texto: "$text"

Formato:
{
  "titulo": "nombre de la tarea",
  "materia": "nombre de la materia o curso",
  "fecha": "fecha exacta en formato YYYY-MM-DD (calculala basandote en la fecha de hoy si se mencionan dias relativos) o 'Sin fecha'",
  "hora": "hora en formato HH:MM o Sin hora",
  "prioridad": "alta | media | baja",
  "tipo": "examen | tarea | laboratorio | proyecto | lectura | otro"
}
''',
          },
        ],
        'max_tokens': 240,
        'temperature': 0.1,
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Groq texto ${response.statusCode}: ${response.body}');
    }
    final content = _messageContent(response.body);
    final data = Map<String, dynamic>.from(
      jsonDecode(_cleanJson(content)) as Map,
    );
    return TaskItem.fromJson({
      ...data,
      'id': _newId(),
      'completada': false,
      'fechaCreacion': DateTime.now().toIso8601String(),
      'notas': 'Creada desde voz: "$text"',
    });
  }

  static Future<List<TaskItem>> extractTasksFromImage(Uint8List bytes) async {
    if (!configured) {
      throw Exception(
        'Falta GROQ_API_KEY. Ejecuta con --dart-define=GROQ_API_KEY=tu_clave.',
      );
    }
    final base64Image = base64Encode(bytes);
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'meta-llama/llama-4-scout-17b-16e-instruct',
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text':
                    '''
Analiza esta imagen como apuntes universitarios, cuaderno, captura o pizarra. Extrae tareas accionables. Hoy es ${DateTime.now().toString().split(' ')[0]}.
Responde SOLO JSON valido:
{
  "tareas": [
    {
      "titulo": "nombre de la tarea",
      "materia": "curso o materia",
      "fecha": "fecha exacta en formato YYYY-MM-DD (calculala basandote en hoy si es relativo) o 'Sin fecha'",
      "hora": "HH:MM o Sin hora",
      "prioridad": "alta | media | baja",
      "tipo": "examen | tarea | laboratorio | proyecto | lectura | otro"
    }
  ]
}
Si no hay texto claro, infiere hasta 3 tareas utiles desde el contexto visual.
''',
              },
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
              },
            ],
          },
        ],
        'max_tokens': 700,
        'temperature': 0.1,
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Groq vision ${response.statusCode}: ${response.body}');
    }
    final content = _messageContent(response.body);
    final data = Map<String, dynamic>.from(
      jsonDecode(_cleanJson(content)) as Map,
    );
    final tasks = (data['tareas'] as List<dynamic>? ?? [])
        .map(
          (item) => TaskItem.fromJson({
            ...Map<String, dynamic>.from(item as Map),
            'id': _newId(),
            'completada': false,
            'fechaCreacion': DateTime.now().toIso8601String(),
            'notas': 'Detectada desde escaner IA.',
          }),
        )
        .toList();
    if (tasks.isEmpty) throw Exception('La IA no detecto tareas en la imagen.');
    return tasks;
  }

  static String _messageContent(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['choices'][0]['message']['content'].toString();
  }

  static String _cleanJson(String input) {
    return input.replaceAll('```json', '').replaceAll('```', '').trim();
  }

  static String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
