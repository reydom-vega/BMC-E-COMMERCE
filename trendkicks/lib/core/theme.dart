import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Sampled from the supplied TrendKicks logo. Keep lime buttons black on top.
const brandBlack = Color(0xFF000000);
const brandLime = Color(0xFFBEFA1E);
const ink = Color(0xFF10120D);
const accent = Color(0xFF3C5700);
const canvas = Color(0xFFF5F6F2);
const muted = Color(0xFF64685F);
const brandTint = Color(0xFFF0FCCD);
const brandBorder = Color(0xFFDEE2D7);
const brandSilver = Color(0xFFE7EAE2);
const onDarkMuted = Color(0xFFD7DCCF);
const danger = Color(0xFFB3261E);
const dangerSurface = Color(0xFFFCE9E7);

extension StoreColors on BuildContext {
  Color get inkColor => Theme.of(this).colorScheme.onSurface;
  Color get mutedColor => Theme.of(this).colorScheme.onSurfaceVariant;
  Color get accentColor => Theme.of(this).colorScheme.secondary;
  Color get surfaceColor => Theme.of(this).colorScheme.surface;
  Color get canvasColor => Theme.of(this).scaffoldBackgroundColor;
  Color get tintColor => Theme.of(this).colorScheme.primaryContainer;
  Color get borderColor => Theme.of(this).colorScheme.outline;
  Color get silverColor => Theme.of(this).colorScheme.surfaceContainerHigh;
  Color get dangerSurfaceColor => Theme.of(this).colorScheme.errorContainer;
}

ThemeData buildTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  final surface = dark ? const Color(0xFF1A1E17) : Colors.white;
  final background = dark ? const Color(0xFF10130E) : canvas;
  final foreground = dark ? const Color(0xFFF1F5EA) : ink;
  final secondaryText = dark ? const Color(0xFFB4BDAA) : muted;
  final outline = dark ? const Color(0xFF414A37) : brandBorder;
  final emphasis = dark ? brandLime : accent;
  final tint = dark ? const Color(0xFF293810) : brandTint;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: brandLime,
        brightness: brightness,
      ).copyWith(
        primary: brandLime,
        onPrimary: ink,
        secondary: emphasis,
        onSecondary: dark ? ink : Colors.white,
        surface: surface,
        onSurface: foreground,
        onSurfaceVariant: secondaryText,
        primaryContainer: tint,
        onPrimaryContainer: foreground,
        outline: outline,
        surfaceContainerLowest: surface,
        surfaceContainerLow: background,
        surfaceContainer: surface,
        surfaceContainerHigh: dark ? const Color(0xFF2B3225) : brandSilver,
        error: dark ? const Color(0xFFFFB4AB) : danger,
        errorContainer: dark ? const Color(0xFF492322) : dangerSurface,
        onErrorContainer: dark ? const Color(0xFFFFDAD6) : danger,
      );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    fontFamily: 'Manrope',
    appBarTheme: AppBarTheme(
      backgroundColor: brandBlack,
      foregroundColor: Colors.white,
      centerTitle: false,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: brandBlack,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: surface,
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: DividerThemeData(color: outline, space: 28),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.all(17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: emphasis, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: ink,
        backgroundColor: brandLime,
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        side: BorderSide(color: outline),
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: emphasis),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: brandLime,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? ink : secondaryText,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Manrope',
          fontSize: 11,
          color: states.contains(WidgetState.selected)
              ? foreground
              : secondaryText,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w500,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: brandLime,
      secondarySelectedColor: brandLime,
      disabledColor: scheme.surfaceContainerHigh,
      checkmarkColor: ink,
      side: BorderSide(color: outline),
      labelStyle: TextStyle(
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? ink : foreground,
        ),
        fontFamily: 'Manrope',
      ),
      secondaryLabelStyle: const TextStyle(color: ink, fontFamily: 'Manrope'),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: brandLime,
      unselectedLabelColor: onDarkMuted,
      indicatorColor: brandLime,
      dividerColor: Color(0xFF34382D),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: emphasis),
    sliderTheme: SliderThemeData(
      activeTrackColor: emphasis,
      thumbColor: emphasis,
      valueIndicatorColor: tint,
      valueIndicatorTextStyle: TextStyle(color: foreground),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: emphasis,
      selectionColor: brandLime.withValues(alpha: 0.35),
      selectionHandleColor: emphasis,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: brandBlack,
      contentTextStyle: TextStyle(color: Colors.white, fontFamily: 'Manrope'),
      actionTextColor: brandLime,
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: dark ? brandLime : brandBlack,
      textColor: dark ? ink : Colors.white,
    ),
  );
}
