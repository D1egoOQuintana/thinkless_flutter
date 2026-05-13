part of '../../main.dart';

/// Design tokens — inspirados en Linear, Vercel, Stripe y Arc.
/// Sistema de capas (surface hierarchy) con profundidad real,
/// fondos slate azulados (nunca negro puro) y acentos tecnológicos.
class AppColors {
  // ───── Surfaces (slate, profundidad real) ─────
  static const background       = Color(0xFF0A0B11); // app shell
  static const surfaceLowest    = Color(0xFF0D0F16); // bottom nav, modales
  static const surface          = Color(0xFF11131B); // base de pantalla
  static const surfaceContainer = Color(0xFF161924); // cards primarias
  static const surfaceVariant   = Color(0xFF1B1E2B); // cards alternas
  static const surfaceHigh      = Color(0xFF1F2330); // hover / inputs
  static const surfaceHighest   = Color(0xFF272B3A); // pressed / overlays

  // ───── Borders & dividers ─────
  static const outlineVariant   = Color(0xFF252938); // borde sutil
  static const outline          = Color(0xFF323748); // borde marcado
  static const outlineSubtle    = Color(0xFF1D2030); // hairlines

  // ───── Text ─────
  static const onSurface        = Color(0xFFF4F5FA); // primary text
  static const onSurfaceVariant = Color(0xFFB0B5C7); // secondary text
  static const secondary        = Color(0xFF7A7F92); // tertiary / muted
  static const onPrimary        = Color(0xFFFFFFFF);

  // ───── Brand: violeta moderno (Linear-like) ─────
  static const primary          = Color(0xFF7C5CFF);
  static const primaryHover     = Color(0xFF8E72FF);
  static const primaryPressed   = Color(0xFF6A48F0);
  static const primaryContainer = Color(0xFF231B4D); // bg tinted
  static const violet           = Color(0xFF7C5CFF);
  static const violetLight      = Color(0xFFB7A4FF);
  static const indigo           = Color(0xFF5B6CFF);

  // ───── Acentos semánticos (tono moderno) ─────
  static const mint             = Color(0xFF3DDC97); // success / done
  static const mintSoft         = Color(0xFF153026);
  static const blue             = Color(0xFF5B9DFF); // info / accent
  static const blueSoft         = Color(0xFF12233D);
  static const yellow           = Color(0xFFFFB547); // warning / media
  static const yellowSoft       = Color(0xFF332512);
  static const pink             = Color(0xFFFF6FA8); // accent
  static const pinkSoft         = Color(0xFF331824);
  static const error            = Color(0xFFFF5C72); // urgente / error
  static const errorContainer   = Color(0xFF301318);
  static const onErrorContainer = Color(0xFFFFA5B0);
}

/// Spacing token — 8pt system (use multiples).
class AppSpacing {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Radius tokens — superficies modernas, no demasiado redondeadas.
class AppRadius {
  static const double xs  = 8;
  static const double sm  = 10;
  static const double md  = 12;
  static const double lg  = 14;
  static const double xl  = 16;
  static const double xxl = 20;
  static const double pill = 999;
}

/// Motion tokens — animaciones rápidas, profesionales.
class AppMotion {
  static const Duration fast    = Duration(milliseconds: 140);
  static const Duration base    = Duration(milliseconds: 220);
  static const Duration slow    = Duration(milliseconds: 340);
  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve standard   = Curves.easeOutQuart;
}

/// Shadow tokens — sombras suaves y profundas (estilo Stripe/Linear).
class AppShadow {
  static List<BoxShadow> get sm => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.20),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get md => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.28),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.18),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get lg => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.40),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.20),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> brand({double opacity = 0.30}) => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: opacity),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.25),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}
