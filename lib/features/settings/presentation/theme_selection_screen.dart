import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
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
          // ── THEME CARDS (2-column, aspect ratio ~0.72) ───────────
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

              // VIP Festive — Ramadan
              _VipPresetCard(
                name: 'Ramadan 2025',
                gradientColors: const [Color(0xFF1A0A2E), Color(0xFF4A1A6E)],
                icon: Icons.nightlight_round,
                iconColor: const Color(0xFFFFD700),
                onTap: () => _showVipSnackBar(context),
              ),

              // VIP Festive — Diwali
              _VipPresetCard(
                name: 'Happy Diwali',
                gradientColors: const [Color(0xFF2D1B00), Color(0xFF8B4500)],
                icon: Icons.local_fire_department_rounded,
                iconColor: const Color(0xFFFF6B00),
                onTap: () => _showVipSnackBar(context),
              ),

              // VIP Festive — Christmas
              _VipPresetCard(
                name: 'Christmas',
                gradientColors: const [Color(0xFF0A2A0A), Color(0xFF1A5C1A)],
                icon: Icons.ac_unit_rounded,
                iconColor: Colors.white,
                onTap: () => _showVipSnackBar(context),
              ),

              // VIP Festive — New Year
              _VipPresetCard(
                name: 'New Year',
                gradientColors: const [Color(0xFF0A0A2A), Color(0xFF1A1A6E)],
                icon: Icons.celebration_rounded,
                iconColor: AppColors.accent,
                onTap: () => _showVipSnackBar(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showVipSnackBar(BuildContext context) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'VIP themes coming soon',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        behavior: SnackBarBehavior.floating,
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

// ── VIP Preset Card ───────────────────────────────────────────────────

class _VipPresetCard extends StatelessWidget {
  final String name;
  final List<Color> gradientColors;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _VipPresetCard({
    required this.name,
    required this.gradientColors,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
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
                      name,
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

              // VIP badge — top-left
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'VIP',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      fontFamily: 'Inter',
                    ),
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
