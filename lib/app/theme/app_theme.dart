import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  static const _controlRadius = 16.0;

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

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
      surface: surface,
      error: AppColors.error,
    ).copyWith(
      primary: AppColors.accent,
      secondary: AppColors.accentBlue,
      onSurface: onSurface,
      surfaceContainerLow: dark ? AppColors.surface : const Color(0xFFF5F5F6),
      surfaceContainer: elevated,
      surfaceContainerHigh: dark ? AppColors.surfaceHighlight : const Color(0xFFECECEF),
      surfaceContainerHighest: dark ? AppColors.surfaceHighlight : const Color(0xFFE7E7EA),
      outline: border,
      outlineVariant: dark ? AppColors.borderSubtle : const Color(0xFFEDEDF0),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      fontFamily: 'Inter',
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 60,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        ),
        titleTextStyle: AppTextStyles.heading2.copyWith(
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -.35,
        ),
        iconTheme: IconThemeData(color: onSurface, size: 22),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.accent.withValues(alpha: .14),
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          color: states.contains(WidgetState.selected) ? onSurface : secondaryText,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          fontSize: 11,
          fontFamily: 'Inter',
        )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? AppColors.accent : secondaryText,
          size: 23,
        )),
        elevation: 0,
        height: 68,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.accent.withValues(alpha: .14),
        indicatorShape: const StadiumBorder(),
        selectedIconTheme: const IconThemeData(color: AppColors.accent, size: 24),
        unselectedIconTheme: IconThemeData(color: secondaryText, size: 23),
        selectedLabelTextStyle: TextStyle(
          color: onSurface,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: secondaryText,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        useIndicator: true,
        groupAlignment: -.7,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: secondaryText,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 3.5,
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: border,
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accent.withValues(alpha: .10),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      ),
      dividerTheme: DividerThemeData(color: border.withValues(alpha: .7), thickness: .7, space: 0),
      listTileTheme: ListTileThemeData(
        dense: false,
        minTileHeight: 58,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        iconColor: secondaryText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
        subtitleTextStyle: TextStyle(
          color: secondaryText,
          fontSize: 12,
          fontFamily: 'Inter',
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? AppColors.surfaceHighlight : const Color(0xFF202022),
        contentTextStyle: const TextStyle(color: Colors.white, fontFamily: 'Inter', fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: border.withValues(alpha: .7)),
        ),
        elevation: 2,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: secondaryText.withValues(alpha: .55),
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevated,
        isDense: false,
        hintStyle: TextStyle(color: secondaryText),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_controlRadius),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_controlRadius),
          borderSide: BorderSide(color: border.withValues(alpha: .8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_controlRadius),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_controlRadius)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
            fontSize: 14,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_controlRadius)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: border.withValues(alpha: .85)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_controlRadius)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Inter'),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: elevated,
        selectedColor: AppColors.accent.withValues(alpha: .14),
        side: BorderSide(color: border.withValues(alpha: .7)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: TextStyle(color: onSurface, fontSize: 12, fontFamily: 'Inter'),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border.withValues(alpha: .55)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border.withValues(alpha: .7)),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? AppColors.surfaceHighlight : const Color(0xFF202022),
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(color: Colors.white, fontFamily: 'Inter', fontSize: 12),
        waitDuration: const Duration(milliseconds: 500),
      ),
      splashColor: AppColors.accent.withValues(alpha: .06),
      highlightColor: AppColors.accent.withValues(alpha: .03),
    );
  }
}
