import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

abstract final class Palette {
  static const background = Color(0xFF0A0A0B);
  static const card = Color(0xFF1C1C1E);
  static const cardHigh = Color(0xFF2C2C2E);
  static const grey = Color(0xFF98989F);
  static const separator = Color(0x1FFFFFFF);
  static const neon = Color(0xFFF2F25A);
  static const coral = Color(0xFFFF5C6C);
  static const appleRed = Color(0xFFFA2D48);
  static const white = Color(0xFFFFFFFF);

  static const accents = [
    appleRed,
    neon,
    coral,
    Color(0xFF7CF2C4),
    Color(0xFF8AB4FF),
    Color(0xFFC9A0FF),
    white,
  ];

  static const widgetBackgrounds = [
    card,
    Color(0xFF000000),
    white,
    neon,
    coral,
    Color(0xFF23233F),
  ];

  /// Text/icon color that reads well on [color].
  static Color on(Color color) =>
      color.computeLuminance() > 0.45 ? Colors.black : Colors.white;
}

/// Liquid-glass look: translucent fill, hairline border, soft top highlight.
abstract final class Glass {
  static const blur = 28.0;
  static const fill = Color(0x1AFFFFFF);
  static const fillStrong = Color(0x2EFFFFFF);
  static const border = Color(0x2EFFFFFF);
  static const highlight = Color(0x24FFFFFF);
}

/// Curvas tipo iOS: arrancan rápido y frenan largo, sin rebotes bruscos.
abstract final class Motion {
  /// Hojas y pantallas que entran (curva de los sheets de iOS).
  static const sheet = Cubic(0.32, 0.72, 0, 1);
  static const standard = Curves.easeOutCubic;
  static const quick = Duration(milliseconds: 220);
  static const medium = Duration(milliseconds: 380);
  static const slow = Duration(milliseconds: 520);
}

abstract final class TextStyles {
  static const _font = 'Inter';

  static const display = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w800,
    fontSize: 32,
    height: 1.1,
    letterSpacing: -0.9,
    color: Palette.white,
  );
  static const title = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w700,
    fontSize: 20,
    letterSpacing: -0.4,
    color: Palette.white,
  );
  static const body = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w500,
    fontSize: 16,
    letterSpacing: -0.2,
    color: Palette.white,
  );
  static const caption = TextStyle(
    fontFamily: _font,
    fontSize: 13.5,
    letterSpacing: -0.1,
    color: Palette.grey,
  );

  /// Small uppercase label ("ÁLBUM DESTACADO").
  static const overline = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w600,
    fontSize: 12,
    letterSpacing: 0.4,
    color: Palette.grey,
  );

  /// Times and counters with fixed-width digits so they don't jitter.
  static const numbers = TextStyle(
    fontFamily: _font,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    color: Palette.grey,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Dot-matrix digits, only for stats.
  static const dots = TextStyle(
    fontFamily: 'Doto',
    fontWeight: FontWeight.w700,
    fontSize: 15,
    letterSpacing: 1,
    color: Palette.white,
  );
}

ThemeData buildTheme(Color accent) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
      ).copyWith(
        primary: accent,
        onPrimary: Palette.on(accent),
        secondary: Palette.coral,
        surface: Palette.background,
        surfaceContainer: Palette.card,
        surfaceContainerHigh: Palette.cardHigh,
        onSurfaceVariant: Palette.grey,
      );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: Palette.background,
    splashFactory: InkSparkle.splashFactory,
    // Transición de iOS (paralaje + deslizar desde el borde para regresar).
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: CupertinoPageTransitionsBuilder()},
    ),
    dividerColor: Palette.separator,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyles.title,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xF21C1C1E),
      showDragHandle: true,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Palette.cardHigh),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.cardHigh,
      contentTextStyle: TextStyles.body.copyWith(fontSize: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Palette.background,
      indicatorColor: accent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? Palette.on(accent)
              : Palette.grey,
        ),
      ),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontFamily: 'Inter', fontSize: 12, color: Palette.grey),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: Palette.white,
      unselectedLabelColor: Palette.grey,
      indicatorColor: accent,
      dividerColor: Colors.transparent,
      tabAlignment: TabAlignment.start,
      labelStyle: TextStyles.body.copyWith(fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Glass.fill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        borderSide: BorderSide.none,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      titleTextStyle: TextStyles.body,
      subtitleTextStyle: TextStyles.caption,
    ),
  );
}
