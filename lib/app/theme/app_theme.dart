import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  static const _radius = 12.0;

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? AppColors.background : const Color(0xFFF7F7F8);
    final surface = dark ? AppColors.surface : Colors.white;
    final elevated = dark ? AppColors.surfaceElevated : const Color(0xFFF1F1F3);
    final onSurface = dark ? AppColors.textPrimary : const Color(0xFF171718);
    final secondaryText = dark ? AppColors.textSecondary : const Color(0xFF69696E);
    final border = dark ? AppColors.border : const Color(0xFFE5E5E8);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      fontFamily: 'Inter',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: brightness,
        surface: surface,
        error: AppColors.error,
      ).copyWith(
        primary: AppColors.accent,
        secondary: AppColors.accentBlue,
        onSurface: onSurface,
        surfaceContainerHighest: elevated,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 56,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: background,
          systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        ),
        titleTextStyle: AppTextStyles.heading2.copyWith(
          color: onSurface,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -.25,
        ),
        iconTheme: IconThemeData(color: onSurface, size: 22),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.accent.withValues(alpha: .10),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          color: states.contains(WidgetState.selected) ? onSurface : secondaryText,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          fontSize: 10.5,
          fontFamily: 'Inter',
        )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? AppColors.accent : secondaryText,
          size: 22,
        )),
        elevation: 0,
        height: 64,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: secondaryText,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 2.5,
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: border,
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accent.withValues(alpha: .10),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 0),
      listTileTheme: ListTileThemeData(
        dense: true,
        minTileHeight: 54,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        iconColor: secondaryText,
        titleTextStyle: TextStyle(color: onSurface, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
        subtitleTextStyle: TextStyle(color: secondaryText, fontSize: 12, fontFamily: 'Inter'),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? AppColors.surfaceElevated : const Color(0xFF202022),
        contentTextStyle: const TextStyle(color: Colors.white, fontFamily: 'Inter', fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 2,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
        elevation: 2,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevated,
        isDense: true,
        hintStyle: TextStyle(color: secondaryText),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter', fontSize: 13.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter', fontSize: 13.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter', fontSize: 13.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter'),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: elevated,
        selectedColor: AppColors.accent.withValues(alpha: .10),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        labelStyle: TextStyle(color: onSurface, fontSize: 12, fontFamily: 'Inter'),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: border)),
      ),
      splashColor: AppColors.accent.withValues(alpha: .05),
      highlightColor: AppColors.accent.withValues(alpha: .03),
    );
  }
}
