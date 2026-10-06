import 'package:flutter/material.dart';

import '../brand.dart';

const _radius = BorderRadius.all(Radius.circular(8));
const _errorColor = Color(0xFFB42318);

// Primary action: the band gradient with ink text, half opacity when disabled
Widget _gradientBackground(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) => Opacity(
  opacity: states.contains(WidgetState.disabled) ? 0.5 : 1,
  child: DecoratedBox(
    decoration: BoxDecoration(
      gradient: bandGradient(glow),
      borderRadius: _radius,
    ),
    child: child,
  ),
);

abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: accent,
            brightness: Brightness.light,
          ).copyWith(
            primary: accent,
            surface: Colors.white,
            onSurface: ink,
            onSurfaceVariant: muted,
            outline: muted,
            outlineVariant: hairline,
            error: _errorColor,
            inverseSurface: ink,
            onInverseSurface: paper,
            // Neutral containers, otherwise dialogs and menus turn pink
            surfaceTint: Colors.transparent,
            surfaceContainerLowest: Colors.white,
            surfaceContainerLow: Colors.white,
            surfaceContainer: Colors.white,
            surfaceContainerHigh: Colors.white,
            surfaceContainerHighest: paper,
          ),
      scaffoldBackgroundColor: paper,
    );
    final text = base.textTheme;
    TextStyle? heading(TextStyle? style) =>
        style?.merge(display(style.fontSize ?? 22, color: ink));

    return base.copyWith(
      textTheme: text.copyWith(
        displayLarge: heading(text.displayLarge),
        displayMedium: heading(text.displayMedium),
        displaySmall: heading(text.displaySmall),
        headlineLarge: heading(text.headlineLarge),
        headlineMedium: heading(text.headlineMedium),
        headlineSmall: heading(text.headlineSmall),
        titleLarge: heading(text.titleLarge),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: display(26, color: ink),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: const WidgetStatePropertyAll(ink),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 52)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: _radius),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          backgroundBuilder: _gradientBackground,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: Colors.white,
          side: const BorderSide(color: hairline),
          minimumSize: const Size(double.infinity, 52),
          shape: const RoundedRectangleBorder(borderRadius: _radius),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: ink, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: _errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: _errorColor, width: 2),
        ),
        floatingLabelStyle: TextStyle(color: ink),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: hairline),
        ),
      ),
      dividerTheme: const DividerThemeData(color: hairline, thickness: 1),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: TextStyle(color: paper, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: _radius),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: ink),
      iconTheme: const IconThemeData(color: ink),
    );
  }
}
