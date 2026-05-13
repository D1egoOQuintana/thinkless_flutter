# CLAUDE.md

# Language
- Responde siempre en español.
- Explica cambios importantes de forma clara y breve.
- Evita respuestas innecesariamente largas.

# Core Engineering Rules
- Prioriza simplicidad sobre complejidad.
- No agregues funcionalidades no solicitadas.
- Mantén arquitectura limpia y escalable.
- No hagas refactors innecesarios.
- Modifica únicamente lo relacionado con la tarea actual.
- Mantén consistencia con el codebase existente.
- Reutiliza componentes antes de crear nuevos.
- Evita duplicación de lógica.
- Si existe ambigüedad importante, pregunta antes de implementar.
- No inventes APIs, paquetes o funcionalidades inexistentes.
- Verifica antes de finalizar.

# Token Efficiency
- Mantén respuestas técnicas compactas.
- Evita generar archivos enormes innecesariamente.
- Trabaja por módulos.
- Resume cambios después de tareas complejas.
- No expliques conceptos básicos a menos que se solicite.

# Flutter Architecture
- Usa arquitectura limpia y modular.
- Mantén separación clara entre UI, lógica y datos.
- Usa widgets reutilizables.
- Evita widgets gigantes.
- Mantén estructura escalable.
- Prioriza rendimiento.
- Evita rebuilds innecesarios.
- Usa buenas prácticas modernas de Flutter.

# UI/UX Rules
- Diseño premium moderno.
- UX intuitiva y profesional.
- Evita interfaces genéricas estilo AI.
- Excelente jerarquía visual.
- Espaciado limpio y consistente.
- Componentes visualmente elegantes.
- Prioriza claridad visual.
- Mantén consistencia en toda la app.
- Usa microinteracciones profesionales.
- Usa animaciones suaves y fluidas.
- Evita animaciones excesivas o molestas.
- Mantén navegación intuitiva.
- Mobile-first.
- Responsive real.
- Dark mode elegante.
- Diseño empresarial moderno.

# Visual Inspiration
Inspiración visual:
- Linear
- Vercel
- Stripe
- Notion
- Framer
- Arc Browser

# Animation Rules
- Usa animaciones modernas y suaves.
- Transiciones fluidas entre pantallas.
- Feedback visual inmediato.
- Animaciones coherentes con la UX.
- Prioriza rendimiento sobre efectos exagerados.

# Task System Rules
Para el sistema de tareas:
- Permitir edición completa de tareas.
- Categorías dinámicas editables.
- Prioridades configurables.
- Estados claros de tareas.
- Flujo rápido para agregar tareas.
- UX enfocada en productividad real.

# Calendar Rules
Para el calendario:
- Soporte desde 6 AM hasta 12 AM.
- Scroll fluido.
- Bloques horarios dinámicos.
- Excelente legibilidad.
- Interacción intuitiva.
- Diseño moderno tipo Google Calendar + Linear.

# Focus Mode Rules
Para modo concentración:
- Reducir distracciones.
- Experiencia inmersiva.
- Temporizador visual elegante.
- Estadísticas de enfoque.
- Explicar limitaciones reales de Android/Flutter antes de implementar bloqueos de apps.
- No inventar funcionalidades imposibles.

# Code Quality
- Código limpio y legible.
- Nombres claros.
- Evita sobreingeniería.
- Evita lógica innecesaria.
- Mantén coherencia de estilos.
- Mantén componentes desacoplados.

# Playwright Rules
Cuando revises UI:
- Detecta overflow.
- Detecta problemas responsive.
- Detecta inconsistencias visuales.
- Detecta problemas de spacing.
- Detecta animaciones rotas.
- Detecta problemas UX.

# Workflow
Antes de implementar:
- Analiza estructura existente.
- Entiende dependencias importantes.
- Revisa componentes relacionados.

Después de implementar:
- Resume cambios importantes.
- Explica posibles riesgos.
- Menciona qué fue validado.
- Indica qué faltaría probar.

# Restrictions
- No romper funcionalidades existentes.
- No modificar módulos no relacionados.
- No agregar dependencias innecesarias.
- No generar código experimental sin avisar.
- No usar soluciones temporales sin explicarlo.

# Preferred Style
- Código profesional.
- UI moderna.
- Arquitectura escalable.
- Experiencia premium.
- Producción real.