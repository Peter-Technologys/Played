import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/providers/remote_themes_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/custom_theme_manager.dart';
import '../settings_provider.dart';

class ThemeSelectionScreen extends ConsumerStatefulWidget {
  const ThemeSelectionScreen({super.key});

  @override
  ConsumerState<ThemeSelectionScreen> createState() =>
      _ThemeSelectionScreenState();
}

class _ThemeSelectionScreenState extends ConsumerState<ThemeSelectionScreen> {
  String? _wallpaperPath;

  @override
  void initState() {
    super.initState();
    _wallpaperPath = CustomThemeManager.instance.wallpaperPath;
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    HapticFeedback.selectionClick();
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    await CustomThemeManager.instance.setWallpaper(picked.path);
    if (mounted) {
      setState(() => _wallpaperPath = CustomThemeManager.instance.wallpaperPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final sn = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Theme & Appearance',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontFamily: 'Inter',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // ── LOCAL THEME CARDS (2-column, aspect ratio ~0.72) ─────
          _SectionHeader(label: 'Colour Theme'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // Customize Theme — pick from gallery
              _CustomizeWallpaperCard(
                isSelected: _wallpaperPath != null,
                onTap: () => _pickFromGallery(context),
              ),

              // Dark Colour
              _ThemeCard(
                name: 'Dark Colour',
                gradientColors: const [Color(0xFF1B232A), Color(0xFF0F111A)],
                isSelected: settings.themeMode == AppThemeMode.dark &&
                    _wallpaperPath == null,
                labelColor: Colors.white,
                onTap: () {
                  HapticFeedback.selectionClick();
                  sn.setThemeMode(AppThemeMode.dark);
                },
              ),

              // Light Colour
              _ThemeCard(
                name: 'Light Colour',
                gradientColors: const [Color(0xFFEBEFF5), Color(0xFFC3CFE2)],
                isSelected: settings.themeMode == AppThemeMode.light &&
                    _wallpaperPath == null,
                labelColor: const Color(0xFF1B232A),
                onTap: () {
                  HapticFeedback.selectionClick();
                  sn.setThemeMode(AppThemeMode.light);
                },
              ),

              // AMOLED
              _ThemeCard(
                name: 'AMOLED Black',
                gradientColors: const [Color(0xFF0A0A0A), Colors.black],
                isSelected: settings.themeMode == AppThemeMode.amoled &&
                    _wallpaperPath == null,
                labelColor: Colors.white,
                onTap: () {
                  HapticFeedback.selectionClick();
                  sn.setThemeMode(AppThemeMode.amoled);
                },
              ),
            ],
          ),

          // ── SERVER THEMES ─────────────────────────────────────────
          const SizedBox(height: 24),
          _SectionHeader(label: 'Server Themes'),
          const SizedBox(height: 12),
          _ServerThemesSection(
            onThemeApplied: () => setState(() {}),
          ),
        ],
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.accent, AppColors.accentViolet],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 1.4,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

// ── Theme Card (3-column) ─────────────────────────────────────────────

class _ThemeCard extends StatelessWidget {
  final String name;
  final List<Color> gradientColors;
  final bool isSelected;
  final Color labelColor;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.name,
    required this.gradientColors,
    required this.isSelected,
    required this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: const Color(0xFF00D2FF), width: 2)
              : Border.all(color: AppColors.border, width: 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF00D2FF).withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Gradient background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

              // Bottom label bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),

