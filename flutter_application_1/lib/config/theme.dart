// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';

// class AppTheme {
//   static const Color deepBackground = Color(0xFFF6F8FC);
//   static const Color surface = Colors.white;
//   static const Color surfaceElevated = Color(0xFFF9FAFE);
//   static const Color accent = Color(0xFF6576E8);
//   static const Color accentSoft = Color(0xFFE9EDFF);
//   static const Color mutedText = Color(0xFF748096);
//   static const Color border = Color(0xFFE8ECF3);
//   static const Color success = Color(0xFF5FB98B);
//   static const Color primaryText = Color(0xFF202B3C);

//   static ThemeData darkTheme() {
//     final base = ThemeData.light(useMaterial3: true);
//     return base.copyWith(
//       scaffoldBackgroundColor: deepBackground,
//       canvasColor: deepBackground,
//       cardColor: surface,
//       dividerColor: border,
//       colorScheme: const ColorScheme.light(
//         primary: accent,
//         onPrimary: Colors.white,
//         secondary: Color(0xFF8B7BE8),
//         surface: surface,
//         onSurface: primaryText,
//         onSurfaceVariant: mutedText,
//         outline: border,
//       ).copyWith(surfaceContainerHighest: surfaceElevated),
//       textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
//         bodyMedium: GoogleFonts.inter(color: primaryText),
//         bodyLarge: GoogleFonts.inter(color: primaryText),
//         titleMedium: GoogleFonts.inter(color: primaryText, fontWeight: FontWeight.w600),
//         titleLarge: GoogleFonts.inter(color: primaryText, fontWeight: FontWeight.w700),
//         labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
//       ),
//       appBarTheme: const AppBarTheme(
//         backgroundColor: deepBackground,
//         foregroundColor: primaryText,
//         surfaceTintColor: Colors.transparent,
//         elevation: 0,
//       ),
//       inputDecorationTheme: InputDecorationTheme(
//         filled: true,
//         fillColor: surface,
//         hintStyle: const TextStyle(color: mutedText),
//         border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: border)),
//         enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: border)),
//         focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: accent, width: 1.3)),
//       ),
//       elevatedButtonTheme: ElevatedButtonThemeData(
//         style: ElevatedButton.styleFrom(
//           backgroundColor: accent,
//           foregroundColor: Colors.white,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//           elevation: 0,
//         ),
//       ),
//       iconButtonTheme: IconButtonThemeData(
//         style: IconButton.styleFrom(
//           backgroundColor: surface,
//           foregroundColor: mutedText,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//         ),
//       ),
//       cardTheme: CardThemeData(
//         color: surface,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         elevation: 0,
//         margin: EdgeInsets.zero,
//       ),
//       scrollbarTheme: const ScrollbarThemeData().copyWith(thumbColor: WidgetStateProperty.all(const Color(0xFFD5DBE7))),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color deepBackground = Color(0xFFF1EDFB);
  static const Color surface = Color(0xFFFAF8FE);
  static const Color surfaceElevated = Color(0xFFF3EFFC);
  // static const Color deepBackground = Color(0xFFF7F6FD);
  // static const Color surface = Colors.white;
  // static const Color surfaceElevated = Color(0xFFF9F8FF);
  static const Color accent = Color(0xFF7C5CFC);
  static const Color accentSoft = Color(0xFFEDE7FF);
  static const Color mutedText = Color(0xFF7C7A94);
  static const Color border = Color(0xFFE9E6F7);
  static const Color success = Color(0xFF5FB98B);
  static const Color primaryText = Color(0xFF231F3D);

  static ThemeData darkTheme() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: deepBackground,
      canvasColor: deepBackground,
      cardColor: surface,
      dividerColor: border,
      colorScheme: const ColorScheme.light(
        primary: accent,
        onPrimary: Colors.white,
        secondary: Color(0xFF9B7BE8),
        surface: surface,
        onSurface: primaryText,
        onSurfaceVariant: mutedText,
        outline: border,
      ).copyWith(surfaceContainerHighest: surfaceElevated),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        bodyMedium: GoogleFonts.inter(color: primaryText),
        bodyLarge: GoogleFonts.inter(color: primaryText),
        titleMedium: GoogleFonts.inter(
          color: primaryText,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: GoogleFonts.inter(
          color: primaryText,
          fontWeight: FontWeight.w700,
        ),
        labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: deepBackground,
        foregroundColor: primaryText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: mutedText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: accent, width: 1.3),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          elevation: 0,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          backgroundColor: surface,
          foregroundColor: mutedText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      scrollbarTheme: const ScrollbarThemeData().copyWith(
        thumbColor: WidgetStateProperty.all(const Color(0xFFDCD6F0)),
      ),
    );
  }
}
