import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Aurora" — northern lights over dark water: deep teal ground, teal accent
/// and a lime glow. Every screen pulls its colors from here.
class AppTheme {
  // Grounds
  static const Color background = Color(0xFF051216);
  static const Color sidebar = Color(0xFF061A1F);
  static const Color surface = Color(0xFF0D252B);
  static const Color raised = Color(0xFF123540);
  static const Color border = Color(0xFF1D4450);

  // Text
  static const Color text = Color(0xFFE6FBF7);
  static const Color body = Color(0xFFCBEFEA);
  static const Color muted = Color(0xFF8FB9B3);

  // Accent
  static const Color accent = Color(0xFF2DD4BF);
  static const Color onAccent = Color(0xFF04221E);
  static const Color accentText = Color(0xFF5EEAD4);
  static const Color danger = Color(0xFFFCA5A5);

  // Glow / logo
  static const Color glowCyan = Color(0xFF22D3EE);
  static const Color glowLime = Color(0xFFA3E635);
  static const Color logoStart = Color(0xFF22D3EE);
  static const Color logoEnd = Color(0xFF84CC16);

  static const LinearGradient logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [logoStart, logoEnd],
  );

  static Color get userBubble => accent.withValues(alpha: 0.14);
  static Color get userBubbleBorder => accent.withValues(alpha: 0.45);

  static TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w600,
  }) => GoogleFonts.spaceGrotesk(
    fontSize: size,
    fontWeight: weight,
    color: text,
    letterSpacing: -size * 0.025,
    height: 1.12,
  );

  static ThemeData darkTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.spaceGroteskTextTheme(
      base.textTheme,
    ).apply(bodyColor: text, displayColor: text);

    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardColor: surface,
      dividerColor: border,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: onAccent,
        secondary: glowLime,
        surface: surface,
        onSurface: text,
        onSurfaceVariant: muted,
        outline: border,
        error: danger,
      ).copyWith(surfaceContainerHighest: raised),
      textTheme: textTheme,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.3),
        selectionHandleColor: accent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: muted),
        prefixIconColor: muted,
        suffixIconColor: muted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: outline(border),
        enabledBorder: outline(border),
        focusedBorder: outline(accent, 1.4),
        errorBorder: outline(danger),
        focusedErrorBorder: outline(danger, 1.4),
        errorStyle: const TextStyle(color: danger),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          disabledBackgroundColor: accent.withValues(alpha: 0.5),
          disabledForegroundColor: onAccent,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentText),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: muted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: sidebar,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: raised,
        contentTextStyle: GoogleFonts.spaceGrotesk(color: text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(raised),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(12),
          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: 0.5),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: border),
            ),
          ),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(text),
          iconColor: const WidgetStatePropertyAll(muted),
          minimumSize: const WidgetStatePropertyAll(Size(260, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          ),
          overlayColor: WidgetStatePropertyAll(accent.withValues(alpha: 0.12)),
          textStyle: WidgetStatePropertyAll(
            GoogleFonts.spaceGrotesk(fontSize: 14.5),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: raised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        textStyle: GoogleFonts.spaceGrotesk(color: text, fontSize: 12.5),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(border),
      ),
    );
  }
}