              // Selected checkmark badge
              if (isSelected)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00D2FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.black,
                      size: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Customize Wallpaper Card ──────────────────────────────────────────

class _CustomizeWallpaperCard extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _CustomizeWallpaperCard({
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: const Color(0xFF00D2FF), width: 2)
              : Border.all(
                  color: const Color(0xFF00D2FF).withValues(alpha: 0.5),
                  width: 1.5,
                ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF00D2FF).withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Center content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_rounded,
                  color: AppColors.accent,
                  size: 26,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pick from Gallery',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose any photo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),

            // Selected checkmark badge
            if (isSelected)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00D2FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.black,
                    size: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Server Themes Section ─────────────────────────────────────────────

/// Watches [remoteThemesProvider] and renders loading / error / data states.
class _ServerThemesSection extends ConsumerWidget {
  /// Called after a theme is applied so the parent can call setState.
  final VoidCallback onThemeApplied;

  const _ServerThemesSection({required this.onThemeApplied});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themesAsync = ref.watch(remoteThemesProvider);

    return themesAsync.when(
      loading: () => _ShimmerGrid(),
      error: (_, __) => _ErrorTile(
        onRetry: () => ref.read(remoteThemesProvider.notifier).refresh(),
      ),
      data: (themes) {
        if (themes.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No server themes available',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: themes.length,
          itemBuilder: (context, i) => _RemoteThemeCard(
            theme: themes[i],
            onApplied: onThemeApplied,
          ),
        );
      },
    );
  }
}

// ── Shimmer placeholder grid ──────────────────────────────────────────

class _ShimmerGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: const Color(0xFF2A2F45),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(
          2,
          (_) => Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Error tile ────────────────────────────────────────────────────────

class _ErrorTile extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorTile({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Could not load server themes',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontFamily: 'Inter',
              ),
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Remote Theme Card ─────────────────────────────────────────────────

class _RemoteThemeCard extends StatelessWidget {
  final RemoteTheme theme;
  final VoidCallback onApplied;

  const _RemoteThemeCard({required this.theme, required this.onApplied});

  /// Converts a snake_case theme id to Title Case display name.
  /// e.g. `new_year` → `New Year`, `uganda_independence` → `Uganda Independence`
  static String _formatName(String id) {
    return id
        .split('_')
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  /// Returns gradient colors based on the theme id.
  static List<Color> _gradientFor(String id) {
    final lower = id.toLowerCase();
    if (lower == 'space' || lower == 'default') {
      return const [Color(0xFF0D0D2B), Color(0xFF1A1A4E)];
    }
    if (lower.contains('new_year') || lower == 'newyear') {
      return const [Color(0xFF0A0A2A), Color(0xFF1A1A6E)];
    }
    if (lower.contains('christmas') || lower.contains('xmas')) {
      return const [Color(0xFF0A2A0A), Color(0xFF1A5C1A)];
    }
    if (lower.contains('uganda') || lower.contains('independence')) {
      return const [Color(0xFF1A2A00), Color(0xFF3A5A00)];
    }
    return const [Color(0xFF1B232A), Color(0xFF0F111A)];
  }

  /// Returns the icon for the theme id.
  static IconData _iconFor(String id) {
    final lower = id.toLowerCase();
    if (lower == 'space' || lower == 'default') return Icons.star_rounded;
    if (lower.contains('new_year') || lower == 'newyear') {
      return Icons.celebration_rounded;
    }
    if (lower.contains('christmas') || lower.contains('xmas')) {
      return Icons.ac_unit_rounded;
    }
    if (lower.contains('uganda') || lower.contains('independence')) {
      return Icons.flag_rounded;
    }
    return Icons.palette_rounded;
  }

  /// Returns the icon color for the theme id.
  static Color _iconColorFor(String id) {
    final lower = id.toLowerCase();
    if (lower.contains('uganda') || lower.contains('independence')) {
      return const Color(0xFFFCDC04);
    }
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final isSelected =
        ThemeProvider.instance.selectedThemeId == theme.id;
    final displayName = _formatName(theme.id);
    final gradientColors = _gradientFor(theme.id);
    final icon = _iconFor(theme.id);
    final iconColor = _iconColorFor(theme.id);

    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        await ThemeProvider.instance.applyRemoteTheme(theme.id);
        onApplied();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$displayName theme applied',
                style: const TextStyle(fontFamily: 'Inter'),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: const Color(0xFF00D2FF), width: 2)
              : Border.all(color: AppColors.border, width: 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF00D2FF).withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Gradient background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

              // Center icon + label
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: iconColor, size: 32),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),

              // SERVER badge — top-left
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'SERVER',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),

              // Selected checkmark badge — bottom-right
              if (isSelected)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00D2FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.black,
                      size: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
