# ThinkLess Flutter

Aplicacion Flutter para gestion de tareas academicas con:

- organizacion por prioridad y calendario
- entrada por voz con IA
- escaneo de tareas desde imagen
- modo no molestar y alertas

## Arquitectura actual

Se separo la base del proyecto en capas y modulos para evitar el archivo monolitico:

| Capa | Ubicacion | Responsabilidad |
|---|---|---|
| `app` | `lib/app/` | Configuracion visual y navegacion base |
| `features/*/domain` | `lib/features/**/domain/` | Entidades y reglas de negocio |
| `features/*/data` | `lib/features/**/data/` | Persistencia local y servicios externos |
| `main` | `lib/main.dart` | Punto de entrada y composicion principal |

## Estructura principal

```text
lib/
  main.dart
  app/
    navigation/app_view.dart
    theme/app_colors.dart
  features/
    assistant/data/groq_service.dart
    settings/domain/no_molestar_config.dart
    tasks/domain/task_item.dart
    tasks/data/task_store.dart
```
