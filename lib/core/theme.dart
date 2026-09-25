import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
class PLColors {
  PLColors._();

  // Warm off-white backgrounds
  static const Color shell   = Color(0xFFF0EDE8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card    = Color(0xFFFAF8F5);
  static const Color border  = Color(0xFFE8E3DC);
  static const Color divider = Color(0xFFF1EDE7);

  // Text
  static const Color textPrimary   = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted     = Color(0xFF64748B);
  static const Color textLight     = Color(0xFF94A3B8);
  static const Color textFaint     = Color(0xFFCBD5E1);

  // Brand / known
  static const Color known        = Color(0xFF2563EB);
  static const Color knownBg      = Color(0xFFDCFCE7);
  static const Color knownText    = Color(0xFF15803D);

  // Unknown / danger
  static const Color unknown      = Color(0xFFDC2626);
  static const Color unknownBg    = Color(0xFFFEE2E2);
  static const Color unknownText  = Color(0xFFDC2626);

  // Live green
  static const Color live         = Color(0xFF22C55E);
  static const Color liveBg       = Color(0xFFDCFCE7);

  // Avatar palette
  static const Color avIndigoBg   = Color(0xFFEDE9FE);
  static const Color avIndigoFg   = Color(0xFF4338CA);
  static const Color avTealBg     = Color(0xFFCCFBF1);
  static const Color avTealFg     = Color(0xFF0D9488);
  static const Color avRoseBg     = Color(0xFFFFE4E6);
  static const Color avRoseFg     = Color(0xFFE11D48);
  static const Color avAmberBg    = Color(0xFFFEF3C7);
  static const Color avAmberFg    = Color(0xFFD97706);
  static const Color avSkyBg      = Color(0xFFE0F2FE);
  static const Color avSkyFg      = Color(0xFF0284C7);
  static const Color avRedBg      = Color(0xFFFEE2E2);
  static const Color avRedFg      = Color(0xFFDC2626);
}

// ── Typography ────────────────────────────────────────────────────────────────
class PLFonts {
  PLFonts._();

  static TextStyle syne({
    double size = 14,
    FontWeight weight = FontWeight.w600,
    Color color = PLColors.textPrimary,
    double? letterSpacing,
  }) =>
      GoogleFonts.syne(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  static TextStyle mono({
    double size = 12,
    FontWeight weight = FontWeight.w400,
    Color color = PLColors.textSecondary,
    double? letterSpacing,
  }) =>
      GoogleFonts.dmMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );
}

// ── Theme ─────────────────────────────────────────────────────────────────────
ThemeData plTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: PLColors.shell,
    colorScheme: const ColorScheme.light(
      primary: PLColors.known,
      surface: PLColors.surface,
      onPrimary: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: PLColors.surface,
      foregroundColor: PLColors.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: PLFonts.syne(size: 14, letterSpacing: 0.14),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PLColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: PLColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: PLColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF93C5FD), width: 1.5),
      ),
      hintStyle: PLFonts.mono(color: PLColors.textFaint),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: PLColors.textPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: PLFonts.mono(size: 12, letterSpacing: 0.08),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: PLColors.textMuted),
    ),
  );
}

// ── Brand theme helper ───────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static const Color background  = PLColors.shell;
  static const Color surface     = PLColors.surface;
  static const Color surfaceAlt  = PLColors.card;
  static const Color border      = PLColors.border;
  static const Color borderLight = PLColors.divider;

  static const Color ink         = PLColors.textPrimary;
  static const Color inkLight    = PLColors.textSecondary;
  static const Color inkMuted    = PLColors.textMuted;
  static const Color inkFaint    = PLColors.textFaint;
  static const Color inkGhost    = Color(0xFFE2E8F0);

  static const Color brandBlue   = PLColors.known;
  static const Color brandRed    = PLColors.unknown;
  static const Color brandGreen  = PLColors.live;
  static const Color avRedBg      = PLColors.avRedBg;

  static TextStyle get monoSmall => PLFonts.mono(size: 11);
  static TextStyle get monoLabel => PLFonts.mono(size: 9, weight: FontWeight.w500, letterSpacing: 1.0);
  static TextStyle get brandText => PLFonts.syne(size: 14, weight: FontWeight.w800, letterSpacing: 0.14);
  static TextStyle get sectionLabel => PLFonts.mono(size: 10, weight: FontWeight.w600, letterSpacing: 1.2, color: PLColors.textLight);
  static TextStyle get cardName => PLFonts.syne(size: 14, weight: FontWeight.w700);
  static TextStyle get statNum  => PLFonts.syne(size: 20, weight: FontWeight.w700, color: PLColors.textPrimary);

  static List<Color> avatarColors(String? name) {
    final pair = getAvatarColorsRecord(name);
    return [pair.bg, pair.fg];
  }
}

// ── Avatar color helper ───────────────────────────────────────────────────────
({Color bg, Color fg}) getAvatarColorsRecord(String? name) {
  if (name == null || name.isEmpty) return (bg: PLColors.avRedBg, fg: PLColors.avRedFg);
  const pairs = [
    (bg: PLColors.avIndigoBg, fg: PLColors.avIndigoFg),
    (bg: PLColors.avTealBg,   fg: PLColors.avTealFg),
    (bg: PLColors.avRoseBg,   fg: PLColors.avRoseFg),
    (bg: PLColors.avAmberBg,  fg: PLColors.avAmberFg),
    (bg: PLColors.avSkyBg,    fg: PLColors.avSkyFg),
  ];
  return pairs[name.codeUnitAt(0) % pairs.length];
}
