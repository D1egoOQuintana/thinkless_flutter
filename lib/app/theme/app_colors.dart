part of '../../main.dart';

/// Design tokens — Warm Academic Minimal.
/// Paleta warm paper: fondo #fffaf6, texto #302f35,
/// teal primario #086779, acento naranja #ea582a.
class AppColors {
  // ───── Surfaces (warm paper hierarchy) ─────
  static const background       = Color(0xFFFFFAF6); // warm paper
  static const surfaceLowest    = Color(0xFFFFFFFF); // cards, sheets, modales
  static const surface          = Color(0xFFFCF8FF); // base de pantalla
  static const surfaceContainer = Color(0xFFF6F2FA); // cards secundarias
  static const surfaceVariant   = Color(0xFFF0ECF4); // cards alternas
  static const surfaceHigh      = Color(0xFFEBE7EF); // hover / inputs
  static const surfaceHighest   = Color(0xFFE5E1E9); // pressed / overlays
  static const surfaceWarm      = Color(0xFFFDF4EB); // warm tint (nav, inputs)

  // ───── Borders & dividers ─────
  static const outlineVariant   = Color(0xFFBEC8CB); // borde sutil
  static const outline          = Color(0xFF7A7F92); // borde marcado
  static const outlineSubtle    = Color(0xFFE8E5DF); // hairlines

  // ───── Text ─────
  static const onSurface        = Color(0xFF302F35); // texto primario (tinta)
  static const onSurfaceVariant = Color(0xFF494740); // texto secundario
  static const secondary        = Color(0xFF7A776F); // texto muted
  static const onPrimary        = Color(0xFFFFFFFF);

  // ───── Brand: teal académico ─────
  static const primary          = Color(0xFF086779);
  static const primaryHover     = Color(0xFF096E83);
  static const primaryPressed   = Color(0xFF075E72);
  static const primaryContainer = Color(0xFFB8E3EA); // soft teal bg
  static const violet           = Color(0xFF086779); // alias → primary
  static const violetLight      = Color(0xFF0A8FA7); // teal brighter
  static const indigo           = Color(0xFF086779); // alias → primary

  // ───── Acento: naranja quemado ─────
  static const accent           = Color(0xFFEA582A);
  static const accentSoft       = Color(0xFFFDE8E0);
  static const pink             = Color(0xFFEA582A); // alias acento
  static const pinkSoft         = Color(0xFFFDE8E0);

  // ───── Semánticos ─────
  static const mint             = Color(0xFF196B22); // hecho / éxito
  static const mintSoft         = Color(0xFFEDF7EE);
  static const blue             = Color(0xFF086779); // info → teal alias
  static const blueSoft         = Color(0xFFE0F2F5);
  static const yellow           = Color(0xFFEA582A); // urgente → acento
  static const yellowSoft       = Color(0xFFFDF0E8);
  static const error            = Color(0xFFBA1A1A);
  static const errorContainer   = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);
}

/// Spacing token — 8pt system (use multiples).
class AppSpacing {
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 20;
  static const double xxl  = 24;
  static const double xxxl = 32;
}

/// Radius tokens — superficies modernas, no demasiado redondeadas.
class AppRadius {
  static const double xs   = 8;
  static const double sm   = 10;
  static const double md   = 12;
  static const double lg   = 14;
  static const double xl   = 16;
  static const double xxl  = 20;
  static const double pill = 999;
}

/// Motion tokens — animaciones rápidas, profesionales.
class AppMotion {
  static const Duration fast   = Duration(milliseconds: 140);
  static const Duration base   = Duration(milliseconds: 220);
  static const Duration slow   = Duration(milliseconds: 340);
  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve standard   = Curves.easeOutQuart;
}

/// Shadow tokens — sombras suaves warm (estilo editorial).
class AppShadow {
  static List<BoxShadow> get sm => [
    BoxShadow(
      color: const Color(0xFF302F35).withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get md => [
    BoxShadow(
      color: const Color(0xFF302F35).withValues(alpha: 0.10),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF302F35).withValues(alpha: 0.04),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get lg => [
    BoxShadow(
      color: const Color(0xFF302F35).withValues(alpha: 0.14),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: const Color(0xFF302F35).withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> brand({double opacity = 0.22}) => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: opacity),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: const Color(0xFF302F35).withValues(alpha: 0.05),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];
}
